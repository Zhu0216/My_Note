# V1 Web and X510 acceptance matrix

Date: 2026-10-10

Integrated baseline:

- Web: `flutter build web --debug --no-wasm-dry-run` passed on commit
  `0b63b65`.
- Android: the current debug APK was rebuilt, installed, cold-launched, and
  stayed in the foreground on Samsung SM-X510 (`R52X200FM7F`), Android 16 /
  API 36, PID 26228.
- Automated suite: all 132 tests passed on the same application baseline,
  including one integrated current-schema restart and portable export/import
  workflow across every local record family and all four note templates.
- Device interaction: current Notes, four template editors, Calendar, Home,
  Upcoming/Todos, Finance, Subscriptions, Settings, backup controls, reminder
  status, image editing, and attachment presentation were exercised without a
  crash or red screen.

`Integrated PASS` means the feature is included in that Web build and X510 APK
and the application launched without an immediate crash or red screen. The
Evidence column names the direct behavior check used in addition to that smoke
baseline.

| Backlog | Web | X510 | Direct evidence |
| --- | --- | --- | --- |
| P0-001 | Integrated PASS | Integrated PASS | Revision, rapid journal, newest checkpoint, and intentionally empty revision tests |
| P0-002 | PASS | SKIPPED: Web-only | Headless Chrome canonical-loopback redirect evidence recorded in backlog |
| P0-003 | Integrated PASS | Integrated PASS | Complete JSON export/import, invalid-import immutability, and Web download tests |
| P0-004 | Integrated PASS | Integrated PASS | Backup-history listing, primary/checkpoint/history recovery, and restore tests |
| P0-005 | Integrated PASS | Integrated PASS | Clean analysis and complete model/template suite |
| P0-006 | Integrated PASS | Integrated PASS | Restored app-shell render and full feature suite |
| P0-007 | Integrated PASS | Integrated PASS | Duplicate ID, folder, date, number, broken-link, cycle, and ledger validation tests |
| P1-001 | Integrated PASS | Integrated PASS | Typed-link deduplication and export round-trip test |
| P1-002 | Integrated PASS | Integrated PASS | Relationship picker add/remove and outgoing/reverse navigation tests |
| P1-003 | Integrated PASS | Integrated PASS | Upcoming source edit, hidden state, and ordering tests |
| P1-004 | Integrated PASS | Integrated PASS | Dated plan task inclusion, deduplication, and completion tests |
| P1-005 | Integrated PASS | Integrated PASS | General rich note restart, inline style, list, todo block, image, and attachment-related editor tests |
| P1-006 | Integrated PASS | Integrated PASS | Theme contrast, persistence, and clean-theme tests |
| P1-007 | Integrated PASS | Integrated PASS | Cover/background picker, persistence, rendering, and removal tests |
| P1-008 | Integrated PASS | Integrated PASS | Legacy plan migration and legacy-editor save tests |
| P1-009 | Integrated PASS | Integrated PASS | Nested phase/task creation, reorder, subtree removal, restart, and export/import tests |
| P1-010 | Integrated PASS | Integrated PASS | Metadata editor, weighted progress, and home-task derivation tests |
| P1-011 | Integrated PASS | Integrated PASS | Legacy mind-map migration and legacy-editor save tests |
| P1-012 | Integrated PASS | Integrated PASS | Canvas add, move, lock, collapse, and persistence tests |
| P1-013 | Integrated PASS | Integrated PASS | Free connection edit/cleanup and auto-layout tests |
| P1-014 | Integrated PASS | Integrated PASS | Legacy life-project migration and legacy-editor save tests |
| P1-015 | Integrated PASS | Integrated PASS | Dashboard status/weight/progress and restart/export/import tests |
| P1-016 | Integrated PASS | Integrated PASS | Ledger migration, stable account ID, derived balance, edit/delete, and ambiguity tests |
| P1-017 | Integrated PASS | Integrated PASS | Shared-account deduplication, multi-account thresholds, and achieved-before tests |
| P2-001 | PASS | PASS | Web and Android release/debug builds with selected notification package stack |
| P2-002 | Integrated PASS | PASS | Native X510 integration created, found, and cancelled a pending notification; post-push app PID 11690 |
| P2-003 | PASS | PASS | Due derivation, persistent occurrence deduplication, source-selection tests; post-push app PID 12580 |
| P2-004 | PASS | PASS | Complete 132-test suite covers migration and critical data-safety paths |
| P1-019 | PASS | PASS | Direct image selection/drag, eight handles, independent resize, no text overlap, border subtoolbar, and crop cancel |
| P1-020 | PASS | PASS | Attachment document-flow block, Traditional Chinese internal preview, complete toolbar, and Android external-app chooser |
| P1-021 | PASS | PASS | Current theme/cover persistence and list rendering tests included in the integrated suite and APK |
| P1-022 | PASS | PASS | Paragraph/list newline placement and reload tests included in the integrated suite and APK |
| P2-007 | PASS | PASS | Home separator widget acceptance and current Home device surface |
| P2-008 | PASS | PASS | 132-test cross-module persistence workflow plus current cross-module X510 interaction and cold reinstall/launch |

## Remaining release observations

### Current truth-audit increment

- Web: debug build passed after the P2-008 note-export remediation.
- Automated suite: all 132 tests passed, including PDF/TXT/Markdown conversion,
  Traditional Chinese PDF generation, current persistence, templates,
  Calendar, Home, deletion/undo, attachments, and relationship behavior.
- One integrated workflow now creates every local v1 record family and all four
  note templates, then verifies Home settings, reminders, account-derived
  balances, typed links, local restart, and portable export/import together.
  This exposed and fixed todo `reminderTime` being incorrectly validated as an
  ISO date instead of its serialized `hour:minute` value.
- P0-008, P0-009, P1-018, P1-021, P1-022, and P2-007 have direct automated
  acceptance evidence recorded in the backlog and are included in this Web
  build.
- P1-019 device acceptance verified direct image selection and movement, all
  eight visible resize handles, independent horizontal resizing, text-flow
  separation, border activation at `0.2 px`, and safe crop cancellation.
- P1-020 device acceptance verified the attachment block, complete toolbar,
  readable Traditional Chinese internal preview, and Android external-app
  chooser.
- P2-008 is complete: the current APK's principal modules and all four template
  editors were exercised on X510, then the app passed a clean rebuild,
  reinstall, cold launch, and foreground-process check. Restart/export/import
  and relationship persistence use the integrated 132-test workflow.

- The Android build still emits the non-blocking upstream Built-in Kotlin/KGP
  warning tracked by P2-006.
- Firebase/cloud functions and store release remain explicitly deferred and are
  not part of this local-first v1 acceptance baseline.
