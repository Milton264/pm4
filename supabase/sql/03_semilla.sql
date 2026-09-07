-- Semilla de referencia. No incluye clientes, citas, operaciones ni contraseñas.
SET LOCAL search_path=valhalla_private,pg_catalog;
INSERT INTO rol(codigo,nombre,activo) VALUES
 ('administrador','Administrador',1),('encargado','Encargado',1),('barbero','Barbero',1),('whatsapp','Personal de WhatsApp',1)
ON CONFLICT(codigo) DO NOTHING;
INSERT INTO sucursal(nombre,activo) VALUES('El Trébol',1),('Bypass',1) ON CONFLICT(nombre) DO NOTHING;
INSERT INTO metodo_pago(codigo,nombre,activo) VALUES('EFECTIVO','Efectivo',1),('TRANSFERENCIA','Transferencia',1) ON CONFLICT(codigo) DO NOTHING;
INSERT INTO banco(codigo,nombre,activo) VALUES('AGRICOLA','Banco Agrícola',1),('BAC','América Central',1),('CUSCATLAN','Banco Cuscatlán',1) ON CONFLICT(codigo) DO NOTHING;
INSERT INTO motivo_gratuidad(codigo,nombre,activo) VALUES('FIDELIDAD','Fidelidad',1),('CUMPLEANOS','Cumpleaños',1),('MEMBRESIA','Membresía',1) ON CONFLICT(codigo) DO NOTHING;
INSERT INTO configuracion_negocio(id,nombre,meta_fidelidad,created_at,updated_at) VALUES(1,'Valhalla',10,now(),now()) ON CONFLICT(id) DO NOTHING;
-- Correo del administrador reservado. El propietario elige su contraseña al activar
-- su cuenta en Flutter y confirma el código recibido por Supabase Auth.
INSERT INTO usuario(id_rol,nombre_completo,correo,activo)
SELECT id_rol,'Milton Ramírez','milton.ramirez@catolica.edu.sv',1 FROM rol WHERE codigo='administrador'
ON CONFLICT(correo) DO NOTHING;
INSERT INTO usuario_sucursal(id_usuario,id_sucursal,es_principal,activo)
SELECT u.id_usuario,s.id_sucursal,CASE WHEN s.nombre='El Trébol' THEN 1 ELSE 0 END,1
FROM usuario u CROSS JOIN sucursal s WHERE u.correo='milton.ramirez@catolica.edu.sv'
ON CONFLICT(id_usuario,id_sucursal) DO NOTHING;
