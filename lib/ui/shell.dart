import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/contracts.dart';
import '../domain/models.dart';
import '../main.dart';
import 'components.dart';
import 'checkout_page.dart';
import 'administration.dart';
import 'access.dart';
import '../data/api_repository.dart';

const destinations = [
  ('Resumen', Icons.space_dashboard_outlined),
  ('Nuevo cobro', Icons.point_of_sale),
  ('Clientes', Icons.people_outline),
  ('Operaciones', Icons.receipt_long_outlined),
  ('Membresías', Icons.workspace_premium_outlined),
  ('Inventario', Icons.inventory_2_outlined),
  ('Servicios', Icons.content_cut),
  ('Gastos', Icons.payments_outlined),
  ('Caja', Icons.account_balance_wallet_outlined),
  ('Comisiones', Icons.pie_chart_outline),
  ('Agenda', Icons.calendar_month_outlined),
  ('Auditoría', Icons.history),
  ('Catálogos', Icons.tune),
  ('Equipo', Icons.badge_outlined),
  ('Configuración', Icons.settings_outlined),
  ('Mi cuenta', Icons.person_outline),
];

class ValhallaShell extends StatefulWidget {
  final ValhallaRepository initial;
  final Future<void> Function()? onLogout;
  final VoidCallback? onPasswordChanged;
  const ValhallaShell({
    super.key,
    required this.initial,
    this.onLogout,
    this.onPasswordChanged,
  });
  @override
  State<ValhallaShell> createState() => _ValhallaShellState();
}

class _ValhallaShellState extends State<ValhallaShell> {
  late ValhallaRepository repo;
  int page = 0, revision = 0, selectorRevision = 0;
  var checkoutKey = GlobalKey<CheckoutPageState>();
  bool leaving = false;
  List<DbRow> sessionBranches = [];
  String? contextError;
  String catalogKind = 'services';
  @override
  void initState() {
    super.initState();
    repo = widget.initial;
    if (!allowed.contains(page)) page = allowed.first;
    loadContext();
  }

  void refresh() {
    if (page == 1 && checkoutKey.currentState != null) {
      checkoutKey.currentState!.reloadCatalog();
      return;
    }
    if (mounted) setState(() => revision++);
  }

