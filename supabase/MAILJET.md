# Activar Mailjet en Supabase

La recuperación y activación por código ya están implementadas. El proveedor de correo se configura una sola vez en Supabase, sin instalar un servidor en tu computadora.

Abre https://supabase.com/dashboard/project/gapseqbyjbwudjwegxun/auth/smtp y activa SMTP personalizado:

| Campo | Valor |
|---|---|
| Host | `in-v3.mailjet.com` |
| Puerto | `587` |
| Username | La API key de Mailjet que compartiste |
| Password | La Secret key de Mailjet que compartiste |
| Sender name | `VALHALLA` |
| Sender email | Un correo remitente verificado en esa cuenta de Mailjet |

Guarda los cambios. En las plantillas de Supabase, pega `templates/confirmar_cuenta.html` en Confirm signup y `templates/recuperar_password.html` en Reset password. Mantén habilitada la confirmación de correo. La app recibe el código introducido por el usuario.

La clave publicable de Supabase conecta la app, pero no permite cambiar SMTP. Este ajuste no se aplicó remotamente desde esta entrega. Las credenciales privadas de Mailjet no se incluyen en Flutter ni en el ZIP.

Referencias: [Supabase SMTP](https://supabase.com/docs/guides/auth/auth-smtp), [Mailjet SMTP](https://dev.mailjet.com/docs/smtp-relay/configuration), [credenciales Mailjet](https://documentation.mailjet.com/hc/en-us/articles/360043229473-How-can-I-configure-my-SMTP-parameters).
