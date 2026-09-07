# Modelo PostgreSQL de VALHALLA

35 tablas de negocio. Este diccionario se obtiene ejecutando el modelo en PostgreSQL y consultando sus metadatos. Las identidades de acceso se relacionan con `auth.users`, administrada por Supabase.

Importes: centavos enteros. Existencias: milésimas. Fechas operativas: `timestamp with time zone`; cumpleaños: `date`.

## banco

| Campo | Tipo | Admite nulo | Valor inicial |
|---|---|---|---|
| id_banco | bigint | No | Identidad autogenerada |
| codigo | text | No | — |
| nombre | text | No | — |
| activo | bigint | No | — |

Restricciones y relaciones:

- `CHECK ((activo = ANY (ARRAY[(0)::bigint, (1)::bigint])))`
- `UNIQUE (codigo)`
- `PRIMARY KEY (id_banco)`

## beneficio_cumpleanos

| Campo | Tipo | Admite nulo | Valor inicial |
|---|---|---|---|
| id | bigint | No | Identidad autogenerada |
| id_cliente | bigint | No | — |
| anio | bigint | No | — |
| id_operacion | bigint | No | — |

Restricciones y relaciones:

- `UNIQUE (id_cliente, anio)`
- `UNIQUE (id_operacion)`
- `PRIMARY KEY (id)`
- `FOREIGN KEY (id_cliente) REFERENCES valhalla_private.cliente(id_cliente)`
- `FOREIGN KEY (id_operacion) REFERENCES valhalla_private.operacion(id_operacion)`

## bitacora_auditoria

| Campo | Tipo | Admite nulo | Valor inicial |
|---|---|---|---|
| id_auditoria | bigint | No | Identidad autogenerada |
| id_usuario | bigint | No | — |
| id_sucursal | bigint | Sí | — |
| entidad | text | No | — |
| id_registro | bigint | No | — |
| accion | text | No | — |
| valor_anterior | text | Sí | — |
| valor_nuevo | text | Sí | — |
| motivo | text | Sí | — |
| fecha_hora | timestamp with time zone | No | now() |

Restricciones y relaciones:

- `PRIMARY KEY (id_auditoria)`
- `FOREIGN KEY (id_sucursal) REFERENCES valhalla_private.sucursal(id_sucursal) ON DELETE RESTRICT`
- `FOREIGN KEY (id_usuario) REFERENCES valhalla_private.usuario(id_usuario) ON DELETE RESTRICT`

## cita

| Campo | Tipo | Admite nulo | Valor inicial |
|---|---|---|---|
| id_cita | bigint | No | Identidad autogenerada |
| id_cliente | bigint | No | — |
| id_sucursal | bigint | No | — |
| id_barbero | bigint | No | — |
| id_creada_por | bigint | No | — |
| fecha_hora | timestamp with time zone | No | now() |
| estado | text | No | — |
| observaciones | text | Sí | — |
| created_at | timestamp with time zone | No | now() |
| updated_at | timestamp with time zone | Sí | now() |
| duracion_minutos | bigint | No | 30 |
| id_confirmada_por | bigint | Sí | — |
| confirmada_at | timestamp with time zone | Sí | — |

Restricciones y relaciones:

- `CHECK (((estado = 'ATENDIDA'::text) = ((confirmada_at IS NOT NULL) AND (id_confirmada_por IS NOT NULL))))`
- `CHECK (((duracion_minutos >= 5) AND (duracion_minutos <= 480)))`
- `CHECK ((estado = ANY (ARRAY['PENDIENTE'::text, 'ATENDIDA'::text, 'CANCELADA'::text])))`
- `PRIMARY KEY (id_cita)`
- `FOREIGN KEY (id_barbero) REFERENCES valhalla_private.usuario(id_usuario) ON DELETE RESTRICT`
- `FOREIGN KEY (id_cliente) REFERENCES valhalla_private.cliente(id_cliente) ON DELETE RESTRICT`
- `FOREIGN KEY (id_confirmada_por) REFERENCES valhalla_private.usuario(id_usuario) ON DELETE RESTRICT`
- `FOREIGN KEY (id_creada_por) REFERENCES valhalla_private.usuario(id_usuario) ON DELETE RESTRICT`
- `FOREIGN KEY (id_sucursal) REFERENCES valhalla_private.sucursal(id_sucursal) ON DELETE RESTRICT`

## cita_servicio

