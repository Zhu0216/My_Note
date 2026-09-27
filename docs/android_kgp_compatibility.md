# Android Built-in Kotlin compatibility

Checked: 2026-09-27

## Current result

The project uses Flutter's current Android Gradle layout and a clean debug APK
build succeeds. Flutter still reports that these upstream plugins apply the
Kotlin Gradle Plugin directly:

- `file_picker 10.3.3`
- `firebase_storage 13.4.3`
- `flutter_timezone 5.1.0`
- `share_plus 12.0.1`

This is a future-compatibility warning emitted by Flutter 3.44.3. It does not
break the current Android build or runtime.

## Upgrade investigation

`flutter pub outdated` was checked against pub.dev. `flutter_timezone 5.1.0`
is current. A trial used the newest resolvable Firebase packages,
`share_plus 12.0.2`, and `file_picker 13.1.0`:

- the warning remained and expanded to additional Firebase plugins;
- `file_picker 13.1.0` has a breaking federated API that invalidates the
  existing picker abstraction and tests;
- `share_plus 13.3.0` conflicts with `file_picker 10.3.3` through incompatible
  `win32` constraints;
- the trial did not provide a warning-free configuration, so the package
  changes were not retained.

The warning cannot be removed in the application Gradle files without forking
or replacing those plugins. Recheck when each upstream plugin publishes a
Built-in Kotlin release.

## Clean-build correction

A clean build exposed that `UCropActivity` references
`Theme.AppCompat.Light.NoActionBar` while AppCompat was only available through
an old transitive build cache. The app now declares
`androidx.appcompat:appcompat:1.7.1` directly. After that correction, a clean
debug APK and the regular Web release build both complete successfully.
