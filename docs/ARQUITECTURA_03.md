# Arquitectura 0.3
Flutter se comunica por HTTPS con Supabase Auth y PostgREST. Las pantallas conservan los contratos de negocio. No se incluyen procesos de servidor propios ni contraseñas administrativas en el cliente.

## Acceso a datos
Las 35 tablas están en `valhalla_private`, con RLS habilitado y sin permisos directos de lectura/escritura para `anon` o `authenticated`. No se debe agregar este esquema a los esquemas expuestos de PostgREST.

La función pública `valhalla_rpc` tiene SECURITY INVOKER y solo admite usuarios autenticados. Delega en una función interna SECURITY DEFINER necesaria para operar sobre las tablas privadas. Esta función valida:
1. `auth.uid()`, correo confirmado y registro activo en Equipo.
2. Una sesión existente en `auth.sessions`, creada después de la última modificación de acceso.
3. Rol obtenido de la base y sucursal asignada activa.
4. Una lista cerrada de acciones por rol y las reglas de cada operación.

La función interna tiene un search_path fijo hacia esquemas sin permisos CREATE para usuarios finales. Los auxiliares no pueden ser ejecutados por clientes. No se usan metadatos editables del usuario para decidir permisos.

## Permisos
| Acción | Administrador | Encargado | WhatsApp | Barbero |
|---|---|---|---|---|
| Clientes y notas | Gestiona | Gestiona | Gestiona | Sin acceso |
| Crear/cancelar citas | Sí | Sí | Sí | No |
| Consultar agenda | Sucursal asignada | Sucursal asignada | Sucursal asignada | Solo propias |
| Confirmar corte | Sí | Sí | No | Solo propio |
| Cobros, inventario, caja y gastos | Sí | Sí | No | No |
| Comisiones | Sucursal | Sucursal | No | Solo propias |
| Equipo, catálogos y configuración | Sí | Sí | No | No |
| Cuenta y recuperación | Propia | Propia | Propia | Propia |

Las cuentas activadas conservan su correo en Equipo para evitar reasignaciones de identidad. Para cambiarlo, se desactiva la cuenta anterior y se registra la nueva. No se puede eliminar o degradar al último administrador activo.

## Consistencia
Los cobros calculan precios, beneficios, comisiones y cambios de stock en una sola transacción. Si falla una parte, se revierte todo. El dinero se representa en centavos enteros y el stock en milésimas.

Un bloqueo transaccional común serializa las escrituras breves del negocio, incluidos cobros, cambios de precios, cierres, beneficios y traslados entre sucursales. Es una decisión conservadora apropiada para el volumen inicial de la barbería; no es un diseño para miles de escrituras por segundo.

Las claves de idempotencia están vinculadas a usuario, sucursal, acción y contenido. Reintentar una solicitud idéntica devuelve el resultado anterior; reutilizar la clave con datos distintos falla.

Las citas se comprueban por barbero entre todas las sucursales. La confirmación registra actor y fecha, acepta reintentos sin duplicar auditoría y no permite marcar como atendidas citas futuras o canceladas.

## Autenticación y correo
Las contraseñas, códigos, caducidad y límites de intentos pertenecen a Supabase Auth. El proyecto debe configurar SMTP, plantillas con `{{ .Token }}`, confirmación de correo y política de contraseña. La aplicación añade una espera de 60 segundos para reenviar, pero la protección real frente a abuso corresponde a Auth.

No se guardan contraseñas en la base de negocio. La aplicación guarda solo la URL y la clave pública en preferencias y conserva la sesión en memoria. Al reiniciar se inicia sesión nuevamente. Al cambiar o recuperar contraseña se solicita cierre global de sesiones.

## Instalar y migrar
El instalador SQL es para una instalación nueva en el esquema reservado de VALHALLA. Utiliza una transacción y se detiene si las tablas ya existen. No borra objetos para forzar su ejecución. Cambios posteriores requieren migraciones aditivas revisadas.

Los datos SQLite no se importan con la semilla. Se conserva la entrega anterior como origen si es necesario planificar una importación.
