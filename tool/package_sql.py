from pathlib import Path
root=Path(__file__).resolve().parents[1]
files=[root/'supabase/sql'/n for n in ['01_modelo.sql','02_operaciones.sql','03_semilla.sql']]
body='-- VALHALLA 0.3.0 · Instalación PostgreSQL/Supabase.\n-- No contiene contraseñas. No elimina tablas existentes.\nBEGIN;\n'
body+='\n'.join(p.read_text() for p in files)
body+='\nCOMMIT;\n'
(root/'supabase/INSTALAR_VALHALLA.sql').write_text(body)
print('Instalador SQL generado.')