| Campo | Tipo | Admite nulo | Valor inicial |
|---|---|---|---|
| id_cita_servicio | bigint | No | Identidad autogenerada |
| id_cita | bigint | No | — |
| id_servicio | bigint | No | — |
| cantidad | bigint | No | 1 |
| observacion | text | Sí | — |

Restricciones y relaciones:

- `CHECK ((cantidad > 0))`
- `PRIMARY KEY (id_cita_servicio)`
- `FOREIGN KEY (id_cita) REFERENCES valhalla_private.cita(id_cita) ON DELETE RESTRICT`
- `FOREIGN KEY (id_servicio) REFERENCES valhalla_private.servicio(id_servicio) ON DELETE RESTRICT`

## cliente

| Campo | Tipo | Admite nulo | Valor inicial |
|---|---|---|---|
| id_cliente | bigint | No | Identidad autogenerada |
| nombre_completo | text | No | — |
| telefono | text | No | — |
| fecha_nacimiento | date | No | — |
| created_at | timestamp with time zone | No | now() |
| updated_at | timestamp with time zone | Sí | now() |

Restricciones y relaciones:

- `CHECK ((((length(TRIM(BOTH FROM nombre_completo)) >= 3) AND (length(TRIM(BOTH FROM nombre_completo)) <= 150)) AND ((length(regexp_replace(telefono, '[^0-9]'::text, ''::text, 'g'::text)) >= 8) AND (length(regexp_replace(telefono, '[^0-9]'::text, ''::text, 'g'::text)) <= 15))))`
- `PRIMARY KEY (id_cliente)`

## cliente_nota

| Campo | Tipo | Admite nulo | Valor inicial |
|---|---|---|---|
| id_nota | bigint | No | Identidad autogenerada |
| id_cliente | bigint | No | — |
| id_usuario | bigint | No | — |
| texto | text | No | — |
| created_at | timestamp with time zone | No | — |

Restricciones y relaciones:

- `PRIMARY KEY (id_nota)`
- `FOREIGN KEY (id_cliente) REFERENCES valhalla_private.cliente(id_cliente)`
- `FOREIGN KEY (id_usuario) REFERENCES valhalla_private.usuario(id_usuario)`

## configuracion_negocio

| Campo | Tipo | Admite nulo | Valor inicial |
|---|---|---|---|
| id | bigint | No | Identidad autogenerada |
| nombre | text | No | — |
| meta_fidelidad | bigint | No | — |
| created_at | timestamp with time zone | No | — |
| updated_at | timestamp with time zone | No | — |

Restricciones y relaciones:

- `CHECK ((id = 1))`
- `CHECK (((meta_fidelidad >= 1) AND (meta_fidelidad <= 100)))`
- `CHECK (((length(TRIM(BOTH FROM nombre)) >= 2) AND (length(TRIM(BOTH FROM nombre)) <= 120)))`
- `PRIMARY KEY (id)`

## cuadre_caja

| Campo | Tipo | Admite nulo | Valor inicial |
|---|---|---|---|
| id_cuadre_caja | bigint | No | Identidad autogenerada |
| id_sucursal | bigint | No | — |
| id_cerrado_por | bigint | No | — |
| idempotency_key | text | No | — |
| periodo_inicio | timestamp with time zone | No | — |
| periodo_fin | timestamp with time zone | No | — |
| efectivo_esperado | bigint | No | — |
| efectivo_contado | bigint | No | — |
| diferencia | bigint | No | — |
| explicacion_diferencia | text | Sí | — |
| estado | text | No | — |
| fecha_hora_cierre | timestamp with time zone | Sí | — |
| created_at | timestamp with time zone | No | now() |

Restricciones y relaciones:

- `CHECK ((periodo_fin >= periodo_inicio))`
- `CHECK (((diferencia = 0) OR (length(TRIM(BOTH FROM COALESCE(explicacion_diferencia, ''::text))) > 0)))`
- `CHECK ((diferencia = (efectivo_contado - efectivo_esperado)))`
- `CHECK ((efectivo_contado >= 0))`
- `UNIQUE (idempotency_key)`
- `PRIMARY KEY (id_cuadre_caja)`
- `FOREIGN KEY (id_cerrado_por) REFERENCES valhalla_private.usuario(id_usuario) ON DELETE RESTRICT`
- `FOREIGN KEY (id_sucursal) REFERENCES valhalla_private.sucursal(id_sucursal) ON DELETE RESTRICT`

## fidelidad_movimiento

