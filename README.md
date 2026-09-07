# VALHALLA · Flutter y Supabase
Versión **0.3.1+5**. Gestión de barbería para Windows y Android con datos compartidos en PostgreSQL. La URL y la clave pública de Supabase ya están incorporadas; basta con ejecutar Flutter. Para habilitar Mailjet consulta `supabase/MAILJET.md`.

Sigue **EMPIEZA_AQUI.md** para instalar el modelo, habilitar el correo y conectar la aplicación. No se requiere ejecutar un proceso Dart/Shelf ni contratar un servidor para esta versión.

## Funciones incluidas
- Acceso por correo y contraseña, activación de cuenta y recuperación por código.
- Equipo con roles y sucursales; administrador y encargado tienen gestión completa.
- Clientes, notas, historial y fidelidad.
- Agenda: administrador, encargado y WhatsApp crean/cancelan citas. El barbero consulta las propias y confirma cortes realizados.
- Cobros con servicios/productos, descuentos con motivo, efectivo o transferencia.
- Precio histórico, comisión aplicada al momento del cobro, inventario y traslados.
- Membresías con servicios y condiciones conservados al momento de compra.
- Gastos, apertura y cierre de caja con control de saldo y auditoría.

Confirmar un corte no cobra automáticamente ni genera comisiones por sí mismo. El cobro se registra en **Nuevo cobro** por administración o el encargado.

## Estructura
- `lib/ui/`: interfaz Flutter adaptable.
- `lib/data/api_client.dart`: Supabase Auth y llamadas a PostgreSQL.
- `lib/data/api_repository.dart`: operaciones de aplicación y solicitudes idempotentes.
- `packages/valhalla_core/`: contratos, modelos y validaciones locales.
- `supabase/INSTALAR_VALHALLA.sql`: instalación completa.
- `supabase/sql/`: modelo, operaciones y semilla por separado.
- `supabase/templates/`: plantillas de correo.
- `test/`: pruebas del cliente y de recuperación en escritorio/móvil.
- `tool/postgres_test.mjs`: pruebas ejecutables con PostgreSQL embebido.
- `docs/`: arquitectura, modelo y validación.

## Verificación
```powershell
.\scripts\verificar.ps1
```

Las pruebas SQL también se ejecutan con:
```sh
cd tool
npm ci
npm run test:postgres
```

Las pruebas crean identidades y datos únicamente en una base temporal, sin conectarse a la base del negocio ni enviar correos.

## Límites actuales
Esta versión requiere Internet para consultar y guardar. No incorpora sincronización sin conexión, instaladores EXE/APK ni importación automática de datos SQLite. Las credenciales y la configuración SMTP se gestionan en Supabase. El plan de alojamiento y los límites de correo dependen de la cuenta del propietario.

Referencias oficiales: [Flutter](https://supabase.com/docs/reference/dart/introduction), [correo SMTP](https://supabase.com/docs/guides/auth/auth-smtp), [seguridad de la API](https://supabase.com/docs/guides/api/securing-your-api).
