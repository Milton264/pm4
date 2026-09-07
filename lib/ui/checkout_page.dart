import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/contracts.dart';
import '../domain/models.dart';
import '../main.dart';
import 'components.dart';

class CheckoutPage extends StatefulWidget {
  final ValhallaRepository repo;
  final VoidCallback onSaved;
  const CheckoutPage({super.key, required this.repo, required this.onSaved});
  @override
  State<CheckoutPage> createState() => CheckoutPageState();
}

class CheckoutPageState extends State<CheckoutPage> {
  late Future<void> loading;
  List<DbRow> clients = [],
      services = [],
      products = [],
      barbers = [],
      banks = [];
  final cart = <CartLine>[];
  int? client, barber;
  int bank = 1, loyaltyGoal = 10;
  bool transfer = false, busy = false, productTab = false;
  final received = TextEditingController(), reference = TextEditingController();
  final key = const Uuid().v4();
  String? error;
  @override
  void initState() {
    super.initState();
    loading = load();
  }

  Future<void> load() async {
    loyaltyGoal = numOf(await widget.repo.business(), 'meta_fidelidad');
    clients = await widget.repo.clients();
    services = await widget.repo.services();
    products = await widget.repo.products();
    barbers = await widget.repo.barbers();
    banks = await widget.repo.banks();
    bank = banks.isEmpty ? 0 : numOf(banks.first, 'id_banco');
    client = clients.isEmpty ? null : numOf(clients.first, 'id_cliente');
    barber = barbers.isEmpty ? null : numOf(barbers.first, 'id_usuario');
  }

  @override
  void dispose() {
    received.dispose();
    reference.dispose();
    super.dispose();
  }

