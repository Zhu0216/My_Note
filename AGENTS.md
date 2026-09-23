# My Note autonomous development rules

## Sources of truth and startup

- The user's latest explicit instruction has highest priority.
- The final Grill Me specification is the authoritative product specification. Do not independently change its requirements, user-visible behavior, or UX.
- Use `D:\log\index.html` as the primary progress checkpoint and audit log. Read it before rescanning the project or Grill Me. Compare against Grill Me only when the Log is insufficient, then write the missing status and decisions back to the Log so later runs do not repeat the comparison.
- `D:\Flutter_Project\my_note\codex_action_log.html` is a legacy/incomplete copy and is not the primary checkpoint unless the primary Log is unavailable.
- At the start of each autonomous run, fetch Git, inspect the working tree and recent commits for human changes, preserve all human work, then select the highest-priority safe unfinished task.

Priority order:

1. Latest explicit user instruction.
2. P0: application cannot run, data-loss risk, or severe regression.
3. P1: unfinished Grill Me requirement.
4. P2: currently active feature.
5. P3: related bugs and existing project errors.
6. P4: relevant tests.
7. P5: code-quality improvements directly related to current work.

Do not invent new product features when the backlog is complete. When all TODO items are complete, end the current run; check again at the next scheduled wake-up.

## Backlog execution contract

- `docs/grill_me_spec.md` and `docs/grill_me_backlog.md` are the durable Grill Me specification and execution queue. Read both during every autonomous run.
- Creating, reconciling, or committing specification/backlog documents is setup work, not completion of a development run. If any safe `PLANNED`, `IN PROGRESS`, or `NEEDS VERIFICATION` item remains, continue in the same run and perform implementation or acceptance work on the highest-priority actionable item.
- A documentation-only commit, successful fetch, clean analysis, repeated test run, or build does not satisfy the requirement to continue development while actionable backlog work remains.
- Each run must name the selected backlog ID before work begins and update its status and evidence before ending. Do not claim that TODOs are empty unless every non-deferred backlog item is `DONE` with current acceptance evidence.
- Continue through additional independent actionable items in the same wake-up while time and usage remain. End only for the explicit stop conditions in this file; completing one logical task by itself is not a stop condition.
- Never describe changes that existed before the run as work completed by that run. Record the starting commit and starting working-tree state, then attribute only the new diff created during the run.
- Before sending a final response, run this explicit stop gate and record its outcome internally: `(all non-deferred backlog items DONE) OR (approval required) OR (no safe independent item) OR (same blocker exhausted three approaches) OR (usage unavailable)`. If every condition is false, a final response is prohibited: re-read the backlog, select the next item, and continue tool work in the same run.
- After committing one backlog item, do not summarize or hand off merely because the commit succeeded. Update its evidence, select the next actionable backlog ID, and begin that item immediately.

## Autonomous permissions and approval boundaries

Codex may autonomously implement specified requirements, fix bugs and existing project errors, add or improve relevant tests, perform small or medium refactors, add free Flutter/Dart dependencies, remove verified dead code under the deletion safeguards below, improve the Log page, and create/commit/push task branches.

Stop and obtain explicit user approval before:

- a large architectural change;
- a database or Firebase schema migration;
- any change to production Firebase resources or configuration;
- a core authentication or security change;
- reading, creating, changing, or exposing secrets or API keys;
- force-pushing or rewriting Git history;
- removing a primary feature;
- any action with irreversible data-loss risk;
- using a paid service, paid API, paid package, or making a purchase;
- changing explicit Grill Me UX or functionality;
- choosing between mutually exclusive product options that the specification cannot resolve.

Never buy credits, automatically reload paid tokens, or consume a banked reset that requires a human decision. If usage is unavailable, stop the run; resume only after the platform's natural reset or explicit user action.

## UI quality policy

- Do not keep or introduce simplistic, placeholder-like, or obviously low-quality UI packages or solutions merely because they are easy to implement.
- Prefer mature, maintained, production-appropriate Flutter packages or native Flutter implementations.
- Before adding or replacing a major UI package, evaluate maintenance status, current Flutter compatibility, extensibility, architecture impact, and license/cost.
- Preserve working behavior and the UX defined by Grill Me. Do not replace a working UI solely for visual preference without a concrete product or maintenance benefit.
- Record material UI-package decisions in `D:\log\index.html`.

## Git and deletion safety

