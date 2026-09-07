import {readFile,writeFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
const {PGlite}=await import(process.env.PGLITE_MODULE??'@electric-sql/pglite');
const root=fileURLToPath(new URL('../',import.meta.url));
const db=new PGlite();
try{
  await db.exec('CREATE ROLE anon;CREATE ROLE authenticated;CREATE SCHEMA auth;CREATE TABLE auth.users(id uuid PRIMARY KEY);');
  await db.exec('BEGIN;'+await readFile(root+'supabase/sql/01_modelo.sql','utf8')+'COMMIT;');
  const columns=(await db.query("SELECT table_name,column_name,data_type,is_nullable,column_default,is_identity FROM information_schema.columns WHERE table_schema='valhalla_private' ORDER BY table_name,ordinal_position")).rows;
  const constraints=(await db.query("SELECT t.relname tabla,c.conname nombre,c.contype tipo,pg_get_constraintdef(c.oid) definicion FROM pg_constraint c JOIN pg_class t ON t.oid=c.conrelid JOIN pg_namespace n ON n.oid=t.relnamespace WHERE n.nspname='valhalla_private' ORDER BY t.relname,c.conname")).rows;
  await writeFile(root+'docs/diccionario_postgres_03.json',JSON.stringify({columns,constraints},null,2));
  const tables=[...new Set(columns.map(x=>x.table_name))];
  let md='# Modelo PostgreSQL de VALHALLA\n\n'+tables.length+' tablas de negocio. Este diccionario se obtiene ejecutando el modelo en PostgreSQL y consultando sus metadatos. Las identidades de acceso se relacionan con `auth.users`, administrada por Supabase.\n\nImportes: centavos enteros. Existencias: milésimas. Fechas operativas: `timestamp with time zone`; cumpleaños: `date`.\n';
  for(const table of tables){
    md+='\n## '+table+'\n\n| Campo | Tipo | Admite nulo | Valor inicial |\n|---|---|---|---|\n';
    for(const c of columns.filter(c=>c.table_name===table))md+=`| ${c.column_name} | ${c.data_type} | ${c.is_nullable==='YES'?'Sí':'No'} | ${c.is_identity==='YES'?'Identidad autogenerada':(c.column_default??'—').replaceAll('|','\\|')} |\n`;
    md+='\nRestricciones y relaciones:\n\n';
    for(const c of constraints.filter(c=>c.tabla===table))md+='- `'+c.definicion+'`\n';
  }
  await writeFile(root+'docs/MODELO_SUPABASE.md',md);
  process.stdout.write(`Diccionario: ${tables.length} tablas, ${columns.length} campos, ${constraints.filter(c=>c.tipo==='f').length} relaciones.\n`);
}finally{await db.close();}
