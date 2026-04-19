import http from 'node:http';
import { execFile, spawn } from 'node:child_process';
import { createHash } from 'node:crypto';
import { promisify } from 'node:util';
import { closeSync, createReadStream, createWriteStream, existsSync, mkdirSync, openSync, readdirSync, readFileSync, readSync, statSync, writeFileSync } from 'node:fs';
import { homedir, tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');

function parseEnvFile(path) {
  if (!existsSync(path)) return {};
  const result = {};
  for (const line of readFileSync(path, 'utf8').split(/\r?\n/)) {
    const match = /^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/.exec(line);
    if (match) result[match[1]] = match[2];
  }
  return result;
}

/** Merge repo-root `.env` into `process.env` for keys not already set (so `npm start` picks up NG_* without a shell wrapper). */
function applyRepoEnv() {
  const parsed = parseEnvFile(join(root, '.env'));
  for (const [key, value] of Object.entries(parsed)) {
    if (process.env[key] === undefined) process.env[key] = value;
  }
}
applyRepoEnv();

/** Directory basename segments that imply state was pointed at a non-Webkitium checkout (still matched for sanitization). */
const FOREIGN_NG_SEGMENTS = new Set(['WebKit-ng', 'webkit-ng']);

function pathHasForeignNgTreeSegment(p) {
  return resolve(p).split(/[/\\]/).some((seg) => FOREIGN_NG_SEGMENTS.has(seg));
}

function defaultWebkitiumStateDir() {
  const candidates = [];
  if (process.env.XDG_STATE_HOME) candidates.push(join(process.env.XDG_STATE_HOME, 'webkitium'));
  candidates.push(join(homedir(), '.local/state/webkitium'));
  for (const c of candidates) {
    if (!pathHasForeignNgTreeSegment(c)) return resolve(c);
  }
  return join(tmpdir(), `webkitium-${process.uid}`);
}

function resolveStateDir() {
  let dir;
  if (process.env.NG_VAR_DIR) dir = resolve(process.env.NG_VAR_DIR);
  else if (process.env.WEBKITIUM_STATE_DIR) dir = resolve(process.env.WEBKITIUM_STATE_DIR);
  else if (process.env.XDG_STATE_HOME) dir = join(process.env.XDG_STATE_HOME, 'webkitium');
  else dir = join(homedir(), '.local/state/webkitium');
  if (pathHasForeignNgTreeSegment(dir)) return defaultWebkitiumStateDir();
  return dir;
}

const serviceDir = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const dashboardPath = join(serviceDir, 'public', 'index.html');
const varDir = resolveStateDir();
const logDir = join(varDir, 'logs');
const stateFile = join(varDir, 'state.json');
const port = Number(process.env.PORT || 8787);
const running = new Map();
const execFileAsync = promisify(execFile);

mkdirSync(logDir, { recursive: true });

function loadDashboardHtml() {
  if (!existsSync(dashboardPath)) {
    return `<!DOCTYPE html><html><head><meta charset="utf-8"/><title>Webkitium</title></head><body>
<p>Dashboard missing. Add <code>orchestrator/public/index.html</code> (see repo).</p>
<p><a href="/meta">API meta</a></p></body></html>`;
  }
  return readFileSync(dashboardPath, 'utf8');
}

const dashboardHtml = loadDashboardHtml();

function html(res, status, body) {
  res.writeHead(status, {
    'content-type': 'text/html; charset=utf-8',
    'cache-control': 'no-store'
  });
  res.end(body);
}

class HttpError extends Error {
  constructor(statusCode, message) {
    super(message);
    this.statusCode = statusCode;
  }
}

function badRequest(message) {
  throw new HttpError(400, message);
}

function now() {
  return new Date().toISOString();
}

function stableJson(value) {
  if (Array.isArray(value)) return `[${value.map(stableJson).join(',')}]`;
  if (value && typeof value === 'object') {
    return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${stableJson(value[key])}`).join(',')}}`;
  }
  return JSON.stringify(value);
}

function sha256Json(value) {
  return createHash('sha256').update(stableJson(value)).digest('hex');
}

function loadState() {
  if (!existsSync(stateFile)) return { builds: [] };
  return JSON.parse(readFileSync(stateFile, 'utf8'));
}

function activeBuildsFromMarkerFiles() {
  const markers = [
    { platform: 'windows', path: join(varDir, 'WINDOWS_ACTIVE_BUILD.env'), idKey: 'WINDOWS_BUILD_ID' },
    { platform: 'macos', path: join(varDir, 'MACOS_ACTIVE_BUILD.env'), idKey: 'MACOS_BUILD_ID' },
    { platform: 'android', path: join(varDir, 'ANDROID_ACTIVE_BUILD.env'), idKey: 'ANDROID_BUILD_ID' }
  ];

  return markers.flatMap(({ platform, path, idKey }) => {
    const env = parseEnvFile(path);
    const id = env[idKey];
    if (!id) return [];
    const request = { env, platformEnv: { [platform]: env }, external: true };
    const inferred = inferExternalBuildStatusFromLog(id, platform);
    const logFile = existsSync(join(logDir, `${id}-${platform}.service.log`))
      ? join(logDir, `${id}-${platform}.service.log`)
      : join(logDir, `${id}-${platform}.log`);
    return [{
      id,
      status: inferred.status,
      reason: `external ${platform} build (marker file; ${inferred.detail})`,
      createdAt: null,
      updatedAt: now(),
      external: true,
      externalMarker: true,
      externalInference: inferred.detail,
      platforms: [{
        name: platform,
        status: inferred.status,
        external: true,
        externalInference: inferred.detail,
        remote: inferred.remote,
        progress: inferred.progress,
        cache: inferred.cache,
        artifactValidity: inferred.artifactValidity,
        log: logFile,
        artifactPrefix: artifactPrefixForPlatform(id, platform, request),
        workdir: env[`${platform.toUpperCase()}_BUILD_POLL_WORKDIR`],
        ssmCommandId: env[`${platform.toUpperCase()}_SSM_COMMAND_ID`],
        ssmInstanceId: env[`${platform.toUpperCase()}_SSM_INSTANCE_ID`],
        region: env.AWS_REGION
      }],
      request
    }];
  });
}

function mergeMarkerBuildsById(markerBuilds) {
  const rank = (s) => ({ failed: 5, cancelled: 5, cancelling: 4, running: 3, unknown: 2, succeeded: 1 }[s] ?? 0);
  const pick = (a, b) => (rank(a) >= rank(b) ? a : b);
  const byId = new Map();
  for (const build of markerBuilds) {
    const prev = byId.get(build.id);
    if (!prev) {
      byId.set(build.id, { ...build, platforms: [...(build.platforms || [])] });
      continue;
    }
    prev.platforms = [...(prev.platforms || []), ...(build.platforms || [])];
    prev.status = pick(prev.status, build.status);
    prev.reason = [prev.reason, build.reason].filter(Boolean).join(' · ');
    prev.updatedAt = now();
  }
  return [...byId.values()];
}

function loadBuilds() {
  const state = loadState();
  const builds = [...(state.builds || [])];
  const byId = new Map(builds.map((build) => [build.id, build]));
  for (const build of mergeMarkerBuildsById(activeBuildsFromMarkerFiles())) {
    const existing = byId.get(build.id);
    if (!existing) {
      builds.unshift(build);
      continue;
    }
    existing.externalMarker = true;
    existing.externalInference = build.externalInference;
    existing.updatedAt = now();
    for (const markerPlatform of build.platforms || []) {
      const platform = existing.platforms?.find((item) => item.name === markerPlatform.name);
      if (!platform) {
        existing.platforms = [...(existing.platforms || []), markerPlatform];
        continue;
      }
      platform.externalMarker = true;
      platform.externalInference = markerPlatform.externalInference;
      platform.remote = markerPlatform.remote;
      platform.progress = markerPlatform.progress;
      platform.cache = markerPlatform.cache;
      platform.artifactValidity = markerPlatform.artifactValidity;
      platform.workdir = platform.workdir || markerPlatform.workdir;
      platform.ssmCommandId = platform.ssmCommandId || markerPlatform.ssmCommandId;
      platform.ssmInstanceId = platform.ssmInstanceId || markerPlatform.ssmInstanceId;
      platform.region = platform.region || markerPlatform.region;
      if (['running', 'unknown'].includes(platform.status) || ['failed', 'cancelled', 'succeeded'].includes(markerPlatform.status)) {
        platform.status = markerPlatform.status;
      }
    }
    existing.status = existing.platforms?.some((item) => item.status === 'cancelling') ? 'cancelling'
      : existing.platforms?.some((item) => item.status === 'running') ? 'running'
      : existing.platforms?.every((item) => item.status === 'succeeded') ? 'succeeded'
      : existing.platforms?.some((item) => item.status === 'cancelled') ? 'cancelled'
      : existing.platforms?.some((item) => item.status === 'failed') ? 'failed'
      : existing.status;
  }
  return builds;
}

function saveState(state) {
  mkdirSync(varDir, { recursive: true });
  writeFileSync(stateFile, JSON.stringify(state, null, 2));
}

function updateBuild(id, patch) {
  const state = loadState();
  const build = state.builds.find((item) => item.id === id);
  if (!build) return null;
  Object.assign(build, patch, { updatedAt: now() });
  saveState(state);
  return build;
}

function json(res, status, payload) {
  res.writeHead(status, {
    'content-type': 'application/json',
    'cache-control': 'no-store',
    'access-control-allow-origin': '*'
  });
  res.end(JSON.stringify(payload, null, 2));
}

async function body(req) {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  if (!chunks.length) return {};
  try {
    return JSON.parse(Buffer.concat(chunks).toString('utf8'));
  } catch {
    badRequest('request body must be valid JSON');
  }
}

function normalizeStringRecord(value, label) {
  if (value === undefined || value === null) return {};
  if (typeof value !== 'object' || Array.isArray(value)) {
    badRequest(`${label} must be an object of string keys and string/number/boolean values`);
  }

  const result = {};
  for (const [key, raw] of Object.entries(value)) {
    if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(key)) {
      badRequest(`${label}.${key} is not a valid environment variable name`);
    }
    if (raw === undefined || raw === null) continue;
    if (!['string', 'number', 'boolean'].includes(typeof raw)) {
      badRequest(`${label}.${key} must be a string, number, or boolean`);
    }
    result[key] = String(raw);
  }
  return result;
}

