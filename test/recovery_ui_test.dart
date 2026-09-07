import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/main.dart';
import 'package:valhalla/data/api_client.dart';
import 'package:valhalla/ui/access.dart';

class RecoveryTestClient extends ApiClient {
  int sends = 0, resets = 0;
  RecoveryTestClient()
    : super(
        ApiClient.projectUrl,
        publishableKey: 'sb_publishable_test_public_key',
      );
  @override
  Future<String> requestRecovery(String email) async {
    sends++;
    return 'Revisa el código en tu correo.';
  }

  @override
  Future<void> resetPassword(
    String email,
    String code,
    String replacement,
  ) async {
    resets++;
  }
}

void main() {
  for (final size in [const Size(1440, 1000), const Size(320, 740)]) {
    testWidgets('Recuperación sin desbordamiento ${size.width}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = RecoveryTestClient();
      addTearDown(client.close);
      await tester.pumpWidget(
        ValhallaApp(
          home: AuthSurface(child: RecoveryForm(client: client)),
        ),
      );
      Future<void> fill(String label, String value) async {
        final f = find.widgetWithText(TextField, label);
        await tester.ensureVisible(f);
        await tester.enterText(f, value);
        await tester.pump();
      }

      Future<void> tap(String label) async {
        final f = find.text(label);
        await tester.ensureVisible(f);
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      await fill('Correo electrónico', 'admin@example.test');
      await tap('Enviar código');
      expect(client.sends, 1);
      await fill('Código del correo', '123456');
      await fill('Nueva contraseña', 'Una contraseña nueva!');
      await fill('Repetir nueva contraseña', 'No coincide');
      await tap('Guardar nueva contraseña');
      expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
      expect(client.resets, 0);
      await fill('Repetir nueva contraseña', 'Una contraseña nueva!');
      await tap('Guardar nueva contraseña');
      expect(client.resets, 1);
      expect(find.text('Contraseña actualizada.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
