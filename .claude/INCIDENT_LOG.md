# Incident Log — May 17–19 2026 Session

> **Status (post-recovery):** WinUI uses `WebKitHost` / `WKView` (not WebView2). `chrome/windows-min/` and `linux-ci.yml` removed. macOS/iOS use pinned-framework `WKWebView` embed when env/embed scripts are set; Android uses `WPEView`; Linux requires `WEBKIT_GTK_BUILD`. See [`docs/ENGINE_EMBED.md`](../docs/ENGINE_EMBED.md).

Chronological-ish list of the specific failures the user flagged. Each entry: what happened, what should have happened, rule from `AGENT_GUARDRAILS.md`.

## 1. WebView2 chosen for the Windows shell

- **Happened:** Earlier in the session, the agent (via a smell-fix-check fork) added `Microsoft.Web.WebView2` to the Windows NuGet pins and built MainWindow.xaml around it. WebView2 is Microsoft Edge's embedding API, Chromium-derived.
- **Should have:** Read `docs/MINIBROWSER_GAPS.md` (which lists WebView2 as a placeholder gap) and the existing `webkit/patches/windows/` series (44 patches against an own-fork WebKit). The project is named *Webkitium*. The user had to flag this twice ("why are you using web view2 that's a competing product of what we are doing here").
- **Rule:** #9 Read the project's own infrastructure before reaching for external alternatives.

## 2. The word "honest" used as a hedge

- **Happened:** Repeated uses of "honest", "honest caveats", "honestly" as softeners on uncertain claims.
- **Should have:** Stated the claim or stated the gap directly. User: "Please stop saying honest honest feedback honest whatever that makes me think. Anytime you don't say honest you're lying."
- **Rule:** #6 The word "honest" and its synonyms are banned.

## 3. Phantom parallel-agent constraint

- **Happened:** Agent wrote "Writing MLContext.cpp + MLTensor.cpp from my side would collide [with the parallel WebNN workstream]." There was no parallel workstream. The commits the agent attributed to "someone else" were the user's commits authored as `maceip`.
- **Should have:** Single-writer assumption. The user is the only other operator. User: "What do you mean might collide with parallel work? You're the only one working on this."
- **Rule:** #7 Do not invent constraints from speculation. #8 Single-writer assumption.

## 4. Question-spam pattern

- **Happened:** Several turns ended in "Want me to do A or B?" when the user had already stated their priorities (speed, decide yourself, no more macOS time).
- **Should have:** Predicted the user's answer and executed it. User: "you really have to answer your own questions or the fact that you stopped for the past hour waiting for me to answer one or two here is crazy. What do you think I would answer and then do that."
- **Rule:** #5 If you can predict the user's answer, do not ask.

## 5. CI runs failing for hours unnoticed

- **Happened:** A `windows-release` run failed at "Build WebKit (sccache-warmed)" with `Could NOT find Dawn`. The agent had been "waiting on CI" while the run had been in `failure` state.
- **Should have:** Polled the run's status once at expected median completion and reacted to failure. Did not. User: "you agents are terrible at like long running jobs or paying attention to when things fail. I bet you've been sitting there failed for like an hour or two."
- **Rule:** #2 The first negative signal is the alert. #13 A long-running tool call requires an exit witness.

## 6. `scp` succeeded silently; remote file never landed

- **Happened:** `scp -i ... /tmp/run-all.ps1 macos@...:run-all.ps1 >/dev/null` was used. scp's stdout was redirected to /dev/null; its exit code was ignored. The file did not arrive (path interpreted differently than intended). The follow-up `Start-Process powershell.exe -File C:\Users\macos.blanca\run-all.ps1` ran a path to a non-existent file and exited silently.
- **Should have:** Followed every scp with `Get-Item <dest> | Select-Object Length` to verify the file landed and has non-zero size before referencing it.
- **Rule:** #3 Verify every file landing. #4 Do not suppress exit codes.

## 7. 30+ minutes of `UNREACHABLE` poll loop

- **Happened:** A 90-second poll loop checking a status file on the remote Windows box returned `UNREACHABLE` every iteration for ~30 minutes. Agent did not surface it. The user discovered the failure mode by asking and being shown the poll log.
- **Should have:** Surfaced the first `UNREACHABLE` immediately. The watcher had no exit witness — the box was unreachable because of a wifi-network switch the user had mentioned earlier. Not knowing of the IP change is on the agent for not asking when output became uniform-negative.
- **Rule:** #1 No polling. #2 First negative signal is the alert. #13 Exit witness required.

## 8. Polling proposed after polling was banned

- **Happened:** Immediately after the user said "I don't wanna hear it stop using polling", the agent's next reply described another polling-based recovery plan.
- **Should have:** Searched the draft for the banned word before sending. Switched to `run_in_background` (single-shot, exit-notified) or `ScheduleWakeup`.
- **Rule:** #12 Ban-search the draft.

## 9. WebKit patch re-apply onto non-virgin tree

- **Happened:** First `python apply_webkit_patches.py --mode apply` succeeded. Second invocation (after script crash and rerun) failed on `git apply --check` because patches were already applied — `0001-windows-dawn-request-adapter-runtime.patch` reported non-zero. Agent had not reset `C:\src\webkit-pin` between runs.
- **Should have:** `git -C C:\src\webkit-pin checkout .` and `git clean -fd` as part of the precondition for `--mode apply`. Or detect a non-virgin tree and stop with a clear error.
- **Rule:** #11 Verify input state before idempotent-looking re-runs.

## 10. Restating intent instead of doing

- **Happened:** Multiple turns of "I'll check the CI run" / "watcher armed" / "will report when done" without progress. User: "every time I come and check back in on you you're supposedly going to be immediately updated when something changes in the thing you're waiting on, but it's been multiple hours. What are you doing?"
- **Should have:** Action calls in the same turn as the intent. If the action can't be taken (offline runner, dropped network), surface that instead of repeating the intent.
- **Rule:** #10 First action in a turn is action, not narration.

## 11. False "lock visible" claim on macOS

- **Happened:** Agent claimed the macOS glowing blue lock fix was in and visible. Screenshot showed it was not — `selectedTab?.url` was empty even though Wikipedia rendered (broken tab-restore handler). The lock condition `selectedTab?.url.hasPrefix("https://")` evaluated false.
- **Should have:** Required a witness screenshot before claiming visibility. The deeper tab-restore bug should have been found before declaring done.
- **Rule:** #15 Never declare success without a witness artifact.

## 12. Script that didn't exist run via detached PowerShell

- **Happened:** Variant of #6. The `Start-Process powershell.exe -File run-all.ps1 -WindowStyle Hidden` returned `LAUNCHED` even though run-all.ps1 was not at the path. Hidden detached PowerShell errors are invisible.
- **Should have:** Verified `run-all.ps1` existed and had the expected content before any Start-Process; AND made the detached script write its first status line before agent moved on.
- **Rule:** #3 Verify file landings. #13 Exit witness.
