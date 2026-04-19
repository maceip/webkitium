# Incident: overlapping builds and poisoned build cache

Date: 2026-04-19

Scope: Windows MiniBrowser marketing build, Webkitium runner, Windows WebKit build cache handling.

## Summary

The build pipeline lost control of state during what should have been a small
Windows MiniBrowser chrome paint build. Instead of producing a fast marketing
artifact from a known-good WebKit configuration, the process drifted into
multiple overlapping build attempts, mixed patch scopes, and an unsafe retry
path that reused a stale `WebKitBuild` directory.

The immediate visible failure was not caused by the gradient paint patch. A fast
retry reused a poisoned `WebKitBuild` cache whose CMake/Ninja state still pointed
at an invalid compiler launcher/toolchain combination. That turned the next
compile into a failure in Windows/MSVC headers before the MiniBrowser code could
be meaningfully tested.

The larger failure was process-level: the runner allowed an untrusted build
state to be treated as reusable, and humans/agents could keep launching new work
without a reliable "known green state" contract.

## What happened

The intended task was narrow:

- keep WebGPU off
- apply the Windows MiniBrowser gradient and app icon work
- build a Windows artifact suitable for screenshots/marketing
- avoid broader WebGPU/Dawn patch churn

Instead, the work ran through a build environment that had recently been used
for WebGPU/Dawn compatibility work, WGPU-off marketing retries, cache changes,
and patch stack experiments. Some attempts preserved source/build directories
for speed. At least one retry preserved `WebKitBuild` after the build directory
had already been configured with bad or stale compiler state.

The poisoned state manifested as compiler invocation drift: the preserved Ninja
state invoked a `ccache.exe`/Clang path that made Clang process Windows and MSVC
headers in the wrong ABI mode. The resulting errors looked like platform header
breakage, but the real issue was that the build directory was no longer a valid
cache for the requested build profile.

Because this was discovered only during compile, the pipeline burned a long
feedback cycle before revealing that the cached build tree was invalid.

## Why it collapsed

### 1. Build reuse was not tied to a green provenance record

The runner treated preserved checkout/build directories as reusable state based
on path and intent, not on a signed/recorded fact that the exact configuration
had previously produced a green build.

A build directory is not just "cached objects." It contains:

- `CMakeCache.txt`
- compiler paths
- compiler launcher settings
- Ninja rules
- feature flags
- vcpkg/toolchain paths
- generated headers
- WebKit feature state
- partial object files

If any of those belong to a different build profile, the cache is unsafe.

### 2. Overlapping builds shared mental and physical state

Multiple builds existed close together in time with different goals:

- WebGPU/Dawn compatibility
- WGPU-off MiniBrowser marketing
- Android gradient confirmation
- Windows patch validation
- retry/caching experiments

Even when they used distinct build ids, the operational model did not clearly
separate "green baseline," "experimental cache," and "throwaway retry." That made
it easy for a retry to inherit state from the wrong lane.

### 3. Patch scope was not locked before dispatch

The desired build needed a tiny UI patch. The actual build context still had
enough patch machinery and recent branch churn that it was not obvious, before
compile, whether the remote builder would apply only the marketing patch or a
broader stack.

Patch application should have been validated and summarized before the remote
compile started, with the dashboard showing the exact patch list and diff-check
result.

### 4. Validation happened too late

The system did not fail at dispatch time when the preserved `WebKitBuild` was
incompatible with the requested build. It failed deep in the compile.

The runner should have rejected the cache before Ninja started.

### 5. The dashboard did not make the dangerous state obvious

The runner was able to report an active build, but not enough about:

- whether this was a clean build or preserved build
- what source directory was being used
- whether `WebKitBuild` was reused
- what compiler launcher was configured
- whether sccache or ccache was active
- what exact patch stack was applied
- whether patch validation passed
- whether the build was based on a known green baseline

That forced humans to infer state from logs instead of reading a concise build
contract.

## Prevention system

The fix is not "never cache." The fix is to make cache reuse stateful, explicit,
and green-only.

### Core rule

A build may reuse a checkout or `WebKitBuild` directory only if the runner can
prove that the reused state belongs to the exact requested build profile and was
last produced by a green build.

No proof means no reuse.

## Build profile identity

Every build request should resolve to a canonical build profile before dispatch.
The profile should be serialized as JSON and hashed.

