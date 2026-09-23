# My Note v1 Grill Me Backlog

This backlog is the execution companion to `grill_me_spec.md`. Status is based
on source inspection, Git history, the primary Log, and current verification.
`NEEDS VERIFICATION` is intentionally used when historic evidence exists but
the current behavior has not been independently accepted for this v1 baseline.

## Status vocabulary

- `DONE`: implemented and has current, recorded acceptance evidence.
- `IN PROGRESS`: code or UI exists but the full requirement is unfinished.
- `PLANNED`: specified work has not begun.
- `NEEDS VERIFICATION`: likely present from prior work, but lacks current v1
  acceptance evidence.
- `BLOCKED`: cannot safely proceed without external configuration or approval.

## P0 — Data safety and architecture

### P0-001 — Revisioned local persistence

- Status: `DONE`
- User-visible behavior: every create, edit, move, rename, and delete survives
  closing and reopening; older data cannot overwrite a newer change.
- Acceptance: mutation-order tests pass; restart keeps final state; a damaged
  primary snapshot restores the newest valid checkpoint or backup.
- Dependencies: `shared_preferences`, local JSON serializers.
- Evidence: `AppStore` has revision/checkpoint/journal/backup-history code.
  On 2026-09-23, the full suite passed 57 tests, including damaged-primary
  recovery, legacy-seed rejection, mixed-data recovery, checkpoint precedence,
  rapid mutation journal order, and intentionally empty latest revisions.
  Flutter Web built successfully from the same working tree.

### P0-002 — Canonical Web local-data origin

- Status: `DONE`
- User-visible behavior: `127.0.0.1:8080` and `localhost:8080` cannot create
  separate Web data stores.
- Acceptance: loopback URL redirects to `localhost`; data survives reload on
  the canonical URL.
- Dependencies: `web/index.html`, browser localStorage.
- Evidence: `web/index.html` redirects IPv4 and IPv6 loopback hosts before
  Flutter bootstraps. On 2026-09-23, headless Chrome requested
  `127.0.0.1:8080` once, then reloaded the document and all Flutter assets
  from `localhost` (`::1`) on the same port. This prevents a second
  loopback-origin localStorage namespace from being used.

### P0-003 — Portable JSON backup and restore

- Status: `IN PROGRESS`
- User-visible behavior: Settings exports all local data as JSON and imports it
  after creating a recovery point.
- Acceptance: versioned export validates; import restores every record family;
  invalid files leave current state unchanged.
- Dependencies: `AppStore`, File Picker, local persistence.
- Evidence: recovery snapshot `4c071a2` preserves the adopted baseline. The
  isolated implementation exposes versioned JSON export/import in Settings,
  checkpoints the prior snapshot before import, and rejects invalid bundles
  before in-memory mutation. Focused export/restore and invalid-import tests
  passed on 2026-09-23. Web and X510 file-picker acceptance remain.

### P0-004 — Backup history and recovery UI

- Status: `DONE`
- User-visible behavior: users inspect backup timestamps and restore a selected
  snapshot without manually editing JSON.
- Acceptance: Settings lists recoverable backups, requires confirmation, and
  shows restored record counts.
- Dependencies: P0-001, P0-003.
- Evidence: Settings now lists validated recovery snapshots with timestamps and
  record counts. Restore requires a second confirmation and reuses the guarded
  import flow, which checkpoints current data first. On 2026-09-23,
  formatter/analyzer, the full 59-test suite, and Flutter Web build passed;
  the focused test verifies listing and restoring a stored snapshot.

### P0-005 — Domain model extraction

- Status: `DONE`
- User-visible behavior: no intentional UI change; future changes avoid one
  monolithic source file.
- Acceptance: records and schemas live under `lib/data/`; existing behavior
  and full tests remain unchanged.
- Dependencies: P0-001.
- Evidence: adopted recovery snapshot `4c071a2` is retained on
  `backup/pre-codex-adoption-20260923-150100`. The extracted
  `app_models.dart`, `template_documents.dart`, and `local_data_bundle.dart`
  now carry domain records and document schemas, while `main.dart` remains the
  composition root. On 2026-09-23, formatting, analysis, all 57 tests, and a
  Flutter Web build passed before the isolated extraction commit.

### P0-006 — Store and feature-layer extraction

- Status: `IN PROGRESS`
- User-visible behavior: current navigation, local data, and rich-note editing
  remain stable while implementation becomes independently maintainable.
- Acceptance: persistence moves to `data/`; feature pages and shared helpers
  use focused imports instead of `part of main.dart`.
