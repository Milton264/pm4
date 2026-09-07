import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/api_client.dart';
import '../data/api_repository.dart';
import '../domain/models.dart';
import '../main.dart';
import 'components.dart';
import 'shell.dart';

class AccessGate extends StatefulWidget {
  const AccessGate({super.key});
  @override
  State<AccessGate> createState() => _AccessGateState();
}

class _AccessGateState extends State<AccessGate> {
  ApiClient? client;
  DbRow? account;
  String? error;
  bool loading = true;
  String address = ApiClient.projectUrl, publicKey = '';
  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    address =
        prefs.getString('valhalla.supabase_url') ??
        const String.fromEnvironment(
          'SUPABASE_URL',
          defaultValue: ApiClient.projectUrl,
        );
    publicKey =
        prefs.getString('valhalla.supabase_key') ??
        const String.fromEnvironment(
          'SUPABASE_PUBLISHABLE_KEY',
          defaultValue: ApiClient.projectPublishableKey,
        );
    if (publicKey.isEmpty) {
      if (mounted) setState(() => loading = false);
      return;
    }
    await connect();
  }

  Future<void> connect() async {
    client?.close();
    final next = ApiClient(address, publishableKey: publicKey);
    next.onExpired = () {
      if (mounted) setState(() => account = null);
    };
    client = next;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await next.checkConnection();
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is RuleError ? e.message : 'No se pudo conectar.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> connection() async {
    final url = TextEditingController(text: address),
        key = TextEditingController(text: publicKey);
    final ok = await editor(
      context,
      title: 'Conexión a la nube',
      button: 'Conectar',
      fields: (c, s) => spaced([
        const Text(
          'Configura una vez el proyecto de VALHALLA. Todos los dispositivos utilizarán la misma información.',
        ),
        TextField(
          controller: url,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'URL de Supabase'),
        ),
        TextField(
          controller: key,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            labelText: 'Clave pública de aplicación',
            hintText: 'sb_publishable_…',
            helperText:
                'Usa la clave publicable; nunca la contraseña de PostgreSQL.',
          ),
        ),
      ]),
      save: () async {
        final uri = Uri.tryParse(url.text.trim());
        if (uri == null ||
            uri.scheme != 'https' ||
            !uri.hasAuthority ||
            uri.userInfo.isNotEmpty ||
            uri.hasQuery ||
            uri.hasFragment ||
            (uri.path.isNotEmpty && uri.path != '/')) {
          throw const RuleError('Escribe la URL HTTPS del proyecto.');
        }
        if (!ApiClient.isPublicKey(key.text.trim())) {
          throw const RuleError(
            'Utiliza una clave publicable o anon. No se aceptan claves secretas de administración.',
          );
        }
        final probe = ApiClient(
          uri.toString(),
          publishableKey: key.text.trim(),
        );
        try {
          await probe.checkConnection();
        } finally {
          probe.close();
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('valhalla.supabase_url', uri.toString());
        await prefs.setString('valhalla.supabase_key', key.text.trim());
        address = uri.toString();
        publicKey = key.text.trim();
      },
    );
    url.dispose();
    key.dispose();
    if (ok == true && mounted) await connect();
  }

  Future<void> logout() async {
    try {
      await client?.logout();
    } finally {
      if (mounted) setState(() => account = null);
    }
  }

  @override
  void dispose() {
    client?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (account != null && client != null) {
      final d = account!;
      return ValhallaShell(
        initial: ApiRepository(
          client!,
          Session(
            numOf(d, 'userId'),
            numOf(d, 'branchId'),
            Profile.values.byName(d['profile'] as String),
            name: d['name'] as String,
            email: d['email'] as String,
          ),
        ),
        onLogout: logout,
        onPasswordChanged: () {
          if (mounted) setState(() => account = null);
        },
      );
    }
    return AuthSurface(
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : client == null || error != null
          ? spaced([
              Text(
                'Conecta VALHALLA.',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              Text(
                error ?? 'Inicia la conexión con tu base de datos en la nube.',
              ),
              FilledButton(
                onPressed: connection,
                child: const Text('Configurar conexión'),
              ),
              if (client != null)
                TextButton(onPressed: connect, child: const Text('Reintentar')),
            ])
          : AccessForm(
              client: client!,
              connection: connection,
              onAccess: (value) {
                if (mounted) setState(() => account = value);
              },
            ),
    );
  }
}