  DbRow item(CartLine l) => (l.product ? products : services).firstWhere(
    (r) => numOf(r, l.product ? 'id_producto' : 'id_servicio') == l.id,
  );
  int price(CartLine l) =>
      numOf(item(l), l.product ? 'precio_venta_actual' : 'precio');
  int lineTotal(CartLine l) =>
      l.benefit.isNotEmpty ? 0 : (price(l) - l.discount) * l.quantity;
  int get total => cart.fold(0, (sum, l) => sum + lineTotal(l));
  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: loading,
    builder: (context, s) {
      if (s.hasError) return EmptyState('No se pudo cargar', '${s.error}');
      if (s.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (clients.isEmpty || barbers.isEmpty) {
        return const EmptyState(
          'Faltan datos para cobrar',
          'Registra un cliente y asigna un barbero a la sucursal.',
        );
      }
      return spaced([
        const PageTitle(
          'Una buena experiencia.',
          'Registra la atención y cobra en un solo paso.',
        ),
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 860;
            final catalog = spaced([
              Panel(
                child: spaced([
                  select<int>(
                    label: 'Cliente',
                    enabled: !busy,
                    value: client!,
                    options: clients
                        .map(
                          (r) => (
                            numOf(r, 'id_cliente'),
                            '${r['nombre_completo']}',
                          ),
                        )
                        .toList(),
                    change: (v) => setState(() {
                      client = v;
                      for (var i = 0; i < cart.length; i++) {
                        final l = cart[i];
                        cart[i] = CartLine(
                          l.id,
                          product: l.product,
                          quantity: l.quantity,
                          discount: l.discount,
                          reason: l.reason,
                          expectedUnitPrice: l.expectedUnitPrice,
                        );
                      }
                      error = null;
                    }),
                  ),
                  select<int>(
                    label: 'Barbero',
                    enabled: !busy,
                    value: barber!,
                    options: barbers
                        .map(
                          (r) => (
                            numOf(r, 'id_usuario'),
                            '${r['nombre_completo']}',
                          ),
                        )
                        .toList(),
                    change: (v) => setState(() => barber = v),
                  ),
                ]),
              ),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Servicios'),
                    icon: Icon(Icons.content_cut),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Productos'),
                    icon: Icon(Icons.inventory_2_outlined),
                  ),
                ],
                selected: {productTab},
                onSelectionChanged: (v) => setState(() => productTab = v.first),
              ),
              LayoutBuilder(
                builder: (context, c) {
                  final columns = c.maxWidth >= 480 ? 2 : 1;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final row in productTab ? products : services)
                        SizedBox(
                          width: (c.maxWidth - (columns - 1) * 12) / columns,
                          child: Card(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: busy
                                  ? null
                                  : () => setState(
                                      () => cart.add(
                                        CartLine(
                                          numOf(
                                            row,
                                            productTab
                                                ? 'id_producto'
                                                : 'id_servicio',
                                          ),
                                          product: productTab,
                                          expectedUnitPrice: numOf(
                                            row,
                                            productTab
                                                ? 'precio_venta_actual'
                                                : 'precio',
                                          ),
                                        ),
                                      ),
                                    ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          productTab
                                              ? Icons.inventory_2_outlined
                                              : Icons.content_cut,
                                          color: forest,
                                        ),
                                        const Spacer(),
                                        const Icon(
                                          Icons.add_circle_outline,
                                          color: forest,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 22),
                                    Text(
                                      '${row['nombre']}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      money(
                                        numOf(
                                          row,
                                          productTab
                                              ? 'precio_venta_actual'
                                              : 'precio',
                                        ),
                                      ),
                                      style: const TextStyle(
                                        fontSize: 23,
                                        color: forest,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      productTab
                                          ? '${numOf(row, 'stock_actual') ~/ 1000} disponibles'
                                          : numOf(row, 'elegible_fidelidad') ==
                                                1
                                          ? 'Admite beneficios'
                                          : 'Servicio profesional',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF73776F),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ]);
            final summary = Panel(
              child: spaced([
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Detalle de atención',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${cart.length} ${cart.length == 1 ? 'línea' : 'líneas'}',
                    ),
                  ],
                ),
                if (cart.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Text(
                      'Selecciona servicios o productos del catálogo.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (var i = 0; i < cart.length; i++) cartRow(i),
                const Divider(),
                Row(
                  children: [
                    const Expanded(
                      child: Text('TOTAL', style: TextStyle(letterSpacing: 2)),
                    ),
                    Text(
                      money(total),
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                select<bool>(
                  label: 'Método de pago',
                  enabled: !busy,
                  value: transfer,
                  options: const [(false, 'Efectivo'), (true, 'Transferencia')],
                  change: (v) => setState(() => transfer = v),
                ),
                if (transfer) ...[
                  if (banks.isNotEmpty)
                    select<int>(
                      label: 'Banco',
                      enabled: !busy,
                      value: bank,
                      options: banks
                          .map((b) => (numOf(b, 'id_banco'), '${b['nombre']}'))
                          .toList(),
                      change: (v) => setState(() => bank = v),
                    ),
                  TextField(
                    controller: reference,
                    enabled: !busy,
                    decoration: const InputDecoration(
                      labelText: 'Referencia de transferencia',
                    ),
                  ),
                ] else ...[
                  TextField(
                    controller: received,
                    enabled: !busy,
                    onChanged: (_) => setState(() {}),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Efectivo recibido (USD)',
                      prefixText: '\$ ',
                    ),
                  ),
                  Text(
                    changeText(),
                    style: const TextStyle(
                      color: forest,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (error != null)
                  TextButton.icon(
                    onPressed: busy ? null : reloadCatalog,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualizar catálogo'),
                  ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                FilledButton.icon(
                  onPressed: busy || cart.isEmpty ? null : pay,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(busy ? 'Guardando…' : 'Confirmar cobro'),
                ),
                const Text(
                  'Los descuentos requieren un encargado. El cobro actualiza caja, inventario y comisiones.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF73776F)),
                ),
              ]),
            );
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: catalog),
                      const SizedBox(width: 24),
                      SizedBox(width: 370, child: summary),
                    ],
                  )
                : spaced([catalog, summary]);
          },
        ),
      ]);
    },
  );
  String changeText() {
    try {
      final cash = parseMoney(received.text);
      return cash >= total
          ? 'Cambio: ${money(cash - total)}'
          : 'Faltan ${money(total - cash)}';
    } catch (_) {
      return 'Introduce el efectivo para calcular el cambio.';
    }
  }

