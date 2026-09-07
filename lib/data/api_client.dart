import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart' as sb;
import '../domain/models.dart';

class ApiFailure extends RuleError {
  final int status;
  final String code;
  const ApiFailure(super.message, this.status, this.code);
}

class _MemoryAuthStorage extends sb.GotrueAsyncStorage {
  final Map<String, String> values = {};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    values.remove(key);
  }
}

/// Conexión desde Flutter a Supabase. No requiere ejecutar un backend propio.
class ApiClient {
  static const projectUrl = 'https://gapseqbyjbwudjwegxun.supabase.co';
  static const projectPublishableKey =
      'sb_publishable_WwyN6QxFUG5SnFdUKhKkqg_dQjxMojS';
  static bool isPublicKey(String key) {
    if (key.startsWith('sb_publishable_') && key.length > 25) return true;
    try {
      final parts = key.split('.');
      if (parts.length != 3) return false;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return payload is Map && payload['role'] == 'anon';
    } catch (_) {
      return false;
    }
  }

  final Uri origin;
  final String publishableKey;
  final http.Client _http;
  late final sb.SupabaseClient cloud;
  void Function()? onExpired;
  String? get token => cloud.auth.currentSession?.accessToken;

  ApiClient(String url, {required this.publishableKey, http.Client? client})
    : origin = Uri.parse(url),
      _http = client ?? http.Client() {
    cloud = sb.SupabaseClient(
      url,
      publishableKey,
      httpClient: _http,
      authOptions: sb.AuthClientOptions(
        authFlowType: sb.AuthFlowType.pkce,
        pkceAsyncStorage: _MemoryAuthStorage(),
      ),
    );
  }

  static String authMessage(sb.AuthException e) => switch (e.code) {
    'invalid_credentials' => 'Correo o contraseña incorrectos.',
    'email_not_confirmed' => 'Confirma tu correo antes de ingresar.',
    'otp_expired' => 'El código no es válido o venció. Solicita uno nuevo.',
    'over_email_send_rate_limit' || 'over_request_rate_limit' =>
      'Se alcanzó el límite de solicitudes. Espera unos minutos antes de reintentar.',
    'email_address_not_authorized' =>
      'El envío a este correo no está habilitado. El administrador debe configurar el correo en Supabase.',
    'user_already_exists' || 'email_exists' =>
      'La cuenta ya existe. Inicia sesión o recupera tu contraseña.',
    'weak_password' =>
      'Utiliza una contraseña más segura, de al menos 12 caracteres.',
    'same_password' => 'Elige una contraseña diferente a la anterior.',
    _ =>
      'No se pudo completar el acceso. Revisa los datos y la configuración de correo.',
  };

  Future<T> _guard<T>(Future<T> Function() work) async {
    try {
      return await work().timeout(const Duration(seconds: 30));
    } on sb.AuthException catch (e) {
      throw RuleError(authMessage(e));
    } on sb.PostgrestException catch (e) {
      if (e.code == 'P0001') {
        if (e.message.contains('sesión terminó')) onExpired?.call();
        throw RuleError(e.message);
      }
      if (e.code == '23505') {
        throw const RuleError('Ese registro ya existe. Revisa los datos.');
      }
      if (e.code == '23503') {
        throw const RuleError(
          'El registro está relacionado con otros datos o ya no está disponible.',
        );
      }
      if (e.code == '42501') {
        throw const RuleError(
          'Tu cuenta no tiene permiso para esta operación.',
        );
      }
      if (e.code == 'PGRST202') {
        throw const RuleError(
          'Falta instalar el SQL de VALHALLA en este proyecto de Supabase.',
        );
      }
      throw const RuleError(
        'No se pudo guardar o consultar la información. Revisa los datos e intenta de nuevo.',
      );
    } on TimeoutException {
      throw const RuleError(
        'La conexión está tardando. Conservamos los datos del formulario; puedes reintentar.',
      );
    } on http.ClientException {
      throw const RuleError(
        'No hay conexión con Supabase. Revisa Internet e intenta de nuevo.',
      );
    } on SocketException {
      throw const RuleError('No hay conexión a Internet. Revisa tu red.');
    }
  }

