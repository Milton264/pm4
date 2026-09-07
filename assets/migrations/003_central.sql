-- API central: identidad local al servidor y configuración administrada.
CREATE TABLE configuracion_negocio (
  id INTEGER PRIMARY KEY CHECK(id=1),
  nombre TEXT NOT NULL CHECK(length(trim(nombre)) BETWEEN 2 AND 120),
  meta_fidelidad INTEGER NOT NULL CHECK(meta_fidelidad BETWEEN 1 AND 100),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE TABLE credencial_usuario (
  id_usuario INTEGER PRIMARY KEY REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
  correo TEXT NOT NULL COLLATE NOCASE UNIQUE,
  password_hash TEXT NOT NULL,
  cambiar_password INTEGER NOT NULL DEFAULT 0 CHECK(cambiar_password IN (0,1)),
  version_acceso INTEGER NOT NULL DEFAULT 1,
  updated_at TEXT NOT NULL
);
CREATE TABLE sesion_acceso (
  token_hash TEXT PRIMARY KEY NOT NULL,
  id_usuario INTEGER NOT NULL REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
  version_acceso INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  revoked_at TEXT
);
CREATE INDEX ix_sesion_usuario ON sesion_acceso(id_usuario,expires_at);
CREATE TABLE intento_acceso (
  clave TEXT PRIMARY KEY NOT NULL,
  fallos INTEGER NOT NULL CHECK(fallos>=0),
  ventana_inicio TEXT NOT NULL
);
ALTER TABLE fidelidad_movimiento RENAME TO fidelidad_movimiento_v2;
CREATE TABLE fidelidad_movimiento (
  id INTEGER PRIMARY KEY,
  id_cliente INTEGER NOT NULL REFERENCES cliente(id_cliente) ON DELETE RESTRICT,
  id_operacion INTEGER NOT NULL UNIQUE REFERENCES operacion(id_operacion) ON DELETE RESTRICT,
  puntos INTEGER NOT NULL CHECK(puntos=1 OR puntos<0),
  created_at TEXT NOT NULL
);
INSERT INTO fidelidad_movimiento SELECT * FROM fidelidad_movimiento_v2;
DROP TABLE fidelidad_movimiento_v2;
CREATE INDEX ix_fidelidad_cliente ON fidelidad_movimiento(id_cliente);
