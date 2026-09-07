import {readFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import assert from 'node:assert/strict';
const {PGlite}=await import(process.env.PGLITE_MODULE ?? '@electric-sql/pglite');
const root=fileURLToPath(new URL('../',import.meta.url));
const pg=new PGlite();
let checks=0;
const check=(name,fn)=>Promise.resolve().then(fn).then(()=>{checks++;process.stdout.write(`OK ${name}\n`);});
try {
  await pg.exec(`CREATE ROLE anon; CREATE ROLE authenticated; CREATE SCHEMA auth;
    CREATE TABLE auth.users(id uuid PRIMARY KEY,email text,email_confirmed_at timestamptz);
    CREATE TABLE auth.sessions(id uuid PRIMARY KEY,user_id uuid,created_at timestamptz DEFAULT now());
    CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
    CREATE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql AS $$SELECT coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb$$;
    GRANT USAGE ON SCHEMA public TO authenticated,anon;`);
  const parts=await Promise.all(['01_modelo.sql','02_operaciones.sql','03_semilla.sql'].map(n=>readFile(root+'supabase/sql/'+n,'utf8')));
  await check('Instalación PostgreSQL íntegra',()=>pg.exec('BEGIN;'+parts.join('\n')+'COMMIT;'));
  await check('Semilla repetible sin duplicados',async()=>{
    await pg.exec('BEGIN;'+parts[2]+'COMMIT;');
    assert.equal((await pg.query('SELECT count(*)::int n FROM valhalla_private.usuario')).rows[0].n,1);
    assert.equal((await pg.query('SELECT count(*)::int n FROM valhalla_private.rol')).rows[0].n,4);
  });
  const uuid=i=>`10000000-0000-4000-8000-${String(i).padStart(12,'0')}`;
  async function identity(i,email){
    await pg.query('INSERT INTO auth.users VALUES($1,$2,now())',[uuid(i),email]);
    await pg.query('INSERT INTO auth.sessions(id,user_id) VALUES($1,$2)',[uuid(i+100),uuid(i)]);
  }
  async function rpc(i,action,d={},branch=1){
    await pg.query("SELECT set_config('request.jwt.claim.sub',$1,false),set_config('request.jwt.claims',$2,false)",[uuid(i),JSON.stringify({sub:uuid(i),session_id:uuid(i+100)})]);
    await pg.exec('SET ROLE authenticated');
    try{return (await pg.query('SELECT public.valhalla_rpc($1,$2::jsonb,$3) result',[action,JSON.stringify(d),branch])).rows[0].result;}
    finally{await pg.exec('RESET ROLE');}
  }
  const denied=async(fn,pattern)=>{await assert.rejects(fn,pattern??/permiso|acceso|sesión|sesion|Sucursal|disponible/);};
  await identity(1,'milton.ramirez@catolica.edu.sv');
  await check('Primera cuenta reservada y acceso por sucursal',async()=>{
    assert.equal((await rpc(1,'me')).profile,'administrador');
    await denied(()=>rpc(1,'me',{},999));
  });
  const staff=async(i,profile)=>{
    const email=`${profile}${i}@example.test`;
    const id=await rpc(1,'saveStaff',{name:`Usuario ${profile} ${i}`,email,profile,active:true,branches:[1,2]});
    await identity(i,email); await rpc(i,'me'); return id;
  };
  const barber=await staff(2,'barbero'),wa=await staff(3,'whatsapp'),manager=await staff(4,'encargado'),other=await staff(5,'barbero');
  let service,product,client,plan;
  await check('Encargado administra catálogos y equipo',async()=>{
    service=await rpc(4,'saveCatalog',{kind:'services',data:{nombre:'Corte',activo:1,precio:800,categoria:'Cabello',elegible_fidelidad:1,elegible_cumpleanos:1}});
    product=await rpc(4,'saveCatalog',{kind:'products',data:{nombre:'Pomada',activo:1,precio:1200,stock_minimo:1}});
    await rpc(4,'saveCatalog',{kind:'commissions',data:{nombre:'Comisión',activo:1,tipo_calculo:'PORCENTAJE',valor:4000,id_servicio:service}});
    assert.equal((await rpc(4,'staff')).length,5);
    assert.equal((await rpc(4,'catalog',{kind:'services'}))[0].precio,800);
  });
  await check('WhatsApp crea clientes y citas, barbero solo confirma sus cortes',async()=>{
    client=await rpc(3,'saveClient',{name:'Cliente Pruebas',phone:'7000-1234',birth:'1990-01-01'});
    const body={client,barber,service,date:new Date(Date.now()+3600000).toISOString(),duration:30,key:'cita-1'};
    await denied(()=>rpc(2,'appointment',body));
    const id=await rpc(3,'appointment',body);
    assert.equal(await rpc(3,'appointment',body),id);
    await denied(()=>rpc(2,'cancelAppointment',{id}));
    await denied(()=>rpc(3,'completeAppointment',{id}));
    await denied(()=>rpc(5,'completeAppointment',{id}));
    await denied(()=>rpc(2,'completeAppointment',{id}),/horario/);
    await assert.rejects(()=>rpc(3,'appointment',{...body,key:'overlap'}),/ya tiene una cita/);
    await pg.query("UPDATE valhalla_private.cita SET fecha_hora=now()-interval '1 hour' WHERE id_cita=$1",[id]);
    await rpc(2,'completeAppointment',{id}); await rpc(2,'completeAppointment',{id});
    assert.equal((await rpc(2,'appointments'))[0].estado,'ATENDIDA');
    assert.equal((await rpc(5,'appointments')).length,0);
    assert.equal((await pg.query("SELECT count(*)::int n FROM valhalla_private.bitacora_auditoria WHERE accion='CONFIRMAR_CORTE'")).rows[0].n,1);
    assert.equal((await pg.query('SELECT count(*)::int n FROM valhalla_private.operacion')).rows[0].n,0);
  });
  const sale=key=>({key,clientId:client,barberId:barber,received:800,expectedTotal:800,lines:[{id:service,quantity:1,discount:0,benefit:'',reason:'',expectedUnitPrice:800}]});
  await check('Cobro, pago, comisión, fidelidad e idempotencia',async()=>{
    await denied(()=>rpc(2,'checkout',sale('barber-cobro')));
    await denied(()=>rpc(3,'cashBalance'));
    const op=await rpc(4,'checkout',sale('sale-1'));
    assert.equal(await rpc(4,'checkout',sale('sale-1')),op);
    await assert.rejects(()=>rpc(4,'checkout',{...sale('sale-1'),received:900}),/otros datos/);
    assert.equal(await rpc(4,'cashBalance'),800);
    assert.equal((await rpc(4,'receipt',{id:op})).lines[0].total,800);
    assert.equal((await rpc(2,'commissions'))[0].comision,320);
    assert.equal(await rpc(3,'points',{client}),1);
  });
  await check('Stock insuficiente revierte todos los registros',async()=>{
    const before=await rpc(4,'operations');
    await assert.rejects(()=>rpc(4,'checkout',{...sale('stock-bad'),received:2000,expectedTotal:2000,lines:[...sale('x').lines,{id:product,product:true,quantity:1,discount:0,benefit:'',expectedUnitPrice:1200}]}),/Existencias/);
    assert.equal((await rpc(4,'operations')).length,before.length);
    await rpc(4,'adjustStock',{product,units:3,type:'ENTRADA',reason:'Compra inicial',key:'stock-1'});
    await rpc(4,'adjustStock',{product,units:1,type:'TRASLADO',destination:2,reason:'Traslado',key:'stock-2'});
    assert.equal((await rpc(4,'products'))[0].stock_actual,2000);
    assert.equal((await rpc(4,'products',{},2))[0].stock_actual,1000);
  });
  await check('Membresías conservan nombre y servicios del momento de compra',async()=>{
    plan=await rpc(4,'saveCatalog',{kind:'plans',data:{nombre:'Plan cuatro',codigo:'PLAN4',activo:1,precio:2800,cantidad_servicios:4,duracion_dias:30,servicios:[service]}});
    await rpc(4,'buyMembership',{client,plan,received:2800,expectedPrice:2800,key:'plan-sale'});
    const membership=(await rpc(3,'memberships',{client}))[0];
    assert.equal(membership.restante,4);
    await rpc(4,'checkout',{...sale('redeem-plan'),received:0,expectedTotal:0,lines:[{id:service,quantity:1,discount:0,benefit:'MEMBRESIA',membershipId:membership.id_membresia,reason:'',expectedUnitPrice:800}]});
    assert.equal((await rpc(3,'memberships',{client,usableOnly:true}))[0].restante,3);
  });
  await check('Gastos, cierre y control del saldo esperado',async()=>{
    await rpc(4,'expense',{description:'Compra de insumos',category:'Operación',amount:100,transfer:false,key:'expense-1'});
    const expectedBalance=await rpc(4,'cashBalance');
    await assert.rejects(()=>rpc(4,'closeCash',{counted:expectedBalance,expectedBalance:0,explanation:'',key:'close-bad'}),/cambió/);
    await rpc(4,'closeCash',{counted:expectedBalance,expectedBalance,explanation:'',key:'close-1'});
    assert.equal(await rpc(4,'cashBalance'),0);
    await rpc(4,'openingCash',{amount:500,key:'open-1'});
    assert.equal(await rpc(4,'cashBalance'),500);
  });
  await check('Fidelidad, cumpleaños y precios históricos',async()=>{
    await rpc(4,'saveCatalog',{kind:'settings',data:{nombre:'Valhalla',meta_fidelidad:1}});
    const free=key=>({...sale(key),received:0,expectedTotal:0,lines:[{id:service,quantity:1,discount:0,benefit:'FIDELIDAD',reason:'',expectedUnitPrice:800}]});
    await rpc(4,'checkout',free('loyalty-free'));
    assert.equal(await rpc(3,'points',{client}),0);
    await assert.rejects(()=>rpc(4,'checkout',free('loyalty-twice')),/insuficientes/);
    await pg.query("UPDATE valhalla_private.cliente SET fecha_nacimiento=((now() AT TIME ZONE 'America/El_Salvador')::date-interval '25 years')::date WHERE id_cliente=$1",[client]);
    const birthday=key=>({...free(key),lines:[{...free(key).lines[0],benefit:'CUMPLEANOS'}]});
    await rpc(4,'checkout',birthday('birthday-free'));
    await assert.rejects(()=>rpc(4,'checkout',birthday('birthday-twice')),/cumpleaños/);
    await rpc(4,'servicePrice',{service,price:900});
    await assert.rejects(()=>rpc(4,'checkout',sale('stale-price')),/precio/);
    assert.equal((await rpc(4,'services'))[0].precio,900);
    assert.equal((await pg.query('SELECT precio_normal FROM valhalla_private.operacion_servicio ORDER BY id_operacion_servicio LIMIT 1')).rows[0].precio_normal,800);
  });
  await check('Consultas de todos los módulos y cancelación autorizada',async()=>{
    for(const action of ['clients','services','products','banks','barbers','branches','business','plans','operations','commissions','appointments','staff']){
      assert.notEqual(await rpc(4,action),undefined);
    }
    for(const kind of ['services','products','plans','banks','branches','commissions'])assert.ok(Array.isArray(await rpc(4,'catalog',{kind})));
    for(const kind of ['gasto','cuadre_caja','bitacora_auditoria','movimiento_inventario'])assert.ok(Array.isArray(await rpc(4,'records',{kind})));
    await rpc(3,'saveNote',{client,note:'Prefiere atención por la tarde.'});
    assert.equal((await rpc(3,'clientNotes',{client}))[0].autor,'Usuario whatsapp 3');
    const history=await rpc(3,'history',{client});
    assert.equal('total_cobrado' in history[0],false);
    const id=await rpc(3,'appointment',{client,barber:other,service,date:new Date(Date.now()+86400000).toISOString(),duration:30,key:'cancel-me'});
    await rpc(3,'cancelAppointment',{id});
    await assert.rejects(()=>rpc(5,'completeAppointment',{id}),/pendiente/);
  });
  await check('Roles no se falsifican; anónimos y escrituras directas rechazados',async()=>{
    await denied(()=>rpc(2,'staff',{profile:'administrador'}));
    await pg.exec('SET ROLE authenticated');
    try { await assert.rejects(()=>pg.exec('SELECT * FROM valhalla_private.usuario'),/permission denied/); }
    finally { await pg.exec('RESET ROLE'); }
    await pg.exec('SET ROLE anon');
    try { await assert.rejects(()=>pg.exec("SELECT public.valhalla_rpc('staff')"),/permission denied/); }
    finally { await pg.exec('RESET ROLE'); }
    const rls=(await pg.query("SELECT count(*)::int n FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='valhalla_private' AND c.relkind='r' AND NOT c.relrowsecurity")).rows[0].n;
    assert.equal(rls,0);
  });
  await check('Desactivar personal y cerrar sesiones revoca el acceso',async()=>{
    await rpc(4,'saveStaff',{id:barber,name:'Usuario barbero 2',email:'barbero2@example.test',profile:'barbero',active:false,branches:[1]});
    await denied(()=>rpc(2,'appointments'));
    await pg.query('DELETE FROM auth.sessions WHERE user_id=$1',[uuid(5)]);
    await denied(()=>rpc(5,'appointments'));
  });
  await check('Registrarse sin autorización o sin verificar correo no concede acceso',async()=>{
    await identity(6,'not-in-team@example.test');await denied(()=>rpc(6,'me'));
    await pg.query('UPDATE auth.users SET email_confirmed_at=NULL WHERE id=$1',[uuid(4)]);
    await assert.rejects(()=>rpc(4,'me'),/Confirma tu correo/);
    await assert.rejects(()=>rpc(1,'saveStaff',{id:1,name:'Admin',email:'milton.ramirez@catolica.edu.sv',profile:'barbero',active:true,branches:[1]}),/administrador activo/);
  });
  process.stdout.write(`RESULTADO: ${checks} grupos de pruebas PostgreSQL correctos.\n`);
} catch(e){ process.stderr.write(`${e.message}\n${e.where??''}\n`); process.exitCode=1; }
finally{await pg.close();}
