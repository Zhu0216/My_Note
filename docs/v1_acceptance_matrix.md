# V1 Web and X510 acceptance matrix

Date: 2026-09-27

Integrated baseline:

- Web: `flutter build web --release --no-pub` passed on commit `f976658`.
- Android: debug APK built, installed, and stayed in the foreground on Samsung
  SM-X510 (`R52X200FM7F`), Android 16 / API 36, after commit `f976658`.
- Automated suite: 104 tests passed on the same application baseline.
- P2-004 commit `2b593a0` changes documentation only, so it does not invalidate
  the application baseline above.

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
| P2-004 | PASS | PASS | Complete 104-test suite covers migration and critical data-safety paths |

## Remaining release observations

- The Android build still emits the non-blocking upstream Built-in Kotlin/KGP
  warning tracked by P2-006.
- Firebase/cloud functions and store release remain explicitly deferred and are
  not part of this local-first v1 acceptance baseline.
