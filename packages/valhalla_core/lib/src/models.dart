typedef DbRow = Map<String, Object?>;
int numOf(DbRow row, String key) => (row[key] as num?)?.toInt() ?? 0;
const maxMoney = 999999999999;
String decimalMoney(int cents) {
  final n = cents.abs();
  return '${cents < 0 ? '-' : ''}${n ~/ 100}.${(n % 100).toString().padLeft(2, '0')}';
}

String money(int cents) => '\$${decimalMoney(cents)}';
void checkMoney(int cents, {bool positive = false}) {
  if (cents < (positive ? 1 : 0) || cents > maxMoney) {
    throw const RuleError('Monto fuera del rango permitido.');
  }
}

int parseMoney(String value) {
  final text = value.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d{1,10}(\.\d{1,2})?$').hasMatch(text)) {
    throw const RuleError('Escribe un monto válido con hasta dos decimales.');
  }
  final parts = text.split('.');
  final amount =
      int.parse(parts[0]) * 100 +
      (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
  checkMoney(amount);
  return amount;
}

String timestamp(DateTime date) => DateTime.fromMillisecondsSinceEpoch(
  date.toUtc().millisecondsSinceEpoch,
  isUtc: true,
).toIso8601String();
DateTime businessDate(DateTime date) =>
    date.toUtc().subtract(const Duration(hours: 6));

class RuleError implements Exception {
  final String message;
  const RuleError(this.message);
  @override
  String toString() => message;
}

enum Profile { administrador, encargado, barbero, whatsapp }

class Session {
  final int userId;
  final int branchId;
  final Profile profile;
  final String name, email;
  const Session(
    this.userId,
    this.branchId,
    this.profile, {
    this.name = '',
    this.email = '',
  });
  Session atBranch(int id) =>
      Session(userId, id, profile, name: name, email: email);
  bool get isAdmin => profile == Profile.administrador;
  bool get manages =>
      profile == Profile.administrador || profile == Profile.encargado;
  bool get canSchedule => manages || profile == Profile.whatsapp;
  bool get canConfirmCut => manages || profile == Profile.barbero;
}

class CartLine {
  final int id;
  final bool product;
  final int quantity;
  final int discount;
  final String benefit;
  final int? membershipId;
  final String reason;
  final int? expectedUnitPrice;
  const CartLine(
    this.id, {
    this.product = false,
    this.quantity = 1,
    this.discount = 0,
    this.benefit = '',
    this.membershipId,
    this.reason = '',
    this.expectedUnitPrice,
  });
}

class Checkout {
  final String key;
  final int clientId;
  final int barberId;
  final List<CartLine> lines;
  final bool transfer;
  final int? bankId;
  final String reference;
  final int received;
  final int? expectedTotal;
  const Checkout({
    required this.key,
    required this.clientId,
    required this.barberId,
    required this.lines,
    this.transfer = false,
    this.bankId,
    this.reference = '',
    this.received = 0,
    this.expectedTotal,
  });
}

class Receipt {
  final DbRow operation, payment;
  final List<DbRow> lines;
  const Receipt(this.operation, this.payment, this.lines);
}
