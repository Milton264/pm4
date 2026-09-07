-- Cambios aditivos: conserva todos los registros existentes.
CREATE TABLE solicitud_idempotente (
  clave TEXT PRIMARY KEY NOT NULL,
  accion TEXT NOT NULL,
  id_usuario INTEGER NOT NULL REFERENCES usuario(id_usuario),
  id_sucursal INTEGER NOT NULL REFERENCES sucursal(id_sucursal),
  solicitud TEXT NOT NULL,
  id_resultado INTEGER NOT NULL,
  created_at TEXT NOT NULL
);
CREATE TABLE membresia_servicio (
  id_membresia INTEGER NOT NULL REFERENCES membresia(id_membresia),
  id_servicio INTEGER NOT NULL REFERENCES servicio(id_servicio),
  PRIMARY KEY (id_membresia,id_servicio)
);
INSERT INTO membresia_servicio SELECT m.id_membresia,p.id_servicio FROM membresia m JOIN membresia_plan_servicio p ON p.id_plan_membresia=m.id_plan_membresia;
ALTER TABLE membresia ADD COLUMN nombre_plan_aplicado TEXT;
UPDATE membresia SET nombre_plan_aplicado=(SELECT nombre FROM membresia_plan p WHERE p.id_plan_membresia=membresia.id_plan_membresia);
ALTER TABLE gasto ADD COLUMN id_cuadre_caja INTEGER REFERENCES cuadre_caja(id_cuadre_caja);
ALTER TABLE cita ADD COLUMN duracion_minutos INTEGER NOT NULL DEFAULT 30 CHECK(duracion_minutos BETWEEN 5 AND 480);
CREATE INDEX ix_gasto_cuadre ON gasto(id_sucursal,id_cuadre_caja);
CREATE INDEX ix_caja_pendiente ON movimiento_caja(id_sucursal,id_cuadre_caja);
CREATE INDEX ix_cita_horario ON cita(id_barbero,estado,fecha_hora);