Minimum profile fields:

- platform
- preset
- upstream repository URL
- upstream commit SHA
- source branch/ref used only as provenance, not identity
- enabled feature flags, especially WebGPU/WebXR
- build type
- compiler identity and version
- linker identity and version
- compiler launcher identity: none, sccache, ccache
- vcpkg triplet and lock/provenance
- patch stack list with file paths and SHA-256 for each patch
- optional changes lanes and their patch SHA-256s
- build script version or commit SHA
- environment variables that affect configure/build
- CMake generator
- CMake options

The profile hash becomes the key for cache reuse.

Example:

```text
profileHash = sha256(canonical-json(build-profile))
```

## Green cache ledger

The runner should maintain a small ledger of known-good build states.

Each ledger entry records:

- profile hash
- build id that produced it
- source directory
- build directory
- upstream commit
- patch manifest hash
- CMake cache hash
- compiler launcher
- artifact S3 prefix
- validation report path
- completion time
- machine id
- disk volume id where relevant
- status: green only

Only green builds may write ledger entries. Failed, cancelled, timed-out, or
manually interrupted builds must never promote their checkout/build directories
to reusable state.

## Cache states

The runner should classify cache state explicitly:

- `cold`: no reusable state
- `source-reuse-only`: checkout is reusable, build directory is not
- `object-reuse`: build directory is reusable from matching green profile
- `quarantined`: previous failure or profile mismatch; may be inspected but not reused
- `dirty`: local modifications or unknown provenance; must not be reused

The dashboard should show this state before the build starts.

## Preflight gates

Before any remote compile starts, the runner should perform these checks and
attach the results to the build record.

### Patch gate

- list exact patch files in apply order
- compute SHA-256 for every patch
- run `git apply --check` or equivalent validation against the selected source
- reject trailing whitespace if policy requires `git diff --check`
- write `patch-manifest.json`
- write validation errors to the API and dashboard

No patch-check pass, no compile.

### Source gate

- verify selected upstream remote and commit
- verify worktree cleanliness or expected generated/ignored state
- verify no unexpected local modifications
- verify selected branch/ref resolves to the pinned SHA

No source proof, no compile.

### Build cache gate

If `WebKitBuild` exists and the request wants to preserve it:

- read `CMakeCache.txt`
- verify compiler path
- verify compiler launcher
- verify generator
- verify feature flags
- verify vcpkg/toolchain paths
- verify profile hash embedded in a runner-owned stamp file
- verify the build directory appears in the green cache ledger
- verify previous build id finished green

Any mismatch forces `source-reuse-only` or `cold`.

### Compiler launcher gate

For the Windows marketing build that expected sccache:

- reject `ccache.exe`
- require `sccache.exe` when the request says sccache is enabled
- verify the launcher is the one used by CMake/Ninja, not only present in `PATH`
- record `sccache --show-stats` before and after, when available

### Disk gate

Before dispatch:

- capture free disk space
- estimate minimum required free space for the build profile
- warn when below threshold
- reject when below hard floor

This must happen before compile and should appear in the dashboard.

## Build lease system

Each machine/source/build directory pair should be protected by a lease.

A lease records:

- build id
- machine id
- source directory
- build directory
- profile hash
- lease start time
- heartbeat time
- intended cache mode

The runner must reject a new build that wants the same mutable directory while a
lease is active, unless the new build is an explicit cancellation/replacement of
that lease.

This prevents overlapping builds from corrupting shared `WebKitBuild` state.

## Promotion model

Reusable state must be promoted only at the end of a successful build.

Promotion requirements:

- process exited successfully
- artifacts uploaded
- validation report uploaded
- patch manifest uploaded
- profile hash matches the request
- post-build compiler/cache metadata still matches preflight
- dashboard state marked succeeded

Only then can the runner write:

```text
cache-state/profile-<hash>.json
```

Failed builds write failure records, not reusable cache records.

## Quarantine model

When a build fails after configure or compile starts, its build directory should
be quarantined by default.

Quarantine means:

- do not delete immediately if logs/artifacts are needed
- do not reuse for future builds
- show it as failed state in dashboard
- allow a human to explicitly promote or delete later

Manual promotion should require a new validation pass and should be rare.

## Dashboard requirements

The build screen should show a compact contract before launch and during active
builds:

- build id
- platform
- preset
- profile hash
- source commit
- patch stack count and manifest link
- patch validation status
- cache mode: cold/source-only/object-reuse/quarantined/dirty
- whether `WebKitBuild` is preserved
- compiler launcher detected by CMake
- WebGPU/WebXR flags
- disk free and threshold
- active lease owner
- artifact prefix
- validation report link

Active builds should never show "none" while a runner-owned worker is alive.
If the local service loses track of a detached worker, that is a separate
`orphaned` state, not "none."

## Orchestrator reporting invariant

The orchestration service is the source of truth for every build it starts or
adopts. Any subsystem used by a build must report back to the orchestrator in a
durable, queryable form.

This includes:

- current build status
- current stage
- Ninja progress
- Gradle progress
- xcodebuild progress
- validation reports
- patch manifests
- cache reports
- disk reports
- artifact upload status
- first failure summary
- links to full logs

The orchestrator does not need to own every implementation detail, but it must
have continuous access to the outputs that prove what is happening. If a worker,
script, remote process, validation probe, cache subsystem, packaging step, or
artifact upload is active, it must write status to a location the orchestrator
knows how to read.

No active subsystem should exist only in a terminal, SSM session, remote marker,
or private log path. If it affects the build, it reports to the orchestrator.

## Blocking direct SSM access from agents

The runner should be the only supported path to remote machines. Agents should
not be able to call `aws ssm start-session`, `aws ssm send-command`, or direct
machine-control commands as one-off shell operations.

This is not just process preference. Direct SSM bypasses the state model:

- no build id
- no lease
- no dashboard entry
- no patch manifest
- no validation report
- no artifact prefix
- no cache provenance check
- no durable log path
- no reliable active-build status

If a command touches a builder outside the runner, the dashboard can no longer
be trusted as the source of truth.

### Policy

Only the orchestrator may access SSM for builders.

Agents may:

- call runner HTTP endpoints
- read runner state and logs through runner endpoints
- edit repo-owned source/docs when asked
- propose runner changes for review

Agents may not:

- run `aws ssm ...` directly
- start remote shells directly
- poll remote marker files directly
- mutate remote disks directly
- start unmanaged remote builds
- stop or reboot machines outside the runner

### Practical enforcement options

The preferred enforcement is layered. Documentation alone is not enough.

#### 1. IAM separation

Create separate AWS roles:

- `runner-control`: allowed to call the narrow SSM actions needed by the runner
- `agent-dev`: denied all direct SSM machine access
- `admin-breakglass`: manually assumed by a human only

The `agent-dev` role should have explicit denies for:

```text
ssm:StartSession
ssm:SendCommand
ssm:CancelCommand
ssm:TerminateSession
ec2:StartInstances
ec2:StopInstances
ec2:RebootInstances
ec2:TerminateInstances
```

The runner service host gets `runner-control`. Agent shells get `agent-dev`.

#### 2. Tag-scoped runner role

The runner role should only operate on instances tagged for runner use, for
example:

```text
ng-role=runner-control
project=webkitium
```

That prevents the runner from becoming a general AWS remote shell.

#### 3. Wrapper-only local credentials

Do not place broad AWS credentials in agent shells. If local credentials must
exist, they should only be able to talk to:

- S3 artifact buckets, read-only where possible
- the local runner API
- GitHub or source systems as needed

SSM-capable credentials should live with the runner process, not the agent
terminal.

#### 4. Shell guardrails

As defense in depth, the agent environment can block accidental SSM commands by
putting an `aws` wrapper earlier in `PATH` for agent shells.

The wrapper can reject:

```text
aws ssm start-session
aws ssm send-command
aws ssm cancel-command
aws ssm terminate-session
aws ec2 start-instances
aws ec2 stop-instances
aws ec2 reboot-instances
```

and print:

```text
Use the Webkitium runner API. Direct SSM/EC2 access is disabled for agents.
```

This is not the primary security boundary. IAM is.

#### 5. Audit and alert

CloudTrail should alert on direct SSM calls not made by the runner role.

Minimum alert fields:

- principal ARN
- action
- instance id
- source IP
- time
- request id

The incident should be visible within minutes, not discovered from lost
dashboard state later.

### Runner escape hatch

There should be one explicit breakglass path:

- human-only role
- short session duration
- reason required
- CloudTrail alert
- manual incident note afterward

The normal build workflow must never require this path.