function validateBuildEnvPayload(payload) {
  normalizeStringRecord(payload.env, 'env');
  const platformEnv = payload.platformEnv || {};
  if (typeof platformEnv !== 'object' || Array.isArray(platformEnv)) {
    badRequest('platformEnv must be an object keyed by platform');
  }
  for (const [platform, env] of Object.entries(platformEnv)) {
    normalizeStringRecord(env, `platformEnv.${platform}`);
  }
}

function platformConfig() {
  return readJsonFile(join(root, 'config', 'platforms.json')).platforms || {};
}

function normalizePlatforms(value) {
  const platforms = value || ['android', 'windows', 'macos'];
  if (!Array.isArray(platforms) || platforms.length === 0) {
    badRequest('platforms must be a non-empty array');
  }

  const configs = platformConfig();
  const seen = new Set();
  const result = [];
  for (const platform of platforms) {
    if (typeof platform !== 'string' || !platform) {
      badRequest('platforms entries must be non-empty strings');
    }
    const config = configs[platform];
    if (!config) {
      badRequest(`Unknown platform: ${platform}`);
    }
    if (config.status === 'empty') {
      badRequest(`Platform is not wired yet: ${platform}`);
    }
    if (!seen.has(platform)) {
      seen.add(platform);
      result.push(platform);
    }
  }
  return result;
}

