param([string]$Device = '')
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'No se pudieron instalar las dependencias.' }
$FlutterArgs = @('run')
if ($Device) { $FlutterArgs += @('-d', $Device) }
$ConfigPath = Join-Path (Get-Location) 'config/supabase.local.json'
if (Test-Path $ConfigPath) { $FlutterArgs += "--dart-define-from-file=$ConfigPath" }
& flutter @FlutterArgs
if ($LASTEXITCODE -ne 0) { throw 'No se pudo iniciar Flutter. Selecciona el dispositivo Android conectado.' }