class AuthSurface extends StatelessWidget {
  final Widget child;
  const AuthSurface({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 960;
          final form = SingleChildScrollView(
            padding: EdgeInsets.all(wide ? 56 : 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!wide) ...[
                      const Text(
                        'V /',
                        style: TextStyle(fontSize: 40, color: forest),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'VALHALLA',
                        style: TextStyle(
                          letterSpacing: 5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                    child,
                  ],
                ),
              ),
            ),
          );
          return Row(
            children: [
              if (wide)
                Expanded(
                  child: ColoredBox(
                    color: ink,
                    child: Padding(
                      padding: const EdgeInsets.all(56),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'V /',
                            style: TextStyle(
                              color: gold,
                              fontSize: 60,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'VALHALLA',
                            style: TextStyle(
                              color: Colors.white,
                              letterSpacing: 6,
                              fontSize: 20,
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            'Cada detalle.\nCada cliente.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              height: 1.15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -1.5,
                            ),
                          ),
                          const SizedBox(height: 28),
                          Container(width: 80, height: 3, color: gold),
                          const SizedBox(height: 28),
                          const Text(
                            'Tu barbería, en orden.',
                            style: TextStyle(
                              color: Color(0xFFADB3A8),
                              fontSize: 18,
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            'EL TRÉBOL  /  BYPASS',
                            style: TextStyle(
                              color: gold,
                              fontSize: 12,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Expanded(child: Center(child: form)),
            ],
          );
        },
      ),
    ),
  );
}

class AccessForm extends StatefulWidget {
  final ApiClient client;
  final Future<void> Function() connection;
  final ValueChanged<DbRow> onAccess;
  const AccessForm({
    super.key,
    required this.client,
    required this.connection,
    required this.onAccess,
  });
  @override
  State<AccessForm> createState() => _AccessFormState();
}

class _AccessFormState extends State<AccessForm> {
  final email = TextEditingController(), password = TextEditingController();
  bool busy = false, visible = false;
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final account = await widget.client.login(email.text, password.text);
      if (mounted) widget.onAccess(account);
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              error = e is RuleError ? e.message : 'No se pudo iniciar sesión.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> openRecovery(bool activate) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AuthSurface(
          child: RecoveryForm(
            client: widget.client,
            initialEmail: email.text,
            activation: activate,
          ),
        ),
      ),
    );
    if (ok == true && mounted) {
      password.clear();
      setState(() => error = null);
    }
  }

  @override
  Widget build(BuildContext context) => AutofillGroup(
    child: spaced([
      Text('Bienvenido.', style: Theme.of(context).textTheme.headlineLarge),
      const Text(
        'Ingresa con tu cuenta para continuar.',
        style: TextStyle(color: Color(0xFF73776F), height: 1.6),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: email,
        enabled: !busy,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        autofillHints: const [AutofillHints.username],
        decoration: const InputDecoration(labelText: 'Correo electrónico'),
      ),
      TextField(
        controller: password,
        enabled: !busy,
        obscureText: !visible,
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: const [AutofillHints.password],
        onSubmitted: (_) {
          if (!busy) submit();
        },
        decoration: InputDecoration(
          labelText: 'Contraseña',
          suffixIcon: IconButton(
            onPressed: busy ? null : () => setState(() => visible = !visible),
            tooltip: visible ? 'Ocultar contraseña' : 'Mostrar contraseña',
            icon: Icon(
              visible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
          ),
        ),
      ),
      if (error != null)
        Text(
          error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      FilledButton(
        onPressed: busy ? null : submit,
        child: Text(busy ? 'Ingresando…' : 'Iniciar sesión'),
      ),
      TextButton(
        onPressed: busy ? null : () => openRecovery(false),
        child: const Text('Olvidé mi contraseña'),
      ),
      TextButton(
        onPressed: busy ? null : () => openRecovery(true),
        child: const Text('Activar mi cuenta'),
      ),
      const Text(
        'El administrador o encargado debe agregarte primero al equipo.',
        style: TextStyle(fontSize: 12, color: Color(0xFF73776F)),
      ),
      TextButton.icon(
        onPressed: busy ? null : widget.connection,
        icon: const Icon(Icons.cloud_outlined, size: 18),
        label: const Text('Conexión a la nube'),
      ),
    ]),
  );
}

class RecoveryForm extends StatefulWidget {
  final ApiClient client;
  final String initialEmail;
  final bool activation;
  const RecoveryForm({
    super.key,
    required this.client,
    this.initialEmail = '',
    this.activation = false,
  });
  @override
  State<RecoveryForm> createState() => _RecoveryFormState();
}

class _RecoveryFormState extends State<RecoveryForm> {
  late final email = TextEditingController(text: widget.initialEmail);
  final code = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController();
  bool busy = false, visible = false;
  int stage = 0, remaining = 0;
  String? error, info;
  Timer? timer;
  void cooldown() {
    timer?.cancel();
    remaining = 60;
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => remaining--);
      if (remaining <= 0) t.cancel();
    });
  }

  void validate({bool resend = false}) {
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.text.trim())) {
      throw const RuleError('Escribe un correo válido.');
    }
    if (!resend &&
        ((widget.activation && stage == 0) ||
            (!widget.activation && stage == 1))) {
      ApiClient.validatePassword(password.text);
      if (password.text != confirm.text) {
        throw const RuleError('Las contraseñas no coinciden.');
      }
    }
  }

  Future<void> submit({bool resend = false}) async {
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      validate(resend: resend);
      if (stage == 0 || resend) {
        if (widget.activation) {
          if (resend) {
            await widget.client.resendActivation(email.text);
          } else {
            await widget.client.activate(email.text, password.text);
          }
          info = 'Revisa el código enviado a tu correo y escríbelo aquí.';
        } else {
          info = await widget.client.requestRecovery(email.text);
        }
        if (mounted) {
          setState(() {
            stage = 1;
            cooldown();
          });
        }
      } else {
        if (!RegExp(r'^\d{6,10}$').hasMatch(code.text.trim())) {
          throw const RuleError('Escribe el código completo del correo.');
        }
        if (widget.activation) {
          await widget.client.verifyActivation(email.text, code.text);
        } else {
          await widget.client.resetPassword(
            email.text,
            code.text,
            password.text,
          );
        }
        timer?.cancel();
        if (mounted) setState(() => stage = 2);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is RuleError
              ? e.message
              : 'No se pudo completar la solicitud.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    for (final c in [email, code, password, confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: spaced([
      Text(
        stage == 2
            ? (widget.activation
                  ? 'Tu cuenta está confirmada.'
                  : 'Contraseña actualizada.')
            : (widget.activation ? 'Activa tu cuenta.' : 'Recupera tu acceso.'),
        style: Theme.of(context).textTheme.headlineLarge,
      ),
      if (stage == 2) ...[
        Text(
          widget.activation
              ? 'Ya puedes iniciar sesión con tu correo y contraseña.'
              : 'Inicia sesión con tu nueva contraseña. Las sesiones anteriores se han cerrado.',
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Volver a iniciar sesión'),
        ),
      ] else ...[
        Text(
          stage == 0
              ? (widget.activation
                    ? 'Usa el correo que el administrador o encargado registró en tu equipo.'
                    : 'Te enviaremos un código para que puedas elegir una nueva contraseña.')
              : info ?? 'Revisa tu correo.',
        ),
        TextField(
          controller: email,
          enabled: !busy && stage == 0,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Correo electrónico'),
        ),
        if (stage == 1)
          TextField(
            controller: code,
            enabled: !busy,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: const InputDecoration(labelText: 'Código del correo'),
          ),
        if ((widget.activation && stage == 0) ||
            (!widget.activation && stage == 1)) ...[
          TextField(
            controller: password,
            enabled: !busy,
            obscureText: !visible,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'Nueva contraseña',
              helperText: '12 caracteres como mínimo',
              suffixIcon: IconButton(
                onPressed: () => setState(() => visible = !visible),
                tooltip: visible ? 'Ocultar contraseña' : 'Mostrar contraseña',
                icon: Icon(
                  visible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
          ),
          TextField(
            controller: confirm,
            enabled: !busy,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Repetir nueva contraseña',
            ),
          ),
        ],
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        FilledButton(
          onPressed: busy ? null : () => submit(),
          child: Text(
            busy
                ? 'Procesando…'
                : stage == 0
                ? 'Enviar código'
                : widget.activation
                ? 'Confirmar cuenta'
                : 'Guardar nueva contraseña',
          ),
        ),
        if (stage == 1)
          TextButton(
            onPressed: busy || remaining > 0
                ? null
                : () => submit(resend: true),
            child: Text(
              remaining > 0 ? 'Reenviar en $remaining s' : 'Reenviar código',
            ),
          ),
        if (stage == 1)
          const Text(
            'Revisa spam si no encuentras el mensaje. Si el código venció, solicita uno nuevo.',
            style: TextStyle(fontSize: 12, color: Color(0xFF73776F)),
          ),
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Volver'),
        ),
      ],
    ]),
  );
}