  Future<void> loadContext() async {
    try {
      final values = await repo.branches();
      if (mounted) {
        setState(() {
          sessionBranches = values;
          contextError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => contextError = e is RuleError
              ? e.message
              : 'No se pudieron cargar las sucursales.',
        );
      }
    }
  }

  void openCatalog(String kind) {
    catalogKind = kind;
    navigate(12);
  }

  Future<void> signOut() async {
    if (!await leaveDraft() || !mounted) return;
    await widget.onLogout?.call();
  }

  List<int> get allowed => switch (repo.session.profile) {
    Profile.whatsapp => [2, 6, 10, 15],
    Profile.barbero => [10, 9, 15],
    Profile.encargado => List.generate(destinations.length, (i) => i),
    Profile.administrador => List.generate(destinations.length, (i) => i),
  };
  Future<bool> leaveDraft() async {
    if (leaving) return false;
    leaving = true;
    try {
      return await checkoutKey.currentState?.canLeave() ?? true;
    } finally {
      leaving = false;
    }
  }

  Future<void> navigate(int target, {bool drawer = false}) async {
    if (target == page) {
      if (drawer) Navigator.pop(context);
      return;
    }
    if (!await leaveDraft() || !mounted) return;
    if (drawer) Navigator.pop(context);
    setState(() {
      checkoutKey = GlobalKey<CheckoutPageState>();
      page = target;
    });
  }

  Future<void> changeBranch(int branch) async {
    if (!await leaveDraft()) {
      if (mounted) setState(() => selectorRevision++);
      return;
    }
    if (!mounted) return;
    setState(() {
      checkoutKey = GlobalKey<CheckoutPageState>();
      repo = repo.withSession(repo.session.atBranch(branch));
      if (!allowed.contains(page)) page = allowed.first;
      revision++;
    });
  }

  Widget navigation(bool desktop) => SizedBox(
    width: 248,
    child: Material(
      color: const Color(0xFF191D19),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(26, 32, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'V /',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w300,
                      color: gold,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'VALHALLA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      letterSpacing: 4,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'BARBERÍA · GESTIÓN',
                    style: TextStyle(
                      color: Color(0xFFADB3A8),
                      fontSize: 10,
                      letterSpacing: 1.8,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final i in allowed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        selected: page == i,
                        selectedTileColor: gold,
                        selectedColor: ink,
                        textColor: const Color(0xFFC8CDC4),
                        iconColor: const Color(0xFFC8CDC4),
                        leading: Icon(destinations[i].$2, size: 20),
                        title: Text(
                          destinations[i].$1,
                          style: const TextStyle(fontSize: 14),
                        ),
                        onTap: () {
                          navigate(i, drawer: !desktop);
                        },
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    repo.session.name.isEmpty
                        ? profileLabel(repo.session.profile)
                        : repo.session.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profileLabel(repo.session.profile),
                    style: const TextStyle(
                      color: Color(0xFFADB3A8),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: signOut,
                    style: TextButton.styleFrom(
                      foregroundColor: gold,
                      alignment: Alignment.centerLeft,
                    ),
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Cerrar sesión'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final desktop = constraints.maxWidth >= 1000;
      return Scaffold(
        drawer: desktop ? null : Drawer(child: navigation(false)),
        appBar: desktop
            ? null
            : AppBar(
                title: const Text(
                  'VALHALLA',
                  style: TextStyle(fontSize: 17, letterSpacing: 3),
                ),
                actions: [
                  IconButton(
                    onPressed: refresh,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Actualizar',
                  ),
                ],
              ),
        body: Row(
          children: [
            if (desktop) navigation(true),
            Expanded(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: desktop ? 32 : 16,
                      vertical: 14,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFDFE2D9)),
                      ),
                    ),
                    child: Wrap(
                      spacing: desktop ? 16 : 12,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: desktop ? 160 : 136,
                          child: select<int>(
                            label: 'Sucursal',
                            fieldKey: ValueKey(
                              'sucursal-${repo.branch}-$selectorRevision',
                            ),
                            value: repo.branch,
                            options: sessionBranches.isEmpty
                                ? [(repo.branch, 'Sucursal')]
                                : [
                                    for (final row in sessionBranches)
                                      (
                                        numOf(row, 'id_sucursal'),
                                        '${row['nombre']}',
                                      ),
                                  ],
                            change: changeBranch,
                          ),
                        ),
                        SizedBox(
                          width: desktop ? 260 : 176,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                repo.session.name.isEmpty
                                    ? 'Mi cuenta'
                                    : repo.session.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                profileLabel(repo.session.profile),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF73776F),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (desktop)
                          IconButton(
                            onPressed: () {
                              refresh();
                              loadContext();
                            },
                            icon: const Icon(Icons.refresh),
                            tooltip: 'Actualizar',
                          ),
                        if (contextError != null)
                          TextButton.icon(
                            onPressed: loadContext,
                            icon: const Icon(Icons.wifi_off, size: 18),
                            label: const Text('Reintentar conexión'),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      key: ValueKey('scroll-${repo.branch}-$page'),
                      padding: EdgeInsets.all(desktop ? 32 : 16),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1440),
                          child: KeyedSubtree(
                            key: ValueKey(
                              '${repo.branch}-${repo.session.profile}-$revision-$page',
                            ),
                            child: content(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
  Widget content() => switch (page) {
    0 => dashboard(),
    1 => CheckoutPage(
      key: checkoutKey,
      repo: repo,
      onSaved: () {
        setState(() {
          page = 3;
          revision++;
        });
      },
    ),
    2 => clients(),
    3 => operations(),
    4 => memberships(),
    5 => inventory(),
    6 => services(),
    7 => expenses(),
    8 => cash(),
    9 => commissions(),
    10 => appointments(),
    11 => audit(),
    12 => CatalogPage(
      repo: repo,
      initialKind: catalogKind,
      onSaved: loadContext,
    ),
    13 =>
      repo is ApiRepository
          ? StaffPage(client: (repo as ApiRepository).client, repo: repo)
          : const EmptyState(
              'Equipo',
              'Conecta una cuenta para administrar los accesos.',
            ),
    14 => SettingsPage(repo: repo, onSaved: refresh),
    _ => account(),
  };
  Widget account() => spaced([
    PageTitle(
      repo.session.name.isEmpty ? 'Mi cuenta' : repo.session.name,
      repo.session.email,
    ),
    Text(
      '${profileLabel(repo.session.profile)} · ${sessionBranches.map((b) => b['nombre']).join(' / ')}',
    ),
    if (repo is ApiRepository)
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Panel(
          child: PasswordChange(
            client: (repo as ApiRepository).client,
            onChanged: widget.onPasswordChanged ?? () {},
          ),
        ),
      ),
  ]);
  Widget dashboard() => spaced([
    const PageTitle('Cada detalle cuenta.', 'Tu barbería, en una sola vista.'),
    if (repo.session.manages)
      RowsView(
        future: Future.wait([repo.barbers(), repo.services(), repo.clients()])
            .then(
              (values) => [
                {
                  'equipo': values[0].isNotEmpty,
                  'servicios': values[1].isNotEmpty,
                  'clientes': values[2].isNotEmpty,
                },
              ],
            ),
        builder: (rows) {
          final ready = rows.single;
          if (ready.values.every((value) => value == true)) {
            return const SizedBox.shrink();
          }
          return Panel(
            child: spaced([
              const Text(
                'Prepara tu primera atención',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
              ),
              const Text(
                'Registra el equipo y los servicios que ofrece esta sucursal para comenzar a cobrar.',
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (ready['equipo'] != true)
                    OutlinedButton.icon(
                      onPressed: () => navigate(13),
                      icon: const Icon(Icons.person_add_outlined),
                      label: const Text('Agregar barbero'),
                    ),
                  if (ready['servicios'] != true)
                    OutlinedButton.icon(
                      onPressed: () => openCatalog('services'),
                      icon: const Icon(Icons.content_cut),
                      label: const Text('Configurar servicios'),
                    ),
                  if (ready['clientes'] != true)
                    OutlinedButton.icon(
                      onPressed: () => navigate(2),
                      icon: const Icon(Icons.people_outline),
                      label: const Text('Registrar cliente'),
                    ),
                ],
              ),
            ]),
          );
        },
      ),
    RowsView(
      future: repo.operations(),
      builder: (rows) {
        final today = businessDate(DateTime.now());
        final daily = rows.where((r) {
          final d = businessDate(DateTime.parse(r['fecha_hora'] as String));
          return d.year == today.year &&
              d.month == today.month &&
              d.day == today.day;
        }).toList();
        return spaced([
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              Metric(
                'Ingresos de hoy',
                money(
                  daily.fold(0, (sum, r) => sum + numOf(r, 'total_cobrado')),
                ),
                Icons.trending_up,
              ),
              Metric(
                'Operaciones de hoy',
                '${daily.length}',
                Icons.receipt_long,
              ),
              Metric(
                'Clientes atendidos',
                '${daily.map((r) => r['id_cliente']).toSet().length}',
                Icons.people_outline,
              ),
            ],
          ),
          Panel(
            child: Wrap(
              spacing: 20,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const SizedBox(
                  width: 300,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Listos para el siguiente cliente',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Servicios, productos y beneficios en un solo cobro.',
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => navigate(1),
                  icon: const Icon(Icons.add),
                  label: const Text('Registrar atención'),
                ),
              ],
            ),
          ),
          const Text(
            'Últimas operaciones',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
          ),
          operationList(rows.take(5).toList()),
        ]);
      },
    ),
    if (repo.session.manages)
      RowsView(
        future: repo.products(),
        builder: (rows) {
          final low = rows
              .where(
                (r) => numOf(r, 'stock_actual') <= numOf(r, 'stock_minimo'),
              )
              .toList();
          return Panel(
            child: ResponsiveListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                low.isEmpty ? Icons.check_circle_outline : Icons.warning_amber,
                color: forest,
              ),
              title: Text(
                rows.isEmpty
                    ? 'Agrega tus productos'
                    : low.isEmpty
                    ? 'Inventario en orden'
                    : '${low.length} productos bajo el mínimo',
              ),
              subtitle: Text(
                rows.isEmpty
                    ? 'Configura los productos y registra sus existencias.'
                    : low.isEmpty
                    ? 'Todas las existencias superan su mínimo.'
                    : low.map((r) => r['nombre']).join(', '),
              ),
              trailing: TextButton(
                onPressed: () => setState(() => page = 5),
                child: const Text('Ver inventario'),
              ),
            ),
          );
        },
      ),
  ]);
  Widget operationList(List<DbRow> rows) => rows.isEmpty
      ? const EmptyState(
          'Todavía no hay cobros',
          'Registra una atención para comenzar.',
        )
      : Panel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final row in rows)
                ResponsiveListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: paper,
                    child: Text(
                      '#${row['id_operacion']}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  title: Text('${row['nombre_completo']}'),
                  subtitle: Text(
                    '${dateLabel(row['fecha_hora'])}\n${row['observaciones'] ?? row['barbero'] ?? 'Venta'}',
                  ),
                  isThreeLine: true,
                  trailing: Text(
                    money(numOf(row, 'total_cobrado')),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onTap: () => receipt(numOf(row, 'id_operacion')),
                ),
            ],
          ),
        );
  Widget operations() => spaced([
    const PageTitle('Operaciones', 'Cobros guardados y comprobantes.'),
    RowsView(future: repo.operations(), builder: operationList),
  ]);
  Future<void> receipt(int id) async {
    Receipt data;
    try {
      data = await repo.receipt(id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
      return;
    }
    final op = data.operation, lines = data.lines, pay = data.payment;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Comprobante #$id'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: spaced([
              Text(dateLabel(op['fecha_hora'])),
              for (final l in lines)
                Row(
                  children: [
                    Expanded(child: Text('${l['cantidad']} × ${l['nombre']}')),
                    Text(money(numOf(l, 'total'))),
                  ],
                ),
              if (lines.isEmpty) Text('${op['observaciones']}'),
              const Divider(),
              Text('Bruto: ${money(numOf(op, 'total_bruto'))}'),
              Text(
                'Beneficios y descuentos: ${money(numOf(op, 'total_descuentos'))}',
              ),
              Text(
                'TOTAL ${money(numOf(op, 'total_cobrado'))}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                pay['metodo'] == 'EFECTIVO'
                    ? 'Efectivo: ${money(numOf(pay, 'efectivo_recibido'))}\nCambio: ${money(numOf(pay, 'cambio'))}'
                    : 'Transferencia · ${pay['referencia_transferencia']}',
              ),
              const Text(
                'Comprobante de atención',
                style: TextStyle(fontSize: 12),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget clients() => ClientList(repo: repo, refresh: refresh);
  Widget inventory() => spaced([
    PageTitle(
      'Inventario',
      'Existencias por sucursal y movimientos trazables.',
      action: repo.session.manages
          ? FilledButton.icon(
              onPressed: () => openCatalog('products'),
              icon: const Icon(Icons.add),
              label: const Text('Administrar productos'),
            )
          : null,
    ),
    RowsView(
      future: repo.products(),
      builder: (rows) => spaced([
        for (final r in rows)
          Panel(
            child: ResponsiveListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: paper,
                child: Icon(Icons.inventory_2_outlined, color: forest),
              ),
              title: Text('${r['nombre']}'),
              subtitle: Text(
                '${money(numOf(r, 'precio_venta_actual'))} · Mínimo ${numOf(r, 'stock_minimo') ~/ 1000}',
              ),
              trailing: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                children: [
                  Text(
                    '${numOf(r, 'stock_actual') ~/ 1000} uds.',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color:
                          numOf(r, 'stock_actual') <= numOf(r, 'stock_minimo')
                          ? Colors.red
                          : forest,
                    ),
                  ),
                  IconButton(
                    onPressed: () => runAction(context, () => stockDialog(r)),
                    tooltip: 'Registrar movimiento',
                    icon: const Icon(Icons.swap_horiz),
                  ),
                ],
              ),
            ),
          ),
      ]),
    ),
    const Text(
      'Últimos movimientos',
      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
    ),
    RowsView(
      future: repo.records('movimiento_inventario'),
      builder: (rows) => recordsList(
        rows,
        (r) => '${r['tipo_movimiento']} · ${numOf(r, 'cantidad') ~/ 1000} uds.',
        (r) => 'Producto #${r['id_producto']} · ${r['observacion'] ?? ''}',
      ),
    ),
  ]);
  Future<void> stockDialog(DbRow row) async {
    final qty = TextEditingController(text: '1'),
        note = TextEditingController();
    var type = 'ENTRADA';
    final available = (await repo.branches())
        .where((r) => r['id_sucursal'] != repo.branch)
        .toList();
    if (!mounted) return;
    var destination = available.isEmpty
        ? 0
        : numOf(available.first, 'id_sucursal');
    final requestKey = const Uuid().v4();
    final ok = await editor(
      context,
      title: 'Mover ${row['nombre']}',
      fields: (context, update) => spaced([
        select<String>(
          label: 'Movimiento',
          value: type,
          options: const [
            ('ENTRADA', 'Entrada de inventario'),
            ('CONSUMO_INTERNO', 'Consumo interno'),
            ('TRASLADO', 'Trasladar a una sucursal'),
          ],
          change: (v) => update(() => type = v),
        ),
        if (type == 'TRASLADO' && available.isNotEmpty)
          select<int>(
            label: 'Sucursal de destino',
            value: destination,
            options: [
              for (final row in available)
                (numOf(row, 'id_sucursal'), '${row['nombre']}'),
            ],
            change: (v) => update(() => destination = v),
          ),
        if (type == 'TRASLADO' && available.isEmpty)
          const Text('No tienes otra sucursal autorizada para trasladar.'),
        TextField(
          controller: qty,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Unidades enteras'),
        ),
        TextField(
          controller: note,
          decoration: const InputDecoration(labelText: 'Motivo'),
        ),
      ]),
      save: () async => repo.adjustStock(
        numOf(row, 'id_producto'),
        int.tryParse(qty.text) ?? 0,
        type,
        note.text,
        key: requestKey,
        destination: destination,
      ),
    );
    qty.dispose();
    note.dispose();
    if (ok == true) refresh();
  }

  Widget services() => spaced([
    PageTitle(
      'Servicios',
      'Precios vigentes e historial conservado en cada cobro.',
      action: repo.session.manages
          ? FilledButton.icon(
              onPressed: () => openCatalog('services'),
              icon: const Icon(Icons.add),
              label: const Text('Administrar servicios'),
            )
          : null,
    ),
    RowsView(
      future: repo.services(),
      builder: (rows) => spaced([
        for (final r in rows)
          Panel(
            child: ResponsiveListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: paper,
                child: Icon(Icons.content_cut, color: forest),
              ),
              title: Text('${r['nombre']}'),
              subtitle: Text(
                numOf(r, 'elegible_fidelidad') == 1
                    ? 'Elegible para fidelidad y cumpleaños'
                    : '${r['categoria']}',
              ),
              trailing: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    money(numOf(r, 'precio')),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (repo.session.manages)
                    IconButton(
                      onPressed: () => priceDialog(r),
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Cambiar precio',
                    ),
                ],
              ),
            ),
          ),
      ]),
    ),
  ]);
  Future<void> priceDialog(DbRow r) async {
    final price = TextEditingController(text: decimalMoney(numOf(r, 'precio')));
    final ok = await editor(
      context,
      title: 'Precio de ${r['nombre']}',
      fields: (c, s) => TextField(
        controller: price,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Nuevo precio (USD)'),
      ),
      save: () =>
          repo.servicePrice(numOf(r, 'id_servicio'), parseMoney(price.text)),
    );
    price.dispose();
    if (ok == true) refresh();
  }

  Widget recordsList(
    List<DbRow> rows,
    String Function(DbRow) title,
    String Function(DbRow) subtitle,
  ) => rows.isEmpty
      ? const EmptyState(
          'Sin registros',
          'Los movimientos aparecerán aquí al guardarlos.',
        )
      : Panel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final r in rows)
                ResponsiveListTile(
                  title: Text(title(r)),
                  subtitle: Text(
                    '${subtitle(r)}\n${dateLabel(r['fecha_hora'] ?? r['fecha_hora_cierre'])}',
                  ),
                  isThreeLine: true,
                ),
            ],
          ),
        );
  Widget expenses() => spaced([
    PageTitle(
      'Gastos',
      'Egresos de efectivo o banco.',
      action: FilledButton.icon(
        onPressed: () => runAction(context, expenseDialog),
        icon: const Icon(Icons.add),
        label: const Text('Registrar gasto'),
      ),
    ),
    RowsView(
      future: repo.records('gasto'),
      builder: (rows) => recordsList(
        rows,
        (r) => '${r['descripcion']} · ${money(numOf(r, 'monto'))}',
        (r) =>
            '${r['categoria']} · ${numOf(r, 'id_metodo_pago') == 1 ? 'Efectivo' : 'Transferencia'}',
      ),
    ),
  ]);
  Future<void> expenseDialog() async {
    final desc = TextEditingController(),
        amount = TextEditingController(),
        cat = TextEditingController(text: 'Operación');
    var transfer = false, bank = 1;
    final requestKey = const Uuid().v4(), banks = await repo.banks();
    if (!mounted) return;
    bank = banks.isEmpty ? 0 : numOf(banks.first, 'id_banco');
    final ok = await editor(
      context,
      title: 'Registrar gasto',
      fields: (c, s) => spaced([
        TextField(
          controller: desc,
          decoration: const InputDecoration(labelText: 'Descripción'),
        ),
        TextField(
          controller: cat,
          decoration: const InputDecoration(labelText: 'Categoría'),
        ),
        TextField(
          controller: amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Monto (USD)'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Pagar por transferencia'),
          value: transfer,
          onChanged: (v) => s(() => transfer = v),
        ),
        if (transfer)
          select<int>(
            label: 'Banco',
            value: bank,
            options: banks
                .map((b) => (numOf(b, 'id_banco'), '${b['nombre']}'))
                .toList(),
            change: (v) => s(() => bank = v),
          ),
      ]),
      save: () => repo.expense(
        desc.text,
        cat.text,
        parseMoney(amount.text),
        transfer: transfer,
        bank: bank,
        key: requestKey,
      ),
    );
    desc.dispose();
    amount.dispose();
    cat.dispose();
    if (ok == true) refresh();
  }

  Widget cash() => spaced([
    const PageTitle('Caja', 'Efectivo pendiente de cierre de esta sucursal.'),
    FutureBuilder<int>(
      future: repo.cashBalance(),
      builder: (c, s) => Panel(
        child: spaced([
          const Text(
            'EFECTIVO ESPERADO',
            style: TextStyle(letterSpacing: 1.5, color: forest),
          ),
          Text(
            s.hasData ? money(s.data!) : '…',
            style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w500),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: () => runAction(context, () => cashDialog(false)),
                icon: const Icon(Icons.add),
                label: const Text('Fondo de apertura'),
              ),
              FilledButton.icon(
                onPressed: () => runAction(context, () => cashDialog(true)),
                icon: const Icon(Icons.lock_outline),
                label: const Text('Realizar cierre'),
              ),
            ],
          ),
          const Text(
            'Al cerrar, se retira el efectivo del período. Registra el fondo de apertura del siguiente turno. No se arrastra automáticamente.',
          ),
        ]),
      ),
    ),
    const Text(
      'Cierres anteriores',
      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
    ),
    RowsView(
      future: repo.records('cuadre_caja'),
      builder: (rows) => recordsList(
        rows,
        (r) =>
            'Cierre #${r['id_cuadre_caja']} · ${money(numOf(r, 'efectivo_contado'))}',
        (r) =>
            'Esperado ${money(numOf(r, 'efectivo_esperado'))} · Diferencia ${money(numOf(r, 'diferencia'))}',
      ),
    ),
  ]);
  Future<void> cashDialog(bool closing) async {
    final expected = await repo.cashBalance();
    if (!mounted) return;
    final amount = TextEditingController(),
        reason = TextEditingController(),
        key = const Uuid().v4();
    final ok = await editor(
      context,
      title: closing ? 'Cerrar caja' : 'Fondo de apertura',
      button: closing ? 'Confirmar cierre' : 'Registrar fondo',
      fields: (c, s) => spaced([
        TextField(
          controller: amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: closing
                ? 'Efectivo contado (USD)'
                : 'Fondo inicial (USD)',
          ),
        ),
        if (closing)
          TextField(
            controller: reason,
            decoration: const InputDecoration(
              labelText: 'Explicación de diferencia, si existe',
            ),
          ),
      ]),
      save: () async {
        if (closing) {
          await repo.closeCash(
            parseMoney(amount.text),
            reason.text,
            key,
            expectedBalance: expected,
          );
        } else {
          await repo.openingCash(parseMoney(amount.text), key: key);
        }
      },
    );
    amount.dispose();
    reason.dispose();
    if (ok == true) refresh();
  }

  Widget commissions() => spaced([
    const PageTitle(
      'Comisiones',
      'Calculadas sobre servicios cobrados, después de descuentos.',
    ),
    RowsView(
      future: repo.commissions(),
      builder: (rows) => rows.isEmpty
          ? const EmptyState(
              'Sin comisiones',
              'Aparecerán después del primer servicio cobrado.',
            )
          : spaced([
              for (final r in rows)
                Panel(
                  child: spaced([
                    Text(
                      '${r['nombre_completo']}',
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Wrap(
                      spacing: 32,
                      runSpacing: 16,
                      children: [
                        Text('${r['servicios']} líneas de servicio'),
                        Text('Base: ${money(numOf(r, 'base'))}'),
                        Text(
                          'Comisión: ${money(numOf(r, 'comision'))}',
                          style: const TextStyle(
                            fontSize: 22,
                            color: forest,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ]),
                ),
            ]),
    ),
  ]);
  Widget memberships() => spaced([
    PageTitle(
      'Club Valhalla',
      'Planes, servicios disponibles y consumos.',
      action: repo.session.manages
          ? FilledButton.icon(
              onPressed: () => runAction(context, membershipDialog),
              icon: const Icon(Icons.add),
              label: const Text('Vender membresía'),
            )
          : null,
    ),
    RowsView(
      future: repo.plans(),
      builder: (plans) => plans.isEmpty
          ? const EmptyState(
              'No hay planes vigentes',
              'Revisa sus fechas y servicios.',
            )
          : spaced([
              for (final p in plans)
                Panel(
                  child: ResponsiveListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.workspace_premium, color: forest),
                    title: Text('${p['nombre']}'),
                    subtitle: Text(
                      '${p['cantidad_servicios']} servicios · ${p['duracion_dias']} días\n${p['servicios']}',
                    ),
                    trailing: Text(money(numOf(p, 'precio'))),
                  ),
                ),
            ]),
    ),
    RowsView(
      future: repo.memberships(),
      builder: (rows) => rows.isEmpty
          ? const EmptyState(
              'Tu club comienza aquí',
              'Vende un plan y úsalo como beneficio al cobrar.',
            )
          : spaced([
              for (final r in rows)
                Panel(
                  child: ResponsiveListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '#${r['id_membresia']} · ${r['nombre_completo']}',
                    ),
                    subtitle: Text(
                      '${r['nombre']} · ${r['estado_vigente']}\nVence ${dateLabel(r['fecha_vencimiento'])}',
                    ),
                    isThreeLine: true,
                    trailing: Text(
                      '${r['restante']}/${r['servicios_iniciales']}',
                      style: const TextStyle(fontSize: 26, color: forest),
                    ),
                  ),
                ),
            ]),
    ),
  ]);
  Future<void> membershipDialog() async {
    final clients = await repo.clients(), plans = await repo.plans();
    if (!mounted) return;
    if (clients.isEmpty || plans.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Necesitas un cliente y un plan vigente.'),
        ),
      );
      return;
    }
    var client = numOf(clients.first, 'id_cliente'),
        plan = numOf(plans.first, 'id_plan_membresia');
    final received = TextEditingController(
          text: decimalMoney(numOf(plans.first, 'precio')),
        ),
        key = const Uuid().v4();
    DbRow selected() => plans.firstWhere((p) => p['id_plan_membresia'] == plan);
    final ok = await editor(
      context,
      title: 'Vender membresía',
      fields: (c, update) => spaced([
        select<int>(
          label: 'Cliente',
          value: client,
          options: clients
              .map((r) => (numOf(r, 'id_cliente'), '${r['nombre_completo']}'))
              .toList(),
          change: (v) => update(() => client = v),
        ),
        select<int>(
          label: 'Plan',
          value: plan,
          options: plans
              .map((r) => (numOf(r, 'id_plan_membresia'), '${r['nombre']}'))
              .toList(),
          change: (v) => update(() {
            plan = v;
            received.text = decimalMoney(numOf(selected(), 'precio'));
          }),
        ),
        Text(
          '${selected()['cantidad_servicios']} servicios · ${selected()['duracion_dias']} días · ${money(numOf(selected(), 'precio'))}',
        ),
        TextField(
          controller: received,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Efectivo recibido (USD)',
          ),
        ),
      ]),
      save: () async {
        await repo.buyMembership(
          client,
          plan,
          parseMoney(received.text),
          key,
          expectedPrice: numOf(selected(), 'precio'),
        );
      },
    );
    received.dispose();
    if (ok == true) refresh();
  }

  final Set<int> appointmentBusy = {};
  Widget appointments() => spaced([
    PageTitle(
      'Agenda',
      repo.session.canSchedule
          ? 'Horarios y duración de las próximas atenciones.'
          : 'Tus citas asignadas. Confirma cada corte al finalizar.',
      action: repo.session.canSchedule
          ? FilledButton.icon(
              onPressed: () => runAction(context, appointmentDialog),
              icon: const Icon(Icons.add),
              label: const Text('Nueva cita'),
            )
          : null,
    ),
    RowsView(
      future: repo.appointments(),
      builder: (rows) => rows.isEmpty
          ? EmptyState(
              'Agenda libre',
              repo.session.canSchedule
                  ? 'Programa la siguiente visita de un cliente.'
                  : 'Tus próximas citas aparecerán aquí cuando te las asignen.',
            )
          : spaced([
              for (final r in rows)
                Panel(
                  child: ResponsiveListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${r['nombre_completo']} · ${r['servicio']}'),
                    subtitle: Text(
                      '${dateLabel(r['fecha_hora'])} · ${r['duracion_minutos']} min\n${r['barbero']} · ${r['estado'] == 'ATENDIDA'
                          ? 'Corte confirmado'
                          : r['estado'] == 'CANCELADA'
                          ? 'Cancelada'
                          : 'Pendiente'}',
                    ),
                    isThreeLine: true,
                    trailing: r['estado'] == 'PENDIENTE'
                        ? Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (repo.session.canConfirmCut)
                                FilledButton.icon(
                                  onPressed:
                                      appointmentBusy.contains(
                                        numOf(r, 'id_cita'),
                                      )
                                      ? null
                                      : () => changeAppointment(r, true),
                                  icon: const Icon(Icons.check, size: 18),
                                  label: const Text('Confirmar corte'),
                                ),
                              if (repo.session.canSchedule)
                                IconButton(
                                  tooltip: 'Cancelar cita',
                                  icon: const Icon(Icons.event_busy),
                                  onPressed:
                                      appointmentBusy.contains(
                                        numOf(r, 'id_cita'),
                                      )
                                      ? null
                                      : () => changeAppointment(r, false),
                                ),
                            ],
                          )
                        : Icon(
                            r['estado'] == 'CANCELADA'
                                ? Icons.event_busy
                                : Icons.check_circle_outline,
                            color: forest,
                          ),
                  ),
                ),
            ]),
    ),
  ]);
  Future<void> changeAppointment(DbRow row, bool complete) async {
    final id = numOf(row, 'id_cita');
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          complete ? '¿Confirmar corte realizado?' : '¿Cancelar esta cita?',
        ),
        content: Text(
          complete
              ? 'La atención quedará registrada como realizada. El cobro se registra por separado.'
              : 'Se liberará este horario de la agenda.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(complete ? 'Confirmar corte' : 'Cancelar cita'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => appointmentBusy.add(id));
    try {
      await message(
        context,
        () => complete
            ? repo.completeAppointment(id)
            : repo.cancelAppointment(id),
        refresh,
      );
    } finally {
      if (mounted) setState(() => appointmentBusy.remove(id));
    }
  }

  Future<void> appointmentDialog() async {
    final clients = await repo.clients(),
        services = await repo.services(),
        barbers = await repo.barbers();
    if (!mounted || clients.isEmpty || services.isEmpty || barbers.isEmpty) {
      return;
    }
    var client = numOf(clients.first, 'id_cliente'),
        service = numOf(services.first, 'id_servicio'),
        barber = numOf(barbers.first, 'id_usuario');
    var date = businessDate(DateTime.now()).add(const Duration(days: 1));
    var duration = 30;
    final requestKey = const Uuid().v4();
    final ok = await editor(
      context,
      title: 'Programar cita',
      fields: (c, s) => spaced([
        select<int>(
          label: 'Cliente',
          value: client,
          options: clients
              .map((r) => (numOf(r, 'id_cliente'), '${r['nombre_completo']}'))
              .toList(),
          change: (v) => client = v,
        ),
        select<int>(
          label: 'Servicio',
          value: service,
          options: services
              .map((r) => (numOf(r, 'id_servicio'), '${r['nombre']}'))
              .toList(),
          change: (v) => service = v,
        ),
        select<int>(
          label: 'Barbero',
          value: barber,
          options: barbers
              .map((r) => (numOf(r, 'id_usuario'), '${r['nombre_completo']}'))
              .toList(),
          change: (v) => barber = v,
        ),
        select<int>(
          label: 'Duración',
          value: duration,
          options: const [
            (15, '15 minutos'),
            (30, '30 minutos'),
            (45, '45 minutos'),
            (60, '60 minutos'),
            (90, '90 minutos'),
            (120, '120 minutos'),
          ],
          change: (v) => s(() => duration = v),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            final d = await showDatePicker(
              context: c,
              initialDate: date,
              firstDate: businessDate(DateTime.now()),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (d == null || !c.mounted) return;
            final t = await showTimePicker(
              context: c,
              initialTime: TimeOfDay.fromDateTime(date),
            );
            if (t != null) {
              s(
                () => date = DateTime(d.year, d.month, d.day, t.hour, t.minute),
              );
            }
          },
          icon: const Icon(Icons.calendar_month),
          label: Text(
            dateLabel(
              timestamp(
                DateTime.utc(
                  date.year,
                  date.month,
                  date.day,
                  date.hour,
                  date.minute,
                ).add(const Duration(hours: 6)),
              ),
            ),
          ),
        ),
      ]),
      save: () => repo.appointment(
        client,
        barber,
        service,
        DateTime.utc(
          date.year,
          date.month,
          date.day,
          date.hour,
          date.minute,
        ).add(const Duration(hours: 6)),
        duration: duration,
        key: requestKey,
      ),
    );
    if (ok == true) refresh();
  }

  Widget audit() => spaced([
    const PageTitle('Auditoría', 'Quién hizo qué, cuándo y en qué sucursal.'),
    RowsView(
      future: repo.records('bitacora_auditoria'),
      builder: (rows) => recordsList(
        rows,
        (r) => '${r['accion']} · ${r['entidad']} #${r['id_registro']}',
        (r) => 'Usuario #${r['id_usuario']} · ${r['valor_nuevo']}',
      ),
    ),
  ]);
}

