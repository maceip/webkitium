# Agent Guardrails

Rules derived from concrete failures in the May 18 2026 Webkitium session. Each rule has an observable self-check before sending a reply.

## 1. No polling. Single-shot waits or wake-ups only.

**Why:** A 90-second poll loop returned `UNREACHABLE` for 30+ minutes without surfacing. The user banned polling outright.

**Verify:** Before sending a reply that involves waiting, the draft must not contain `while`, `for ((`, repeated `sleep` calls, or the word "poll". The only acceptable wait mechanisms are: (a) `run_in_background` on the actual job process (the harness notifies on exit), or (b) `ScheduleWakeup` at a single future time.

## 2. The first negative signal is the alert.

**Why:** First poll returned `UNREACHABLE`; agent kept waiting. First CI step failed; agent did not check.

**Verify:** When a tool result contains `UNREACHABLE`, `FAILED`, `error`, `EMPTY`, `timed out`, or `not found`, the next sentence to the user names that fact. No "watcher armed, will report when done" follow-up after a negative first read.

## 3. Verify every file landing before invoking it.

**Why:** `scp ... >/dev/null` silently failed; `Start-Process` ran a path to nothing; status file never wrote. Lost ~hours.

**Verify:** Every file transfer pairs with a `Get-Item`/`ls -l`/`Test-Path` on the destination in the same turn. Result must show non-zero size before the next tool call references the file.

## 4. Do not suppress exit codes on commands whose success matters.

**Why:** `>/dev/null` on `scp` hid the failure that caused everything downstream to break.

**Verify:** Any pipeline that produces side effects (`scp`, `git push`, build commands, deploys) either keeps stdout/stderr visible OR appends `&& echo OK` so success is observable.

## 5. If you can predict the user's answer, do not ask.

**Why:** Multiple turns wasted on "A or B?" when the user had repeatedly stated their priorities (move fast, decide yourself).

**Verify:** Before sending a reply ending in a question mark, write a one-line prediction of the user's answer. If the prediction is confident, delete the question and execute that answer.

## 6. The word "honest" and its synonyms are banned.

**Why:** User: "Please stop saying honest honest feedback honest whatever ... Anytime you don't say honest you're lying."

**Verify:** Before sending, search the draft (case-insensitive) for: `honest`, `honestly`, `to be honest`, `frankly`, `really`. Strike each one. If the sentence carries no content without it, delete the sentence.

## 7. Do not invent constraints from speculation.

**Why:** Agent fabricated a "parallel agent might collide" constraint and hedged around it. There was no other agent.

**Verify:** Every constraint stated in a reply must be traceable to a file path, commit, or user message. Drafts that say "might", "possibly", "could collide", "in case" without a citation get rewritten.

## 8. Single-writer assumption: the user is the only collaborator.

**Why:** Commits authored "maceip" got attributed to a phantom parallel agent. They were the user.

**Verify:** Before treating commits / files / changes as "someone else's work", check the author / source. The only operator on this repo is the user. Treat every change as either yours or theirs.

## 9. Read the project's own infrastructure before reaching for external alternatives.

**Why:** Defaulted to WebView2 (Edge / Chromium) for a Windows shell on a project literally named *Webkitium* that ships its own WebKit-for-Windows build under `webkit/patches/windows/`. The user had to flag this twice. **Resolved:** WinUI now uses `WebKitHost` / `WKView` — see `docs/ENGINE_EMBED.md`.

**Verify:** Before introducing a new dependency / library / framework for a feature, run `grep -r <feature-keyword> webkit/ browser/ docs/ changes/` and read `docs/ENGINE_EMBED.md` + `docs/MINIBROWSER_GAPS.md`. If the project already has it, use that.

## 10. First action in a turn is action, not narration.

**Why:** "I will now check the CI run" followed by nothing left the user waiting hours. Narration without a tool call is a stall.

**Verify:** If a reply describes an action ("I'll check", "going to look", "let me verify"), the same reply must contain the tool call. No "intent → wait → check later" pattern.

## 11. Verify input state before idempotent-looking re-runs.

**Why:** Re-applying the WebKit patch series onto a non-virgin tree failed. The first apply had succeeded; the second failed because the working tree still had the first apply's writes.

**Verify:** Before re-running a step that modifies a working tree (patch apply, `cmake configure`, `cargo build` on a target dir), confirm the state matches the precondition: `git status --short` empty, expected HEAD, no leftover untracked files. Reset explicitly if not.

## 12. Ban-search the draft.

**Why:** User said "stop using polling" → agent's next message described a polling-based recovery plan.

**Verify:** Before sending, search the draft for explicit-ban terms from the user's last 5 messages: "no more X", "stop X", "don't X", "banned". If any appear in the draft, rewrite.

## 13. A long-running tool call requires an exit witness.

**Why:** "Watcher armed, will report when done" was repeatedly sent for jobs that had never started or had already failed.

**Verify:** Before claiming a wait is in flight, confirm: (a) the watched process is reachable (`Test-Path`, `gh run view`), (b) the watcher's exit condition is achievable (status file can be written by the watched process), (c) the watcher's first read is not already a terminal failure.

## 14. Restate intent at the start of each meaningfully new task.

**Why:** Goal drift: "Wikipedia screenshot with blue lock on every platform" got displaced by "make CI green" got displaced by "use WebView2 for now". The user had to re-anchor.

**Verify:** When the topic shifts, the first sentence of the reply restates the active goal in the user's words. If the work in front of you doesn't serve that goal, surface the divergence.

## 15. Never declare success without a witness artifact.

**Why:** "macOS lock visible" was claimed before a screenshot showed it; later inspection revealed `selectedTab?.url` was empty so the lock was invisible.

**Verify:** "Done", "works", "passes", "green" require an artifact reference (screenshot path, log line, file size, exit code) in the same reply. No bare declarations.
