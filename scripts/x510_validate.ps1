param(
  [string]$DeviceId = 'R52X200FM7F',
  [string]$PackageName = 'com.allinone.mynote'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$adb = Join-Path $env:LOCALAPPDATA 'Android\sdk\platform-tools\adb.exe'
$apk = Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-debug.apk'

if (-not (Test-Path -LiteralPath $adb)) {
  Write-Output 'SKIPPED: Android SDK adb was not found.'
  exit 0
}

$deviceLine = (& $adb devices -l | Select-String -Pattern "^$([regex]::Escape($DeviceId))\s+").Line
if (-not $deviceLine -or $deviceLine -notmatch '\sdevice(?:\s|$)') {
  Write-Output "SKIPPED: X510 $DeviceId is offline or unauthorized."
  exit 0
}

Push-Location $projectRoot
try {
  & flutter build apk --debug
  if ($LASTEXITCODE -ne 0) {
    Write-Output 'FAIL: Debug APK build failed.'
    exit $LASTEXITCODE
  }

  & $adb -s $DeviceId install -r $apk
  if ($LASTEXITCODE -ne 0) {
    Write-Output 'FAIL: APK installation failed.'
    exit $LASTEXITCODE
  }

  & $adb -s $DeviceId shell am force-stop $PackageName | Out-Null
  & $adb -s $DeviceId shell monkey -p $PackageName -c android.intent.category.LAUNCHER 1 | Out-Null
  Start-Sleep -Seconds 5

  $appPid = (& $adb -s $DeviceId shell pidof $PackageName).Trim()
  $foreground = (& $adb -s $DeviceId shell dumpsys activity activities |
      Select-String -Pattern "topResumedActivity=.*$([regex]::Escape($PackageName))/.MainActivity" |
      Select-Object -First 1)
  if (-not $appPid -or -not $foreground) {
    Write-Output 'FAIL: App did not remain running in the foreground after launch.'
    exit 1
  }

  Write-Output "PASS: $PackageName is running on SM-X510 ($DeviceId), pid $appPid."
} finally {
  Pop-Location
}
