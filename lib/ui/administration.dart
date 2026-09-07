import 'package:flutter/material.dart';
import '../data/contracts.dart';
import '../data/api_client.dart';
import '../domain/models.dart';
import '../main.dart';
import 'components.dart';

const catalogKinds = [
  ('services', 'Servicios'),
  ('products', 'Productos'),
  ('plans', 'Planes de membresía'),
  ('branches', 'Sucursales'),
  ('commissions', 'Reglas de comisión'),
  ('banks', 'Bancos'),
];
const profileLabels = [
  (Profile.administrador, 'Administrador'),
  (Profile.encargado, 'Encargado'),
  (Profile.barbero, 'Barbero'),
  (Profile.whatsapp, 'Personal de WhatsApp'),
];
String profileLabel(Profile profile) =>
    profileLabels.firstWhere((p) => p.$1 == profile).$2;

class CatalogPage extends StatefulWidget {
  final ValhallaRepository repo;
  final String initialKind;
  final VoidCallback onSaved;
  const CatalogPage({
    super.key,
    required this.repo,
    required this.onSaved,
    this.initialKind = 'services',
  });
  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  late String kind;
  late Future<List<DbRow>> loading;
  @override
  void initState() {
    super.initState();
    kind = widget.initialKind;
    load();
  }

  void load() {
    loading = widget.repo.catalog(kind);
  }

