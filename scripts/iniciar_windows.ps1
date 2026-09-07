param()
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Instala Flutter y agrega su carpeta bin al PATH. Consulta README.md.'
}
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'No se pudieron instalar las dependencias.' }
$ConfigPath = Join-Path (Get-Location) 'config/supabase.local.json'
if (Test-Path $ConfigPath) {
  flutter run -d windows "--dart-define-from-file=$ConfigPath"
} else {
  flutter run -d windows
}
if ($LASTEXITCODE -ne 0) { throw 'No se pudo iniciar la aplicación Windows.' }