- Dependencies: P0-005; prior explicit approval to split files.
- Evidence: persistence state, mutation APIs, revision journal, backup history,
  import/restore, and local commit scheduling have moved from the monolithic
  `main.dart` into `lib/data/app_store.dart` without behavior changes. On
  2026-09-23, record JSON codecs, legacy-seed detection, and primitive parsing
  helpers also moved to `lib/data/local_serialization.dart`. The data layer now
  owns its library boundary in `lib/data/my_note_data.dart`; `main.dart` uses a
  focused import/export instead of treating data files as parts of the app
  entrypoint. Analysis, the full 64-test suite, and Flutter Web build passed
  after each extraction. Home/dashboard/todo/upcoming now use the standalone
  focused-import `lib/features/home/home_page.dart` library, with editor actions
  injected by the composition root and todo labels/styles supplied by
  `lib/ui/todo_display.dart`; the notes browser, folder navigation, filters,
  batch actions, and note cards live under `lib/features/notes/`. Calendar
  month/week/list pages now use the standalone focused-import
  `lib/features/calendar/calendar_page.dart` library; finance dashboard,
  account, chart, history, and timeline views now use the standalone
  focused-import `lib/features/finance/finance_page.dart` library; local
  backup/import/recovery settings now use the
  standalone focused-import `lib/features/settings/settings_page.dart` library.
  Common page shells, FAB menus, action buttons, and
  swipe-delete components moved to the standalone focused-import library
  `lib/ui/shared_components.dart`; generic section headers and empty states use
  the focused `lib/ui/basic_display.dart` library; metric, note-list/grid,
  selection, and sort display widgets now use the standalone focused-import
  `lib/ui/display_components.dart` library, with note template labels and icons
  supplied by `lib/ui/note_template_metadata.dart`; stable text/folder input dialogs and
  folder-name constraints now use focused imports from
  `lib/ui/prompt_dialogs.dart` and `lib/ui/folder_names.dart`; schedule/finance rows and calendar period,
  swipe, month-picker, month-grid, and week-strip widgets now use the standalone
  focused-import `lib/ui/calendar_components.dart` library; finance bar/ring charts and painters moved
  to the standalone `lib/ui/finance_charts.dart`, backed by focused pure display
  formatters in `lib/ui/formatters.dart`; bottom navigation, item animation, and the
  navigation scope moved to the standalone `lib/ui/app_navigation.dart` library,
  Store access moved to the focused `lib/ui/app_store_scope.dart` library,
  and calendar date/period calculations moved to the focused
  `lib/ui/calendar_helpers.dart` library. These are consumed through focused
  imports rather than `part of`. File picking, crop, export, PDF, and share
  operations moved from the rich editor into
  `lib/services/note_file_service.dart`. Remaining: replace transitional
  feature parts with focused imports where dependencies permit.

### P0-007 — Data integrity validation

- Status: `DONE`
- User-visible behavior: import/migration failures explain the problem and
  never partially replace existing data.
- Acceptance: validation checks IDs, folder paths, references, dates, numeric
  values, and document tree/canvas invariants before commit.
- Dependencies: P0-003, P0-005.
- Evidence: `LocalDataBundle.decode` now validates the complete candidate before
  `AppStore.importBundle` can mutate live data. Validation rejects missing or
  duplicate record IDs, malformed folder paths, invalid dates and numbers,
  broken typed references, plan cycles/task children, missing mind-map roots or
  connection endpoints, and life-sheet account references. On 2026-09-23,
  focused rejection tests also proved that a failed import retains current
  in-memory data; the full 63-test suite, analyzer, and Flutter Web build passed.

## P1 — Cross-record memory network and upcoming items

### P1-001 — Persist typed record links

- Status: `DONE`
- User-visible behavior: records retain links to notes, plans, mind maps, life
  projects, todos, schedules, finance entries, subscriptions, and accounts.
- Acceptance: links round-trip through save/export/import and do not duplicate.
- Dependencies: P0-005.
- Evidence: notes, schedules, subscriptions, finance entries, accounts, and
  todos now own deduplicated `RelatedItemLink` collections. Plan nodes,
  mind-map nodes, and life-sheet items use the same normalization. Every link
  serializes through local save/export/import, and import validation rejects
  unknown, duplicate, or dangling targets. The focused round-trip test covers
  all nine relationship types and every root record family.

### P1-002 — Common relationship picker and reverse links

- Status: `PLANNED`
- User-visible behavior: every supported editor has a `關聯項目` picker; links
  open target records and show reverse references.
- Acceptance: search, select, create-and-link, remove-link, deep navigation,
  and reverse-link counts work on Web and Android.
