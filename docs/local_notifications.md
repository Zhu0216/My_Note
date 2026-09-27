# Local notification decision

## Selected packages

- `flutter_local_notifications ^22.3.1`
- `timezone ^0.11.1`
- `flutter_timezone ^5.1.0`

All three packages are free to use. `flutter_local_notifications` uses the
BSD-3-Clause license, `timezone` uses BSD-2-Clause, and `flutter_timezone` uses
Apache-2.0.

## Why this stack

- It supports scheduled Android notifications while the app is closed.
- Notification IDs can be used to update or cancel a reminder without creating
  duplicates.
- `zonedSchedule` supports timezone-aware dates and daylight-saving changes.
- The Android implementation exposes notification permission requests and both
  exact and inexact scheduling modes.
- The packages support the project's Dart 3.12.2, Java 17, compile SDK, and AGP
  8.11.1 toolchain.
- The packages are actively maintained and have current Flutter releases.

## V1 scheduling policy

- Use inexact scheduling that may run while idle. V1 does not request exact
  alarm permission and does not use full-screen intents.
- Request Android notification permission in context when the user enables a
  reminder, not during an unrelated app launch.
- Use stable source-derived notification IDs so create, edit, disable, complete,
  and delete operations replace or cancel the corresponding notification.
- Todo reminders require a due date and enabled reminder time.
- Schedule reminders use the event start minus its reminder lead time.
- Subscription reminders use the next payment date minus reminder days.
- Reconcile all pending reminders after loading local data and after relevant
  source records change.
- Keep Web email delivery deferred. The Web app uses the in-app reminder surface
  specified by P2-003.

## Android requirements for P2-002

- Core library desugaring and multidex are enabled.
- Add boot-completed permission and the plugin's scheduled-notification and boot
  receivers.
- Keep the existing `POST_NOTIFICATIONS` permission.
- Initialize timezone data and set the device IANA timezone before scheduling.
- Create one user-visible reminder notification channel.

## Implemented Android behavior

- Channel ID: `my_note_reminders`.
- Managed payload prefix: `my_note:`; reconciliation only cancels reminders
  owned by My Note's local reminder service.
- Schedule mode: `inexactAllowWhileIdle`, so no exact-alarm permission is used.
- Subscription reminders run at 09:00 local time on the configured day.
- A dedicated monochrome `ic_notification` drawable is used for Android status
  bar compatibility.
