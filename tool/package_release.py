"""Empaqueta la entrega configurada sin archivos generados ni documentación obsoleta."""
from pathlib import Path
import argparse
import hashlib
import re
import shutil
import zipfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path, default=root.parent / 'entrega')
out = parser.parse_args().output.resolve()
out.mkdir(parents=True, exist_ok=True)
top_files = {
    'README.md', 'EMPIEZA_AQUI.md', 'pubspec.yaml', 'pubspec.lock',
    'analysis_options.yaml', '.gitignore', '.metadata',
}
folders = {'lib', 'packages', 'windows', 'android', 'linux', 'assets', 'test', 'supabase', 'tool'}
docs = {
    'ARQUITECTURA_03.md', 'VALIDACION_03.md', 'MODELO_SUPABASE.md',
    'diccionario_postgres_03.json', 'der_lucid_original.sql',
    'pruebas_postgres_03.txt', 'pruebas_cliente_03.txt', 'analisis_dart_03.txt',
}
scripts = {'iniciar_windows.ps1', 'iniciar_android.ps1', 'verificar.ps1'}
excluded = {'.dart_tool', '.git', 'node_modules', 'build', 'ephemeral', '__pycache__', '.gradle'}

def included(path):
    rel = path.relative_to(root)
    if any(part in excluded for part in rel.parts):
        return False
    if path.suffix in {'.pyc', '.db', '.pem', '.secret', '.log'}:
        return False
    if path.name in {'local.properties', '.flutter-plugins-dependencies'}:
        return False
    return (
        (len(rel.parts) == 1 and rel.name in top_files)
        or rel.parts[0] in folders
        or (rel.parts[0] == 'docs' and rel.name in docs)
        or (rel.parts[0] == 'scripts' and rel.name in scripts)
        or rel.as_posix() == 'config/supabase.example.json'
    )

for name in ['pruebas_postgres_03.txt', 'pruebas_cliente_03.txt', 'analisis_dart_03.txt']:
    path = root / 'docs' / name
    path.write_text(re.sub(r'\x1b\[[0-9;]*m', '', path.read_text()), encoding='utf-8')

prefix = 'VALHALLA_v0_3_1/'
archive = out / 'VALHALLA_Flutter_v0_3_1_Configurado.zip'
with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for path in sorted(root.rglob('*')):
        if path.is_file() and included(path):
            z.write(path, prefix + path.relative_to(root).as_posix())
sql = out / 'VALHALLA_Supabase_Tablas_y_Semilla.sql'
shutil.copyfile(root / 'supabase' / 'INSTALAR_VALHALLA.sql', sql)

with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    assert 'version: 0.3.1+5' in z.read(prefix + 'pubspec.yaml').decode()
    assert z.read(prefix + 'supabase/INSTALAR_VALHALLA.sql') == sql.read_bytes()
    assert not any('/server/' in name or '/node_modules/' in name for name in z.namelist())
    # La aplicación y el instalador no contienen cadenas de conexión privadas.
    for name in z.namelist():
        if name.endswith(('.dart', '.sql', '.json', '.yaml', '.md', '.txt', '.ps1')):
            data = z.read(name)
            if name == prefix + 'test/cloud_client_test.dart':
                data = data.replace(b'postgresql://postgres:example@host/db', b'')
            assert not re.search(rb'postgres(?:ql)?://[^\s]+:[^\s]+@', data), name
    print(f'ZIP verificado: {len(z.namelist())} archivos.')
for path in [archive, sql]:
    print(f'{path.name}: {path.stat().st_size} bytes; SHA256 {hashlib.sha256(path.read_bytes()).hexdigest()}')