| Campo | Tipo | Admite nulo | Valor inicial |
|---|---|---|---|
| id | bigint | No | Identidad autogenerada |
| id_cliente | bigint | No | — |
| id_operacion | bigint | No | — |
| puntos | bigint | No | — |
| created_at | timestamp with time zone | No | — |

Restricciones y relaciones:

- `UNIQUE (id_operacion)`
- `PRIMARY KEY (id)`
- `CHECK (((puntos = 1) OR (puntos < 0)))`
- `FOREIGN KEY (id_cliente) REFERENCES valhalla_private.cliente(id_cliente) ON DELETE RESTRICT`
- `FOREIGN KEY (id_operacion) REFERENCES valhalla_private.operacion(id_operacion) ON DELETE RESTRICT`

## gasto

| Campo | Tipo | Admite nulo | Valor inicial |
|---|---|---|---|
| id_gasto | bigint | No | Identidad autogenerada |
| id_sucursal | bigint | No | — |
| id_registrado_por | bigint | No | — |
| id_metodo_pago | bigint | No | — |
| id_banco | bigint | Sí | — |
| idempotency_key | text | No | — |
| fecha_hora | timestamp with time zone | No | now() |
| categoria | text | No | — |
| descripcion | text | No | — |
| monto | bigint | No | — |
| observacion | text | Sí | — |
| created_at | timestamp with time zone | No | now() |
| id_cuadre_caja | bigint | Sí | — |

Restricciones y relaciones:

- `FOREIGN KEY (id_banco) REFERENCES valhalla_private.banco(id_banco) ON DELETE RESTRICT`
- `FOREIGN KEY (id_cuadre_caja) REFERENCES valhalla_private.cuadre_caja(id_cuadre_caja)`
- `FOREIGN KEY (id_metodo_pago) REFERENCES valhalla_private.metodo_pago(id_metodo_pago) ON DELETE RESTRICT`
- `FOREIGN KEY (id_registrado_por) REFERENCES valhalla_private.usuario(id_usuario) ON DELETE RESTRICT`
- `FOREIGN KEY (id_sucursal) REFERENCES valhalla_private.sucursal(id_sucursal) ON DELETE RESTRICT`
- `UNIQUE (idempotency_key)`
- `CHECK ((monto > 0))`
- `PRIMARY KEY (id_gasto)`

## inventario_sucursal

| Campo | Tipo | Admite nulo | Valor inicial |
|---|---|---|---|
| id_inventario_sucursal | bigint | No | Identidad autogenerada |
| id_sucursal | bigint | No | — |
| id_producto | bigint | No | — |
| stock_actual | bigint | No | — |
| stock_minimo | bigint | No | — |
| updated_at | timestamp with time zone | No | now() |

Restricciones y relaciones:

- `FOREIGN KEY (id_producto) REFERENCES valhalla_private.producto(id_producto) ON DELETE RESTRICT`
- `FOREIGN KEY (id_sucursal) REFERENCES valhalla_private.sucursal(id_sucursal) ON DELETE RESTRICT`
- `UNIQUE (id_sucursal, id_producto)`
- `PRIMARY KEY (id_inventario_sucursal)`
- `CHECK ((stock_actual >= 0))`
- `CHECK ((stock_minimo >= 0))`

## membresia

| Campo | Tipo | Admite nulo | Valor inicial |
|---|---|---|---|
| id_membresia | bigint | No | Identidad autogenerada |
| id_cliente | bigint | No | — |
| id_plan_membresia | bigint | No | — |
| id_operacion_compra | bigint | Sí | — |
| fecha_compra | timestamp with time zone | No | — |
| fecha_activacion | timestamp with time zone | No | — |
| precio_pagado | bigint | No | — |
| servicios_iniciales | bigint | No | — |
| estado | text | No | — |
| created_at | timestamp with time zone | No | now() |
| fecha_vencimiento | timestamp with time zone | Sí | — |
| nombre_plan_aplicado | text | Sí | — |

Restricciones y relaciones:

- `FOREIGN KEY (id_cliente) REFERENCES valhalla_private.cliente(id_cliente) ON DELETE RESTRICT`
- `FOREIGN KEY (id_operacion_compra) REFERENCES valhalla_private.operacion(id_operacion) ON DELETE RESTRICT`
- `FOREIGN KEY (id_plan_membresia) REFERENCES valhalla_private.membresia_plan(id_plan_membresia) ON DELETE RESTRICT`
- `PRIMARY KEY (id_membresia)`
- `CHECK ((precio_pagado >= 0))`
- `CHECK ((servicios_iniciales > 0))`

## membresia_consumo

