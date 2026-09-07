-- Recuperación: solo se conserva el resumen del código y la versión de acceso.
CREATE TABLE recuperacion_password (
  id_usuario INTEGER PRIMARY KEY REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
  codigo_hash TEXT NOT NULL,
  version_acceso INTEGER NOT NULL,
  intentos INTEGER NOT NULL DEFAULT 0 CHECK(intentos BETWEEN 0 AND 5),
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  used_at TEXT
);
CREATE INDEX ix_recuperacion_expira ON recuperacion_password(expires_at);
ALTER TABLE cita ADD COLUMN id_confirmada_por INTEGER REFERENCES usuario(id_usuario) ON DELETE RESTRICT;
ALTER TABLE cita ADD COLUMN confirmada_at TEXT;
