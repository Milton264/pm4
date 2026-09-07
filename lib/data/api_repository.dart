import 'package:uuid/uuid.dart';
import '../domain/models.dart';
import 'contracts.dart';
import 'api_client.dart';

class ApiRepository implements ValhallaRepository {
  final ApiClient client;
  @override
  final Session session;
  ApiRepository(this.client, this.session);
  @override
  int get branch => session.branchId;
  @override
  String get now => timestamp(DateTime.now());
  @override
  ApiRepository withSession(Session value) {
    if (value.userId != session.userId || value.profile != session.profile) {
      throw const RuleError('Inicia sesión para cambiar de usuario.');
    }
    return ApiRepository(client, value);
  }

  Future<Object?> _call(String action, [DbRow body = const {}]) =>
      client.request(
        'api/v1/rpc/$action',
        method: 'POST',
        body: body,
        branch: branch,
      );
  Future<List<DbRow>> _rows(String action, [DbRow body = const {}]) async =>
      ApiClient.rows(await _call(action, body));
  Future<void> _void(String action, DbRow body) async {
    await _call(action, body);
  }

  @override
  Future<List<DbRow>> clients([String search = '']) =>
      _rows('clients', {'search': search});
  @override
  Future<List<DbRow>> services() => _rows('services');
  @override
  Future<List<DbRow>> products() => _rows('products');
  @override
  Future<List<DbRow>> banks() => _rows('banks');
  @override
  Future<List<DbRow>> barbers() => _rows('barbers');
  @override
  Future<List<DbRow>> branches() => _rows('branches');
  @override
  Future<DbRow> business() async =>
      Map<String, Object?>.from(await _call('business') as Map);
  @override
  Future<List<DbRow>> catalog(String kind) => _rows('catalog', {'kind': kind});
  @override
  Future<int> saveCatalog(String kind, DbRow data) async =>
      (await _call('saveCatalog', {'kind': kind, 'data': data})) as int;
  @override
  Future<List<DbRow>> clientNotes(int client) =>
      _rows('clientNotes', {'client': client});
  @override
  Future<void> saveNote(int client, String note) =>
      _void('saveNote', {'client': client, 'note': note});
  @override
  Future<int> saveClient(
    String name,
    String phone,
    DateTime birth, {
    int? id,
  }) async =>
      (await _call('saveClient', {
            'name': name,
            'phone': phone,
            'birth': birth.toIso8601String(),
            'id': id,
          }))
          as int;
  @override
  Future<List<DbRow>> history(int client) =>
      _rows('history', {'client': client});
  @override
  Future<int> points(int client) async =>
      (await _call('points', {'client': client})) as int;
  @override
  Future<int> checkout(Checkout order) async =>
      (await _call('checkout', {
            'key': order.key,
            'clientId': order.clientId,
            'barberId': order.barberId,
            'transfer': order.transfer,
            'bankId': order.bankId,
            'reference': order.reference,
            'received': order.received,
            'expectedTotal': order.expectedTotal,
            'lines': [
              for (final l in order.lines)
                {
                  'id': l.id,
                  'product': l.product,
                  'quantity': l.quantity,
                  'discount': l.discount,
                  'benefit': l.benefit,
                  'membershipId': l.membershipId,
                  'reason': l.reason,
                  'expectedUnitPrice': l.expectedUnitPrice,
                },
            ],
          }))
          as int;
  @override
  Future<void> adjustStock(
    int product,
    int units,
    String type,
    String reason, {
    String? key,
    int? destination,
  }) => _void('adjustStock', {
    'product': product,
    'units': units,
    'type': type,
    'reason': reason,
    'key': key ?? const Uuid().v4(),
    'destination': destination,
  });
  @override
  Future<int> cashBalance() async => (await _call('cashBalance')) as int;
  @override
  Future<void> expense(
    String description,
    String category,
    int amount, {
    bool transfer = false,
    int? bank,
    String? key,
  }) => _void('expense', {
    'description': description,
    'category': category,
    'amount': amount,
    'transfer': transfer,
    'bank': bank,
    'key': key ?? const Uuid().v4(),
  });
  @override
  Future<void> openingCash(int amount, {String? key}) =>
      _void('openingCash', {'amount': amount, 'key': key ?? const Uuid().v4()});
  @override
  Future<int> closeCash(
    int counted,
    String explanation,
    String key, {
    int? expectedBalance,
  }) async =>
      (await _call('closeCash', {
            'counted': counted,
            'explanation': explanation,
            'key': key,
            'expectedBalance': expectedBalance,
          }))
          as int;
  @override
  Future<List<DbRow>> operations() => _rows('operations');
  @override
  Future<Receipt> receipt(int id) async {
    final result = await _call('receipt', {'id': id}) as Map;
    return Receipt(
      Map<String, Object?>.from(result['operation'] as Map),
      Map<String, Object?>.from(result['payment'] as Map),
      ApiClient.rows(result['lines']),
    );
  }

  @override
  Future<List<DbRow>> commissions() => _rows('commissions');
  @override
  Future<List<DbRow>> records(String kind) => _rows('records', {'kind': kind});
  @override
  Future<void> servicePrice(int service, int price) =>
      _void('servicePrice', {'service': service, 'price': price});
  @override
  Future<List<DbRow>> plans() => _rows('plans');
  @override
  Future<List<DbRow>> memberships({
    int? client,
    int? service,
    bool usableOnly = false,
  }) => _rows('memberships', {
    'client': client,
    'service': service,
    'usableOnly': usableOnly,
  });
  @override
  Future<int> buyMembership(
    int client,
    int plan,
    int received,
    String key, {
    int? expectedPrice,
  }) async =>
      (await _call('buyMembership', {
            'client': client,
            'plan': plan,
            'received': received,
            'key': key,
            'expectedPrice': expectedPrice,
          }))
          as int;
  @override
  Future<List<DbRow>> appointments() => _rows('appointments');
  @override
  Future<void> appointment(
    int client,
    int barber,
    int service,
    DateTime date, {
    int duration = 30,
    String? key,
  }) => _void('appointment', {
    'client': client,
    'barber': barber,
    'service': service,
    'date': timestamp(date),
    'duration': duration,
    'key': key ?? const Uuid().v4(),
  });
  @override
  Future<void> cancelAppointment(int id) =>
      _void('cancelAppointment', {'id': id});
  @override
  Future<void> completeAppointment(int id) =>
      _void('completeAppointment', {'id': id});
}