- Dependencies: P1-001, P0-006.
- Evidence: none.

### P1-003 — Derived upcoming aggregation

- Status: `DONE`
- User-visible behavior: upcoming view derives schedules, subscriptions, and
  due todos without separately storing duplicates.
- Acceptance: source edits update immediately; hidden items remain hidden;
  displayed count reflects all matching records.
- Dependencies: P0-001.
- Evidence: home headers show total schedule, upcoming, and todo counts even
  when their visible previews are capped. Focused tests cover five schedules
  with a two-item preview, two subscriptions, and three todos, plus direct
  source edits, removal, hidden-item filtering, management inclusion, and the
  complete derived count. The same shared implementation passed Web build and
  post-push SM-X510 installation/launch acceptance on 2026-09-23.

### P1-004 — Plan tasks in upcoming items

- Status: `DONE`
- User-visible behavior: incomplete plan tasks with due dates appear in upcoming
  items even if not shown in home todos.
- Acceptance: task appears once with plan icon and opens plan; completed or
  undated tasks do not appear.
- Dependencies: P1-001, P1-003, P1-005.
- Evidence: the derived upcoming aggregator now reads incomplete dated task
  nodes directly from plan notes, uses a plan flag and plan title, suppresses a
  separately linked todo duplicate, excludes completed/undated tasks, respects
  hidden-item settings, and offers an `開啟計畫` source action. Focused tests
  cover the inclusion and de-duplication rules.

## P1 — General note experience

### P1-005 — Preserve general rich-note behavior

- Status: `NEEDS VERIFICATION`
- User-visible behavior: only general notes use rich text with images,
  attachments, lists, inline todo blocks, links, and export.
- Acceptance: current rich-editor test suite passes after extraction; actions
  retain focus and data after restart.
- Dependencies: P0-006.
- Evidence: prior 57-test Log entry; current v1 acceptance is pending.

### P1-006 — Optional note appearance themes

- Status: `PLANNED`
- User-visible behavior: default notes are clean white; users may apply a
  restrained built-in visual theme.
- Acceptance: theme persists, has sufficient text contrast, and resets cleanly.
- Dependencies: P1-005.
- Evidence: none.

### P1-007 — Optional cover and background image

- Status: `PLANNED`
- User-visible behavior: notes may use optional cover/background images without
  making either mandatory.
- Acceptance: select/remove/persist/render flows work on Web and Android and
  preserve rich-editor contrast.
- Dependencies: P1-005, File Picker.
- Evidence: none.

## P1 — Plan template

### P1-008 — Plan v1-to-v2 migration

- Status: `IN PROGRESS`
- User-visible behavior: existing flat plan tasks remain visible after the
  phase/task editor replaces old field lists.
- Acceptance: `plan.v1` maps to v2 phase/task tree and saves as v2 after edit.
- Dependencies: P0-003, P0-007.
- Evidence: `PlanDocument.fromJson` handles legacy fields; write migration/UI
  acceptance remains.

### P1-009 — Nested phase/task editor

- Status: `PLANNED`
- User-visible behavior: plans support unlimited nested phases and terminal
  tasks that users create, reorder, complete, and remove.
- Acceptance: tasks cannot have children; phases can; all operations survive
  restart and export/import.
- Dependencies: P1-008, P0-006.
- Evidence: none.

### P1-010 — Plan metadata and weighted progress

- Status: `PLANNED`
- User-visible behavior: phases/tasks support due dates, priority, weight,
  todo/schedule links, home-todo inclusion, and recursive weighted progress.
- Acceptance: percentages are correct for nested trees and update immediately.
- Dependencies: P1-009, P1-002.
- Evidence: model calculation exists only; no editor implementation.

## P1 — Mind map template

### P1-011 — Mind-map v1-to-v2 migration

- Status: `IN PROGRESS`
- User-visible behavior: old topic/node data remains visible with a required
  root node.
- Acceptance: every import has one valid root; legacy positions/colors survive;
  invalid references are rejected safely.
- Dependencies: P0-007.
- Evidence: root fallback model exists; canvas/write migration remain.

### P1-012 — Mind-map canvas interaction

- Status: `PLANNED`
- User-visible behavior: users pan/zoom, add/select/move/lock/collapse nodes;
  the central topic remains required.
- Acceptance: locked nodes cannot move; state survives restart; mouse/touch work.
- Dependencies: P1-011, P0-006.
- Evidence: none.

### P1-013 — Mind-map connections and layout

- Status: `PLANNED`
- User-visible behavior: parent-child/free links show color, solid/dashed style,
  and optional arrow; one-click layout excludes locked nodes.