- Work on a branch named `codex/<task-name>`; never automatically merge into `main`.
- Make one commit per logical task. Do not mix unrelated changes. Pre-existing human changes may be adopted only through the recovery-snapshot protocol below, then split into the matching logical backlog commits.
- Push completed task commits to the configured remote.
- Before deleting any material file, code path, or feature, verify that a recoverable Git copy exists and has already been pushed, then record the backup commit/branch and deletion in the Log. Do not delete if that recovery proof is missing.
- If push fails, preserve the local commit, record the failure and actionable reason in the Log, and continue only with independent safe work.

## Recovery snapshot and adoption of pre-existing work

- Pre-existing uncommitted work is not, by itself, a blocker or a reason to request ownership confirmation. Codex is authorized to inspect, test, complete, refactor, and commit pre-existing changes that directly implement the approved Grill Me backlog, while preserving attribution in the Log.
- Before first modifying or committing an uncommitted baseline, inspect the exact tracked and untracked files for secrets, credentials, generated artifacts, and unrelated personal data. If any may be present, do not stage or expose them; record a blocker only for those unsafe files and continue with other safe work.
- Create a recoverable snapshot branch named `backup/pre-codex-adoption-<timestamp>` from the current HEAD, commit the exact safe in-scope pre-existing changes without rewriting them, push that backup branch, and record its branch and commit SHA in `D:\log\index.html`.
- Return to the active `codex/<task-name>` branch and restore the snapshot changes as uncommitted work (for example, apply the backup commit without committing). Then use path- or hunk-level staging to split the adopted work into one logical backlog commit at a time. Unrelated or later-backlog hunks remain uncommitted and preserved.
- Do not create duplicate snapshots for the same unchanged baseline. Reuse the recorded pushed snapshot until new human edits appear.
- Distinguish adopted pre-existing implementation from changes authored during the current run. Validate both, but never claim that the run originally authored adopted code.
- Ask the user only when the pre-existing changes conflict with the Grill Me specification, contain or may expose secrets, cross an approval boundary, or present a mutually exclusive product decision that the specification cannot resolve.

## Validation and failure handling

For every code-changing logical task, run the relevant subset of:

1. `dart format .`
2. `flutter analyze`
3. relevant `flutter test` targets (or the full suite when scope is broad)
4. `flutter build web` when web behavior, shared UI, dependencies, or release buildability may be affected

For verification-only backlog items that create no application-code diff, run the smallest direct acceptance check that proves the stated criterion; do not automatically repeat the full test suite, Web build, Git push, or X510 deployment unless that evidence is actually required. Do not claim success without recording the actual results in the Log. For the same blocking problem, try at most three materially different solutions. If all three fail, record a blocker with attempts and evidence, then move to another independent task. Stop the run when no safe independent work remains, approval is required, usage is unavailable, or all TODOs are complete.

## X510 device validation

- Identify the device from live evidence, never from the nickname alone. Use `flutter devices` and the Android SDK's `adb devices -l`; record the Flutter device ID, model, Android version, and connection/authorization state in the Log.
- When an authorized supported X510 Android target is connected, build/install the app, launch it, and verify that its main activity remains running without an immediate crash. Run relevant integration tests when they exist and are suitable.
- X510 validation succeeded on 2026-09-23 for `SM-X510`, device ID `R52X200FM7F`, Android 16/API 36. Post-push deployment validation is enabled.
- After every successful push of project code, run `powershell -ExecutionPolicy Bypass -File scripts/x510_validate.ps1`. Record its `PASS`, `FAIL`, or `SKIPPED` result in the Log. `SKIPPED` means the verified X510 is offline or unauthorized and never blocks development or the push.

## Six-hour autonomous wake-up procedure

Every six hours:

1. Read `docs/grill_me_spec.md`, `docs/grill_me_backlog.md`, and `D:\log\index.html`.
2. Run `git fetch` without discarding local work.
3. Inspect working-tree changes and commits since the previous checkpoint to detect human edits; preserve and prioritize the newest explicit human direction.
4. State the selected backlog ID, then continue the highest-priority safe unfinished task using the rules above. After setup/documentation work, immediately proceed to implementation or acceptance work in the same run.
5. Update the Log with decisions, files changed, validation, commit/push status, X510 `PASS`/`FAIL`/`SKIPPED`, blockers, and the next task.
6. End that run when TODOs are empty, a blocker or approval boundary prevents safe progress, no safe work remains, or usage is unavailable. Wake again six hours later unless the automation is explicitly disabled.
