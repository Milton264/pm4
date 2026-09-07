import 'models.dart';

abstract interface class ValhallaRepository {
  Session get session;
  String get now;
  int get branch;
  ValhallaRepository withSession(Session value);
  Future<List<DbRow>> clients([String search = '']);
  Future<List<DbRow>> services();
  Future<List<DbRow>> products();
  Future<List<DbRow>> banks();
  Future<List<DbRow>> barbers();
  Future<int> saveClient(String name, String phone, DateTime birth, {int? id});
  Future<List<DbRow>> history(int client);
  Future<int> points(int client);
  Future<int> checkout(Checkout order);
  Future<void> adjustStock(
    int product,
    int units,
    String type,
    String reason, {
    String? key,
    int? destination,
  });
  Future<int> cashBalance();
  Future<void> expense(
    String description,
    String category,
    int amount, {
    bool transfer = false,
    int? bank,
    String? key,
  });
  Future<void> openingCash(int amount, {String? key});
  Future<int> closeCash(
    int counted,
    String explanation,
    String key, {
    int? expectedBalance,
  });
  Future<List<DbRow>> operations();
  Future<Receipt> receipt(int id);
  Future<List<DbRow>> commissions();
  Future<List<DbRow>> records(String kind);
  Future<void> servicePrice(int service, int price);
  Future<List<DbRow>> plans();
  Future<List<DbRow>> memberships({
    int? client,
    int? service,
    bool usableOnly = false,
  });
  Future<int> buyMembership(
    int client,
    int plan,
    int received,
    String key, {
    int? expectedPrice,
  });
  Future<List<DbRow>> appointments();
  Future<void> appointment(
    int client,
    int barber,
    int service,
    DateTime date, {
    int duration = 30,
    String? key,
  });
  Future<void> cancelAppointment(int id);
  Future<void> completeAppointment(int id);
  Future<List<DbRow>> branches();
  Future<DbRow> business();
  Future<List<DbRow>> catalog(String kind);
  Future<int> saveCatalog(String kind, DbRow data);
  Future<List<DbRow>> clientNotes(int client);
  Future<void> saveNote(int client, String note);
}
