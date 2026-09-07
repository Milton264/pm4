-- SQLite v1. Dinero en centavos; cantidades de producto en milésimas.
-- Derivado del DER Lucid; claves foráneas corregidas por identidad.

CREATE TABLE servicio (
  id_servicio INTEGER PRIMARY KEY,
  nombre TEXT NOT NULL,
  categoria TEXT,
  elegible_fidelidad INTEGER NOT NULL CHECK (elegible_fidelidad IN (0,1)),
  elegible_cumpleanos INTEGER NOT NULL CHECK (elegible_cumpleanos IN (0,1)),
  activo INTEGER NOT NULL CHECK (activo IN (0,1)),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE cuadre_caja (
  id_cuadre_caja INTEGER PRIMARY KEY,
  id_sucursal INTEGER NOT NULL,
  id_cerrado_por INTEGER NOT NULL,
  idempotency_key TEXT NOT NULL UNIQUE,
  periodo_inicio TEXT NOT NULL,
  periodo_fin TEXT NOT NULL CHECK (periodo_fin >= periodo_inicio),
  efectivo_esperado INTEGER NOT NULL,
  efectivo_contado INTEGER NOT NULL,
  diferencia INTEGER NOT NULL,
  explicacion_diferencia TEXT,
  estado TEXT NOT NULL,
  fecha_hora_cierre TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  FOREIGN KEY (id_sucursal) REFERENCES sucursal(id_sucursal) ON DELETE RESTRICT,
  FOREIGN KEY (id_cerrado_por) REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
  CHECK (efectivo_contado >= 0),
  CHECK (diferencia = 0 OR length(trim(COALESCE(explicacion_diferencia,''))) > 0),
  CHECK (diferencia = efectivo_contado - efectivo_esperado)
);

CREATE INDEX ix_cuadre_caja_id_sucursal ON cuadre_caja(id_sucursal);

CREATE INDEX ix_cuadre_caja_id_cerrado_por ON cuadre_caja(id_cerrado_por);

CREATE TABLE servicio_precio_historial (
  id_servicio_precio INTEGER PRIMARY KEY,
  id_servicio INTEGER NOT NULL,
  precio INTEGER NOT NULL CHECK (precio >= 0),
  vigencia_desde TEXT NOT NULL,
  vigencia_hasta TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  FOREIGN KEY (id_servicio) REFERENCES servicio(id_servicio) ON DELETE RESTRICT
);

CREATE INDEX ix_servicio_precio_historial_id_servicio ON servicio_precio_historial(id_servicio);

CREATE TABLE rol (
  id_rol INTEGER PRIMARY KEY,
  codigo TEXT NOT NULL UNIQUE,
  nombre TEXT NOT NULL,
  activo INTEGER NOT NULL CHECK (activo IN (0,1))
);

CREATE TABLE usuario (
  id_usuario INTEGER PRIMARY KEY,
  id_rol INTEGER NOT NULL,
  firebase_uid TEXT UNIQUE,
  nombre_completo TEXT NOT NULL,
  activo INTEGER NOT NULL CHECK (activo IN (0,1)),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  FOREIGN KEY (id_rol) REFERENCES rol(id_rol) ON DELETE RESTRICT
);

CREATE INDEX ix_usuario_id_rol ON usuario(id_rol);

CREATE TABLE gasto (
  id_gasto INTEGER PRIMARY KEY,
  id_sucursal INTEGER NOT NULL,
  id_registrado_por INTEGER NOT NULL,
  id_metodo_pago INTEGER NOT NULL,
  id_banco INTEGER,
  idempotency_key TEXT NOT NULL UNIQUE,
  fecha_hora TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  categoria TEXT NOT NULL,
  descripcion TEXT NOT NULL,
  monto INTEGER NOT NULL CHECK (monto > 0),
  observacion TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  FOREIGN KEY (id_sucursal) REFERENCES sucursal(id_sucursal) ON DELETE RESTRICT,
  FOREIGN KEY (id_registrado_por) REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
  FOREIGN KEY (id_metodo_pago) REFERENCES metodo_pago(id_metodo_pago) ON DELETE RESTRICT,
  FOREIGN KEY (id_banco) REFERENCES banco(id_banco) ON DELETE RESTRICT
);

CREATE INDEX ix_gasto_id_sucursal ON gasto(id_sucursal);

CREATE INDEX ix_gasto_id_registrado_por ON gasto(id_registrado_por);

CREATE INDEX ix_gasto_id_metodo_pago ON gasto(id_metodo_pago);

CREATE INDEX ix_gasto_id_banco ON gasto(id_banco);

CREATE TABLE cliente (
  id_cliente INTEGER PRIMARY KEY,
  nombre_completo TEXT NOT NULL,
  telefono TEXT NOT NULL,
  fecha_nacimiento TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE sucursal (
  id_sucursal INTEGER PRIMARY KEY,
  nombre TEXT NOT NULL UNIQUE,
  activo INTEGER NOT NULL CHECK (activo IN (0,1)),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE cita (
  id_cita INTEGER PRIMARY KEY,
  id_cliente INTEGER NOT NULL,
  id_sucursal INTEGER NOT NULL,
  id_barbero INTEGER NOT NULL,
  id_creada_por INTEGER NOT NULL,
  fecha_hora TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  estado TEXT NOT NULL,
  observaciones TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente) ON DELETE RESTRICT,
  FOREIGN KEY (id_sucursal) REFERENCES sucursal(id_sucursal) ON DELETE RESTRICT,
  FOREIGN KEY (id_barbero) REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
  FOREIGN KEY (id_creada_por) REFERENCES usuario(id_usuario) ON DELETE RESTRICT
);

CREATE INDEX ix_cita_id_cliente ON cita(id_cliente);

CREATE INDEX ix_cita_id_sucursal ON cita(id_sucursal);

CREATE INDEX ix_cita_id_barbero ON cita(id_barbero);

CREATE INDEX ix_cita_id_creada_por ON cita(id_creada_por);

CREATE TABLE operacion (
  id_operacion INTEGER PRIMARY KEY,
  id_cliente INTEGER NOT NULL,
  id_cita INTEGER UNIQUE,
  id_sucursal INTEGER NOT NULL,
  id_barbero INTEGER,
  id_registrada_por INTEGER NOT NULL,
  id_cuadre_caja INTEGER,
  idempotency_key TEXT NOT NULL UNIQUE,
  fecha_hora TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  estado TEXT NOT NULL,
  total_bruto INTEGER NOT NULL CHECK (total_bruto >= 0),
  total_descuentos INTEGER NOT NULL CHECK (total_descuentos >= 0),
  total_cobrado INTEGER NOT NULL CHECK (total_cobrado >= 0),
  observaciones TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente) ON DELETE RESTRICT,
  FOREIGN KEY (id_cita) REFERENCES cita(id_cita) ON DELETE RESTRICT,
  FOREIGN KEY (id_sucursal) REFERENCES sucursal(id_sucursal) ON DELETE RESTRICT,
  FOREIGN KEY (id_barbero) REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
  FOREIGN KEY (id_registrada_por) REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
  FOREIGN KEY (id_cuadre_caja) REFERENCES cuadre_caja(id_cuadre_caja) ON DELETE RESTRICT,
  CHECK (total_cobrado = total_bruto - total_descuentos)
);

CREATE INDEX ix_operacion_id_cliente ON operacion(id_cliente);

CREATE INDEX ix_operacion_id_cita ON operacion(id_cita);

CREATE INDEX ix_operacion_id_sucursal ON operacion(id_sucursal);

CREATE INDEX ix_operacion_id_barbero ON operacion(id_barbero);

CREATE INDEX ix_operacion_id_registrada_por ON operacion(id_registrada_por);

CREATE INDEX ix_operacion_id_cuadre_caja ON operacion(id_cuadre_caja);

CREATE TABLE regla_comision (
  id_regla_comision INTEGER PRIMARY KEY,
  id_servicio INTEGER,
  nombre TEXT NOT NULL,
  circunstancia TEXT,
  tipo_calculo TEXT NOT NULL,
  valor INTEGER NOT NULL CHECK (valor >= 0),
  vigencia_desde TEXT NOT NULL,
  vigencia_hasta TEXT,
  activo INTEGER NOT NULL CHECK (activo IN (0,1)),
  FOREIGN KEY (id_servicio) REFERENCES servicio(id_servicio) ON DELETE RESTRICT
);

CREATE INDEX ix_regla_comision_id_servicio ON regla_comision(id_servicio);

CREATE TABLE motivo_gratuidad (
  id_motivo_gratuidad INTEGER PRIMARY KEY,
  codigo TEXT NOT NULL UNIQUE,
  nombre TEXT NOT NULL,
  activo INTEGER NOT NULL CHECK (activo IN (0,1))
);

CREATE TABLE operacion_servicio (
  id_operacion_servicio INTEGER PRIMARY KEY,
  id_operacion INTEGER NOT NULL,
  id_servicio INTEGER NOT NULL,
  id_motivo_gratuidad INTEGER,
  id_regla_comision INTEGER,
  id_autorizado_por INTEGER,
  cantidad INTEGER NOT NULL CHECK (cantidad > 0) DEFAULT 1,
  precio_normal INTEGER NOT NULL CHECK (precio_normal >= 0),
  precio_aplicado INTEGER NOT NULL CHECK (precio_aplicado >= 0),
  motivo_descuento TEXT,
  comentario_descuento TEXT,
  elegible_fidelidad_aplicado INTEGER NOT NULL CHECK (elegible_fidelidad_aplicado IN (0,1)),
  base_comision INTEGER NOT NULL CHECK (base_comision >= 0),
  monto_comision INTEGER NOT NULL CHECK (monto_comision >= 0),
  FOREIGN KEY (id_operacion) REFERENCES operacion(id_operacion) ON DELETE RESTRICT,
  FOREIGN KEY (id_servicio) REFERENCES servicio(id_servicio) ON DELETE RESTRICT,
  FOREIGN KEY (id_motivo_gratuidad) REFERENCES motivo_gratuidad(id_motivo_gratuidad) ON DELETE RESTRICT,
  FOREIGN KEY (id_regla_comision) REFERENCES regla_comision(id_regla_comision) ON DELETE RESTRICT,
  FOREIGN KEY (id_autorizado_por) REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
  CHECK (precio_aplicado <= precio_normal),
  CHECK (id_motivo_gratuidad IS NULL OR precio_aplicado = 0),
  CHECK (base_comision = precio_aplicado * cantidad)
);

CREATE INDEX ix_operacion_servicio_id_operacion ON operacion_servicio(id_operacion);

CREATE INDEX ix_operacion_servicio_id_servicio ON operacion_servicio(id_servicio);

CREATE INDEX ix_operacion_servicio_id_motivo_gratuidad ON operacion_servicio(id_motivo_gratuidad);

CREATE INDEX ix_operacion_servicio_id_regla_comision ON operacion_servicio(id_regla_comision);

CREATE INDEX ix_operacion_servicio_id_autorizado_por ON operacion_servicio(id_autorizado_por);

CREATE TABLE inventario_sucursal (
  id_inventario_sucursal INTEGER PRIMARY KEY,
  id_sucursal INTEGER NOT NULL,
  id_producto INTEGER NOT NULL,
  stock_actual INTEGER NOT NULL,
  stock_minimo INTEGER NOT NULL CHECK (stock_minimo >= 0),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  FOREIGN KEY (id_sucursal) REFERENCES sucursal(id_sucursal) ON DELETE RESTRICT,
  FOREIGN KEY (id_producto) REFERENCES producto(id_producto) ON DELETE RESTRICT,
  UNIQUE (id_sucursal, id_producto),
  CHECK (stock_actual >= 0)
);

CREATE INDEX ix_inventario_sucursal_id_sucursal ON inventario_sucursal(id_sucursal);

CREATE INDEX ix_inventario_sucursal_id_producto ON inventario_sucursal(id_producto);

CREATE TABLE membresia_plan (
  id_plan_membresia INTEGER PRIMARY KEY,
  codigo TEXT NOT NULL UNIQUE,
  nombre TEXT NOT NULL,
  precio INTEGER NOT NULL CHECK (precio >= 0),
  cantidad_servicios INTEGER NOT NULL CHECK (cantidad_servicios > 0),
  vigencia_desde TEXT NOT NULL,
  vigencia_hasta TEXT,
  activo INTEGER NOT NULL CHECK (activo IN (0,1)),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  duracion_dias INTEGER NOT NULL DEFAULT 30 CHECK (duracion_dias > 0)
);

CREATE TABLE membresia_plan_servicio (
  id_plan_servicio INTEGER PRIMARY KEY,
  id_plan_membresia INTEGER NOT NULL,
  id_servicio INTEGER NOT NULL,
  FOREIGN KEY (id_plan_membresia) REFERENCES membresia_plan(id_plan_membresia) ON DELETE RESTRICT,
  FOREIGN KEY (id_servicio) REFERENCES servicio(id_servicio) ON DELETE RESTRICT,
  UNIQUE (id_plan_membresia, id_servicio)
);

CREATE INDEX ix_membresia_plan_servicio_id_plan_membresia ON membresia_plan_servicio(id_plan_membresia);

CREATE INDEX ix_membresia_plan_servicio_id_servicio ON membresia_plan_servicio(id_servicio);

CREATE TABLE movimiento_inventario (
  id_movimiento_inventario INTEGER PRIMARY KEY,
  id_sucursal INTEGER NOT NULL,
  id_producto INTEGER NOT NULL,
  id_operacion INTEGER,
  id_operacion_producto INTEGER,
  id_gasto INTEGER,
  id_traslado INTEGER,
  id_usuario_responsable INTEGER,
  id_registrado_por INTEGER NOT NULL,
  tipo_movimiento TEXT NOT NULL,
  cantidad INTEGER NOT NULL CHECK (cantidad > 0),
  fecha_hora TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  observacion TEXT,
  FOREIGN KEY (id_sucursal) REFERENCES sucursal(id_sucursal) ON DELETE RESTRICT,
  FOREIGN KEY (id_producto) REFERENCES producto(id_producto) ON DELETE RESTRICT,
  FOREIGN KEY (id_operacion) REFERENCES operacion(id_operacion) ON DELETE RESTRICT,
  FOREIGN KEY (id_operacion_producto) REFERENCES operacion_producto(id_operacion_producto) ON DELETE RESTRICT,
  FOREIGN KEY (id_gasto) REFERENCES gasto(id_gasto) ON DELETE RESTRICT,
  FOREIGN KEY (id_traslado) REFERENCES traslado_inventario(id_traslado) ON DELETE RESTRICT,
  FOREIGN KEY (id_usuario_responsable) REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
  FOREIGN KEY (id_registrado_por) REFERENCES usuario(id_usuario) ON DELETE RESTRICT
);

CREATE INDEX ix_movimiento_inventario_id_sucursal ON movimiento_inventario(id_sucursal);

CREATE INDEX ix_movimiento_inventario_id_producto ON movimiento_inventario(id_producto);

CREATE INDEX ix_movimiento_inventario_id_operacion ON movimiento_inventario(id_operacion);

CREATE INDEX ix_movimiento_inventario_id_operacion_producto ON movimiento_inventario(id_operacion_producto);

CREATE INDEX ix_movimiento_inventario_id_gasto ON movimiento_inventario(id_gasto);

CREATE INDEX ix_movimiento_inventario_id_traslado ON movimiento_inventario(id_traslado);

CREATE INDEX ix_movimiento_inventario_id_usuario_responsable ON movimiento_inventario(id_usuario_responsable);

CREATE INDEX ix_movimiento_inventario_id_registrado_por ON movimiento_inventario(id_registrado_por);

CREATE TABLE producto (
  id_producto INTEGER PRIMARY KEY,
  nombre TEXT NOT NULL,
  categoria TEXT,
  unidad_medida TEXT NOT NULL,
  precio_venta_actual INTEGER,
  activo INTEGER NOT NULL CHECK (activo IN (0,1)),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE operacion_producto (
  id_operacion_producto INTEGER PRIMARY KEY,
  id_operacion INTEGER NOT NULL,
  id_producto INTEGER NOT NULL,
  cantidad INTEGER NOT NULL CHECK (cantidad > 0),
  precio_unitario_aplicado INTEGER NOT NULL CHECK (precio_unitario_aplicado >= 0),
  total_linea INTEGER NOT NULL CHECK (total_linea >= 0),
  FOREIGN KEY (id_operacion) REFERENCES operacion(id_operacion) ON DELETE RESTRICT,
  FOREIGN KEY (id_producto) REFERENCES producto(id_producto) ON DELETE RESTRICT
);

CREATE INDEX ix_operacion_producto_id_operacion ON operacion_producto(id_operacion);

CREATE INDEX ix_operacion_producto_id_producto ON operacion_producto(id_producto);

CREATE TABLE traslado_inventario (
  id_traslado INTEGER PRIMARY KEY,
  id_sucursal_origen INTEGER NOT NULL,
  id_sucursal_destino INTEGER NOT NULL,
  id_responsable INTEGER NOT NULL,
  idempotency_key TEXT NOT NULL UNIQUE,
  fecha_hora TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  observacion TEXT,
  FOREIGN KEY (id_sucursal_origen) REFERENCES sucursal(id_sucursal) ON DELETE RESTRICT,
  FOREIGN KEY (id_sucursal_destino) REFERENCES sucursal(id_sucursal) ON DELETE RESTRICT,
  FOREIGN KEY (id_responsable) REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
  CHECK (id_sucursal_origen <> id_sucursal_destino)
);

CREATE INDEX ix_traslado_inventario_id_sucursal_origen ON traslado_inventario(id_sucursal_origen);

CREATE INDEX ix_traslado_inventario_id_sucursal_destino ON traslado_inventario(id_sucursal_destino);

CREATE INDEX ix_traslado_inventario_id_responsable ON traslado_inventario(id_responsable);

CREATE TABLE membresia (
  id_membresia INTEGER PRIMARY KEY,
  id_cliente INTEGER NOT NULL,
  id_plan_membresia INTEGER NOT NULL,
  id_operacion_compra INTEGER,
  fecha_compra TEXT NOT NULL,
  fecha_activacion TEXT NOT NULL,
  precio_pagado INTEGER NOT NULL CHECK (precio_pagado >= 0),
  servicios_iniciales INTEGER NOT NULL CHECK (servicios_iniciales > 0),
  estado TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  fecha_vencimiento TEXT,
  FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente) ON DELETE RESTRICT,
  FOREIGN KEY (id_plan_membresia) REFERENCES membresia_plan(id_plan_membresia) ON DELETE RESTRICT,
  FOREIGN KEY (id_operacion_compra) REFERENCES operacion(id_operacion) ON DELETE RESTRICT
);

CREATE INDEX ix_membresia_id_cliente ON membresia(id_cliente);

CREATE INDEX ix_membresia_id_plan_membresia ON membresia(id_plan_membresia);

CREATE INDEX ix_membresia_id_operacion_compra ON membresia(id_operacion_compra);

CREATE TABLE membresia_consumo (
  id_membresia_consumo INTEGER PRIMARY KEY,
  id_membresia INTEGER NOT NULL,
  id_operacion_servicio INTEGER NOT NULL UNIQUE,
  cantidad INTEGER NOT NULL CHECK (cantidad > 0) DEFAULT 1,
  fecha_consumo TEXT NOT NULL,
  FOREIGN KEY (id_membresia) REFERENCES membresia(id_membresia) ON DELETE RESTRICT,
  FOREIGN KEY (id_operacion_servicio) REFERENCES operacion_servicio(id_operacion_servicio) ON DELETE RESTRICT
);

CREATE INDEX ix_membresia_consumo_id_membresia ON membresia_consumo(id_membresia);

CREATE INDEX ix_membresia_consumo_id_operacion_servicio ON membresia_consumo(id_operacion_servicio);

CREATE TABLE cita_servicio (
  id_cita_servicio INTEGER PRIMARY KEY,
  id_cita INTEGER NOT NULL,
  id_servicio INTEGER NOT NULL,
  cantidad INTEGER NOT NULL CHECK (cantidad > 0) DEFAULT 1,
  observacion TEXT,
  FOREIGN KEY (id_cita) REFERENCES cita(id_cita) ON DELETE RESTRICT,
  FOREIGN KEY (id_servicio) REFERENCES servicio(id_servicio) ON DELETE RESTRICT
);

CREATE INDEX ix_cita_servicio_id_cita ON cita_servicio(id_cita);

CREATE INDEX ix_cita_servicio_id_servicio ON cita_servicio(id_servicio);

CREATE TABLE usuario_sucursal (
  id_usuario_sucursal INTEGER PRIMARY KEY,
  id_usuario INTEGER NOT NULL,
  id_sucursal INTEGER NOT NULL,
  es_principal INTEGER NOT NULL CHECK (es_principal IN (0,1)),
  activo INTEGER NOT NULL CHECK (activo IN (0,1)),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
  FOREIGN KEY (id_sucursal) REFERENCES sucursal(id_sucursal) ON DELETE RESTRICT,
  UNIQUE (id_usuario, id_sucursal)
);

CREATE INDEX ix_usuario_sucursal_id_usuario ON usuario_sucursal(id_usuario);

CREATE INDEX ix_usuario_sucursal_id_sucursal ON usuario_sucursal(id_sucursal);

CREATE TABLE banco (
  id_banco INTEGER PRIMARY KEY,
  codigo TEXT NOT NULL UNIQUE,
  nombre TEXT NOT NULL,
  activo INTEGER NOT NULL CHECK (activo IN (0,1))
);

CREATE TABLE metodo_pago (
  id_metodo_pago INTEGER PRIMARY KEY,
  codigo TEXT NOT NULL UNIQUE,
  nombre TEXT NOT NULL,
  activo INTEGER NOT NULL CHECK (activo IN (0,1))
);

CREATE TABLE pago (
  id_pago INTEGER PRIMARY KEY,
  id_operacion INTEGER NOT NULL UNIQUE,
  id_metodo_pago INTEGER NOT NULL,
  id_banco INTEGER,
  id_registrado_por INTEGER NOT NULL,
  monto INTEGER NOT NULL CHECK (monto >= 0),
  efectivo_recibido INTEGER,
  cambio INTEGER,
  referencia_transferencia TEXT,
  fecha_hora TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  FOREIGN KEY (id_operacion) REFERENCES operacion(id_operacion) ON DELETE RESTRICT,
  FOREIGN KEY (id_metodo_pago) REFERENCES metodo_pago(id_metodo_pago) ON DELETE RESTRICT,
  FOREIGN KEY (id_banco) REFERENCES banco(id_banco) ON DELETE RESTRICT,
  FOREIGN KEY (id_registrado_por) REFERENCES usuario(id_usuario) ON DELETE RESTRICT
);

CREATE INDEX ix_pago_id_operacion ON pago(id_operacion);

CREATE INDEX ix_pago_id_metodo_pago ON pago(id_metodo_pago);

CREATE INDEX ix_pago_id_banco ON pago(id_banco);

CREATE INDEX ix_pago_id_registrado_por ON pago(id_registrado_por);

CREATE TABLE movimiento_caja (
  id_movimiento_caja INTEGER PRIMARY KEY,
  id_sucursal INTEGER NOT NULL,
  id_pago INTEGER,
  id_gasto INTEGER,
  id_cuadre_caja INTEGER,
  id_usuario INTEGER NOT NULL,
  tipo_movimiento TEXT NOT NULL,
  monto INTEGER NOT NULL CHECK (monto > 0),
  fecha_hora TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  observacion TEXT,
  FOREIGN KEY (id_sucursal) REFERENCES sucursal(id_sucursal) ON DELETE RESTRICT,
  FOREIGN KEY (id_pago) REFERENCES pago(id_pago) ON DELETE RESTRICT,
  FOREIGN KEY (id_gasto) REFERENCES gasto(id_gasto) ON DELETE RESTRICT,
  FOREIGN KEY (id_cuadre_caja) REFERENCES cuadre_caja(id_cuadre_caja) ON DELETE RESTRICT,
  FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
  CHECK (tipo_movimiento IN ('INGRESO','EGRESO')),
  CHECK (id_pago IS NULL OR id_gasto IS NULL)
);

CREATE INDEX ix_movimiento_caja_id_sucursal ON movimiento_caja(id_sucursal);

CREATE INDEX ix_movimiento_caja_id_pago ON movimiento_caja(id_pago);

CREATE INDEX ix_movimiento_caja_id_gasto ON movimiento_caja(id_gasto);

CREATE INDEX ix_movimiento_caja_id_cuadre_caja ON movimiento_caja(id_cuadre_caja);

CREATE INDEX ix_movimiento_caja_id_usuario ON movimiento_caja(id_usuario);

CREATE TABLE bitacora_auditoria (
  id_auditoria INTEGER PRIMARY KEY,
  id_usuario INTEGER NOT NULL,
  id_sucursal INTEGER,
  entidad TEXT NOT NULL,
  id_registro INTEGER NOT NULL,
  accion TEXT NOT NULL,
  valor_anterior TEXT,
  valor_nuevo TEXT,
  motivo TEXT,
  fecha_hora TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario) ON DELETE RESTRICT,
  FOREIGN KEY (id_sucursal) REFERENCES sucursal(id_sucursal) ON DELETE RESTRICT
);

