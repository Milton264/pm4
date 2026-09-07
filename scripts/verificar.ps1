$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'Falló la instalación de dependencias.' }
flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'Falló el análisis Flutter.' }
flutter test
if ($LASTEXITCODE -ne 0) { throw 'Fallaron las pruebas Flutter.' }
if (Get-Command npm -ErrorAction SilentlyContinue) {
  Push-Location tool
  try {
    npm ci
    if ($LASTEXITCODE -ne 0) { throw 'Falló la instalación de las herramientas de prueba SQL.' }
    npm run test:postgres
    if ($LASTEXITCODE -ne 0) { throw 'Fallaron las pruebas PostgreSQL.' }
  } finally { Pop-Location }
}