  String description(DbRow r) => switch (kind) {
    'services' => '${r['categoria'] ?? ''} · ${money(numOf(r, 'precio'))}',
    'products' =>
      '${r['categoria'] ?? ''} · ${money(numOf(r, 'precio_venta_actual'))}',
    'plans' =>
      '${money(numOf(r, 'precio'))} · ${r['cantidad_servicios']} servicios · ${r['duracion_dias']} días',
    'commissions' =>
      '${r['servicio'] ?? 'Todos los servicios'} · ${r['tipo_calculo'] == 'PORCENTAJE' ? '${decimalMoney(numOf(r, 'valor'))}%' : money(numOf(r, 'valor'))}',
    'banks' => '${r['codigo']}',
    _ => 'Configuración de sucursal',
  };
  @override
  Widget build(BuildContext context) => spaced([
    PageTitle(
      'Catálogos',
      'Configura lo que tu equipo utiliza cada día.',
      action: FilledButton.icon(
        onPressed: () => runAction(context, () => edit()),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo registro'),
      ),
    ),
    ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: select<String>(
        label: 'Catálogo',
        value: kind,
        options: catalogKinds,
        change: (v) => setState(() {
          kind = v;
          load();
        }),
      ),
    ),
    RowsView(
      future: loading,
      builder: (rows) => rows.isEmpty
          ? const EmptyState(
              'Todavía no hay registros',
              'Agrega el primer registro para comenzar a utilizar este catálogo.',
            )
          : spaced([
              for (final row in rows)
                Panel(
                  child: ResponsiveListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${row['nombre']}'),
                    subtitle: Text(
                      '${description(row)}\n${row['activo'] == 1 ? 'Activo' : 'Inactivo'}',
                    ),
                    trailing: kind == 'commissions'
                        ? null
                        : IconButton(
                            onPressed: () =>
                                runAction(context, () => edit(row)),
                            tooltip: 'Editar registro',
                            icon: const Icon(Icons.edit_outlined),
                          ),
                  ),
                ),
            ]),
    ),
    if (kind == 'commissions')
      const Text(
        'Cada nueva regla conserva los cálculos anteriores y reemplaza la regla vigente de su mismo alcance.',
      ),
  ]);
  Future<void> edit([DbRow? row]) async {
    final editingKind = kind;
    final services = ['plans', 'commissions'].contains(kind)
        ? await widget.repo.catalog('services')
        : <DbRow>[];
    if (!mounted) return;
    final controllers = <String, TextEditingController>{};
    TextEditingController field(String key, [String initial = '']) =>
        controllers.putIfAbsent(
          key,
          () => TextEditingController(text: initial),
        );
    field('nombre', '${row?['nombre'] ?? ''}');
    field('categoria', '${row?['categoria'] ?? ''}');
    field('codigo', '${row?['codigo'] ?? ''}');
    field(
      'precio',
      row == null
          ? ''
          : decimalMoney(
              numOf(row, kind == 'products' ? 'precio_venta_actual' : 'precio'),
            ),
    );
    field('cantidad_servicios', '${row?['cantidad_servicios'] ?? 4}');
    field('duracion_dias', '${row?['duracion_dias'] ?? 30}');
    field(
      'stock_minimo',
      '${row == null ? 0 : numOf(row, 'stock_minimo') ~/ 1000}',
    );
    field('valor', '');
    var active = row?['activo'] != 0,
        loyalty = row?['elegible_fidelidad'] == 1,
        birthday = row?['elegible_cumpleanos'] == 1;
    var calculation = 'PORCENTAJE', service = 0;
    final included = ('${row?['servicios_ids'] ?? ''}')
        .split(',')
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
    Widget input(String key, String label, {bool numeric = false}) => TextField(
      controller: field(key),
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(labelText: label),
    );
    final ok = await editor(
      context,
      title: row == null
          ? 'Agregar ${catalogKinds.firstWhere((k) => k.$1 == editingKind).$2.toLowerCase()}'
          : 'Editar ${row['nombre']}',
      fields: (c, s) => spaced([
        input('nombre', 'Nombre'),
        if (['services', 'products'].contains(editingKind))
          input('categoria', 'Categoría'),
        if (['services', 'products', 'plans'].contains(editingKind))
          input('precio', 'Precio (USD)', numeric: true),
        if (editingKind == 'services') ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Acumula visitas de fidelidad'),
            value: loyalty,
            onChanged: (v) => s(() => loyalty = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Permite beneficio de cumpleaños'),
            value: birthday,
            onChanged: (v) => s(() => birthday = v),
          ),
        ],
        if (editingKind == 'products')
          input('stock_minimo', 'Stock mínimo en esta sucursal', numeric: true),
        if (['plans', 'banks'].contains(editingKind)) input('codigo', 'Código'),
        if (editingKind == 'plans') ...[
          input('cantidad_servicios', 'Servicios incluidos', numeric: true),
          input('duracion_dias', 'Duración en días', numeric: true),
          const Text('Servicios que cubre el plan'),
          for (final service in services.where((r) => r['activo'] == 1))
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${service['nombre']}'),
              value: included.contains(service['id_servicio']),
              onChanged: (v) => s(() {
                if (v == true) {
                  included.add(numOf(service, 'id_servicio'));
                } else {
                  included.remove(service['id_servicio']);
                }
              }),
            ),
        ],
        if (editingKind == 'commissions') ...[
          select<int>(
            label: 'Aplicar a',
            value: service,
            options: [
              (0, 'Todos los servicios'),
              for (final r in services.where((r) => r['activo'] == 1))
                (numOf(r, 'id_servicio'), '${r['nombre']}'),
            ],
            change: (v) => s(() => service = v),
          ),
          select<String>(
            label: 'Tipo de cálculo',
            value: calculation,
            options: const [
              ('PORCENTAJE', 'Porcentaje'),
              ('FIJO', 'Monto fijo por servicio'),
            ],
            change: (v) => s(() => calculation = v),
          ),
          input(
            'valor',
            calculation == 'PORCENTAJE' ? 'Porcentaje (%)' : 'Comisión (USD)',
            numeric: true,
          ),
        ],
        if (editingKind != 'commissions')
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Activo'),
            value: active,
            onChanged: (v) => s(() => active = v),
          ),
      ]),
      save: () async {
        const ids = {
          'services': 'id_servicio',
          'products': 'id_producto',
          'plans': 'id_plan_membresia',
          'branches': 'id_sucursal',
          'banks': 'id_banco',
        };
        int whole(String key) =>
            int.tryParse(field(key).text.trim()) ??
            (throw const RuleError('Escribe cantidades enteras válidas.'));
        await widget.repo.saveCatalog(editingKind, {
          if (row != null) 'id': row[ids[editingKind]],
          'nombre': field('nombre').text,
          'activo': active ? 1 : 0,
          if (['services', 'products'].contains(editingKind))
            'categoria': field('categoria').text,
          if (['services', 'products', 'plans'].contains(editingKind))
            'precio': parseMoney(field('precio').text),
          if (editingKind == 'services') ...{
            'elegible_fidelidad': loyalty ? 1 : 0,
            'elegible_cumpleanos': birthday ? 1 : 0,
          },
          if (editingKind == 'products') 'stock_minimo': whole('stock_minimo'),
          if (['plans', 'banks'].contains(editingKind))
            'codigo': field('codigo').text,
          if (editingKind == 'plans') ...{
            'cantidad_servicios': whole('cantidad_servicios'),
            'duracion_dias': whole('duracion_dias'),
            'servicios': included.toList()..sort(),
          },
          if (editingKind == 'commissions') ...{
            'tipo_calculo': calculation,
            'valor': parseMoney(field('valor').text),
            'id_servicio': service == 0 ? null : service,
          },
        });
      },
    );
    for (final controller in controllers.values) {
      controller.dispose();
    }
    if (ok == true && mounted) {
      setState(load);
      widget.onSaved();
    }
  }
}