CREATE INDEX ix_bitacora_auditoria_id_usuario ON bitacora_auditoria(id_usuario);

CREATE INDEX ix_bitacora_auditoria_id_sucursal ON bitacora_auditoria(id_sucursal);

CREATE INDEX ix_bitacora_auditoria_id_registro ON bitacora_auditoria(id_registro);

CREATE INDEX ix_cliente_nombre ON cliente(nombre_completo COLLATE NOCASE);

CREATE INDEX ix_cliente_telefono ON cliente(telefono);

CREATE INDEX ix_operacion_fecha ON operacion(id_sucursal,fecha_hora);

CREATE UNIQUE INDEX ux_precio_vigente ON servicio_precio_historial(id_servicio) WHERE vigencia_hasta IS NULL;

CREATE TABLE cliente_nota (id_nota INTEGER PRIMARY KEY, id_cliente INTEGER NOT NULL REFERENCES cliente(id_cliente), id_usuario INTEGER NOT NULL REFERENCES usuario(id_usuario), texto TEXT NOT NULL, created_at TEXT NOT NULL);

CREATE TABLE fidelidad_movimiento (id INTEGER PRIMARY KEY, id_cliente INTEGER NOT NULL REFERENCES cliente(id_cliente), id_operacion INTEGER NOT NULL UNIQUE REFERENCES operacion(id_operacion), puntos INTEGER NOT NULL CHECK(puntos IN (1,-10)), created_at TEXT NOT NULL);

CREATE TABLE beneficio_cumpleanos (id INTEGER PRIMARY KEY, id_cliente INTEGER NOT NULL REFERENCES cliente(id_cliente), anio INTEGER NOT NULL, id_operacion INTEGER NOT NULL UNIQUE REFERENCES operacion(id_operacion), UNIQUE(id_cliente,anio));