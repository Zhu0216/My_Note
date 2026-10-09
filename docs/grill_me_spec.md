# My Note v1 Grill Me Specification

## Product definition

My Note v1 is a local-first personal life operating system for Android and
Flutter Web. Its primary daily workflows are:

1. Record and complete todos.
2. View and manage schedules.
3. Track upcoming subscriptions.

Notes, plans, mind maps, life projects, finance, subscriptions, schedules,
and todos are separate tools that can reference one another. Together they
form a navigable memory network, not a visual graph.

The visual graph is intentionally not part of the product roadmap. The term
`memory network` describes linked records, reverse references, and navigation;
it does not imply a node-and-edge canvas now or in a later release.

## v1 boundaries

- v1 is local-first and must work offline.
- Firebase packages and configuration placeholders may remain, but Firebase
  Auth, Firestore, Storage, FCM, and cloud synchronization are not enabled in
  v1.
- Google Play and Apple App Store release preparation is out of scope for v1.
- Existing local data must be migrated, retained, exportable, recoverable, and
  never silently replaced by seed data.
- Web shows reminders when the app is opened. Android delivers real local
  notifications. Web email notifications are deferred until a cloud mail
  service or Firebase Functions is deliberately enabled.

## Home and upcoming items

### Home

The home page prioritizes today schedules, upcoming items, subscriptions,
monthly finance, recent notes, and todos. Its existing configurable ordering,
visibility, list/grid styles, and collapsible sections remain supported.

The titles of `今日行程`, `即將到來`, and `待辦事項` show the total number of
matching items next to the title. A content list may be intentionally capped;
the count is never capped.

### Upcoming items

`近期事項` / `即將到來` is a derived display, not a separately stored entity.
It links back to its source record and is not directly created or edited.

It aggregates relevant time-bound records:

- upcoming schedules;
- subscription payment or expiry dates;
- todos with due dates;
- incomplete plan tasks with due dates, even when they were not added to the
  home todo list.

If this becomes too dense or noisy, plan tasks can later be excluded without
changing the stored data model.

## Links and memory network

Every supported record can expose a consistent `關聯項目` entry point.

- A user can search and link notes, plans, mind maps, life projects, todos,
  schedules, finance records, subscriptions, and accounts.
- A user can create an item and link it immediately.
- Links are navigable in both directions.
- The product deliberately does not render a graph visualization. This is a
  non-goal rather than deferred work.
- v1 links do not require relationship labels such as `depends on` or
  `reference`; a simple untyped link is sufficient.

## General note

Only the general note template contains the rich-text editor. It retains text
formatting, lists, inline todo blocks, images, attachments, references, and
export capabilities.

Note appearance is optional and must not make editing feel like page design:

- The default is clean white paper with no cover or background.
- Users may choose built-in appearance themes.
- A cover image or low-contrast background image is optional.
- Backgrounds must not compromise text contrast or rich-text editing.
- Arbitrary CSS-like per-note layout controls are out of scope.

## Plan template

Plans are structured documents rather than rich-text notes.

```text
Plan
└─ Phase
   ├─ Task
   └─ Child phase
      └─ Task
```

- There are exactly two node types: `phase` and `task`.
- A phase may contain unlimited nested phases and tasks.
- A task is terminal and cannot contain child nodes.
- A phase can have title, due date, weight, and aggregated completion rate.
- A task can have title, completed status, due date, priority, weight,
  references, an optional linked todo, an optional linked schedule, and a
  `show on home todos` choice.
- Completion is weighted: equal weights are the default, but users can change
  the weight of important tasks.
- Phase and plan completion rates are calculated from descendant tasks.
- A dated incomplete task appears in upcoming items even if it is not shown in
  the home todo section.

## Mind map template

Mind maps are structured canvases rather than rich-text notes.

- Every mind map has one required central topic/root node.
- Nodes support title, position, color, expand/collapse, lock state, and links
  to other records.
- Users can pan and zoom the canvas, select nodes, move unlocked nodes, and
  lock nodes.
- Parent-child connections are supported.
- Users can create free connections between nodes.
- A free connection supports color, solid/dashed line style, and an optional
  direction arrow.
- One-click layout arranges only unlocked nodes and preserves the central node
  and all locked-node positions.

## Life project template

`人生試算表` is a structured life-project dashboard. The first screen is a
project-card overview, not a monthly forecast.

### Project card

Each project card has:

- title;
- status: `進行中` or `完成`;
- start date and target date where applicable;
- linked plans, todos, schedules, finance records, subscriptions, and accounts;
- a total weighted progress meter;
- a vertical money meter with current amount, target amount, thresholds, and
  percentage;
- user-created project items.

### Project items

Each item has a name, weight, order, links, completion state, and one display
mode:

- `金錢`: target amount plus either manual current amount or account-derived
  current amount;
- `狀態／完成率`: completed state and manually set progress.

`實際花費` and arbitrary item type fields are not part of v1.

### Finance authority and money meter

An account has an opening balance. Its live balance is calculated from:

```text
opening balance + income entries - expense entries
```

Finance records must select an account. When a life-project money item links
to accounts, the linked account balance is the authority; the item must not
silently overwrite it with a competing manual balance.

Different project items may use different accounts. If multiple money items
reference the same account, they are ordered as one cumulative meter group:

- the account balance is counted only once;
- ordered target thresholds define bottom-to-top meter segments;
- crossing a threshold updates that segment/item's attainment;
- a lower later balance keeps an `achieved before` record while also exposing
  that the threshold is no longer currently maintained;
- multiple linked accounts may contribute to an item, while unique account
  balances must never be double counted across the project.