function normalizePresetPayload(value) {
  if (value === undefined || value === null) return {};
  if (typeof value !== 'object' || Array.isArray(value)) {
    badRequest('presets must be an object keyed by platform');
  }

  const result = {};
  for (const [platform, raw] of Object.entries(value)) {
    if (typeof raw !== 'string') {
      badRequest(`presets.${platform} must be a string`);
    }
    result[platform] = raw;
  }
  return result;
}

function expandBuildRequest(payload, platforms) {
  const presets = normalizePresetPayload(payload.presets || payload.platformPresets);
  const phase = normalizeBuildPhase(payload.phase);
  const configs = platformConfig();
  const platformEnv = {};

  for (const platform of platforms) {
    const presetName = presets[platform];
    const configuredPreset = presetName ? configs[platform]?.presets?.[presetName] : null;
    if (presetName && !configuredPreset) {
      badRequest(`Unknown preset for ${platform}: ${presetName}`);
    }
    platformEnv[platform] = {
      ...normalizeStringRecord(configuredPreset?.env, `presets.${platform}.${presetName}.env`),
      ...normalizeStringRecord(payload.platformEnv?.[platform], `platformEnv.${platform}`)
    };
    if (platform === 'windows') {
      if (platformEnv[platform].NG_WINDOWS_ENABLE_SCCACHE && platformEnv[platform].NG_WINDOWS_ENABLE_SCCACHE !== '1') {
        badRequest('Windows builds require NG_WINDOWS_ENABLE_SCCACHE=1');
      }
      platformEnv[platform].NG_WINDOWS_ENABLE_SCCACHE = '1';
      if (phase && !platformEnv[platform].NG_BUILD_PHASE)
        platformEnv[platform].NG_BUILD_PHASE = String(phase);
    }
  }

  const expanded = {
    ...payload,
    phase,
    reason: normalizeBuildReason(payload.reason, platforms, presets, phase),
    presets,
    platformEnv
  };
  const profile = buildProfileForRequest(expanded, platforms);
  return {
    ...expanded,
    controlPlane: {
      schema: 1,
      profileHash: sha256Json(profile),
      profile,
      lanes: Object.fromEntries(platforms.map((platform) => [platform, laneForPlatform(platform, expanded)]))
    }
  };
}

function laneForPlatform(platform, request) {
  const preset = request.presets?.[platform] || 'default';
  const env = request.platformEnv?.[platform] || {};
  const webgpu = env.NG_WINDOWS_ENABLE_WEBGPU === '1' ? 'webgpu-on' : platform === 'windows' ? 'webgpu-off' : '';
  return [platform, preset, webgpu].filter(Boolean).join('/');
}

function buildProfileForRequest(request, platforms) {
  return {
    platforms,
    presets: request.presets || {},
    env: normalizeStringRecord(request.env, 'env'),
    platformEnv: Object.fromEntries(platforms.map((platform) => [platform, normalizeStringRecord(request.platformEnv?.[platform], `platformEnv.${platform}`)])),
    phase: request.phase || null
  };
}

function normalizeBuildPhase(value) {
  if (value === undefined || value === null || value === '') return null;
  const phase = Number(value);
  if (!Number.isInteger(phase) || phase < 1 || phase > 6)
    badRequest('phase must be an integer from 1 to 6');
  return phase;
}

function normalizeBuildReason(reason, platforms, presets, phase) {
  const raw = String(reason || '').trim();
  const isWindowsWebGPU = platforms.includes('windows') && ['webgpu-dawn', 'webgpu-dawn-fast'].includes(presets.windows);
  if (!isWindowsWebGPU) return raw;
  if (/^webgpu phase \d+:/i.test(raw)) return raw;
  if (phase) return `webgpu phase ${phase}: ${raw || defaultWebGPUPhaseReason(phase)}`;
  if (!raw) return 'webgpu: windows dawn build';
  if (/^webgpu\b/i.test(raw)) return raw;
  return `webgpu: ${raw}`;
}

function defaultWebGPUPhaseReason(phase) {
  switch (phase) {
  case 1:
    return 'foundations reproducible build';
  case 2:
    return 'in-process compute readback';
  case 3:
    return 'canvas present and animation';
  case 4:
    return 'multi-process evaluation';
  case 5:
    return 'conformance subset';
  case 6:
    return 'hardening sustainment';
  default:
    return 'windows dawn build';
  }
}

function artifactPrefixForPlatform(id, platform, request) {
  const env = {
    ...process.env,
    ...normalizeStringRecord(request?.env, 'env'),
    ...normalizeStringRecord(request?.platformEnv?.[platform], `platformEnv.${platform}`)
  };
  const bucket = env.NG_ARTIFACT_BUCKET || 's3://cory-build-artifacts-euc1-095713295645-20260407/webkitium';
  if (platform === 'windows') return env.NG_WINDOWS_ARTIFACT_S3 || `${bucket}/windows/${id}`;
  if (platform === 'macos') return env.NG_MACOS_ARTIFACT_S3 || `${bucket}/macos/${id}`;
  if (platform === 'android') return env.NG_ANDROID_ARTIFACT_S3 || `${bucket}/android/${id}`;
  return `${bucket}/${platform}/${id}`;
}