class StaffPage extends StatefulWidget {
  final ApiClient client;
  final ValhallaRepository repo;
  const StaffPage({super.key, required this.client, required this.repo});
  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> {
  late Future<List<DbRow>> loading;
  @override
  void initState() {
    super.initState();
    loading = widget.client.staff();
  }

  @override
  Widget build(BuildContext context) => spaced([
    PageTitle(
      'Tu equipo',
      'Cuentas, responsabilidades y sucursales asignadas.',
      action: FilledButton.icon(
        onPressed: () => runAction(context, () => edit()),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Agregar usuario'),
      ),
    ),
    RowsView(
      future: loading,
      builder: (rows) => spaced([
        for (final r in rows)
          Panel(
            child: ResponsiveListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: paper,
                child: Text('${r['nombre_completo']}'.substring(0, 1)),
              ),
              title: Text('${r['nombre_completo']}'),
              subtitle: Text(
                '${r['correo'] ?? 'Sin acceso habilitado'}\n${profileLabel(Profile.values.byName(r['rol'] as String))} · ${r['activo'] == 1 ? 'Activo' : 'Inactivo'}',
              ),
              trailing: IconButton(
                onPressed: () => runAction(context, () => edit(r)),
                tooltip: 'Editar usuario',
                icon: const Icon(Icons.edit_outlined),
              ),
            ),
          ),
      ]),
    ),
  ]);
  Future<void> edit([DbRow? row]) async {
    final branches = (await widget.repo.catalog(
      'branches',
    )).where((b) => b['activo'] == 1).toList();
    if (!mounted) return;
    final name = TextEditingController(
          text: row?['nombre_completo'] as String? ?? '',
        ),
        email = TextEditingController(text: row?['correo'] as String? ?? '');
    var profile = Profile.values.byName(row?['rol'] as String? ?? 'barbero'),
        active = row?['activo'] != 0;
    final assigned = ('${row?['sucursales_ids'] ?? widget.repo.branch}')
        .split(',')
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
    final own = row?['id_usuario'] == widget.repo.session.userId;
    final ok = await editor(
      context,
      title: row == null ? 'Agregar usuario' : 'Editar usuario',
      fields: (c, s) => spaced([
        TextField(
          controller: name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nombre completo'),
        ),
        TextField(
          controller: email,
          autocorrect: false,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Correo electrónico'),
        ),
        const Text(
          'El usuario elige su contraseña desde «Activar mi cuenta» en el acceso. Para recuperarla utiliza «Olvidé mi contraseña».',
        ),
        select<Profile>(
          label: 'Rol',
          value: profile,
          options: profileLabels,
          change: (v) => s(() => profile = v),
        ),
        const Text('Sucursales autorizadas'),
        for (final branch in branches)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${branch['nombre']}'),
            value: assigned.contains(branch['id_sucursal']),
            onChanged: (v) => s(() {
              if (v == true) {
                assigned.add(numOf(branch, 'id_sucursal'));
              } else {
                assigned.remove(branch['id_sucursal']);
              }
            }),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Cuenta activa'),
          value: active,
          onChanged: (v) => s(() => active = v),
        ),
        if (own)
          const Text(
            'Al modificar tu cuenta deberás iniciar sesión nuevamente.',
          ),
      ]),
      save: () async {
        await widget.client.saveStaff({
          'id': row?['id_usuario'],
          'name': name.text,
          'email': email.text,
          'profile': profile.name,
          'active': active,
          'branches': assigned.toList()..sort(),
        });
      },
    );
    name.dispose();
    email.dispose();
    if (ok == true && mounted) {
      setState(() {
        loading = widget.client.staff();
      });
    }
  }
}