Total project progress uses weighted item completion. Money progress is a
separate meter, not a replacement for total progress.

## Reminder policy

- Todo notifications require a due date and an enabled reminder.
- Schedule notifications use the schedule's reminder lead time.
- Subscription notifications use the subscription reminder-day value.
- Upcoming items aggregate information and do not send duplicate notifications.
- On Android, reminders use actual local notifications.
- On Web, reminders appear in-app when opened; optional email delivery is a
  post-v1 cloud capability.

## Local data safety

- Every change is serialized and persisted with a revision, checkpoint,
  change journal, latest backup, and backup history.
- Web local development uses `localhost` as the canonical origin; loopback IP
  URLs redirect to it to prevent separate browser storage spaces.
- Settings exposes JSON export and import.
- Import validates the bundle, creates a recovery checkpoint, then applies the
  imported snapshot.
- Legacy direct snapshots remain importable.
- All schema migrations must preserve existing records and be covered by tests.

## v1 completion amendment

The following requirements were confirmed after the original v1 acceptance
pass. They reopen v1 until implementation and acceptance evidence are complete.

### Deletion, undo, and contextual return

- Every existing swipe-delete action deletes immediately without a confirmation
  dialog and offers one app-wide `復原` action for five seconds.
- Additional deletes within the active window join the same batch and restart
  the full five-second timer. Undo restores the complete batch, including
  original ordering, folders, and relationships.
- Hard-deleted targets disappear immediately, but incoming relationships are
  retained until the undo window expires. Expiry atomically removes the records
  and dangling links; interrupted cleanup resumes after restart.
- Moving a note to the trash retains its links. Incoming links are removed only
  when the trash item is permanently deleted.
- Editors and related-item routes return to the actual route that opened them.
  Folder, search, filter, sort, view, expansion, and scroll state are restored;
  batch selection is not restored. A route with no known origin returns Home.
- Deleting a note returns to its origin instead of navigating to the trash.

### General-note images

- Cropping is confined to the original image bounds. It never pads, extends,
  fills, or generates missing image content. Display scaling may exceed the
  original display size.
- An unlocked selected image moves by dragging the image itself; a separate move
  mode is not required. Resize handles remain responsible only for resizing.
- New images have no border. Enabling the border restores the last configured
  width or starts at `0.2 px`; width ranges from `0` to `5 px` in `0.1 px`
  steps. Border color and width live in a secondary toolbar that appears only
  while the border is enabled and does not automatically focus its input.
- The image, border, selection outline, and all eight resize handles remain
  visible and operable on Web and Android without overlapping text.

### Attachments and inserted notes

- Attachment payloads no longer live in SharedPreferences snapshots. Android
  stores blobs in private app files and Web stores blobs in IndexedDB. Notes,
  checkpoints, and backup history reference content-addressed blob IDs so equal
  files are not duplicated.
- Legacy Base64 attachments migrate atomically: metadata changes only after the
  blob is verified. Failure preserves the legacy attachment and current data.
- A single attachment is limited to `25 MB`. `100 MB` is the per-note warning
  boundary: a final upload may cross it, but a note already over `100 MB` cannot
  accept another attachment. `125 MB` is the absolute per-note limit.
- Automatic checkpoints and backup history retain attachment blobs. Manual JSON
  export includes attachments by default and may explicitly exclude them;
  incomplete exports preserve missing-attachment placeholders on import.
- Attachment selection offers preview, external open, download/save-as, rename,
  replace, and remove. Built-in preview supports images, paged PDF viewing, and
  safe plain-text rendering for TXT, Markdown, JSON, and CSV. HTML is never
  executed. Unsupported or damaged files remain downloadable and externally
  openable.
- An inserted-note block and the ordinary relationship picker share the same
  typed link while independently tracking why the link exists. Removing one
  representation preserves the link while the other still references it.
- Inserted-note selection offers preview, edit, retarget, and remove-from-note;
  it never deletes the target note. Editing follows the contextual return path.
  v1 previews are read-only summaries appropriate to each note template.

### Note appearance and editing correctness

- Per-note appearance themes, background color, background image, opacity, and
  background layout mode are removed from the schema and UI. Existing values
  are discarded by the approved migration after a recovery snapshot is made.
- Per-note and per-span custom text colors are removed. Text, links, quotes,
  code, selection, and editor chrome derive their colors from the active app
  theme in light and dark modes.
- Cover images remain, but do not render inside the note body. List views use a
  fixed-height, centered, uncropped `contain` presentation whose width follows
  the source aspect ratio and never exceeds the available card width.
- Pressing Enter between existing text creates and focuses a real empty
  paragraph. It must not place the caret at the beginning of the following
  paragraph. List modes create the correct next list item.

### Home presentation and v1 truth audit

- Adjacent visible Home sections are separated by a centered line using 90% of
  the content width and the theme primary color at 40% opacity. Hidden sections
  do not participate; collapsed visible sections do.
- Every v1 control, menu, toolbar action, gesture, persistence path, restart,
  export/import flow, and critical Web/X510 workflow must be re-audited. Any
  previously `DONE` item that proves cosmetic, incomplete, non-persistent, or
  broken returns to `IN PROGRESS` until it has current evidence.

## Architecture

The implementation is split by responsibility:

- `data/`: records, document schemas, persistence, backup/import/export;
- `features/`: Home, Notes, Calendar, Finance, Settings;
- `editor/`: general-note rich-text editor only;
- `shared/`: theme, navigation, formatters, reusable UI;
- `main.dart`: composition root and app shell.

Refactoring must preserve existing UI behavior unless this specification calls
for a change.
