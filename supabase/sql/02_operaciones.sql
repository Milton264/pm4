-- Funciones internas: las tablas no aceptan escrituras directas desde Flutter.
-- El único punto de entrada valida la identidad, sesión, rol y sucursal en cada llamada.
SET LOCAL search_path = valhalla_private, pg_catalog;

CREATE FUNCTION require_value(ok boolean, message text) RETURNS void
LANGUAGE plpgsql AS $$ BEGIN
  IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION USING MESSAGE=message, ERRCODE='P0001'; END IF;
END $$;

CREATE FUNCTION int_value(d jsonb,k text,lo bigint DEFAULT 0,hi bigint DEFAULT 999999999999)
RETURNS bigint LANGUAGE plpgsql AS $$ DECLARE n bigint; BEGIN
  PERFORM require_value(jsonb_typeof(d->k)='number' AND (d->>k) ~ '^-?[0-9]+$', 'Valor inválido: '||k);
  n := (d->>k)::bigint;
  PERFORM require_value(n BETWEEN lo AND hi,'Valor fuera de rango: '||k); RETURN n;
END $$;

CREATE FUNCTION text_value(d jsonb,k text,lo integer DEFAULT 2,hi integer DEFAULT 150)
RETURNS text LANGUAGE plpgsql AS $$ DECLARE s text := trim(coalesce(d->>k,'')); BEGIN
  PERFORM require_value(jsonb_typeof(d->k)='string' AND length(s) BETWEEN lo AND hi,'Revisa el campo '||k);
  RETURN s;
END $$;

CREATE FUNCTION actor_id() RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE u usuario; mail text; sid uuid; BEGIN
  PERFORM require_value(auth.uid() IS NOT NULL,'Inicia sesión para continuar.');
  SELECT lower(email) INTO mail FROM auth.users WHERE id=auth.uid() AND email_confirmed_at IS NOT NULL;
  PERFORM require_value(mail IS NOT NULL,'Confirma tu correo antes de ingresar.');
  SELECT * INTO u FROM usuario WHERE correo=mail AND (auth_uid=auth.uid() OR auth_uid IS NULL) AND activo=1 FOR UPDATE;
  PERFORM require_value(u.id_usuario IS NOT NULL,'Tu cuenta no tiene acceso activo. Contacta al administrador o encargado.');
  sid := nullif(auth.jwt()->>'session_id','')::uuid;
  PERFORM require_value(EXISTS(SELECT 1 FROM auth.sessions s WHERE s.id=sid AND s.user_id=auth.uid() AND s.created_at>=u.acceso_desde),
    'La sesión terminó o cambió tu acceso. Inicia sesión nuevamente.');
  IF u.auth_uid IS NULL THEN UPDATE usuario SET auth_uid=auth.uid() WHERE id_usuario=u.id_usuario; END IF;
  RETURN u.id_usuario;
END $$;

CREATE FUNCTION audit_entry(u bigint,b bigint,entity text,id bigint,action text,value jsonb DEFAULT '{}',before_value jsonb DEFAULT NULL)
RETURNS void LANGUAGE sql AS $$
  INSERT INTO bitacora_auditoria(id_usuario,id_sucursal,entidad,id_registro,accion,valor_nuevo,valor_anterior)
  VALUES(u,b,entity,id,action,value::text,before_value::text);
$$;

CREATE FUNCTION price_of(s bigint) RETURNS bigint LANGUAGE plpgsql AS $$ DECLARE p bigint; BEGIN
  SELECT h.precio INTO p FROM servicio_precio_historial h JOIN servicio t USING(id_servicio)
  WHERE h.id_servicio=s AND t.activo=1 AND h.vigencia_desde<=now() AND (h.vigencia_hasta IS NULL OR h.vigencia_hasta>now());
  PERFORM require_value(p IS NOT NULL,'Servicio sin precio vigente.'); RETURN p;
END $$;

CREATE FUNCTION balance_of(b bigint) RETURNS bigint LANGUAGE sql AS $$
  SELECT coalesce(sum(CASE WHEN tipo_movimiento='INGRESO' THEN monto ELSE -monto END),0)::bigint
  FROM movimiento_caja WHERE id_sucursal=b AND id_cuadre_caja IS NULL;
$$;

CREATE FUNCTION change_price(s bigint,p bigint) RETURNS void LANGUAGE plpgsql AS $$ BEGIN
  PERFORM require_value(p BETWEEN 0 AND 999999999999,'Precio inválido.');
  PERFORM require_value(EXISTS(SELECT 1 FROM servicio WHERE id_servicio=s),'Servicio inexistente.');
  IF EXISTS(SELECT 1 FROM servicio_precio_historial WHERE id_servicio=s AND vigencia_hasta IS NULL AND precio=p) THEN RETURN; END IF;
  UPDATE servicio_precio_historial SET vigencia_hasta=now() WHERE id_servicio=s AND vigencia_hasta IS NULL;
  INSERT INTO servicio_precio_historial(id_servicio,precio,vigencia_desde) VALUES(s,p,now());
END $$;