function artifactLinksForPlatform(id, platform, request) {
  const artifactPrefix = artifactPrefixForPlatform(id, platform, request);
  const links = { artifactPrefix };
  if (platform === 'android') {
    links.gradleLog = `${artifactPrefix}/gradle-android.log`;
  }
  if (platform === 'windows') {
    links.validationReport = `${artifactPrefix}/validation-report.json`;
    links.validationRecovered = `${artifactPrefix}/validation-recovered.json`;
    links.sccacheReport = `${artifactPrefix}/sccache-report.json`;
    links.patchManifest = `${artifactPrefix}/patch-manifest.json`;
    links.manifestPre = `${artifactPrefix}/manifest-pre.json`;
    links.manifestPost = `${artifactPrefix}/manifest-post.json`;
    links.buildProgress = `${artifactPrefix}/build-progress.json`;
    links.releaseTarball = `${artifactPrefix}/webkitium-windows-${id}.tar.gz`;
  }
  if (platform === 'macos') {
    links.releaseTarball = `${artifactPrefix}/webkitium-macos-${id}.tar.gz`;
  }
  return links;
}

function defaultCheckpointMessage(build, payload) {
  const phase = normalizeBuildPhase(payload.phase ?? build.request?.phase);
  const windows = (build.platforms || []).find((platform) => platform.name === 'windows');
  if (phase === 1 && windows) {
    const artifacts = windows.artifacts || artifactLinksForPlatform(build.id, 'windows', build.request || {});
    return `Phase 1 gate met: preset=${build.request?.presets?.windows || 'default'} artifact=${artifacts.artifactPrefix} validation=${artifacts.validationReport}`;
  }
  if (phase === 2 && windows) {
    const artifacts = windows.artifacts || artifactLinksForPlatform(build.id, 'windows', build.request || {});
    return `Phase 2 checkpoint: compute smoke target; artifact=${artifacts.artifactPrefix} validation=${artifacts.validationReport}`;
  }
  return 'manual checkpoint';
}

function buildEnvForPlatform(build, platform) {
  const request = build.request || {};
  return {
    ...process.env,
    ...normalizeStringRecord(request.env, 'env'),
    ...normalizeStringRecord(request.platformEnv?.[platform], `platformEnv.${platform}`),
    NG_SERVICE_BUILD_ID: build.id,
    NG_SERVICE_PLATFORM: platform,
    NG_CONTROL_PROFILE_HASH: request.controlPlane?.profileHash || '',
    NG_CONTROL_LANE: request.controlPlane?.lanes?.[platform] || ''
  };
}

function platformRuntimeControl(id, platform, request) {
  const env = {
    ...process.env,
    ...normalizeStringRecord(request?.env, 'env'),
    ...normalizeStringRecord(request?.platformEnv?.[platform], `platformEnv.${platform}`)
  };
  if (platform === 'windows') {
    const mutationDir = env.NG_WINDOWS_CLEAN_SOURCE || (env.NG_WINDOWS_FAST_RETRY === '1' ? (env.NG_WINDOWS_FAST_CLEAN_SOURCE || 'C:/W/webkitium-fast') : `C:/W/n<${id}>`);
    return {
      workdir: env.NG_WINDOWS_WORKDIR || `C:/Bootstrap/webkitium-${id}`,
      mutationDir,
      ssmInstanceId: env.NG_WINDOWS_INSTANCE_ID || process.env.NG_WINDOWS_INSTANCE_ID || 'i-05ab9a8ed6d325b3d',
      region: env.AWS_REGION || process.env.AWS_REGION || 'eu-west-1'
    };
  }
  return {};
}

function leaseKeyForPlatform(id, platform, request) {
  const runtime = platformRuntimeControl(id, platform, request);
  const lane = request.controlPlane?.lanes?.[platform] || `${platform}/default`;
  return [platform, lane, runtime.mutationDir || runtime.workdir || 'local'].join(':');
}

function assertNoActiveLease(platforms, request) {
  const requested = new Map(platforms.map((platform) => [platform, leaseKeyForPlatform('pending', platform, request)]));
  const active = loadBuilds().filter((build) => ['running', 'cancelling'].includes(build.status));
  for (const build of active) {
    for (const platform of build.platforms || []) {
      if (!['running', 'cancelling'].includes(platform.status)) continue;
      const requestedLease = requested.get(platform.name);
      if (!requestedLease) continue;
      const existingLease = platform.controlPlane?.leaseKey || leaseKeyForPlatform(build.id, platform.name, build.request || {});
      if (existingLease === requestedLease) {
        throw new HttpError(409, `Active build ${build.id} already owns lease ${existingLease}`);
      }
    }
  }
}