class PasswordChange extends StatefulWidget {
  final ApiClient client;
  final bool requiredChange;
  final VoidCallback onChanged;
  const PasswordChange({
    super.key,
    required this.client,
    required this.onChanged,
    this.requiredChange = false,
  });
  @override
  State<PasswordChange> createState() => _PasswordChangeState();
}

class _PasswordChangeState extends State<PasswordChange> {
  final current = TextEditingController(),
      replacement = TextEditingController(),
      confirm = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    current.dispose();
    replacement.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (replacement.text != confirm.text) {
        throw const RuleError('Las contraseñas no coinciden.');
      }
      await widget.client.changePassword(current.text, replacement.text);
      if (mounted) widget.onChanged();
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is RuleError
              ? e.message
              : 'No se pudo cambiar la contraseña.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: spaced([
      Text(
        widget.requiredChange
            ? 'Tu contraseña personal.'
            : 'Cambiar contraseña',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      Text(
        widget.requiredChange
            ? 'Reemplaza la contraseña inicial antes de entrar al sistema.'
            : 'Se cerrarán las sesiones abiertas de tu cuenta.',
      ),
      TextField(
        controller: current,
        enabled: !busy,
        obscureText: true,
        autocorrect: false,
        enableSuggestions: false,
        decoration: const InputDecoration(labelText: 'Contraseña actual'),
      ),
      TextField(
        controller: replacement,
        enabled: !busy,
        obscureText: true,
        autocorrect: false,
        enableSuggestions: false,
        decoration: const InputDecoration(
          labelText: 'Nueva contraseña',
          helperText: '12 caracteres como mínimo',
        ),
      ),
      TextField(
        controller: confirm,
        enabled: !busy,
        obscureText: true,
        autocorrect: false,
        enableSuggestions: false,
        decoration: const InputDecoration(
          labelText: 'Repetir nueva contraseña',
        ),
      ),
      if (error != null)
        Text(
          error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      FilledButton(
        onPressed: busy ? null : save,
        child: Text(busy ? 'Guardando…' : 'Guardar contraseña'),
      ),
    ]),
  );
}