  Widget cartRow(int index) {
    final l = cart[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${item(l)['nombre']}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              onPressed: busy
                  ? null
                  : () => setState(() => cart.removeAt(index)),
              tooltip: 'Quitar línea',
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              onPressed: busy || l.quantity <= 1 || l.benefit.isNotEmpty
                  ? null
                  : () => quantity(index, -1),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text('${l.quantity}'),
            IconButton(
              onPressed: busy || l.benefit.isNotEmpty
                  ? null
                  : () => quantity(index, 1),
              icon: const Icon(Icons.add_circle_outline),
            ),
            const Spacer(),
            Text(
              money(lineTotal(l)),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        if (!l.product)
          TextButton.icon(
            onPressed: busy ? null : () => benefit(index),
            icon: const Icon(Icons.local_offer_outlined, size: 16),
            label: Text(
              l.benefit.isNotEmpty
                  ? l.benefit
                  : l.discount > 0
                  ? 'Descuento ${money(l.discount)}'
                  : 'Beneficio o descuento',
            ),
          ),
        const Divider(),
      ],
    );
  }

  void quantity(int index, int delta) {
    final l = cart[index];
    setState(
      () => cart[index] = CartLine(
        l.id,
        product: l.product,
        quantity: l.quantity + delta,
        discount: l.discount,
        reason: l.reason,
        expectedUnitPrice: l.expectedUnitPrice,
      ),
    );
  }

