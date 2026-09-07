import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:valhalla/data/api_client.dart';
import 'package:valhalla/data/api_repository.dart';
import 'package:valhalla/domain/models.dart';

void main() {
  late ApiClient client;
  late List<http.Request> requests;
  late bool refuseLogin, refuseCut;
  Map<String, Object?> user() => {
    'id': '10000000-0000-4000-8000-000000000001',
    'aud': 'authenticated',
    'role': 'authenticated',
    'email': 'admin@example.test',
    'app_metadata': <String, Object?>{},
    'user_metadata': <String, Object?>{},
    'created_at': '2026-01-01T00:00:00Z',
  };
  Map<String, Object?> session() => {
    'access_token': 'test-session-token',
    'refresh_token': 'test-refresh-token',
    'expires_in': 3600,
    'token_type': 'bearer',
    'user': user(),
  };
  setUp(() {
    requests = [];
    refuseLogin = false;
    refuseCut = false;
    client = ApiClient(
      ApiClient.projectUrl,
      publishableKey: 'sb_publishable_test_public_key',
      client: MockClient((r) async {
        requests.add(r);
        Object? response = {};
        var status = 200;
        if (r.url.path == '/auth/v1/token') {
          response = refuseLogin
              ? {
                  'code': 'invalid_credentials',
                  'msg': 'Invalid login credentials',
                }
              : session();
          status = refuseLogin ? 400 : 200;
        } else if (r.url.path == '/auth/v1/verify') {
          response = session();
        } else if (r.url.path == '/auth/v1/user') {
          response = user();
        } else if (r.url.path == '/auth/v1/signup') {
          response = user();
        } else if (r.url.path == '/rest/v1/rpc/valhalla_rpc') {
          final b = jsonDecode(r.body) as Map;
          if (b['action'] == 'me') {
            response = {
              'userId': 1,
              'branchId': 1,
              'profile': 'administrador',
              'name': 'Admin',
              'email': 'admin@example.test',
              'mustChangePassword': false,
              'branches': [
                {'id_sucursal': 1, 'nombre': 'El Trébol'},
              ],
            };
          } else if (refuseCut) {
            response = {
              'code': 'P0001',
              'message':
                  'Tu rol no tiene permiso para realizar esta operación.',
            };
            status = 400;
          } else if (b['action'] == 'appointments') {
            response = [];
          } else {
            response = 1;
          }
        }
        return http.Response(
          jsonEncode(response),
          status,
          request: r,
          headers: {
            'content-type': 'application/json',
            'x-supabase-api-version': '2024-01-01',
          },
        );
      }),
    );
  });
  tearDown(() => client.close());
  test('Solo acepta claves públicas y rechaza credenciales administrativas', () {
    expect(ApiClient.isPublicKey('sb_publishable_12345678901234567890'), true);
    expect(ApiClient.isPublicKey('sb_secret_12345678901234567890'), false);
    expect(
      ApiClient.isPublicKey('postgresql://postgres:example@host/db'),
      false,
    );
    String jwt(String role) =>
        'header.${base64Url.encode(utf8.encode(jsonEncode({'role': role})))}.signature';
    expect(ApiClient.isPublicKey(jwt('anon')), true);
    expect(ApiClient.isPublicKey(jwt('service_role')), false);
  });
  test('Login obtiene identidad y permisos de PostgreSQL', () async {
    final account = await client.login(
      ' ADMIN@example.test ',
      'contraseña de prueba',
    );
    expect(account['profile'], 'administrador');
    final tokenRequest = requests.firstWhere(
      (r) => r.url.path.endsWith('/token'),
    );
    expect(jsonDecode(tokenRequest.body)['email'], 'admin@example.test');
    final rpc = requests.firstWhere((r) => r.url.path.contains('/rpc/'));
    expect(jsonDecode(rpc.body)['action'], 'me');
    expect(rpc.headers['authorization'], 'Bearer test-session-token');
    expect(requests.any((r) => r.url.host == '127.0.0.1'), false);
  });
  test(
    'Recuperación verifica código, cambia contraseña y cierra sesiones',
    () async {
      await client.requestRecovery('admin@example.test');
      await client.resetPassword(
        'admin@example.test',
        '123456',
        'Una contraseña nueva 2026!',
      );
      final verify = requests.firstWhere((r) => r.url.path.endsWith('/verify'));
      expect(jsonDecode(verify.body)['type'], 'recovery');
      expect(jsonDecode(verify.body)['token'], '123456');
      expect(
        requests.any((r) => r.url.path.endsWith('/user') && r.method == 'PUT'),
        true,
      );
      expect(
        requests.any(
          (r) =>
              r.url.path.endsWith('/logout') &&
              r.url.queryParameters['scope'] == 'global',
        ),
        true,
      );
      expect(client.token, isNull);
    },
  );
  test('Activación y reenvío utilizan confirmación de registro', () async {
    await client.activate('admin@example.test', 'Una contraseña inicial!');
    await client.resendActivation('admin@example.test');
    await client.verifyActivation('admin@example.test', '123456');
    expect(
      jsonDecode(
        requests.firstWhere((r) => r.url.path.endsWith('/verify')).body,
      )['type'],
      'signup',
    );
    expect(client.token, isNull);
  });
  test('El adaptador conserva clave idempotente y sucursal', () async {
    await client.login('admin@example.test', 'contraseña');
    final repo = ApiRepository(
      client,
      const Session(1, 2, Profile.administrador),
    );
    await repo.appointment(10, 11, 12, DateTime.utc(2027), key: 'same-request');
    final body = jsonDecode(requests.last.body);
    expect(body['action'], 'appointment');
    expect(body['branch'], 2);
    expect(body['d']['key'], 'same-request');
    await repo.completeAppointment(99);
    expect(jsonDecode(requests.last.body)['action'], 'completeAppointment');
  });
  test(
    'Los errores de autenticación y permisos se muestran en español',
    () async {
      refuseLogin = true;
      await expectLater(
        client.login('admin@example.test', 'incorrecta'),
        throwsA(
          isA<RuleError>().having(
            (e) => e.message,
            'message',
            'Correo o contraseña incorrectos.',
          ),
        ),
      );
      refuseLogin = false;
      await client.login('admin@example.test', 'contraseña');
      refuseCut = true;
      await expectLater(
        client.request(
          'api/v1/rpc/completeAppointment',
          method: 'POST',
          body: {'id': 1},
        ),
        throwsA(
          isA<RuleError>().having(
            (e) => e.message,
            'message',
            contains('permiso'),
          ),
        ),
      );
    },
  );
}