| Campo | Tipo | Admite nulo | Valor inicial |
|---|---|---|---|
| id_membresia_consumo | bigint | No | Identidad autogenerada |
| id_membresia | bigint | No | — |
| id_operacion_servicio | bigint | No | — |
| cantidad | bigint | No | 1 |
| fecha_consumo | timestamp with time zone | No | — |

Restricciones y relaciones:

- `FOREIGN KEY (id_membresia) REFERENCES valhalla_private.membresia(id_membresia) ON DELETE RESTRICT`
- `FOREIGN KEY (id_operacion_servicio) REFERENCES valhalla_private.operacion_servicio(id_operacion_servicio) ON DELETE RESTRICT`
- `CHECK ((cantidad > 0))`
- `UNIQUE (id_operacion_servicio)`
- `PRIMARY KEY (id_membresia_consumo)`

## membresia_plan

| Campo | Tipo | Admite nulo | Valor inicial |
|---|---|---|---|
| id_plan_membresia | bigint | No | Identidad autogenerada |
| codigo | text | No | — |
| nombre | text | No | — |
| precio | bigint | No | — |
| cantidad_servicios | bigint | No | — |
| vigencia_desde | timestamp with time zone | No | — |
| vigencia_hasta | timestamp with time zone | Sí | — |
| activo | bigint | No | — |
| created_at | timestamp with time zone | No | now() |
| duracion_dias | bigint | No | 30 |

Restricciones y relaciones:

- `CHECK ((activo = ANY (ARRAY[(0)::bigint, (1)::bigint])))`
- `CHECK ((cantidad_servicios > 0))`
- `UNIQUE (codigo)`
- `CHECK ((duracion_dias > 0))`
- `PRIMARY KEY (id_plan_membresia)`
- `CHECK ((precio >= 0))`

## membresia_plan_servicio

| Campo | Tipo | Admite nulo | Valor inicial |
|---|---|---|---|
| id_plan_servicio | bigint | No | Identidad autogenerada |
| id_plan_membresia | bigint | No | — |
| id_servicio | bigint | No | — |

Restricciones y relaciones:

- `FOREIGN KEY (id_plan_membresia) REFERENCES valhalla_private.membresia_plan(id_plan_membresia) ON DELETE RESTRICT`
- `FOREIGN KEY (id_servicio) REFERENCES valhalla_private.servicio(id_servicio) ON DELETE RESTRICT`
- `UNIQUE (id_plan_membresia, id_servicio)`
- `PRIMARY KEY (id_plan_servicio)`

## membresia_servicio

| Campo | Tipo | Admite nulo | Valor inicial |
|---|---|---|---|
| id_membresia | bigint | No | — |
| id_servicio | bigint | No | — |

Restricciones y relaciones:

- `FOREIGN KEY (id_membresia) REFERENCES valhalla_private.membresia(id_membresia)`
- `FOREIGN KEY (id_servicio) REFERENCES valhalla_private.servicio(id_servicio)`
- `PRIMARY KEY (id_membresia, id_servicio)`

## metodo_pago

| Campo | Tipo | Admite nulo | Valor inicial |
|---|---|---|---|
| id_metodo_pago | bigint | No | Identidad autogenerada |
| codigo | text | No | — |
| nombre | text | No | — |
| activo | bigint | No | — |

Restricciones y relaciones:

- `CHECK ((activo = ANY (ARRAY[(0)::bigint, (1)::bigint])))`
- `UNIQUE (codigo)`
- `PRIMARY KEY (id_metodo_pago)`

## motivo_gratuidad

| Campo | Tipo | Admite nulo | Valor inicial |
|---|---|---|---|
| id_motivo_gratuidad | bigint | No | Identidad autogenerada |
| codigo | text | No | — |
| nombre | text | No | — |
| activo | bigint | No | — |

Restricciones y relaciones:

- `CHECK ((activo = ANY (ARRAY[(0)::bigint, (1)::bigint])))`
- `UNIQUE (codigo)`
- `PRIMARY KEY (id_motivo_gratuidad)`

## movimiento_caja

| Campo | Tipo | Admite nulo | Valor inicial |
|---|---|---|---|
| id_movimiento_caja | bigint | No | Identidad autogenerada |
| id_sucursal | bigint | No | — |
| id_pago | bigint | Sí | — |
| id_gasto | bigint | Sí | — |
| id_cuadre_caja | bigint | Sí | — |
| id_usuario | bigint | No | — |
| tipo_movimiento | text | No | — |
| monto | bigint | No | — |
| fecha_hora | timestamp with time zone | No | now() |
| observacion | text | Sí | — |