function startPlatformBuild(build, platform) {
  const logPath = join(logDir, `${build.id}-${platform}.service.log`);
  writeFileSync(logPath, `[${now()}] starting ${platform} build ${build.id}\n`, { flag: 'a' });
  const child = spawn(join(root, 'webkit', 'scripts', 'common', 'run-build.sh'), [platform, build.id], {
    cwd: root,
    env: buildEnvForPlatform(build, platform),
    stdio: ['ignore', 'pipe', 'pipe']
  });

  const logStream = createWriteStream(logPath, { flags: 'a' });
  child.stdout.pipe(logStream, { end: false });
  child.stderr.pipe(logStream, { end: false });

  running.set(`${build.id}:${platform}`, child);
  const started = loadState();
  const storedBuild = started.builds.find((item) => item.id === build.id);
  const storedPlatform = storedBuild?.platforms.find((item) => item.name === platform);
  if (storedPlatform) {
    storedPlatform.pid = child.pid;
    storedPlatform.startedAt = now();
    saveState(started);
  }

  child.on('error', (error) => {
    running.delete(`${build.id}:${platform}`);
    logStream.end(`[${now()}] spawn failed: ${error.message}\n`);
    const current = loadState();
    const stored = current.builds.find((item) => item.id === build.id);
    const target = stored?.platforms.find((item) => item.name === platform);
    if (target) {
      target.status = 'failed';
      target.error = error.message;
      target.finishedAt = now();
    }
    if (stored) {
      stored.status = stored.platforms.some((item) => item.status === 'running') ? 'running' : 'failed';
      stored.updatedAt = now();
      saveState(current);
    }
  });

  child.on('exit', (code, signal) => {
    running.delete(`${build.id}:${platform}`);
    logStream.end();
    const current = loadState();
    const stored = current.builds.find((item) => item.id === build.id);
    if (!stored) return;
    const target = stored.platforms.find((item) => item.name === platform);
    if (!target) return;
    const inferred = inferExternalBuildStatusFromLog(build.id, platform);
    target.status = code === 0 && inferred.status !== 'failed' ? 'succeeded'
      : inferred.status === 'succeeded' ? 'succeeded'
      : inferred.status === 'cancelled' ? 'cancelled'
      : 'failed';
    target.exitCode = code;
    target.signal = signal;
    if (code !== 0 && inferred.status === 'succeeded') {
      target.warning = `runner exited ${code} after remote success marker: ${inferred.detail}`;
    }
    if (inferred.status === 'failed')
      target.error = inferred.detail;
    target.remote = inferred.remote;
    target.progress = inferred.progress;
    target.cache = inferred.cache;
    target.artifactValidity = inferred.artifactValidity;
    target.finishedAt = now();
    stored.status = stored.platforms.some((item) => item.status === 'cancelling') ? 'cancelling'
      : stored.platforms.some((item) => item.status === 'running') ? 'running'
      : stored.platforms.every((item) => item.status === 'succeeded') ? 'succeeded'
      : stored.platforms.some((item) => item.status === 'cancelled') ? 'cancelled'
      : 'failed';
    stored.updatedAt = now();
    saveState(current);
  });
}

function createBuild(platforms, meta = {}) {
  assertNoActiveLease(platforms, meta);
  const id = `${new Date().toISOString().replace(/[-:.]/g, '').slice(0, 15)}-${Math.floor(Math.random() * 100000)}`;
  const build = {
    id,
    status: 'running',
    reason: meta.reason || '',
    createdAt: now(),
    updatedAt: now(),
    platforms: platforms.map((name) => ({
      name,
      status: 'running',
      log: join(logDir, `${id}-${name}.service.log`),
      artifactPrefix: artifactPrefixForPlatform(id, name, meta),
      artifacts: artifactLinksForPlatform(id, name, meta),
      ...platformRuntimeControl(id, name, meta),
      controlPlane: {
        profileHash: meta.controlPlane?.profileHash,
        lane: meta.controlPlane?.lanes?.[name],
        leaseKey: leaseKeyForPlatform(id, name, meta)
      }
    })),
    request: meta
  };
  const state = loadState();
  state.builds.unshift(build);
  saveState(state);
  for (const platform of platforms) startPlatformBuild(build, platform);
  return build;
}

function getBuild(id) {
  return loadBuilds().find((build) => build.id === id);
}

function readJsonFile(path) {
  return JSON.parse(readFileSync(path, 'utf8'));
}