class SettingsPage extends StatelessWidget {
  final ValhallaRepository repo;
  final VoidCallback onSaved;
  const SettingsPage({super.key, required this.repo, required this.onSaved});
  @override
  Widget build(BuildContext context) => spaced([
    const PageTitle('Configuración', 'Reglas generales de Valhalla.'),
    RowsView(
      future: repo.business().then((r) => [r]),
      builder: (rows) {
        final row = rows.single;
        return Panel(
          child: spaced([
            Text(
              '${row['nombre']}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              'Un beneficio por cada ${row['meta_fidelidad']} visitas elegibles.',
            ),
            const Text(
              'Solo acumulan visitas los servicios pagados que marques como elegibles. El canje cubre una unidad y conserva las demás líneas de la atención.',
            ),
            OutlinedButton.icon(
              onPressed: () => edit(context, row),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar configuración'),
            ),
          ]),
        );
      },
    ),
  ]);
  Future<void> edit(BuildContext context, DbRow row) async {
    final name = TextEditingController(text: row['nombre'] as String),
        goal = TextEditingController(text: '${row['meta_fidelidad']}');
    final ok = await editor(
      context,
      title: 'Configuración del negocio',
      fields: (c, s) => spaced([
        TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Nombre del negocio'),
        ),
        TextField(
          controller: goal,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Visitas para un beneficio',
          ),
        ),
        const Text(
          'La nueva meta se aplica a los saldos de visitas actuales; los canjes ya registrados se conservan.',
        ),
      ]),
      save: () async {
        await repo.saveCatalog('settings', {
          'nombre': name.text,
          'meta_fidelidad': int.tryParse(goal.text),
        });
      },
    );
    name.dispose();
    goal.dispose();
    if (ok == true) onSaved();
  }
}

class ClientNotes extends StatefulWidget {
  final ValhallaRepository repo;
  final int client;
  const ClientNotes({super.key, required this.repo, required this.client});
  @override
  State<ClientNotes> createState() => _ClientNotesState();
}

class _ClientNotesState extends State<ClientNotes> {
  late Future<List<DbRow>> loading;
  @override
  void initState() {
    super.initState();
    loading = widget.repo.clientNotes(widget.client);
  }

  Future<void> add() async {
    final text = TextEditingController();
    final ok = await editor(
      context,
      title: 'Nota de atención',
      fields: (c, s) => TextField(
        controller: text,
        maxLines: 4,
        maxLength: 1000,
        decoration: const InputDecoration(labelText: 'Nota'),
      ),
      save: () => widget.repo.saveNote(widget.client, text.text),
    );
    text.dispose();
    if (ok == true && mounted) {
      setState(() {
        loading = widget.repo.clientNotes(widget.client);
      });
    }
  }

  @override
  Widget build(BuildContext context) => spaced([
    OutlinedButton.icon(
      onPressed: add,
      icon: const Icon(Icons.note_add_outlined),
      label: const Text('Agregar nota de atención'),
    ),
    RowsView(
      future: loading,
      builder: (rows) => spaced([
        for (final r in rows)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${r['texto']}'),
              const SizedBox(height: 4),
              Text(
                '${r['autor']} · ${dateLabel(r['created_at'])}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF73776F)),
              ),
              const Divider(),
            ],
          ),
      ]),
    ),
  ]);
}