Restricciones y relaciones:

- `FOREIGN KEY (id_cuadre_caja) REFERENCES valhalla_private.cuadre_caja(id_cuadre_caja) ON DELETE RESTRICT`
- `FOREIGN KEY (id_gasto) REFERENCES valhalla_private.gasto(id_gasto) ON DELETE RESTRICT`
- `FOREIGN KEY (id_pago) REFERENCES valhalla_private.pago(id_pago) ON DELETE RESTRICT`
- `FOREIGN KEY (id_sucursal) REFERENCES valhalla_private.sucursal(id_sucursal) ON DELETE RESTRICT`
- `FOREIGN KEY (id_usuario) REFERENCES valhalla_private.usuario(id_usuario) ON DELETE RESTRICT`
- `CHECK (((id_pago IS NULL) OR (id_gasto IS NULL)))`
- `CHECK ((monto > 0))`
- `PRIMARY KEY (id_movimiento_caja)`
- `CHECK ((tipo_movimiento = ANY (ARRAY['INGRESO'::text, 'EGRESO'::text])))`

## movimiento_inventario

| Campo | Tipo | Admite nulo | Valor inicial |
|---|---|---|---|
| id_movimiento_inventario | bigint | No | Identidad autogenerada |
| id_sucursal | bigint | No | — |
| id_producto | bigint | No | — |
| id_operacion | bigint | Sí | — |
| id_operacion_producto | bigint | Sí | — |
| id_gasto | bigint | Sí | — |
| id_traslado | bigint | Sí | — |
| id_usuario_responsable | bigint | Sí | — |
| id_registrado_por | bigint | No | — |
| tipo_movimiento | text | No | — |
| cantidad | bigint | No | — |
| fecha_hora | timestamp with time zone | No | now() |
| observacion | text | Sí | — |

Restricciones y relaciones:

- `FOREIGN KEY (id_gasto) REFERENCES valhalla_private.gasto(id_gasto) ON DELETE RESTRICT`
- `FOREIGN KEY (id_operacion) REFERENCES valhalla_private.operacion(id_operacion) ON DELETE RESTRICT`
- `FOREIGN KEY (id_operacion_producto) REFERENCES valhalla_private.operacion_producto(id_operacion_producto) ON DELETE RESTRICT`
- `FOREIGN KEY (id_producto) REFERENCES valhalla_private.producto(id_producto) ON DELETE RESTRICT`
- `FOREIGN KEY (id_registrado_por) REFERENCES valhalla_private.usuario(id_usuario) ON DELETE RESTRICT`
- `FOREIGN KEY (id_sucursal) REFERENCES valhalla_private.sucursal(id_sucursal) ON DELETE RESTRICT`
- `FOREIGN KEY (id_traslado) REFERENCES valhalla_private.traslado_inventario(id_traslado) ON DELETE RESTRICT`
- `FOREIGN KEY (id_usuario_responsable) REFERENCES valhalla_private.usuario(id_usuario) ON DELETE RESTRICT`
- `CHECK ((cantidad > 0))`
- `PRIMARY KEY (id_movimiento_inventario)`

## operacion

| Campo | Tipo | Admite nulo | Valor inicial |
|---|---|---|---|
| id_operacion | bigint | No | Identidad autogenerada |
| id_cliente | bigint | No | — |
| id_cita | bigint | Sí | — |
| id_sucursal | bigint | No | — |
| id_barbero | bigint | Sí | — |
| id_registrada_por | bigint | No | — |
| id_cuadre_caja | bigint | Sí | — |
| idempotency_key | text | No | — |
| fecha_hora | timestamp with time zone | No | now() |
| estado | text | No | — |
| total_bruto | bigint | No | — |
| total_descuentos | bigint | No | — |
| total_cobrado | bigint | No | — |
| observaciones | text | Sí | — |
| created_at | timestamp with time zone | No | now() |
| updated_at | timestamp with time zone | Sí | now() |

Restricciones y relaciones:

- `FOREIGN KEY (id_barbero) REFERENCES valhalla_private.usuario(id_usuario) ON DELETE RESTRICT`
- `FOREIGN KEY (id_cita) REFERENCES valhalla_private.cita(id_cita) ON DELETE RESTRICT`
- `FOREIGN KEY (id_cliente) REFERENCES valhalla_private.cliente(id_cliente) ON DELETE RESTRICT`
- `FOREIGN KEY (id_cuadre_caja) REFERENCES valhalla_private.cuadre_caja(id_cuadre_caja) ON DELETE RESTRICT`
- `FOREIGN KEY (id_registrada_por) REFERENCES valhalla_private.usuario(id_usuario) ON DELETE RESTRICT`
- `FOREIGN KEY (id_sucursal) REFERENCES valhalla_private.sucursal(id_sucursal) ON DELETE RESTRICT`
- `CHECK ((total_cobrado = (total_bruto - total_descuentos)))`
- `UNIQUE (id_cita)`
- `UNIQUE (idempotency_key)`
- `PRIMARY KEY (id_operacion)`
- `CHECK ((total_bruto >= 0))`
- `CHECK ((total_cobrado >= 0))`
- `CHECK ((total_descuentos >= 0))`

## operacion_producto

| Campo | Tipo | Admite nulo | Valor inicial |
|---|---|---|---|
| id_operacion_producto | bigint | No | Identidad autogenerada |
| id_operacion | bigint | No | — |
| id_producto | bigint | No | — |
| cantidad | bigint | No | — |
| precio_unitario_aplicado | bigint | No | — |
| total_linea | bigint | No | — |

Restricciones y relaciones:

- `FOREIGN KEY (id_operacion) REFERENCES valhalla_private.operacion(id_operacion) ON DELETE RESTRICT`
- `FOREIGN KEY (id_producto) REFERENCES valhalla_private.producto(id_producto) ON DELETE RESTRICT`
- `CHECK ((cantidad > 0))`
- `PRIMARY KEY (id_operacion_producto)`
- `CHECK ((precio_unitario_aplicado >= 0))`
- `CHECK ((total_linea >= 0))`

## operacion_servicio

| Campo | Tipo | Admite nulo | Valor inicial |
|---|---|---|---|
| id_operacion_servicio | bigint | No | Identidad autogenerada |
| id_operacion | bigint | No | — |
| id_servicio | bigint | No | — |
| id_motivo_gratuidad | bigint | Sí | — |
| id_regla_comision | bigint | Sí | — |
| id_autorizado_por | bigint | Sí | — |
| cantidad | bigint | No | 1 |
| precio_normal | bigint | No | — |
| precio_aplicado | bigint | No | — |
| motivo_descuento | text | Sí | — |
| comentario_descuento | text | Sí | — |
| elegible_fidelidad_aplicado | bigint | No | — |
| base_comision | bigint | No | — |
| monto_comision | bigint | No | — |

Restricciones y relaciones:

- `FOREIGN KEY (id_autorizado_por) REFERENCES valhalla_private.usuario(id_usuario) ON DELETE RESTRICT`
- `FOREIGN KEY (id_motivo_gratuidad) REFERENCES valhalla_private.motivo_gratuidad(id_motivo_gratuidad) ON DELETE RESTRICT`
- `FOREIGN KEY (id_operacion) REFERENCES valhalla_private.operacion(id_operacion) ON DELETE RESTRICT`
- `FOREIGN KEY (id_regla_comision) REFERENCES valhalla_private.regla_comision(id_regla_comision) ON DELETE RESTRICT`
- `FOREIGN KEY (id_servicio) REFERENCES valhalla_private.servicio(id_servicio) ON DELETE RESTRICT`
- `CHECK ((base_comision >= 0))`
- `CHECK ((cantidad > 0))`
- `CHECK ((precio_aplicado <= precio_normal))`
- `CHECK (((id_motivo_gratuidad IS NULL) OR (precio_aplicado = 0)))`
- `CHECK ((base_comision = (precio_aplicado * cantidad)))`
- `CHECK ((elegible_fidelidad_aplicado = ANY (ARRAY[(0)::bigint, (1)::bigint])))`
- `CHECK ((monto_comision >= 0))`
- `PRIMARY KEY (id_operacion_servicio)`
- `CHECK ((precio_aplicado >= 0))`
- `CHECK ((precio_normal >= 0))`

## pago

| Campo | Tipo | Admite nulo | Valor inicial |
|---|---|---|---|
| id_pago | bigint | No | Identidad autogenerada |
| id_operacion | bigint | No | — |
| id_metodo_pago | bigint | No | — |
| id_banco | bigint | Sí | — |
| id_registrado_por | bigint | No | — |
| monto | bigint | No | — |
| efectivo_recibido | bigint | Sí | — |
| cambio | bigint | Sí | — |
| referencia_transferencia | text | Sí | — |
| fecha_hora | timestamp with time zone | No | now() |