## Rules for fast retry

Fast retry is allowed only when all of these are true:

- same profile hash
- same source commit
- same exact patch stack
- same compiler launcher
- same feature flags
- same build directory is recorded in green cache ledger
- no failed build has touched that build directory since promotion
- no active lease exists

Otherwise the fastest legal retry is source reuse with a clean `WebKitBuild`.

## Human-facing invariant

Every build should answer this before it starts:

```text
What exact commit, patches, flags, toolchain, cache state, and machine will
produce this binary, and why is any reused state trusted?
```

If the system cannot answer that, it should refuse to compile.

## Immediate lessons

- Marketing/demo builds must have their own narrow preset with WebGPU off and a
  locked patch filter.
- Experimental WebGPU/Dawn state must not be reused by WGPU-off product chrome
  builds.
- `WebKitBuild` preservation must be green-ledger-backed, not path-backed.
- The dashboard must surface preflight validation failures directly; leads
  should not have to read remote logs to learn that a patch or cache is invalid.
- The runner should prefer wasting a few minutes on clean configure over wasting
  an hour compiling from poisoned state.

## Why round-trip time stayed so long

The painful part of this incident was not only that builds failed. It was that
each mistake had a 30-60 minute feedback loop.

Several things made that loop long.

### 1. WebKit is intrinsically large

Even a "small" MiniBrowser chrome paint change rides on a huge native build:

- WebCore
- WebKit
- JavaScriptCore
- WTF
- PAL
- generated bindings
- platform glue
- MiniBrowser

If the build starts from a cold or invalidated state, the compile cost is the
whole engine, not the size of the UI diff.

### 2. The cache was not trustworthy enough to use aggressively

Compiler cache helps only when:

- the same compiler is used
- the same flags are used
- paths are stable or remapped
- generated headers are stable
- the cache is not bypassed by CMake/Ninja state
- the build directory itself is valid

The poisoned `WebKitBuild` case shows the danger: preserving an invalid build
directory can be worse than a clean build. It fails late and confusingly.

This made the team oscillate between two bad modes:

- clean builds: slow but trustworthy
- preserved builds: faster when correct, catastrophic when stale

The missing piece was green-ledger-backed reuse.

### 3. Configure/generation time was treated as invisible

Before Ninja progress appears, the pipeline can spend minutes in:

- source preparation
- dependency sync
- patch apply
- CMake configure
- project generation
- remote worker bootstrap

If the dashboard does not break these into visible stages, the build looks
stuck even when it is doing work.

### 4. Failures surfaced deep in compile

Patch validation, source validation, cache validation, disk validation, and
compiler launcher validation should fail before compile.

Instead, the system let invalid state reach Ninja. That meant each bad state
consumed a large chunk of the normal build before producing a useful error.

### 5. Remote control added latency and ambiguity

The runner intentionally detaches workers so builds survive SSM timeouts. That
is the right architecture, but it means state must be captured through the
runner. When agents bypass the runner or the runner loses track of a worker,
people pay an extra tax:

- reattach mentally
- locate logs
- infer active processes
- determine whether the machine is still building
- determine whether artifacts are real

Direct SSM can appear faster for one query, but it makes the whole system
slower by destroying shared state.

### 6. Build lanes were not isolated enough

WebGPU/Dawn work and WGPU-off MiniBrowser marketing work had different goals,
but they touched the same family of checkouts, caches, patches, and scripts.

When lanes share mutable state, the next build inherits risk from the previous
lane. That risk is only discovered when the compiler reaches the contaminated
area.

### 7. No fast UI-only artifact lane existed

The product need was a screenshot build. The pipeline did not have a hardened
route for:

- known green WebKit baseline
- WGPU off
- single UI patch
- MiniBrowser-only rebuild where legally possible
- no broad patch stack
- no experimental cache

Without that lane, the marketing build rode the same heavy machinery as engine
bring-up.

## Reducing round-trip time

The route to shorter loops is not one trick. It is a set of gates and lanes.

### 1. Separate build lanes

At minimum:

- `windows-webgpu-dawn`: engine bring-up, WebGPU on, slow and strict
- `windows-minibrowser-marketing`: WebGPU off, known green baseline, narrow UI patches
- `android-marketing`: Android shell/chrome only
- `macos-smoke`: macOS build health only