  Future<void> checkConnection() => _guard(() async {
    if (!isPublicKey(publishableKey)) {
      throw const RuleError(
        'Configura una clave publicable o anon de Supabase. Nunca uses la contraseña de PostgreSQL ni una clave secreta.',
      );
    }
    final result = await _http.get(
      origin.resolve('/auth/v1/settings'),
      headers: {'apikey': publishableKey},
    );
    if (result.statusCode != 200) {
      throw const RuleError(
        'Revisa la URL del proyecto y la clave pública de Supabase.',
      );
    }
  });

  Future<Object?> request(
    String path, {
    String method = 'GET',
    DbRow? body,
    int? branch,
  }) => _guard(() async {
    final action = path.startsWith('api/v1/rpc/')
        ? path.substring('api/v1/rpc/'.length)
        : path == 'api/v1/me'
        ? 'me'
        : path == 'api/v1/staff'
        ? (method == 'GET' ? 'staff' : 'saveStaff')
        : throw const RuleError('Operación no disponible.');
    return cloud.rpc(
      'valhalla_rpc',
      params: {'action': action, 'd': body ?? {}, 'branch': branch},
    );
  });

  Future<DbRow> login(String email, String password) => _guard(() async {
    await cloud.auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    try {
      return Map<String, Object?>.from(await request('api/v1/me') as Map);
    } catch (_) {
      await cloud.auth.signOut(scope: sb.SignOutScope.local);
      rethrow;
    }
  });

  static void validatePassword(String value) {
    if (value.trim().length < 12 || value.length > 128) {
      throw const RuleError(
        'La contraseña debe tener entre 12 y 128 caracteres.',
      );
    }
  }

  Future<void> activate(String email, String password) => _guard(() async {
    validatePassword(password);
    final result = await cloud.auth.signUp(
      email: email.trim().toLowerCase(),
      password: password,
    );
    if (result.session != null) {
      await cloud.auth.signOut(scope: sb.SignOutScope.local);
    }
  });

  Future<void> verifyActivation(String email, String code) => _guard(() async {
    await cloud.auth.verifyOTP(
      email: email.trim().toLowerCase(),
      token: code.trim(),
      type: sb.OtpType.signup,
    );
    await cloud.auth.signOut(scope: sb.SignOutScope.local);
  });
  Future<void> resendActivation(String email) => _guard(() async {
    await cloud.auth.resend(
      type: sb.OtpType.signup,
      email: email.trim().toLowerCase(),
    );
  });

  Future<String> requestRecovery(String email) => _guard(() async {
    await cloud.auth.resetPasswordForEmail(email.trim().toLowerCase());
    return 'Si el correo pertenece a una cuenta, recibirá un código. Revisa también la carpeta de spam.';
  });

  Future<void> resetPassword(String email, String code, String replacement) =>
      _guard(() async {
        validatePassword(replacement);
        await cloud.auth.verifyOTP(
          email: email.trim().toLowerCase(),
          token: code.trim(),
          type: sb.OtpType.recovery,
        );
        try {
          await cloud.auth.updateUser(sb.UserAttributes(password: replacement));
          await cloud.auth.signOut(scope: sb.SignOutScope.global);
        } finally {
          await cloud.auth.signOut(scope: sb.SignOutScope.local);
        }
      });

  Future<void> changePassword(String current, String replacement) =>
      _guard(() async {
        validatePassword(replacement);
        final email = cloud.auth.currentUser?.email;
        if (email == null) throw const RuleError('Inicia sesión de nuevo.');
        await cloud.auth.signInWithPassword(email: email, password: current);
        await cloud.auth.updateUser(sb.UserAttributes(password: replacement));
        await cloud.auth.signOut(scope: sb.SignOutScope.global);
      });

  Future<void> logout() async {
    try {
      await cloud.auth.signOut(scope: sb.SignOutScope.local);
    } on sb.AuthException {
      /* Se abandona la vista aunque el servicio esté temporalmente fuera de línea. */
    }
  }

  Future<List<DbRow>> staff() async => rows(await request('api/v1/staff'));
  Future<int> saveStaff(DbRow data) async =>
      (await request('api/v1/staff', method: 'POST', body: data)) as int;
  static List<DbRow> rows(Object? value) =>
      (value as List).map((r) => Map<String, Object?>.from(r as Map)).toList();
  void close() {
    unawaited(cloud.dispose());
    _http.close();
  }
}