Restricciones y relaciones:

- `FOREIGN KEY (id_banco) REFERENCES valhalla_private.banco(id_banco) ON DELETE RESTRICT`
- `FOREIGN KEY (id_metodo_pago) REFERENCES valhalla_private.metodo_pago(id_metodo_pago) ON DELETE RESTRICT`
- `FOREIGN KEY (id_operacion) REFERENCES valhalla_private.operacion(id_operacion) ON DELETE RESTRICT`
- `FOREIGN KEY (id_registrado_por) REFERENCES valhalla_private.usuario(id_usuario) ON DELETE RESTRICT`
- `UNIQUE (id_operacion)`
- `CHECK ((monto >= 0))`
- `PRIMARY KEY (id_pago)`

## producto

| Campo | Tipo | Admite nulo | Valor inicial |
|---|---|---|---|
| id_producto | bigint | No | Identidad autogenerada |
| nombre | text | No | — |
| categoria | text | Sí | — |
| unidad_medida | text | No | — |
| precio_venta_actual | bigint | Sí | — |
| activo | bigint | No | — |
| created_at | timestamp with time zone | No | now() |
| updated_at | timestamp with time zone | Sí | now() |

Restricciones y relaciones:

- `CHECK ((activo = ANY (ARRAY[(0)::bigint, (1)::bigint])))`
- `PRIMARY KEY (id_producto)`

## regla_comision

| Campo | Tipo | Admite nulo | Valor inicial |
|---|---|---|---|
| id_regla_comision | bigint | No | Identidad autogenerada |
| id_servicio | bigint | Sí | — |
| nombre | text | No | — |
| circunstancia | text | Sí | — |
| tipo_calculo | text | No | — |
| valor | bigint | No | — |
| vigencia_desde | timestamp with time zone | No | — |
| vigencia_hasta | timestamp with time zone | Sí | — |
| activo | bigint | No | — |

Restricciones y relaciones:

- `CHECK (((tipo_calculo = ANY (ARRAY['FIJO'::text, 'PORCENTAJE'::text])) AND ((tipo_calculo <> 'PORCENTAJE'::text) OR (valor <= 10000))))`
- `FOREIGN KEY (id_servicio) REFERENCES valhalla_private.servicio(id_servicio) ON DELETE RESTRICT`
- `CHECK ((activo = ANY (ARRAY[(0)::bigint, (1)::bigint])))`
- `PRIMARY KEY (id_regla_comision)`
- `CHECK ((valor >= 0))`

## rol

| Campo | Tipo | Admite nulo | Valor inicial |
|---|---|---|---|
| id_rol | bigint | No | Identidad autogenerada |
| codigo | text | No | — |
| nombre | text | No | — |
| activo | bigint | No | — |

Restricciones y relaciones:

- `CHECK ((activo = ANY (ARRAY[(0)::bigint, (1)::bigint])))`
- `UNIQUE (codigo)`
- `PRIMARY KEY (id_rol)`

## servicio

| Campo | Tipo | Admite nulo | Valor inicial |
|---|---|---|---|
| id_servicio | bigint | No | Identidad autogenerada |
| nombre | text | No | — |
| categoria | text | Sí | — |
| elegible_fidelidad | bigint | No | — |
| elegible_cumpleanos | bigint | No | — |
| activo | bigint | No | — |
| created_at | timestamp with time zone | No | now() |
| updated_at | timestamp with time zone | Sí | now() |

Restricciones y relaciones:

- `CHECK ((activo = ANY (ARRAY[(0)::bigint, (1)::bigint])))`
- `CHECK ((elegible_cumpleanos = ANY (ARRAY[(0)::bigint, (1)::bigint])))`
- `CHECK ((elegible_fidelidad = ANY (ARRAY[(0)::bigint, (1)::bigint])))`
- `PRIMARY KEY (id_servicio)`

## servicio_precio_historial

| Campo | Tipo | Admite nulo | Valor inicial |
|---|---|---|---|
| id_servicio_precio | bigint | No | Identidad autogenerada |
| id_servicio | bigint | No | — |
| precio | bigint | No | — |
| vigencia_desde | timestamp with time zone | No | — |
| vigencia_hasta | timestamp with time zone | Sí | — |
| created_at | timestamp with time zone | No | now() |

Restricciones y relaciones:

- `FOREIGN KEY (id_servicio) REFERENCES valhalla_private.servicio(id_servicio) ON DELETE RESTRICT`
- `PRIMARY KEY (id_servicio_precio)`
- `CHECK ((precio >= 0))`