- Acceptance: connections update after deletion; layout preserves root/locks.
- Dependencies: P1-012.
- Evidence: model types exist; renderer absent.

## P1 — Life project template and finance authority

### P1-014 — Life-project v1-to-v2 migration

- Status: `IN PROGRESS`
- User-visible behavior: legacy life-sheet items remain usable as project items.
- Acceptance: old values migrate without loss; removed actual-cost field does
  not block opening legacy records.
- Dependencies: P0-003, P0-007.
- Evidence: model maps legacy current amount; UI/write migration pending.

### P1-015 — Life-project dashboard and weighted progress

- Status: `PLANNED`
- User-visible behavior: active/completed cards show weighted total progress and
  money/status items.
- Acceptance: status, items, weights, order, progress, and links survive restart.
- Dependencies: P1-014, P1-002.
- Evidence: none.

### P1-016 — Ledger-derived account balances

- Status: `PLANNED`
- User-visible behavior: accounts use opening balance plus income minus expense;
  finance entries select an account.
- Acceptance: entry edits update balance immediately; legacy savings migrate
  without changing observed balance.
- Dependencies: P0-007; explicit migration approval before execution.
- Evidence: source still uses mutable `SavingsAccount.amount`.

### P1-017 — Shared-account money meter

- Status: `PLANNED`
- User-visible behavior: money items render ordered thresholds; shared balances
  are counted once and show current versus achieved-before states.
- Acceptance: no double counting; multiple accounts may contribute; decreased
  balance preserves history and reflects current attainment.
- Dependencies: P1-015, P1-016.
- Evidence: schema has account IDs/order only.

## P2 — Local reminders

### P2-001 — Notification solution selection

- Status: `PLANNED`
- User-visible behavior: Android reminders can arrive while app is closed.
- Acceptance: selected package is free, maintained, compatible, and documented.
- Dependencies: package evaluation; no paid service.
- Evidence: none.

### P2-002 — Android local reminder scheduling

- Status: `PLANNED`
- User-visible behavior: eligible todo/schedule/subscription reminders notify at
  their configured time without duplicates.
- Acceptance: create/edit/delete/reschedule works on X510 with permissions/channel.
- Dependencies: P2-001.
- Evidence: none.

### P2-003 — In-app reminder surface

- Status: `PLANNED`
- User-visible behavior: opening Android/Web shows source-linked due reminders;
  Web email stays deferred.
- Acceptance: relevant reminders appear once without duplicate notifications.
- Dependencies: P1-003, P2-002.
- Evidence: none.

## P2 — Verification and release quality

### P2-004 — Template and backup test coverage

- Status: `IN PROGRESS`
- User-visible behavior: future updates do not silently break migrations,
  export/import, templates, links, or backup safety.
- Acceptance: tests cover each migration and critical data-safety path.
- Dependencies: P0/P1 implementations.
- Evidence: uncommitted model/export tests; UI coverage pending.

### P2-005 — Web and X510 acceptance matrix

- Status: `NEEDS VERIFICATION`
- User-visible behavior: completed features have Web and X510 evidence without
  immediate crash/red screen.
- Acceptance: every completed task records Web build and X510 PASS/FAIL/SKIPPED.
- Dependencies: device authorization and build tooling.
- Evidence: X510 detected as SM-X510 / Android 16 / API 36; matrix absent.

### P2-006 — Kotlin plugin warning watch

- Status: `NEEDS VERIFICATION`
- User-visible behavior: debug builds stay possible; upstream KGP warnings are
  handled when compatible versions exist.
- Acceptance: dependencies are checked during updates and warning is resolved
  or documented with package versions.
- Dependencies: upstream package releases.
- Evidence: Log names file_picker, firebase_storage, and share_plus.

## Deferred after v1

### D-001 — Firebase and cloud synchronization

- Status: `BLOCKED`
- User-visible behavior: sign-in, cloud sync, attachment storage, FCM, email,
  and Hosting are post-v1 capabilities.
- Acceptance: start only after Firebase Apps/options exist and a cloud schema is
  explicitly approved.
- Dependencies: project owner configuration and approval.
- Evidence: primary Log states Firebase Apps/options are not created.

### D-002 — Store release and memory-network graph

- Status: `BLOCKED`
- User-visible behavior: store release and visual graph remain deferred with no
  impact on v1 local behavior.
- Acceptance: begin only after v1 and separate product decision.
- Dependencies: release assets/accounts; D-001 where cloud is relevant.
- Evidence: final Grill Me scope defers both.