CREATE FUNCTION move_stock(u bigint,b bigint,p bigint,delta bigint,kind text,note text DEFAULT NULL,op bigint DEFAULT NULL,op_product bigint DEFAULT NULL,transfer_id bigint DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $$ BEGIN
  UPDATE inventario_sucursal SET stock_actual=stock_actual+delta,updated_at=now()
  WHERE id_sucursal=b AND id_producto=p AND stock_actual+delta>=0;
  PERFORM require_value(FOUND,'Existencias insuficientes o producto sin inventario en la sucursal.');
  INSERT INTO movimiento_inventario(id_sucursal,id_producto,id_operacion,id_operacion_producto,id_traslado,id_usuario_responsable,id_registrado_por,tipo_movimiento,cantidad,observacion)
  VALUES(b,p,op,op_product,transfer_id,u,u,kind,abs(delta),note);
END $$;

CREATE FUNCTION save_catalog(u bigint,b bigint,kind text,d jsonb) RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE id bigint := (d->>'id')::bigint; n text; a bigint; item bigint; ids jsonb; old jsonb; BEGIN
  IF kind='settings' THEN
    UPDATE configuracion_negocio SET nombre=text_value(d,'nombre'),meta_fidelidad=int_value(d,'meta_fidelidad',1,100),updated_at=now() WHERE configuracion_negocio.id=1;
    PERFORM audit_entry(u,b,'configuracion_negocio',1,'EDITAR',d); RETURN 1;
  END IF;
  n := text_value(d,'nombre'); a := int_value(d,'activo',0,1);
  CASE kind
  WHEN 'services' THEN
    IF id IS NULL THEN
      INSERT INTO servicio(nombre,activo,categoria,elegible_fidelidad,elegible_cumpleanos)
      VALUES(n,a,d->>'categoria',int_value(d,'elegible_fidelidad',0,1),int_value(d,'elegible_cumpleanos',0,1)) RETURNING id_servicio INTO id;
    ELSE
      UPDATE servicio SET nombre=n,activo=a,categoria=d->>'categoria',elegible_fidelidad=int_value(d,'elegible_fidelidad',0,1),elegible_cumpleanos=int_value(d,'elegible_cumpleanos',0,1),updated_at=now() WHERE id_servicio=id;
      PERFORM require_value(FOUND,'Servicio inexistente.');
    END IF;
    PERFORM change_price(id,int_value(d,'precio',1));
  WHEN 'products' THEN
    IF id IS NULL THEN
      INSERT INTO producto(nombre,activo,categoria,unidad_medida,precio_venta_actual) VALUES(n,a,d->>'categoria','unidad',int_value(d,'precio',1)) RETURNING id_producto INTO id;
    ELSE
      UPDATE producto SET nombre=n,activo=a,categoria=d->>'categoria',precio_venta_actual=int_value(d,'precio',1),updated_at=now() WHERE id_producto=id;
      PERFORM require_value(FOUND,'Producto inexistente.');
    END IF;
    INSERT INTO inventario_sucursal(id_sucursal,id_producto,stock_actual,stock_minimo)
      SELECT id_sucursal,id,0,0 FROM sucursal ON CONFLICT(id_sucursal,id_producto) DO NOTHING;
    UPDATE inventario_sucursal SET stock_minimo=int_value(d,'stock_minimo',0,1000000)*1000 WHERE id_sucursal=b AND id_producto=id;
  WHEN 'banks' THEN
    IF id IS NULL THEN
      INSERT INTO banco(nombre,codigo,activo) VALUES(n,upper(text_value(d,'codigo',2,40)),a) RETURNING id_banco INTO id;
    ELSE
      UPDATE banco SET nombre=n,codigo=upper(text_value(d,'codigo',2,40)),activo=a WHERE id_banco=id;
      PERFORM require_value(FOUND,'Banco inexistente.');
    END IF;
  WHEN 'branches' THEN
    PERFORM require_value(a=1 OR (id<>b AND EXISTS(SELECT 1 FROM sucursal WHERE id_sucursal<>id AND activo=1)),'Conserva una sucursal activa y cambia de sucursal antes de desactivarla.');
    IF id IS NULL THEN
      INSERT INTO sucursal(nombre,activo) VALUES(n,a) RETURNING id_sucursal INTO id;
      INSERT INTO usuario_sucursal(id_usuario,id_sucursal,es_principal,activo) VALUES(u,id,0,1);
      INSERT INTO inventario_sucursal(id_sucursal,id_producto,stock_actual,stock_minimo) SELECT id,id_producto,0,0 FROM producto;
    ELSE
      UPDATE sucursal SET nombre=n,activo=a,updated_at=now() WHERE id_sucursal=id;
      PERFORM require_value(FOUND,'Sucursal inexistente.');
    END IF;
  WHEN 'plans' THEN
    ids:=d->'servicios';
    PERFORM require_value(jsonb_typeof(ids)='array' AND jsonb_array_length(ids) BETWEEN 1 AND 100,'Selecciona servicios para el plan.');
    PERFORM require_value((SELECT count(*)=count(DISTINCT value) FROM jsonb_array_elements(ids)),'Hay servicios repetidos.');
    FOR item IN SELECT value::bigint FROM jsonb_array_elements_text(ids) LOOP
      PERFORM require_value(EXISTS(SELECT 1 FROM servicio WHERE id_servicio=item AND activo=1),'Servicio del plan no disponible.');
    END LOOP;
    IF id IS NULL THEN
      INSERT INTO membresia_plan(nombre,codigo,precio,cantidad_servicios,duracion_dias,vigencia_desde,activo)
      VALUES(n,upper(text_value(d,'codigo',2,40)),int_value(d,'precio',1),int_value(d,'cantidad_servicios',1,1000),int_value(d,'duracion_dias',1,3660),now(),a) RETURNING id_plan_membresia INTO id;
    ELSE
      UPDATE membresia_plan SET nombre=n,codigo=upper(text_value(d,'codigo',2,40)),precio=int_value(d,'precio',1),cantidad_servicios=int_value(d,'cantidad_servicios',1,1000),duracion_dias=int_value(d,'duracion_dias',1,3660),activo=a WHERE id_plan_membresia=id;
      PERFORM require_value(FOUND,'Plan inexistente.');
    END IF;
    DELETE FROM membresia_plan_servicio WHERE id_plan_membresia=id;
    INSERT INTO membresia_plan_servicio(id_plan_membresia,id_servicio) SELECT id,value::bigint FROM jsonb_array_elements_text(ids);
  WHEN 'commissions' THEN
    PERFORM require_value(id IS NULL,'Crea una nueva regla para conservar el historial.');
    PERFORM require_value(d->>'tipo_calculo' IN ('FIJO','PORCENTAJE'),'Tipo de comisión inválido.');
    item:=(d->>'id_servicio')::bigint;
    PERFORM require_value(item IS NULL OR EXISTS(SELECT 1 FROM servicio WHERE id_servicio=item AND activo=1),'Servicio no disponible.');
    IF a=1 THEN UPDATE regla_comision SET activo=0,vigencia_hasta=now() WHERE activo=1 AND id_servicio IS NOT DISTINCT FROM item; END IF;
    INSERT INTO regla_comision(nombre,activo,id_servicio,tipo_calculo,valor,vigencia_desde)
    VALUES(n,a,item,d->>'tipo_calculo',int_value(d,'valor',0,CASE WHEN d->>'tipo_calculo'='PORCENTAJE' THEN 10000 ELSE 999999999999 END),now()) RETURNING id_regla_comision INTO id;
  ELSE RAISE EXCEPTION 'Catálogo no disponible.';
  END CASE;
  PERFORM audit_entry(u,b,kind,id,CASE WHEN d->>'id' IS NULL THEN 'CREAR' ELSE 'EDITAR' END,d,old);
  RETURN id;
END $$;

CREATE FUNCTION save_staff(u bigint,b bigint,d jsonb) RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE id bigint:=(d->>'id')::bigint; mail text; role_id bigint; branch_id bigint; old usuario; a bigint; BEGIN
  mail:=lower(text_value(d,'email',5,254));
  PERFORM require_value(mail ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$','Correo inválido.');
  SELECT id_rol INTO role_id FROM rol WHERE codigo=d->>'profile' AND activo=1;
  PERFORM require_value(role_id IS NOT NULL AND jsonb_typeof(d->'active')='boolean','Revisa rol y estado.');
  a:=CASE WHEN (d->>'active')::boolean THEN 1 ELSE 0 END;
  PERFORM require_value(jsonb_typeof(d->'branches')='array' AND jsonb_array_length(d->'branches')>0,'Asigna al menos una sucursal.');
  PERFORM require_value((SELECT count(*)=count(DISTINCT value) FROM jsonb_array_elements(d->'branches')),'Hay sucursales repetidas.');
  IF id IS NOT NULL THEN
    SELECT * INTO old FROM usuario WHERE id_usuario=id;
    PERFORM require_value(old.id_usuario IS NOT NULL,'Usuario inexistente.');
    PERFORM require_value(old.auth_uid IS NULL OR old.correo=mail,'El correo de una cuenta activada se conserva. Desactiva la cuenta y registra otra si necesitas cambiarlo.');
    IF old.id_rol=(SELECT id_rol FROM rol WHERE codigo='administrador') AND (a=0 OR d->>'profile'<>'administrador') THEN
      PERFORM require_value(EXISTS(SELECT 1 FROM usuario x JOIN rol r ON r.id_rol=x.id_rol WHERE x.id_usuario<>id AND x.activo=1 AND r.codigo='administrador'),'Debe permanecer un administrador activo.');
    END IF;
    UPDATE usuario SET nombre_completo=text_value(d,'name',3),correo=mail,id_rol=role_id,activo=a,updated_at=now(),acceso_desde=now() WHERE id_usuario=id;
  ELSE
    INSERT INTO usuario(nombre_completo,correo,id_rol,activo) VALUES(text_value(d,'name',3),mail,role_id,a) RETURNING id_usuario INTO id;
  END IF;
  UPDATE usuario_sucursal SET activo=0 WHERE id_usuario=id;
  FOR branch_id IN SELECT value::bigint FROM jsonb_array_elements_text(d->'branches') LOOP
    PERFORM require_value(EXISTS(SELECT 1 FROM sucursal WHERE id_sucursal=branch_id AND activo=1),'Sucursal inactiva o inexistente.');
    INSERT INTO usuario_sucursal(id_usuario,id_sucursal,es_principal,activo) VALUES(id,branch_id,CASE WHEN branch_id=(d->'branches'->>0)::bigint THEN 1 ELSE 0 END,1)
    ON CONFLICT(id_usuario,id_sucursal) DO UPDATE SET activo=1,es_principal=excluded.es_principal;
  END LOOP;
  PERFORM audit_entry(u,b,'usuario',id,'GUARDAR_USUARIO',d-'password'); RETURN id;
END $$;

CREATE FUNCTION checkout(u bigint,b bigint,d jsonb) RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE c bigint:=int_value(d,'clientId',1); barber bigint:=int_value(d,'barberId',1);
  l jsonb; computed jsonb:='[]'; x jsonb; service servicio; rule regla_comision;
  m membresia; qty bigint; price bigint; applied bigint; disc bigint; benefit text; motive bigint;
  gross bigint:=0; total bigint:=0; base bigint; commission bigint; eligible boolean:=false;
  loyalty boolean:=false; birthday boolean:=false; goal bigint; uses jsonb:='{}'; used bigint;
  op bigint; detail bigint; payment bigint; method bigint; bank bigint; received bigint:=int_value(d,'received');
  transfer boolean:=coalesce((d->>'transfer')::boolean,false); today date:=(now() AT TIME ZONE 'America/El_Salvador')::date;
BEGIN
  PERFORM require_value(EXISTS(SELECT 1 FROM cliente WHERE id_cliente=c),'Cliente inexistente.');
  PERFORM require_value(EXISTS(SELECT 1 FROM usuario x JOIN rol r USING(id_rol) JOIN usuario_sucursal s USING(id_usuario)
    WHERE x.id_usuario=barber AND x.activo=1 AND r.codigo='barbero' AND r.activo=1 AND s.id_sucursal=b AND s.activo=1),'Selecciona un barbero de la sucursal.');
  PERFORM require_value(jsonb_typeof(d->'lines')='array' AND jsonb_array_length(d->'lines') BETWEEN 1 AND 100,'Agrega de 1 a 100 líneas al cobro.');
  SELECT meta_fidelidad INTO goal FROM configuracion_negocio WHERE id=1;
  FOR l IN SELECT value FROM jsonb_array_elements(d->'lines') LOOP
    qty:=int_value(l,'quantity',1,1000); disc:=int_value(l,'discount'); benefit:=coalesce(l->>'benefit',''); motive:=NULL; rule:=NULL;
    IF coalesce((l->>'product')::boolean,false) THEN
      PERFORM require_value(disc=0 AND benefit='','Los beneficios se aplican únicamente a servicios.');
      SELECT precio_venta_actual INTO price FROM producto WHERE id_producto=int_value(l,'id',1) AND activo=1;
      PERFORM require_value(price IS NOT NULL,'Producto no disponible.'); applied:=price; commission:=0;
    ELSE
      SELECT * INTO service FROM servicio WHERE id_servicio=int_value(l,'id',1) AND activo=1;
      price:=price_of(service.id_servicio);
      PERFORM require_value(disc<=price AND (disc=0 OR length(trim(coalesce(l->>'reason','')))>0),'El descuento requiere un motivo y un monto válido.');
      applied:=price-disc;
      IF benefit<>'' THEN
        PERFORM require_value(qty=1 AND disc=0,'El beneficio corresponde a una unidad y no admite descuento adicional.');
        CASE benefit
        WHEN 'FIDELIDAD' THEN
          PERFORM require_value(NOT loyalty AND service.elegible_fidelidad=1 AND
            (SELECT coalesce(sum(puntos),0) FROM fidelidad_movimiento WHERE id_cliente=c)>=goal,'Visitas insuficientes o servicio no elegible.');
          loyalty:=true;
        WHEN 'CUMPLEANOS' THEN
          PERFORM require_value(NOT birthday AND service.elegible_cumpleanos=1 AND
            (SELECT to_char(fecha_nacimiento,'MM-DD')=to_char(today,'MM-DD') FROM cliente WHERE id_cliente=c) AND
            NOT EXISTS(SELECT 1 FROM beneficio_cumpleanos WHERE id_cliente=c AND anio=extract(year FROM today)),
            'El beneficio corresponde al cumpleaños, una vez al año, en un servicio elegible.'); birthday:=true;
        WHEN 'MEMBRESIA' THEN
          SELECT * INTO m FROM membresia WHERE id_membresia=(l->>'membershipId')::bigint AND id_cliente=c AND estado='ACTIVA' FOR UPDATE;
          used:=coalesce((uses->>m.id_membresia::text)::bigint,0);
          PERFORM require_value(m.id_membresia IS NOT NULL AND m.fecha_activacion<=now() AND (m.fecha_vencimiento IS NULL OR m.fecha_vencimiento>now())
            AND EXISTS(SELECT 1 FROM membresia_servicio WHERE id_membresia=m.id_membresia AND id_servicio=service.id_servicio)
            AND m.servicios_iniciales-(SELECT coalesce(sum(cantidad),0) FROM membresia_consumo WHERE id_membresia=m.id_membresia)>used,
            'Membresía incompatible, agotada o vencida.');
          uses:=jsonb_set(uses,ARRAY[m.id_membresia::text],to_jsonb(used+1));
        ELSE RAISE EXCEPTION 'Beneficio desconocido.';
        END CASE;
        SELECT id_motivo_gratuidad INTO motive FROM motivo_gratuidad WHERE codigo=benefit AND activo=1;
        PERFORM require_value(motive IS NOT NULL,'Motivo de gratuidad no disponible.'); applied:=0;
      END IF;
      SELECT * INTO rule FROM regla_comision WHERE activo=1 AND (id_servicio=service.id_servicio OR id_servicio IS NULL)
        AND vigencia_desde<=now() AND (vigencia_hasta IS NULL OR vigencia_hasta>now()) ORDER BY id_servicio IS NULL,vigencia_desde DESC LIMIT 1;
      base:=applied*qty;
      commission:=CASE WHEN rule.id_regla_comision IS NULL OR base=0 THEN 0 WHEN rule.tipo_calculo='PORCENTAJE' THEN (base*rule.valor+5000)/10000 ELSE rule.valor*qty END;
      eligible:=eligible OR (base>0 AND service.elegible_fidelidad=1);
    END IF;
    PERFORM require_value(l->>'expectedUnitPrice' IS NULL OR (l->>'expectedUnitPrice')::bigint=price,'Cambió un precio. Actualiza el catálogo y revisa el cobro.');
    PERFORM require_value(price BETWEEN 0 AND 999999999999 AND commission BETWEEN 0 AND 999999999999,'Monto fuera del rango permitido.');
    gross:=gross+price*qty; total:=total+applied*qty;
    computed:=computed||jsonb_build_array(l||jsonb_build_object('price',price,'applied',applied,'motive',motive,'rule',rule.id_regla_comision,'commission',commission,
      'eligible',CASE WHEN NOT coalesce((l->>'product')::boolean,false) AND applied>0 AND service.elegible_fidelidad=1 THEN 1 ELSE 0 END));
  END LOOP;
  PERFORM require_value(gross BETWEEN 0 AND 999999999999 AND total BETWEEN 0 AND 999999999999,'Monto fuera del rango permitido.');
  PERFORM require_value(d->>'expectedTotal' IS NULL OR (d->>'expectedTotal')::bigint=total,'El total cambió. Actualiza el catálogo.');
  SELECT id_metodo_pago INTO method FROM metodo_pago WHERE codigo=CASE WHEN transfer THEN 'TRANSFERENCIA' ELSE 'EFECTIVO' END AND activo=1;
  PERFORM require_value(method IS NOT NULL,'Método de pago inactivo.');
  IF transfer THEN
    bank:=(d->>'bankId')::bigint;
    PERFORM require_value(EXISTS(SELECT 1 FROM banco WHERE id_banco=bank AND activo=1) AND length(trim(coalesce(d->>'reference','')))>0,'Indica banco activo y referencia.');
  ELSE PERFORM require_value(received>=total,'El efectivo recibido no cubre el total.'); END IF;
  INSERT INTO operacion(id_cliente,id_sucursal,id_barbero,id_registrada_por,idempotency_key,estado,total_bruto,total_descuentos,total_cobrado)
  VALUES(c,b,barber,u,d->>'key','PAGADA',gross,gross-total,total) RETURNING id_operacion INTO op;
  FOR x IN SELECT value FROM jsonb_array_elements(computed) LOOP
    IF coalesce((x->>'product')::boolean,false) THEN
      INSERT INTO operacion_producto(id_operacion,id_producto,cantidad,precio_unitario_aplicado,total_linea)
      VALUES(op,(x->>'id')::bigint,(x->>'quantity')::bigint*1000,(x->>'price')::bigint,(x->>'price')::bigint*(x->>'quantity')::bigint) RETURNING id_operacion_producto INTO detail;
      PERFORM move_stock(u,b,(x->>'id')::bigint,-(x->>'quantity')::bigint*1000,'VENTA',NULL,op,detail);
    ELSE
      INSERT INTO operacion_servicio(id_operacion,id_servicio,cantidad,precio_normal,precio_aplicado,id_motivo_gratuidad,id_regla_comision,id_autorizado_por,motivo_descuento,elegible_fidelidad_aplicado,base_comision,monto_comision)
      VALUES(op,(x->>'id')::bigint,(x->>'quantity')::bigint,(x->>'price')::bigint,(x->>'applied')::bigint,(x->>'motive')::bigint,(x->>'rule')::bigint,
        CASE WHEN coalesce(x->>'reason','')<>'' THEN u END,x->>'reason',(x->>'eligible')::bigint,(x->>'applied')::bigint*(x->>'quantity')::bigint,(x->>'commission')::bigint) RETURNING id_operacion_servicio INTO detail;
      IF x->>'benefit'='MEMBRESIA' THEN
        INSERT INTO membresia_consumo(id_membresia,id_operacion_servicio,cantidad,fecha_consumo) VALUES((x->>'membershipId')::bigint,detail,1,now());
      END IF;
    END IF;
  END LOOP;
  INSERT INTO pago(id_operacion,id_metodo_pago,id_banco,id_registrado_por,monto,efectivo_recibido,cambio,referencia_transferencia)
  VALUES(op,method,bank,u,total,CASE WHEN NOT transfer THEN received END,CASE WHEN NOT transfer THEN received-total END,CASE WHEN transfer THEN d->>'reference' END) RETURNING id_pago INTO payment;
  IF NOT transfer AND total>0 THEN INSERT INTO movimiento_caja(id_sucursal,id_pago,id_usuario,tipo_movimiento,monto) VALUES(b,payment,u,'INGRESO',total); END IF;
  IF loyalty OR eligible THEN INSERT INTO fidelidad_movimiento(id_cliente,id_operacion,puntos,created_at) VALUES(c,op,CASE WHEN loyalty THEN -goal ELSE 1 END,now()); END IF;
  IF birthday THEN INSERT INTO beneficio_cumpleanos(id_cliente,anio,id_operacion) VALUES(c,extract(year FROM today),op); END IF;
  PERFORM audit_entry(u,b,'operacion',op,'COBRAR',jsonb_build_object('total',total,'lineas',jsonb_array_length(computed)));
  RETURN op;
END $$;

CREATE FUNCTION buy_membership(u bigint,b bigint,d jsonb) RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE p membresia_plan; c bigint:=int_value(d,'client',1); received bigint:=int_value(d,'received'); op bigint; m bigint; pay bigint; BEGIN
  SELECT * INTO p FROM membresia_plan WHERE id_plan_membresia=int_value(d,'plan',1) AND activo=1 AND vigencia_desde<=now() AND (vigencia_hasta IS NULL OR vigencia_hasta>now());
  PERFORM require_value(p.id_plan_membresia IS NOT NULL AND p.duracion_dias BETWEEN 1 AND 3660,'Plan inactivo o fuera de vigencia.');
  PERFORM require_value(d->>'expectedPrice' IS NULL OR (d->>'expectedPrice')::bigint=p.precio,'Cambió el precio del plan.');
  PERFORM require_value(received>=p.precio,'Efectivo insuficiente.');
  PERFORM require_value(EXISTS(SELECT 1 FROM cliente WHERE id_cliente=c),'Cliente inexistente.');
  PERFORM require_value(EXISTS(SELECT 1 FROM membresia_plan_servicio ps JOIN servicio s USING(id_servicio) WHERE ps.id_plan_membresia=p.id_plan_membresia AND s.activo=1),'Plan sin servicios activos.');
  INSERT INTO operacion(id_cliente,id_sucursal,id_registrada_por,idempotency_key,estado,total_bruto,total_descuentos,total_cobrado,observaciones)
  VALUES(c,b,u,d->>'key','PAGADA',p.precio,0,p.precio,'Compra de membresía') RETURNING id_operacion INTO op;
  INSERT INTO membresia(id_cliente,id_plan_membresia,id_operacion_compra,fecha_compra,fecha_activacion,precio_pagado,servicios_iniciales,estado,fecha_vencimiento,nombre_plan_aplicado)
  VALUES(c,p.id_plan_membresia,op,now(),now(),p.precio,p.cantidad_servicios,'ACTIVA',now()+make_interval(days=>p.duracion_dias::integer),p.nombre) RETURNING id_membresia INTO m;
  INSERT INTO membresia_servicio(id_membresia,id_servicio) SELECT m,ps.id_servicio FROM membresia_plan_servicio ps JOIN servicio s USING(id_servicio) WHERE ps.id_plan_membresia=p.id_plan_membresia AND s.activo=1;
  INSERT INTO pago(id_operacion,id_metodo_pago,id_registrado_por,monto,efectivo_recibido,cambio)
  VALUES(op,(SELECT id_metodo_pago FROM metodo_pago WHERE codigo='EFECTIVO' AND activo=1),u,p.precio,received,received-p.precio) RETURNING id_pago INTO pay;
  IF p.precio>0 THEN INSERT INTO movimiento_caja(id_sucursal,id_pago,id_usuario,tipo_movimiento,monto) VALUES(b,pay,u,'INGRESO',p.precio); END IF;
  PERFORM audit_entry(u,b,'membresia',m,'VENDER',jsonb_build_object('operacion',op,'precio',p.precio)); RETURN op;
END $$;

CREATE FUNCTION read_data(u bigint,b bigint,role_code text,action text,d jsonb) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE q text; result jsonb; op jsonb; pay jsonb; BEGIN
  CASE action
  WHEN 'clients' THEN q:=$q$SELECT * FROM cliente WHERE nombre_completo ILIKE '%'||coalesce($3->>'search','')||'%' OR telefono LIKE '%'||coalesce($3->>'search','')||'%' ORDER BY nombre_completo$q$;
  WHEN 'services' THEN q:=$q$SELECT s.*,h.precio FROM servicio s JOIN servicio_precio_historial h USING(id_servicio) WHERE s.activo=1 AND h.vigencia_desde<=now() AND (h.vigencia_hasta IS NULL OR h.vigencia_hasta>now()) ORDER BY s.nombre$q$;
  WHEN 'products' THEN q:=$q$SELECT p.*,i.stock_actual,i.stock_minimo FROM producto p JOIN inventario_sucursal i USING(id_producto) WHERE p.activo=1 AND i.id_sucursal=$2 ORDER BY p.nombre$q$;
  WHEN 'banks' THEN q:=$q$SELECT * FROM banco WHERE activo=1 ORDER BY nombre$q$;
  WHEN 'barbers' THEN q:=$q$SELECT x.id_usuario,x.nombre_completo FROM usuario x JOIN rol r USING(id_rol) JOIN usuario_sucursal s USING(id_usuario) WHERE x.activo=1 AND r.activo=1 AND r.codigo='barbero' AND s.activo=1 AND s.id_sucursal=$2 AND ($4<>'barbero' OR x.id_usuario=$1) ORDER BY x.nombre_completo$q$;
  WHEN 'branches' THEN q:=$q$SELECT s.id_sucursal,s.nombre FROM sucursal s JOIN usuario_sucursal us USING(id_sucursal) WHERE s.activo=1 AND us.activo=1 AND us.id_usuario=$1 ORDER BY us.es_principal DESC,s.nombre$q$;
  WHEN 'business' THEN RETURN (SELECT to_jsonb(x) FROM configuracion_negocio x WHERE id=1);
  WHEN 'points' THEN RETURN (SELECT to_jsonb(coalesce(sum(puntos),0)) FROM fidelidad_movimiento WHERE id_cliente=(d->>'client')::bigint);
  WHEN 'cashBalance' THEN RETURN to_jsonb(balance_of(b));
  WHEN 'clientNotes' THEN q:=$q$SELECT n.id_nota,n.texto,n.created_at,x.nombre_completo autor FROM cliente_nota n JOIN usuario x USING(id_usuario) WHERE n.id_cliente=($3->>'client')::bigint ORDER BY n.id_nota DESC LIMIT 200$q$;
  WHEN 'history' THEN
    IF role_code='whatsapp' THEN
      q:=$q$SELECT o.id_operacion,o.fecha_hora,o.estado FROM operacion o WHERE o.id_cliente=($3->>'client')::bigint AND o.id_sucursal=$2 ORDER BY o.fecha_hora DESC$q$;
    ELSE
      q:=$q$SELECT * FROM operacion WHERE id_cliente=($3->>'client')::bigint AND id_sucursal=$2 AND ($4<>'barbero' OR id_barbero=$1) ORDER BY fecha_hora DESC$q$;
    END IF;
  WHEN 'operations' THEN q:=$q$SELECT o.*,c.nombre_completo,x.nombre_completo barbero FROM operacion o JOIN cliente c USING(id_cliente) LEFT JOIN usuario x ON x.id_usuario=o.id_barbero WHERE o.id_sucursal=$2 AND ($4<>'barbero' OR o.id_barbero=$1) ORDER BY o.id_operacion DESC$q$;
  WHEN 'commissions' THEN q:=$q$SELECT x.nombre_completo,count(os.id_operacion_servicio) servicios,sum(os.base_comision) base,sum(os.monto_comision) comision FROM operacion_servicio os JOIN operacion o USING(id_operacion) JOIN usuario x ON x.id_usuario=o.id_barbero WHERE o.id_sucursal=$2 AND o.estado='PAGADA' AND ($4<>'barbero' OR o.id_barbero=$1) GROUP BY x.id_usuario$q$;
  WHEN 'appointments' THEN q:=$q$SELECT ci.*,c.nombre_completo,s.nombre servicio,x.nombre_completo barbero FROM cita ci JOIN cliente c USING(id_cliente) JOIN cita_servicio cs USING(id_cita) JOIN servicio s USING(id_servicio) JOIN usuario x ON x.id_usuario=ci.id_barbero WHERE ci.id_sucursal=$2 AND ($4<>'barbero' OR ci.id_barbero=$1) ORDER BY CASE ci.estado WHEN 'PENDIENTE' THEN 0 ELSE 1 END,ci.fecha_hora$q$;
  WHEN 'staff' THEN q:=$q$SELECT x.id_usuario,x.nombre_completo,x.correo,x.activo,r.codigo rol,(x.auth_uid IS NOT NULL) acceso_activado,(SELECT string_agg(us.id_sucursal::text,',' ORDER BY us.id_sucursal) FROM usuario_sucursal us WHERE us.id_usuario=x.id_usuario AND us.activo=1) sucursales_ids FROM usuario x JOIN rol r USING(id_rol) ORDER BY x.nombre_completo$q$;
  WHEN 'plans' THEN q:=$q$SELECT p.*,(SELECT string_agg(s.nombre,', ' ORDER BY s.nombre) FROM membresia_plan_servicio ps JOIN servicio s USING(id_servicio) WHERE ps.id_plan_membresia=p.id_plan_membresia) servicios FROM membresia_plan p WHERE p.activo=1 AND p.vigencia_desde<=now() AND (p.vigencia_hasta IS NULL OR p.vigencia_hasta>now()) ORDER BY p.nombre$q$;
  WHEN 'memberships' THEN q:=$q$SELECT z.*,CASE WHEN z.estado<>'ACTIVA' THEN z.estado WHEN z.fecha_activacion>now() THEN 'PENDIENTE' WHEN z.fecha_vencimiento<=now() THEN 'VENCIDA' WHEN z.restante<=0 THEN 'AGOTADA' ELSE 'ACTIVA' END estado_vigente FROM
    (SELECT m.id_membresia,m.id_cliente,m.servicios_iniciales,m.estado,m.fecha_activacion,m.fecha_vencimiento,c.nombre_completo,m.nombre_plan_aplicado nombre,m.servicios_iniciales-coalesce((SELECT sum(cantidad) FROM membresia_consumo mc WHERE mc.id_membresia=m.id_membresia),0) restante
    FROM membresia m JOIN cliente c USING(id_cliente) WHERE ($3->>'client' IS NULL OR m.id_cliente=($3->>'client')::bigint) AND ($3->>'service' IS NULL OR EXISTS(SELECT 1 FROM membresia_servicio s WHERE s.id_membresia=m.id_membresia AND s.id_servicio=($3->>'service')::bigint))) z
    WHERE NOT coalesce(($3->>'usableOnly')::boolean,false) OR (z.estado='ACTIVA' AND z.fecha_activacion<=now() AND (z.fecha_vencimiento IS NULL OR z.fecha_vencimiento>now()) AND z.restante>0) ORDER BY z.id_membresia DESC$q$;
  WHEN 'catalog' THEN
    CASE d->>'kind'
    WHEN 'services' THEN q:=$q$SELECT s.*,(SELECT h.precio FROM servicio_precio_historial h WHERE h.id_servicio=s.id_servicio AND h.vigencia_desde<=now() AND (h.vigencia_hasta IS NULL OR h.vigencia_hasta>now())) precio FROM servicio s ORDER BY nombre$q$;
    WHEN 'products' THEN q:=$q$SELECT p.*,coalesce(i.stock_minimo,0) stock_minimo FROM producto p LEFT JOIN inventario_sucursal i ON i.id_producto=p.id_producto AND i.id_sucursal=$2 ORDER BY nombre$q$;
    WHEN 'branches' THEN q:=$q$SELECT * FROM sucursal ORDER BY nombre$q$;
    WHEN 'banks' THEN q:=$q$SELECT * FROM banco ORDER BY nombre$q$;
    WHEN 'commissions' THEN q:=$q$SELECT r.*,s.nombre servicio FROM regla_comision r LEFT JOIN servicio s USING(id_servicio) ORDER BY r.activo DESC,r.id_regla_comision DESC$q$;
    WHEN 'plans' THEN q:=$q$SELECT p.*,(SELECT string_agg(id_servicio::text,',') FROM membresia_plan_servicio ps WHERE ps.id_plan_membresia=p.id_plan_membresia) servicios_ids FROM membresia_plan p ORDER BY p.nombre$q$;
    ELSE RAISE EXCEPTION 'Catálogo no disponible.'; END CASE;
  WHEN 'records' THEN
    CASE d->>'kind'
    WHEN 'gasto' THEN q:='SELECT * FROM gasto WHERE id_sucursal=$2 ORDER BY id_gasto DESC LIMIT 100';
    WHEN 'cuadre_caja' THEN q:='SELECT * FROM cuadre_caja WHERE id_sucursal=$2 ORDER BY id_cuadre_caja DESC LIMIT 100';
    WHEN 'bitacora_auditoria' THEN q:='SELECT * FROM bitacora_auditoria WHERE id_sucursal=$2 ORDER BY id_auditoria DESC LIMIT 100';
    WHEN 'movimiento_inventario' THEN q:='SELECT * FROM movimiento_inventario WHERE id_sucursal=$2 ORDER BY id_movimiento_inventario DESC LIMIT 100';
    ELSE RAISE EXCEPTION 'Consulta no permitida.'; END CASE;
  WHEN 'receipt' THEN
    SELECT to_jsonb(o) INTO op FROM operacion o WHERE id_operacion=(d->>'id')::bigint AND id_sucursal=b;
    PERFORM require_value(op IS NOT NULL,'Comprobante inexistente o no autorizado.');
    SELECT to_jsonb(x) INTO pay FROM (SELECT p.*,m.codigo metodo FROM pago p JOIN metodo_pago m USING(id_metodo_pago) WHERE p.id_operacion=(d->>'id')::bigint) x;
    SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]') INTO result FROM (
      SELECT s.nombre,os.cantidad,os.precio_aplicado*os.cantidad total FROM operacion_servicio os JOIN servicio s USING(id_servicio) WHERE os.id_operacion=(d->>'id')::bigint
      UNION ALL SELECT p.nombre,op.cantidad/1000,op.total_linea FROM operacion_producto op JOIN producto p USING(id_producto) WHERE op.id_operacion=(d->>'id')::bigint) x;
    RETURN jsonb_build_object('operation',op,'payment',pay,'lines',result);
  ELSE RAISE EXCEPTION 'Operación no disponible.';
  END CASE;
  EXECUTE 'SELECT coalesce(jsonb_agg(to_jsonb(q)),''[]''::jsonb) FROM ('||q||') q' INTO result USING u,b,d,role_code;
  RETURN result;
