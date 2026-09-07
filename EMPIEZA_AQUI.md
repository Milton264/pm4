# VALHALLA 0.3.1 · Supabase configurado
Esta versión utiliza Flutter para Windows y Android y PostgreSQL en Supabase. Solo se inicia Flutter. Necesita Internet; cada dispositivo comparte la misma base.

## 1. Crear tablas y cargar la semilla
Abre el proyecto **gapseqbyjbwudjwegxun** en Supabase, entra a **SQL Editor**, pega el contenido completo de **supabase/INSTALAR_VALHALLA.sql** y pulsa Run.

Crea 35 tablas de negocio en el esquema `valhalla_private`, sus campos, claves foráneas, índices y funciones. Las tablas de autenticación pertenecen a Supabase Auth. Puedes ver las tablas eligiendo ese esquema en Table Editor.

El instalador crea todo en una transacción. No borra tablas existentes. Si ya existe una instalación VALHALLA, se detiene para evitar sobrescribirla. La semilla separada `supabase/sql/03_semilla.sql` admite repetición dentro de una transacción.

## 2. Configurar autenticación y correos
En Supabase Auth habilita Email, registro de usuarios y **Confirm email**. Configura la longitud mínima de contraseña en 12 caracteres y, preferiblemente, el vencimiento del código en 900 segundos.

En las plantillas de correo, sustituye:
- **Confirm signup** por `supabase/templates/confirmar_cuenta.html`.
- **Reset password** por `supabase/templates/recuperar_password.html`.

Ambas usan `{{ .Token }}`. El código se escribe en la aplicación; no requiere configurar enlaces para Windows o Android.

Para enviar correos a empleados que no pertenecen al equipo del proyecto Supabase, configura un proveedor SMTP en Auth. El envío predeterminado de Supabase está restringido a destinatarios del equipo y tiene límites bajos; no equivale a correo listo para todos los empleados. Esta configuración no puede hacerse con el SQL ni con la contraseña de PostgreSQL.

## 3. Conectar Flutter
La URL y la clave publicable suministradas ya están incorporadas en esta entrega. Puedes ejecutar `flutter run` directamente, sin copiar claves ni archivos. Los pasos siguientes solo son necesarios si deseas usar otro proyecto. Para terminar la configuración de Mailjet, sigue `supabase/MAILJET.md`.

Copia la **Publishable key** de Supabase, en la configuración de API keys del proyecto. Usa una clave que comience con `sb_publishable_`. También se admite la clave heredada `anon`.

Puedes pegarla en **Configurar conexión** al abrir la aplicación. La URL del proyecto ya viene cargada.

Para no repetir la configuración en cada instalación, copia `config/supabase.example.json` como `config/supabase.local.json` y reemplaza el marcador por la clave publicable. Ese archivo solo contiene configuración pública; nunca pegues la contraseña de PostgreSQL ni una clave `service_role` o `sb_secret_`.

## 4. Ejecutar
Requiere Flutter con Dart 3.9 o posterior, herramientas de compilación Windows o un dispositivo Android.

Windows, desde esta carpeta:
```powershell
.\scripts\iniciar_windows.ps1
```

Android:
```powershell
.\scripts\iniciar_android.ps1
```

También funciona `flutter run`; configura la conexión desde la aplicación si no pasas el archivo de configuración.

## 5. Primer acceso
La semilla reserva el rol administrador para **milton.ramirez@catolica.edu.sv**, con acceso a El Trébol y Bypass. No crea ninguna contraseña.

Pulsa **Activar mi cuenta**, utiliza ese correo, elige tu contraseña, solicita el código y confírmalo. Luego inicia sesión. Si ya habías creado ese usuario en Supabase Auth, inicia sesión o usa **Olvidé mi contraseña**.

Desde **Equipo**, administrador y encargado pueden registrar los demás correos, roles y sucursales. Cada empleado activa su cuenta siguiendo el mismo proceso. Registrarse en Auth por cuenta propia no otorga acceso al negocio si el correo no está autorizado en Equipo.

## 6. Datos del proyecto anterior
La base SQLite del backend anterior permanece en tu computadora. No se sube automáticamente a Supabase. Conserva la carpeta anterior y `server/data/valhalla.db` si ya guardaste información que necesitas migrar. La semilla de esta entrega inicia clientes, citas, ventas y existencias vacíos.

## Estado de la entrega
Consulta `docs/VALIDACION_03.md` para saber qué se verificó. No se aplicaron cambios a tu Supabase desde este entorno: el conector no tiene acceso a ese proyecto y el host PostgreSQL no resolvió aquí. El SQL está preparado para ejecutarlo en el editor de tu proyecto.
