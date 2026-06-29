$ErrorActionPreference = 'Stop'

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$env:APPDATA = (Join-Path $projectRoot '.dart_appdata')
$env:LOCALAPPDATA = (Join-Path $projectRoot '.dart_localappdata')
$env:PUB_CACHE = (Join-Path $env:LOCALAPPDATA 'Pub\Cache')

New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
New-Item -ItemType Directory -Force -Path $env:LOCALAPPDATA | Out-Null
New-Item -ItemType Directory -Force -Path $env:PUB_CACHE | Out-Null

$flutter = 'D:\Flutter\flutter\bin\flutter.bat'
if (-not (Test-Path $flutter)) {
  throw "Flutter SDK not found: $flutter"
}

$arguments = @('/c', $flutter) + $args
& cmd.exe $arguments
exit $LASTEXITCODE