function lastPrefixedJson(text, prefix) {
  const lines = text.split(/\r?\n/).filter((line) => line.startsWith(prefix));
  if (!lines.length) return null;
  const raw = lines[lines.length - 1].slice(prefix.length).trim();
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

async function runCaptured(command, args, options = {}) {
  const startedAt = now();
  try {
    const result = await execFileAsync(command, args, {
      cwd: options.cwd || root,
      env: { ...process.env, ...(options.env || {}) },
      timeout: options.timeout || 120000,
      maxBuffer: options.maxBuffer || 2 * 1024 * 1024,
      windowsHide: true
    });
    return {
      ok: true,
      command,
      args,
      cwd: options.cwd || root,
      startedAt,
      finishedAt: now(),
      stdout: result.stdout,
      stderr: result.stderr
    };
  } catch (error) {
    return {
      ok: false,
      command,
      args,
      cwd: options.cwd || root,
      startedAt,
      finishedAt: now(),
      exitCode: error.code,
      signal: error.signal,
      stdout: error.stdout || '',
      stderr: error.stderr || error.message
    };
  }
}

async function gitStatus() {
  const [head, branch, status, remote, recent] = await Promise.all([
    runCaptured('git', ['rev-parse', 'HEAD']),
    runCaptured('git', ['branch', '--show-current']),
    runCaptured('git', ['status', '--short']),
    runCaptured('git', ['remote', '-v']),
    runCaptured('git', ['log', '--oneline', '-8'])
  ]);
  return {
    head: head.stdout.trim(),
    branch: branch.stdout.trim(),
    dirty: status.stdout.trim().split(/\r?\n/).filter(Boolean),
    remotes: remote.stdout.trim().split(/\r?\n/).filter(Boolean),
    recent: recent.stdout.trim().split(/\r?\n/).filter(Boolean),
    commands: { head, branch, status, remote, recent }
  };
}

function commandExists(command) {
  const check = process.platform === 'win32'
    ? spawn('where.exe', [command], { stdio: 'ignore' })
    : spawn('bash', ['-lc', `command -v ${JSON.stringify(command)} >/dev/null 2>&1`], { stdio: 'ignore' });
  return new Promise((resolve) => {
    check.on('exit', (code) => resolve(code === 0));
    check.on('error', () => resolve(false));
  });
}

async function dependencyStatus() {
  const requiredCommands = ['git', 'python3', 'node', 'npm', 'aws', 'tar'];
  const optionalCommands = ['ruby', 'perl', 'cmake', 'ninja', 'gperf'];
  const checks = {};
  await Promise.all([...requiredCommands, ...optionalCommands].map(async (command) => {
    checks[command] = await commandExists(command);
  }));
  const missingRequired = requiredCommands.filter((command) => !checks[command]);
  const config = readJsonFile(join(root, 'config', 'dependencies.json'));
  return {
    ok: missingRequired.length === 0,
    missingRequired,
    requiredCommands,
    optionalCommands,
    commands: checks,
    config
  };
}

function logFiles() {
  if (!existsSync(logDir)) return [];
  return readdirSync(logDir)
    .filter((name) => /^[A-Za-z0-9._-]+$/.test(name))
    .map((name) => {
      const path = join(logDir, name);
      const stats = statSync(path);
      return { name, size: stats.size, modifiedAt: stats.mtime.toISOString() };
    })
    .sort((a, b) => b.modifiedAt.localeCompare(a.modifiedAt));
}

function requestUrl(url) {
  return new URL(url, `http://127.0.0.1:${port}`);
}

function tailTextFile(path, lineCount) {
  const lines = Math.max(1, Math.min(Number(lineCount) || 200, 15000));
  const stats = statSync(path);
  const bytesToRead = Math.min(stats.size, Math.max(64 * 1024, lines * 300));
  const buffer = Buffer.alloc(bytesToRead);
  const fd = openSync(path, 'r');
  try {
    readSync(fd, buffer, 0, bytesToRead, stats.size - bytesToRead);
  } finally {
    closeSync(fd);
  }
  return buffer.toString('utf8').split(/\r?\n/).slice(-lines).join('\n');
}

/**
 * Marker-file builds (remote SSM) are injected even after completion because
 * WINDOWS_ACTIVE_BUILD.env / MACOS_ACTIVE_BUILD.env / ANDROID_ACTIVE_BUILD.env may linger. Infer terminal
 * status from the orchestrator tee log on this host (no build-script changes).
 */
function inferExternalBuildStatusFromLog(id, platform) {
  const serviceLogPath = join(logDir, `${id}-${platform}.service.log`);
  const directLogPath = join(logDir, `${id}-${platform}.log`);
  const logPath = existsSync(serviceLogPath) ? serviceLogPath : directLogPath;
  const paths = [serviceLogPath, directLogPath].filter((path, index, all) => existsSync(path) && all.indexOf(path) === index);
  if (!paths.length) {
    return { status: 'unknown', detail: 'no orchestrator log file yet', logPath: null };
  }
  let text = '';
  try {
    for (const path of paths) {
      const stats = statSync(path);
      const n = Math.min(stats.size, 384 * 1024);
      const buf = Buffer.alloc(n);
      const fd = openSync(path, 'r');
      try {
        readSync(fd, buf, 0, n, stats.size - n);
      } finally {
        closeSync(fd);
      }
      text += `\n--- ${path} ---\n${buf.toString('utf8')}`;
    }
  } catch (e) {
    return { status: 'unknown', detail: `log read failed: ${e.message}`, logPath };
  }

  const remote = lastPrefixedJson(text, 'WORKER_STATUS_JSON ');
  const progress = lastPrefixedJson(text, 'WORKER_PROGRESS_JSON ');
  const cache = lastPrefixedJson(text, 'WORKER_CACHE_JSON ');
  const artifactValidity = lastPrefixedJson(text, 'WORKER_ARTIFACT_VALIDITY_JSON ');

  const cancelled = /BUILD_CANCELLED\.txt|^CANCELLED\b|cancelled by orchestrator/im.test(text) || remote?.status === 'cancelled';
  const failed = /remote build FAILED|BUILD_FAILED\.txt|Timed out waiting for BUILD_DONE|ninja: build stopped: subcommand failed|marker poll unexpected|bootstrap SSM failure/i.test(
    text
  ) || remote?.status === 'failed';
  const ok =
    /marker poll OK|remote build completed|checkpoint\.sh.*completed|windows remote build completed|macos remote build completed|android remote build completed/i.test(text) ||
    /BUILD_DONE\.txt/i.test(text) || remote?.status === 'succeeded';

  if (cancelled) return { status: 'cancelled', detail: 'remote worker acknowledged cancellation', logPath, remote, progress, cache, artifactValidity };
  if (failed && ok) return { status: 'failed', detail: 'log contains both success and failure markers; treating as failed', logPath };
  if (failed) return { status: 'failed', detail: 'inferred from orchestrator log', logPath, remote, progress, cache, artifactValidity };
  if (ok) return { status: 'succeeded', detail: 'inferred from orchestrator log', logPath, remote, progress, cache, artifactValidity };

  try {
    const ageMs = Date.now() - statSync(logPath).mtimeMs;
    if (ageMs > 48 * 60 * 60 * 1000) {
      return { status: 'unknown', detail: 'log idle >48h with no terminal pattern; refresh markers or open log', logPath, remote, progress, cache, artifactValidity };
    }
  } catch {
    // ignore
  }

  return { status: remote?.status === 'cancelling' ? 'cancelling' : 'running', detail: 'no terminal pattern in log tail yet', logPath, remote, progress, cache, artifactValidity };
}

async function requestWindowsRemoteCancel(build, platform) {
  const env = {
    ...process.env,
    ...normalizeStringRecord(build.request?.env, 'env'),
    ...normalizeStringRecord(build.request?.platformEnv?.windows, 'platformEnv.windows')
  };
  const instance = platform.ssmInstanceId || env.NG_WINDOWS_INSTANCE_ID || process.env.NG_WINDOWS_INSTANCE_ID;
  const region = env.AWS_REGION || process.env.AWS_REGION || 'eu-west-1';
  const workdir = platform.workdir || env.NG_WINDOWS_WORKDIR;
  if (!instance || !workdir) {
    return { ok: false, error: 'missing Windows instance id or workdir for remote cancel' };
  }
  const script = `$ErrorActionPreference = 'Continue'
$d = ${JSON.stringify(workdir)}
New-Item -ItemType Directory -Force -Path $d | Out-Null
"cancel requested $(Get-Date -Format o) by orchestrator" | Set-Content -Path (Join-Path $d 'CANCEL_REQUESTED.txt') -Encoding UTF8
$status = [ordered]@{ buildId = ${JSON.stringify(build.id)}; status = 'cancelling'; stage = 'cancel-requested'; updated = (Get-Date).ToUniversalTime().ToString('o') }
($status | ConvertTo-Json -Compress) | Set-Content -Path (Join-Path $d 'status.json') -Encoding UTF8
Write-Output 'CANCEL_REQUESTED'
`;
  const paramsPath = join(logDir, `${build.id}-windows-cancel-params.json`);
  writeFileSync(paramsPath, JSON.stringify({ commands: [script] }));
  return runCaptured('aws', [
    'ssm', 'send-command',
    '--region', region,
    '--instance-ids', instance,
    '--document-name', 'AWS-RunPowerShellScript',
    '--comment', `Webkitium cancel ${build.id}`,
    '--parameters', `file://${paramsPath}`,
    '--query', 'Command.CommandId',
    '--output', 'text'
  ], { timeout: 120000, maxBuffer: 512 * 1024 });
}

const server = http.createServer(async (req, res) => {
  try {
    const url = requestUrl(req.url);
    const parts = url.pathname.split('/').filter(Boolean);

    if (req.method === 'OPTIONS') {
      res.writeHead(204, {
        'access-control-allow-origin': '*',
        'access-control-allow-methods': 'GET,POST,OPTIONS',
        'access-control-allow-headers': 'content-type'
      });
      return res.end();
    }

    if (req.method === 'GET' && parts.length === 0) {
      return html(res, 200, dashboardHtml);
    }

    if (req.method === 'GET' && parts[0] === 'meta' && parts.length === 1) {
      const envPath = join(root, '.env');
      return json(res, 200, {
        name: 'Webkitium build service',
        dashboard: 'GET /',
        repoEnvFile: envPath,
        repoEnvPresent: existsSync(envPath),
        endpoints: [
          'GET /health',
          'GET /git',
          'POST /git/pull',
          'GET /platforms',
          'GET /dependencies',
          'GET /dependencies/status',
          'GET /logs',
          'GET /logs/:name?tail=200',
          'GET /builds',
          'POST /builds',
          'POST /builds?dryRun=1',
          'GET /builds/:id',
          'GET /builds/:id/artifacts',
          'GET /builds/:id/logs/:platform?tail=200',
          'POST /builds/:id/restart',
          'POST /builds/:id/checkpoint',
          'POST /builds/:id/cancel'
        ]
      });
    }

    if (req.method === 'GET' && parts[0] === 'git' && parts.length === 1) {
      return json(res, 200, await gitStatus());
    }

    if (req.method === 'POST' && parts[0] === 'git' && parts[1] === 'pull' && parts.length === 2) {
      const payload = await body(req);
      const args = payload?.rebase ? ['pull', '--ff-only', '--rebase'] : ['pull', '--ff-only'];
      const result = await runCaptured('git', args, { timeout: 5 * 60 * 1000 });
      writeFileSync(join(logDir, 'api-git-pull.log'), `[${now()}] git ${args.join(' ')}\n${result.stdout}\n${result.stderr}\n`, { flag: 'a' });
      return json(res, result.ok ? 200 : 500, result);
    }

    if (req.method === 'GET' && parts[0] === 'health' && parts.length === 1) {
      return json(res, 200, {
        ok: true,
        time: now(),
        root,
        port,
        running: [...running.keys()]
      });
    }

    if (req.method === 'GET' && parts[0] === 'platforms' && parts.length === 1) {
      return json(res, 200, readJsonFile(join(root, 'config', 'platforms.json')));
    }

    if (req.method === 'GET' && parts[0] === 'builds' && parts.length === 1) {
      return json(res, 200, loadBuilds());
    }

    if (req.method === 'GET' && parts[0] === 'changes' && parts.length === 1) {
      return json(res, 200, {
        config: readJsonFile(join(root, 'config', 'changes.json')),
        note: 'Enable changes in config/changes.json; patches live under changes/<id>.'
      });
    }

    if (req.method === 'GET' && parts[0] === 'dependencies' && parts.length === 1) {
      const catalogPath = join(varDir, 'dependency-catalog.json');
      return json(res, 200, {
        config: readJsonFile(join(root, 'config', 'dependencies.json')),
        catalog: existsSync(catalogPath) ? readJsonFile(catalogPath) : null
      });
    }

    if (req.method === 'GET' && parts[0] === 'dependencies' && parts[1] === 'status' && parts.length === 2) {
      return json(res, 200, await dependencyStatus());
    }

    if (req.method === 'GET' && parts[0] === 'logs' && parts.length === 1) {
      return json(res, 200, { logDir, logs: logFiles() });
    }

    if (req.method === 'GET' && parts[0] === 'logs' && parts[1] && parts.length === 2) {
      const name = parts[1];
      if (!/^[A-Za-z0-9._-]+$/.test(name)) return json(res, 400, { error: 'invalid log name' });
      const logPath = join(logDir, name);
      if (!existsSync(logPath)) return json(res, 404, { error: 'log not found' });
      if (url.searchParams.has('tail')) {
        res.writeHead(200, { 'content-type': 'text/plain' });
        return res.end(tailTextFile(logPath, url.searchParams.get('tail')));
      }
      res.writeHead(200, { 'content-type': 'text/plain' });
      return createReadStream(logPath).pipe(res);
    }

    if (req.method === 'POST' && parts[0] === 'builds' && parts.length === 1) {
      const payload = await body(req);
      const platforms = normalizePlatforms(payload.platforms);
      validateBuildEnvPayload(payload);
      const request = expandBuildRequest(payload, platforms);
      if (url.searchParams.get('dryRun') === '1' || url.searchParams.get('dryRun') === 'true') {
        return json(res, 200, {
          ok: true,
          dryRun: true,
          platforms,
          request,
          artifactPrefixes: Object.fromEntries(platforms.map((platform) => [platform, artifactPrefixForPlatform('dry-run', platform, request)]))
        });
      }
      return json(res, 202, createBuild(platforms, request));
    }

    if (parts[0] === 'builds' && parts[1]) {
      const build = getBuild(parts[1]);
      if (!build) return json(res, 404, { error: 'build not found' });

      if (req.method === 'GET' && parts.length === 2) return json(res, 200, build);

      if (req.method === 'GET' && parts[2] === 'artifacts' && parts.length === 3) {
        return json(res, 200, {
          buildId: build.id,
          platforms: build.platforms.map((platform) => ({
            name: platform.name,
            status: platform.status,
            artifactPrefix: platform.artifactPrefix,
            artifacts: platform.artifacts || artifactLinksForPlatform(build.id, platform.name, build.request || {}),
            artifactValidity: platform.artifactValidity || null
          }))
        });
      }

      if (req.method === 'GET' && parts[2] === 'logs' && parts[3]) {
        const platform = parts[3];
        const serviceLogPath = join(logDir, `${build.id}-${platform}.service.log`);
        const directLogPath = join(logDir, `${build.id}-${platform}.log`);
        const logPath = existsSync(serviceLogPath) ? serviceLogPath : directLogPath;
        if (!existsSync(logPath)) return json(res, 404, { error: 'log not found' });
        if (url.searchParams.has('tail')) {
          res.writeHead(200, { 'content-type': 'text/plain' });
          return res.end(tailTextFile(logPath, url.searchParams.get('tail')));
        }
        res.writeHead(200, { 'content-type': 'text/plain' });
        return createReadStream(logPath).pipe(res);
      }

      if (req.method === 'POST' && parts[2] === 'checkpoint') {
        const payload = await body(req);
        const checkpoint = {
          time: now(),
          phase: normalizeBuildPhase(payload.phase ?? build.request?.phase),
          message: payload.message || defaultCheckpointMessage(build, payload)
        };
        const updated = updateBuild(build.id, { checkpoints: [...(build.checkpoints || []), checkpoint] });
        return json(res, 200, updated);
      }

      if (req.method === 'POST' && parts[2] === 'cancel') {
        const cancelResults = [];
        for (const platform of build.platforms) {
          const child = running.get(`${build.id}:${platform.name}`);
          if (child) child.kill('SIGTERM');
          if (platform.name === 'windows' && platform.status === 'running') {
            platform.status = 'cancelling';
            platform.cancelRequestedAt = now();
            // The runner, not agents, owns the remote SSM cancel request.
            cancelResults.push({ platform: 'windows', result: await requestWindowsRemoteCancel(build, platform) });
          } else {
            platform.status = platform.status === 'running' ? 'cancelled' : platform.status;
          }
        }
        const status = build.platforms.some((platform) => platform.status === 'cancelling') ? 'cancelling' : 'cancelled';
        const updated = updateBuild(build.id, { status, platforms: build.platforms, cancelResults });
        return json(res, 200, updated);
      }

      if (req.method === 'POST' && parts[2] === 'restart') {
        const payload = await body(req);
        const platforms = normalizePlatforms(payload.platforms || build.platforms.map((platform) => platform.name));
        validateBuildEnvPayload(payload);
        const request = expandBuildRequest({ reason: `restart of ${build.id}`, restartedFrom: build.id, ...payload }, platforms);
        return json(res, 202, createBuild(platforms, request));
      }
    }

    return json(res, 404, { error: 'not found' });
  } catch (error) {
    const status = error.statusCode || (error instanceof SyntaxError ? 400 : 500);
    return json(res, status, { error: error.message, stack: process.env.NODE_ENV === 'production' ? undefined : error.stack });
  }
});

server.listen(port, '0.0.0.0', () => {
  console.log(`Webkitium build service listening on http://127.0.0.1:${port}/ (dashboard + API)`);
});