## solicitud_idempotente

| Campo | Tipo | Admite nulo | Valor inicial |
|---|---|---|---|
| clave | text | No | — |
| accion | text | No | — |
| id_usuario | bigint | No | — |
| id_sucursal | bigint | No | — |
| solicitud | text | No | — |
| id_resultado | bigint | No | — |
| created_at | timestamp with time zone | No | — |

Restricciones y relaciones:

- `FOREIGN KEY (id_sucursal) REFERENCES valhalla_private.sucursal(id_sucursal)`
- `FOREIGN KEY (id_usuario) REFERENCES valhalla_private.usuario(id_usuario)`
- `PRIMARY KEY (clave)`

## sucursal

| Campo | Tipo | Admite nulo | Valor inicial |
|---|---|---|---|
| id_sucursal | bigint | No | Identidad autogenerada |
| nombre | text | No | — |
| activo | bigint | No | — |
| created_at | timestamp with time zone | No | now() |
| updated_at | timestamp with time zone | Sí | now() |

Restricciones y relaciones:

- `CHECK ((activo = ANY (ARRAY[(0)::bigint, (1)::bigint])))`
- `UNIQUE (nombre)`
- `PRIMARY KEY (id_sucursal)`

## traslado_inventario

| Campo | Tipo | Admite nulo | Valor inicial |
|---|---|---|---|
| id_traslado | bigint | No | Identidad autogenerada |
| id_sucursal_origen | bigint | No | — |
| id_sucursal_destino | bigint | No | — |
| id_responsable | bigint | No | — |
| idempotency_key | text | No | — |
| fecha_hora | timestamp with time zone | No | now() |
| observacion | text | Sí | — |

Restricciones y relaciones:

- `FOREIGN KEY (id_responsable) REFERENCES valhalla_private.usuario(id_usuario) ON DELETE RESTRICT`
- `FOREIGN KEY (id_sucursal_destino) REFERENCES valhalla_private.sucursal(id_sucursal) ON DELETE RESTRICT`
- `FOREIGN KEY (id_sucursal_origen) REFERENCES valhalla_private.sucursal(id_sucursal) ON DELETE RESTRICT`
- `CHECK ((id_sucursal_origen <> id_sucursal_destino))`
- `UNIQUE (idempotency_key)`
- `PRIMARY KEY (id_traslado)`

## usuario

| Campo | Tipo | Admite nulo | Valor inicial |
|---|---|---|---|
| id_usuario | bigint | No | Identidad autogenerada |
| id_rol | bigint | No | — |
| auth_uid | uuid | Sí | — |
| nombre_completo | text | No | — |
| activo | bigint | No | — |
| created_at | timestamp with time zone | No | now() |
| updated_at | timestamp with time zone | Sí | now() |
| correo | text | No | — |
| acceso_desde | timestamp with time zone | No | '-infinity'::timestamp with time zone |

Restricciones y relaciones:

- `FOREIGN KEY (id_rol) REFERENCES valhalla_private.rol(id_rol) ON DELETE RESTRICT`
- `CHECK ((activo = ANY (ARRAY[(0)::bigint, (1)::bigint])))`
- `FOREIGN KEY (auth_uid) REFERENCES auth.users(id) ON DELETE RESTRICT`
- `UNIQUE (auth_uid)`
- `CHECK ((correo = lower(TRIM(BOTH FROM correo))))`
- `UNIQUE (correo)`
- `PRIMARY KEY (id_usuario)`

## usuario_sucursal

| Campo | Tipo | Admite nulo | Valor inicial |
|---|---|---|---|
| id_usuario_sucursal | bigint | No | Identidad autogenerada |
| id_usuario | bigint | No | — |
| id_sucursal | bigint | No | — |
| es_principal | bigint | No | — |
| activo | bigint | No | — |
| created_at | timestamp with time zone | No | now() |

Restricciones y relaciones:

- `FOREIGN KEY (id_sucursal) REFERENCES valhalla_private.sucursal(id_sucursal) ON DELETE RESTRICT`
- `FOREIGN KEY (id_usuario) REFERENCES valhalla_private.usuario(id_usuario) ON DELETE RESTRICT`
- `CHECK ((activo = ANY (ARRAY[(0)::bigint, (1)::bigint])))`
- `CHECK ((es_principal = ANY (ARRAY[(0)::bigint, (1)::bigint])))`
- `UNIQUE (id_usuario, id_sucursal)`
- `PRIMARY KEY (id_usuario_sucursal)`