END $$;

CREATE FUNCTION rpc(action text,d jsonb DEFAULT '{}',branch bigint DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,valhalla_private AS $$
DECLARE u bigint; b bigint:=branch; role_code text; managed boolean; mutates boolean;
  id bigint; c bigint; barber bigint; service_id bigint; duration bigint; dt timestamptz;
  amount bigint; expected bigint; transfer boolean; method bigint; bank bigint; destination bigint;
  result jsonb; old solicitud_idempotente; request_key text; row cita; start_at timestamptz; extra jsonb;
BEGIN
  PERFORM require_value(auth.uid() IS NOT NULL,'Inicia sesión para continuar.');
  PERFORM require_value(jsonb_typeof(d)='object' AND octet_length(d::text)<=262144,'Solicitud inválida o demasiado grande.');
  mutates:=action=ANY(ARRAY['saveStaff','saveClient','saveNote','saveCatalog','servicePrice','appointment','cancelAppointment','completeAppointment','checkout','buyMembership','adjustStock','expense','openingCash','closeCash']);
  -- Las operaciones de negocio son breves. Este bloqueo común evita carreras entre
  -- cobros, precios, beneficios, traslados y cierres, incluso entre sucursales.
  IF mutates THEN PERFORM pg_advisory_xact_lock(691204,1); END IF;
  u:=actor_id();
  SELECT r.codigo INTO role_code FROM usuario x JOIN rol r USING(id_rol) WHERE x.id_usuario=u AND r.activo=1;
  managed:=role_code IN ('administrador','encargado');
  PERFORM require_value(role_code IS NOT NULL,'Rol no disponible.');
  IF b IS NULL THEN SELECT s.id_sucursal INTO b FROM sucursal s JOIN usuario_sucursal us USING(id_sucursal) WHERE us.id_usuario=u AND us.activo=1 AND s.activo=1 ORDER BY us.es_principal DESC,s.nombre LIMIT 1; END IF;
  PERFORM require_value(EXISTS(SELECT 1 FROM sucursal s JOIN usuario_sucursal us USING(id_sucursal) WHERE us.id_usuario=u AND us.id_sucursal=b AND us.activo=1 AND s.activo=1),'No tienes acceso a esta sucursal.');
  IF action='me' THEN
    SELECT jsonb_build_object('userId',u,'branchId',b,'profile',role_code,'name',nombre_completo,'email',correo,'mustChangePassword',false,
      'branches',read_data(u,b,role_code,'branches','{}')) INTO result FROM usuario WHERE id_usuario=u;
    RETURN result;
  END IF;
  IF NOT managed THEN
    PERFORM require_value((role_code='whatsapp' AND action=ANY(ARRAY['clients','services','barbers','branches','business','history','points','memberships','clientNotes','saveNote','saveClient','appointments','appointment','cancelAppointment']))
      OR (role_code='barbero' AND action=ANY(ARRAY['branches','business','services','commissions','appointments','completeAppointment'])),
      'Tu rol no tiene permiso para realizar esta operación.');
  END IF;
  IF NOT mutates THEN RETURN read_data(u,b,role_code,action,d); END IF;
  IF action=ANY(ARRAY['appointment','checkout','buyMembership','adjustStock','expense','openingCash','closeCash']) THEN
    request_key:=text_value(d,'key',1,128);
    SELECT * INTO old FROM solicitud_idempotente WHERE clave=request_key;
    IF FOUND THEN
      PERFORM require_value(old.accion=action AND old.id_usuario=u AND old.id_sucursal=b AND old.solicitud::jsonb=d,'La solicitud ya existe con otros datos.');
      RETURN to_jsonb(old.id_resultado);
    END IF;
  END IF;
  CASE action
  WHEN 'saveCatalog' THEN id:=save_catalog(u,b,d->>'kind',d->'data');
  WHEN 'saveStaff' THEN id:=save_staff(u,b,d);
  WHEN 'servicePrice' THEN
    id:=int_value(d,'service',1); PERFORM change_price(id,int_value(d,'price')); PERFORM audit_entry(u,b,'servicio',id,'CAMBIO_PRECIO',d);
  WHEN 'saveClient' THEN
    id:=(d->>'id')::bigint;
    PERFORM require_value((d->>'birth')::date BETWEEN date '1900-01-01' AND (now() AT TIME ZONE 'America/El_Salvador')::date,'Fecha de nacimiento inválida.');
    IF id IS NULL THEN
      INSERT INTO cliente(nombre_completo,telefono,fecha_nacimiento) VALUES(text_value(d,'name',3),text_value(d,'phone',8,30),(d->>'birth')::date) RETURNING id_cliente INTO id;
    ELSE
      UPDATE cliente SET nombre_completo=text_value(d,'name',3),telefono=text_value(d,'phone',8,30),fecha_nacimiento=(d->>'birth')::date,updated_at=now() WHERE id_cliente=id;
      PERFORM require_value(FOUND,'Cliente inexistente.');
    END IF;
    PERFORM audit_entry(u,b,'cliente',id,'GUARDAR',d);
  WHEN 'saveNote' THEN
    INSERT INTO cliente_nota(id_cliente,id_usuario,texto,created_at) VALUES(int_value(d,'client',1),u,text_value(d,'note',2,1000),now()) RETURNING id_nota INTO id;
    PERFORM audit_entry(u,b,'cliente_nota',id,'CREAR',jsonb_build_object('cliente',d->'client'));
  WHEN 'appointment' THEN
    c:=int_value(d,'client',1); barber:=int_value(d,'barber',1); service_id:=int_value(d,'service',1); duration:=int_value(d,'duration',5,480); dt:=date_trunc('minute',(d->>'date')::timestamptz);
    PERFORM require_value(dt>now(),'Selecciona una fecha futura.');
    PERFORM require_value(EXISTS(SELECT 1 FROM servicio WHERE id_servicio=service_id AND activo=1),'Servicio no disponible.');
    PERFORM require_value(EXISTS(SELECT 1 FROM usuario x JOIN rol r USING(id_rol) JOIN usuario_sucursal us USING(id_usuario) WHERE x.id_usuario=barber AND x.activo=1 AND r.activo=1 AND r.codigo='barbero' AND us.id_sucursal=b AND us.activo=1),'Barbero no asignado a la sucursal.');
    PERFORM require_value(NOT EXISTS(SELECT 1 FROM cita WHERE id_barbero=barber AND estado='PENDIENTE' AND fecha_hora<dt+make_interval(mins=>duration::integer) AND fecha_hora+make_interval(mins=>duracion_minutos::integer)>dt),'El barbero ya tiene una cita a esta hora.');
    INSERT INTO cita(id_cliente,id_sucursal,id_barbero,id_creada_por,fecha_hora,duracion_minutos,estado) VALUES(c,b,barber,u,dt,duration,'PENDIENTE') RETURNING id_cita INTO id;
    INSERT INTO cita_servicio(id_cita,id_servicio,cantidad) VALUES(id,service_id,1);
    PERFORM audit_entry(u,b,'cita',id,'CREAR',d);
  WHEN 'cancelAppointment','completeAppointment' THEN
    id:=int_value(d,'id',1);
    SELECT * INTO row FROM cita WHERE id_cita=id AND id_sucursal=b AND (role_code<>'barbero' OR id_barbero=u) FOR UPDATE;
    PERFORM require_value(row.id_cita IS NOT NULL,'Cita no disponible.');
    IF action='completeAppointment' AND row.estado='ATENDIDA' THEN RETURN to_jsonb(id); END IF;
    PERFORM require_value(row.estado='PENDIENTE','Solo se puede modificar una cita pendiente.');
    IF action='completeAppointment' THEN
      PERFORM require_value(row.fecha_hora<=now(),'El horario de esta cita todavía no ha comenzado.');
      UPDATE cita SET estado='ATENDIDA',id_confirmada_por=u,confirmada_at=now(),updated_at=now() WHERE id_cita=id;
    ELSE UPDATE cita SET estado='CANCELADA',updated_at=now() WHERE id_cita=id; END IF;
    PERFORM audit_entry(u,b,'cita',id,CASE WHEN action='completeAppointment' THEN 'CONFIRMAR_CORTE' ELSE 'CANCELAR' END,'{}',jsonb_build_object('estado',row.estado));
  WHEN 'checkout' THEN id:=checkout(u,b,d);
  WHEN 'buyMembership' THEN id:=buy_membership(u,b,d);
  WHEN 'adjustStock' THEN
    c:=int_value(d,'product',1); amount:=int_value(d,'units',1,1000000)*1000;
    PERFORM text_value(d,'reason',2,250);
    PERFORM require_value(EXISTS(SELECT 1 FROM producto WHERE id_producto=c AND activo=1),'Producto no disponible.');
    IF d->>'type'='TRASLADO' THEN
      destination:=int_value(d,'destination',1);
      PERFORM require_value(destination<>b AND EXISTS(SELECT 1 FROM usuario_sucursal us JOIN sucursal s USING(id_sucursal) WHERE us.id_usuario=u AND us.id_sucursal=destination AND us.activo=1 AND s.activo=1),'Sucursal destino no autorizada.');
      INSERT INTO traslado_inventario(id_sucursal_origen,id_sucursal_destino,id_responsable,idempotency_key,observacion) VALUES(b,destination,u,request_key,d->>'reason') RETURNING id_traslado INTO id;
      PERFORM move_stock(u,b,c,-amount,'TRASLADO_SALIDA',d->>'reason',NULL,NULL,id);
      PERFORM move_stock(u,destination,c,amount,'TRASLADO_ENTRADA',d->>'reason',NULL,NULL,id);
    ELSE
      PERFORM require_value(d->>'type' IN ('ENTRADA','CONSUMO_INTERNO'),'Movimiento inválido.'); id:=c;
      PERFORM move_stock(u,b,c,CASE WHEN d->>'type'='ENTRADA' THEN amount ELSE -amount END,d->>'type',d->>'reason');
    END IF;
    PERFORM audit_entry(u,b,'producto',c,d->>'type',d);
  WHEN 'openingCash' THEN
    amount:=int_value(d,'amount',1);
    PERFORM require_value(NOT EXISTS(SELECT 1 FROM movimiento_caja WHERE id_sucursal=b AND id_cuadre_caja IS NULL),'La caja ya tiene movimientos pendientes.');
    INSERT INTO movimiento_caja(id_sucursal,id_usuario,tipo_movimiento,monto,observacion) VALUES(b,u,'INGRESO',amount,'Fondo de apertura') RETURNING id_movimiento_caja INTO id;
    PERFORM audit_entry(u,b,'movimiento_caja',id,'APERTURA',d);
  WHEN 'expense' THEN
    amount:=int_value(d,'amount',1); transfer:=coalesce((d->>'transfer')::boolean,false); bank:=(d->>'bank')::bigint;
    SELECT id_metodo_pago INTO method FROM metodo_pago WHERE codigo=CASE WHEN transfer THEN 'TRANSFERENCIA' ELSE 'EFECTIVO' END AND activo=1;
    IF transfer THEN PERFORM require_value(EXISTS(SELECT 1 FROM banco WHERE id_banco=bank AND activo=1),'Selecciona banco activo.');
    ELSE PERFORM require_value(balance_of(b)>=amount,'Efectivo insuficiente en caja.'); bank:=NULL; END IF;
    INSERT INTO gasto(id_sucursal,id_registrado_por,id_metodo_pago,id_banco,idempotency_key,descripcion,categoria,monto)
    VALUES(b,u,method,bank,request_key,text_value(d,'description',2,250),text_value(d,'category',2,100),amount) RETURNING id_gasto INTO id;
    IF NOT transfer THEN INSERT INTO movimiento_caja(id_sucursal,id_gasto,id_usuario,tipo_movimiento,monto) VALUES(b,id,u,'EGRESO',amount); END IF;
    PERFORM audit_entry(u,b,'gasto',id,'CREAR',d);
  WHEN 'closeCash' THEN
    amount:=int_value(d,'counted'); expected:=balance_of(b);
    PERFORM require_value(d->>'expectedBalance' IS NULL OR (d->>'expectedBalance')::bigint=expected,'La caja cambió mientras contabas. Actualiza el saldo.');
    PERFORM require_value(amount=expected OR length(trim(coalesce(d->>'explanation','')))>0,'Explica la diferencia antes de cerrar.');
    SELECT min(fecha_hora) INTO start_at FROM (
      SELECT fecha_hora FROM movimiento_caja WHERE id_sucursal=b AND id_cuadre_caja IS NULL UNION ALL
      SELECT fecha_hora FROM operacion WHERE id_sucursal=b AND id_cuadre_caja IS NULL UNION ALL
      SELECT fecha_hora FROM gasto WHERE id_sucursal=b AND id_cuadre_caja IS NULL) pending;
    PERFORM require_value(start_at IS NOT NULL,'No hay operaciones ni movimientos por cerrar.');
    INSERT INTO cuadre_caja(id_sucursal,id_cerrado_por,idempotency_key,periodo_inicio,periodo_fin,efectivo_esperado,efectivo_contado,diferencia,explicacion_diferencia,estado,fecha_hora_cierre)
    VALUES(b,u,request_key,start_at,now(),expected,amount,amount-expected,d->>'explanation','CERRADO',now()) RETURNING id_cuadre_caja INTO id;
    UPDATE movimiento_caja SET id_cuadre_caja=id WHERE id_sucursal=b AND id_cuadre_caja IS NULL;
    UPDATE operacion SET id_cuadre_caja=id WHERE id_sucursal=b AND id_cuadre_caja IS NULL;
    UPDATE gasto SET id_cuadre_caja=id WHERE id_sucursal=b AND id_cuadre_caja IS NULL;
    PERFORM audit_entry(u,b,'cuadre_caja',id,'CERRAR',jsonb_build_object('esperado',expected,'contado',amount));
  ELSE RAISE EXCEPTION 'Operación no disponible.';
  END CASE;
  IF request_key IS NOT NULL THEN INSERT INTO solicitud_idempotente(clave,accion,id_usuario,id_sucursal,solicitud,id_resultado,created_at) VALUES(request_key,action,u,b,d::text,id,now()); END IF;
  RETURN to_jsonb(id);
END $$;

REVOKE ALL ON ALL FUNCTIONS IN SCHEMA valhalla_private FROM PUBLIC,anon,authenticated;
GRANT USAGE ON SCHEMA valhalla_private TO authenticated;
GRANT EXECUTE ON FUNCTION valhalla_private.rpc(text,jsonb,bigint) TO authenticated;

CREATE FUNCTION public.valhalla_rpc(action text,d jsonb DEFAULT '{}',branch bigint DEFAULT NULL)
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$
  SELECT valhalla_private.rpc(action,d,branch);
$$;
REVOKE ALL ON FUNCTION public.valhalla_rpc(text,jsonb,bigint) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.valhalla_rpc(text,jsonb,bigint) TO authenticated;

COMMENT ON FUNCTION public.valhalla_rpc(text,jsonb,bigint) IS 'API de VALHALLA: valida la identidad de Auth, sesión activa, rol, sucursal y reglas transaccionales.';
NOTIFY pgrst,'reload schema';