  Future<void> benefit(int index) async {
    final line = cart[index];
    final memberships = await widget.repo.memberships(
      client: client,
      service: line.id,
      usableOnly: true,
    );
    if (!mounted) return;
    var benefit = line.benefit;
    final discount = TextEditingController(text: decimalMoney(line.discount)),
        reason = TextEditingController(text: line.reason);
    final available = memberships
        .where(
          (m) => numOf(m, 'id_cliente') == client && numOf(m, 'restante') > 0,
        )
        .toList();
    int? membership =
        (available.any((m) => m['id_membresia'] == line.membershipId)
            ? line.membershipId
            : null) ??
        (available.isEmpty ? null : numOf(available.first, 'id_membresia'));
    CartLine? replacement;
    final ok = await editor(
      context,
      title: 'Beneficio por servicio',
      button: 'Aplicar a la línea',
      fields: (c, s) => spaced([
        select<String>(
          label: 'Tipo',
          value: benefit,
          options: [
            ('', 'Precio normal / descuento'),
            ('FIDELIDAD', 'Canjear $loyaltyGoal visitas'),
            ('CUMPLEANOS', 'Cumpleaños'),
            ('MEMBRESIA', 'Consumir membresía'),
          ],
          change: (v) => s(() => benefit = v),
        ),
        if (benefit.isEmpty) ...[
          TextField(
            controller: discount,
            enabled: widget.repo.session.manages,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Descuento por unidad (USD)',
            ),
          ),
          TextField(
            controller: reason,
            enabled: widget.repo.session.manages,
            decoration: const InputDecoration(
              labelText: 'Motivo del descuento',
            ),
          ),
        ],
        if (benefit == 'MEMBRESIA')
          if (available.isEmpty)
            const Text('El cliente no tiene membresías con saldo.')
          else
            select<int>(
              label: 'Membresía',
              value: membership!,
              options: available
                  .map(
                    (r) => (
                      numOf(r, 'id_membresia'),
                      '#${r['id_membresia']} · ${r['restante']} servicios',
                    ),
                  )
                  .toList(),
              change: (v) => membership = v,
            ),
        if (benefit.isNotEmpty)
          const Text(
            'El beneficio cubre una unidad de esta línea. Se verificará la elegibilidad al confirmar el cobro.',
          ),
      ]),
      save: () async {
        final amount = benefit.isEmpty ? parseMoney(discount.text) : 0;
        if (amount > price(line)) {
          throw const RuleError('El descuento no puede superar el precio.');
        }
        if (amount > 0 && reason.text.trim().isEmpty) {
          throw const RuleError('Indica el motivo del descuento.');
        }
        if (benefit == 'MEMBRESIA' && membership == null) {
          throw const RuleError('Selecciona una membresía.');
        }
        replacement = CartLine(
          line.id,
          quantity: benefit.isEmpty ? line.quantity : 1,
          discount: amount,
          benefit: benefit,
          membershipId: membership,
          reason: reason.text,
          expectedUnitPrice: line.expectedUnitPrice,
        );
      },
    );
    discount.dispose();
    reason.dispose();
    if (ok == true && mounted) {
      setState(() {
        cart[index] = replacement!;
        if (replacement!.benefit.isNotEmpty && line.quantity > 1) {
          cart.insert(
            index + 1,
            CartLine(
              line.id,
              quantity: line.quantity - 1,
              expectedUnitPrice: line.expectedUnitPrice,
            ),
          );
        }
      });
    }
  }

  bool get hasDraft => cart.isNotEmpty;
  Future<bool> canLeave() async {
    if (busy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Espera a que termine el cobro.')),
      );
      return false;
    }
    if (!hasDraft) return true;
    return await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Hay una atención sin guardar'),
            content: const Text('¿Quieres descartar sus líneas y salir?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Seguir editando'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Descartar y salir'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> reloadCatalog() async {
    if (busy) return;
    try {
      final nextServices = await widget.repo.services(),
          nextProducts = await widget.repo.products(),
          nextLines = <CartLine>[];
      for (final l in cart) {
        final rows = (l.product ? nextProducts : nextServices).where(
          (r) => numOf(r, l.product ? 'id_producto' : 'id_servicio') == l.id,
        );
        if (rows.isEmpty) {
          throw const RuleError(
            'Retira las líneas de servicios o productos que ya no están activos.',
          );
        }
        final price = numOf(
          rows.single,
          l.product ? 'precio_venta_actual' : 'precio',
        );
        if (l.discount > price) {
          throw const RuleError(
            'Reduce el descuento que supera el nuevo precio.',
          );
        }
        nextLines.add(
          CartLine(
            l.id,
            product: l.product,
            quantity: l.quantity,
            discount: l.discount,
            reason: l.reason,
            benefit: l.benefit,
            membershipId: l.membershipId,
            expectedUnitPrice: price,
          ),
        );
      }
      if (mounted) {
        setState(() {
          services = nextServices;
          products = nextProducts;
          cart
            ..clear()
            ..addAll(nextLines);
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is RuleError
              ? e.message
              : 'No se pudo actualizar el catálogo.',
        );
      }
    }
  }

  Future<void> pay() async {
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    final confirmedTotal = total;
    late int id;
    try {
      id = await widget.repo.checkout(
        Checkout(
          key: key,
          expectedTotal: total,
          clientId: client!,
          barberId: barber!,
          lines: List.of(cart),
          transfer: transfer,
          bankId: bank,
          reference: reference.text,
          received: transfer
              ? 0
              : parseMoney(
                  received.text.isEmpty && total == 0 ? '0' : received.text,
                ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = e is RuleError
              ? e.message
              : 'No se pudo guardar. Los datos no se han cobrado; revisa e intenta de nuevo.';
        });
      }
      return;
    }
    if (!mounted) return;
    // A committed sale must never be presented as a failed database write.
    cart.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Cobro #$id guardado · ${money(confirmedTotal)}')),
    );
    widget.onSaved();
  }
}
