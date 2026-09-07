# Validación de VALHALLA 0.3.0

## Ejecutado
- Modelo creado en PostgreSQL embebido (PGlite), incluida la semilla y las funciones.
- 35 tablas, 267 campos y 74 relaciones verificadas mediante el catálogo de PostgreSQL.
- 14 grupos de pruebas SQL: roles, sucursales, agenda, confirmación propia, cancelación, idempotencia, stock, comisiones, membresías, fidelidad, cumpleaños, cambios de precios, gastos, caja y revocación de acceso.
- 6 pruebas del cliente Dart con transporte HTTP controlado: acceso, recuperación, activación, cierre de sesiones, adaptación de operaciones y errores. No envían correos reales.
- Resolución de dependencias y archivo pubspec.lock para Flutter 3.35.3 / Dart 3.9.2. Se incluyen versiones fijadas de Supabase y de las herramientas de prueba SQL.
- Análisis estático de lib, valhalla_core y test utilizando el SDK y las bibliotecas de Flutter.

Los resultados están en `pruebas_postgres_03.txt`, `pruebas_cliente_03.txt` y `analisis_dart_03.txt`.

## Pendiente en el entorno del propietario
- Ejecutar el instalador SQL en el proyecto Supabase. El acceso conectado no tenía permisos sobre ese proyecto y el host PostgreSQL no resolvió desde este entorno. No se aplicaron cambios remotos ni se verificaron sus tablas existentes.
- Configurar una clave publicable, SMTP y las plantillas de correo. No se comprobó entrega a buzones reales.
- Ejecutar las pruebas de widgets y compilar Windows/Android. La revisión automática bloqueó el arranque de la herramienta Flutter porque intentó consultar el endpoint de metadatos de la máquina. El análisis estático y las pruebas del cliente se realizaron por una vía local que no requiere esa consulta.

Se incluyen pruebas de la recuperación a 1440×1000 y 320×740 para ejecutarlas con `flutter test`. No se presentan como ejecutadas aquí.

Las pruebas PostgreSQL usan las funciones de negocio completas. Las tablas de identidad y sesiones de Supabase se sustituyen por tablas temporales compatibles para verificar los permisos; esto no sustituye una prueba final contra Supabase Auth real.