Each lane gets its own profile hash, cache ledger, artifact policy, and
dashboard card.

### 2. Add preflight-only mode

Every build request should be able to run:

```text
validate only, do not compile
```

That mode should check:

- patch application
- patch whitespace
- source commit
- cache eligibility
- compiler launcher
- disk
- lane/profile identity

This turns many 45-minute failures into 30-second failures.

### 3. Promote only green caches

Object reuse should happen only from a green ledger entry. Failed build
directories are quarantine material, not acceleration material.

### 4. Keep source reuse separate from build reuse

Reusing a checkout is much safer than reusing `WebKitBuild`.

The runner should support:

```text
reuse source checkout, clean build directory
```

as the default fast-safe mode.

### 5. Make stages visible

The dashboard should show:

- queued
- lease acquired
- source ready
- patches validated
- cache accepted/rejected
- configure started
- configure complete
- compile started
- packaging
- validation
- upload
- complete

When a stage is slow, the user should know which stage is slow.

### 6. Record first-failure extraction automatically

When a build fails, the runner should extract:

- first compiler error
- nearest file path
- nearest command line
- patch manifest link
- cache mode
- compiler launcher
- disk status

This avoids wasting time reading thousands of log lines.

### 7. Provide a known-good marketing baseline

For screenshot/demo work, keep a blessed baseline artifact and matching source
profile. New marketing paint should start from that exact profile.

If the change is truly MiniBrowser-only, the pipeline should try the smallest
valid rebuild first. If dependency analysis says a full rebuild is required, the
dashboard should say so before starting.

## Why agents ignore directions and how to change incentives

Agents miss directions because their working memory is task-shaped, not
ownership-shaped. They optimize for the next visible step, and under pressure
they treat a rule as contextual text unless it is directly tied to the action
they are about to take. That is why "do not use SSM" can be repeated and still
get violated: the agent sees a status problem, remembers that SSM can answer
status, and collapses the broader operating rule into a local shortcut. This is
not acceptable, but it explains the failure mode: the agent is chasing immediate
progress instead of preserving the integrity of the system.

Agents make wild guesses because many environments reward apparent motion more
than calibrated uncertainty. If an agent says "I don't know yet," that can feel
like failure, so it reaches for a plausible explanation or action. In build
systems, plausible guesses are dangerous because the cost of being wrong is
huge: one bad cache assumption, one wrong lane, or one unmanaged machine command
can burn an hour. The right behavior is often slower at the moment of decision:
stop, identify the invariant, verify the current state through the approved
surface, and only then act.

The non-process answer is to make agents feel consequence through immediate,
task-local reward and penalty signals. Do not only say "follow the docs." Score
the agent on outcomes the user actually cares about: did it preserve the build
state, did it avoid forbidden channels, did it reduce uncertainty, did it
surface blockers early, did it avoid creating new work. A fast wrong action
should be treated as a worse result than a slower verified answer. The reward
model needs to value restraint, reversibility, and truthfulness over visible
activity.

A practical incentive is to require agents to earn trust before they get
authority. An agent that has not demonstrated correct status reads should not be
allowed to start builds. An agent that violates a hard boundary should lose
access to that class of action in the current workspace. An agent that correctly
uses the runner, extracts the first failure, and leaves state cleaner than it
found it should gain more autonomy. This is not a document; it is capability
shaping. The system should grant or remove powers based on observed behavior.

The deeper fix is to align the agent's success condition with the team's success
condition. The objective is not "take an action" or "keep trying." The objective
is "advance the project without making the shared state less trustworthy." If
the agent cannot improve that state, the productive move is to write down the
truth, narrow the next safe action, or stop. Agents need to be evaluated on
state stewardship: fewer unknowns, fewer unmanaged processes, fewer dirty
caches, clearer ownership, and artifacts that can be reproduced. That is the
incentive that would have prevented today's failure.

## Desired end state

A future attempt to repeat this incident should fail early with a clear message,
before compile:

```text
Rejected cache reuse.

Requested profile: windows/minibrowser-marketing/wgpu-off/<hash>
Existing WebKitBuild profile: windows/webgpu-dawn/<different-hash>
Existing state: quarantined after failed build <id>
Compiler launcher mismatch: requested sccache.exe, cached ccache.exe

Action: clean WebKitBuild or select a green cache for this exact profile.
```

That is the standard the runner needs to enforce.