class ClientList extends StatefulWidget {
  final ValhallaRepository repo;
  final VoidCallback refresh;
  const ClientList({super.key, required this.repo, required this.refresh});
  @override
  State<ClientList> createState() => _ClientListState();
}

class _ClientListState extends State<ClientList> {
  String search = '';
  @override
  Widget build(BuildContext context) => spaced([
    PageTitle(
      'Clientes',
      'Relaciones que duran más que un corte.',
      action: FilledButton.icon(
        onPressed: () => edit(),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Nuevo cliente'),
      ),
    ),
    TextField(
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search),
        hintText: 'Buscar por nombre o teléfono',
      ),
      onChanged: (v) => setState(() => search = v),
    ),
    RowsView(
      future: widget.repo.clients(search),
      builder: (rows) => rows.isEmpty
          ? const EmptyState(
              'No hay coincidencias',
              'Prueba otro nombre o registra un cliente.',
            )
          : Panel(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final r in rows)
                    ResponsiveListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: paper,
                        foregroundColor: forest,
                        child: Text(
                          ('${r['nombre_completo']}').substring(0, 1),
                        ),
                      ),
                      title: Text('${r['nombre_completo']}'),
                      subtitle: Text('${r['telefono']}'),
                      trailing: IconButton(
                        onPressed: () => edit(r),
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Editar cliente',
                      ),
                      onTap: () => runAction(context, () => detail(r)),
                    ),
                ],
              ),
            ),
    ),
  ]);
  Future<void> edit([DbRow? row]) async {
    final name = TextEditingController(
          text: row?['nombre_completo'] as String?,
        ),
        phone = TextEditingController(text: row?['telefono'] as String?);
    DateTime? birth = row == null
        ? null
        : DateTime.parse(row['fecha_nacimiento'] as String);
    final ok = await editor(
      context,
      title: row == null ? 'Nuevo cliente' : 'Editar cliente',
      fields: (c, s) => spaced([
        TextField(
          controller: name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nombre completo'),
        ),
        TextField(
          controller: phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Teléfono'),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            final result = await showDatePicker(
              context: c,
              initialDate: birth ?? DateTime(1995),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
            );
            if (result != null) s(() => birth = result);
          },
          icon: const Icon(Icons.cake_outlined),
          label: Text(
            birth == null
                ? 'Elegir fecha de nacimiento'
                : birth!.toIso8601String().substring(0, 10),
          ),
        ),
      ]),
      save: () async {
        if (birth == null) {
          throw const RuleError('Selecciona la fecha de nacimiento.');
        }
        await widget.repo.saveClient(
          name.text,
          phone.text,
          birth!,
          id: row == null ? null : numOf(row, 'id_cliente'),
        );
      },
    );
    name.dispose();
    phone.dispose();
    if (ok == true) widget.refresh();
  }

  Future<void> detail(DbRow row) async {
    final history = await widget.repo.history(numOf(row, 'id_cliente')),
        points = await widget.repo.points(numOf(row, 'id_cliente'));
    final business = await widget.repo.business();
    final memberships = await widget.repo.memberships(
      client: numOf(row, 'id_cliente'),
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('${row['nombre_completo']}'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: spaced([
              Text(
                '${row['telefono']} · Nacimiento ${row['fecha_nacimiento']}',
              ),
              Text(
                '$points visitas acumuladas · Canje desde ${business['meta_fidelidad']}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: forest,
                ),
              ),
              const Divider(),
              for (final membership in memberships)
                Text(
                  '${membership['nombre']} · ${membership['restante']} servicios · ${membership['estado_vigente']}',
                ),
              ClientNotes(repo: widget.repo, client: numOf(row, 'id_cliente')),
              const Text('Historial de atenciones'),
              if (history.isEmpty)
                const Text('Aún no tiene atenciones registradas.'),
              for (final r in history)
                ResponsiveListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    r.containsKey('total_cobrado')
                        ? 'Operación #${r['id_operacion']} · ${money(numOf(r, 'total_cobrado'))}'
                        : '${r['nombre']}',
                  ),
                  subtitle: Text(dateLabel(r['fecha_hora'])),
                ),
            ]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
