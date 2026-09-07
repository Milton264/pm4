import 'package:flutter/material.dart';
import '../domain/models.dart';
import '../main.dart';

Future<void> runAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is RuleError
                ? error.message
                : 'No se pudo completar la acción. Intenta de nuevo.',
          ),
        ),
      );
    }
  }
}

String dateLabel(Object? value) {
  final date = DateTime.tryParse('$value') == null
      ? null
      : businessDate(DateTime.parse('$value'));
  return date == null
      ? '—'
      : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
  });
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: padding, child: child),
  );
}

class PageTitle extends StatelessWidget {
  final String title, subtitle;
  final Widget? action;
  const PageTitle(this.title, this.subtitle, {super.key, this.action});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 24,
      runSpacing: 16,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(color: Color(0xFF73776F))),
          ],
        ),
        ?action,
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  final String title, detail;
  const EmptyState(this.title, this.detail, {super.key});
  @override
  Widget build(BuildContext context) => Panel(
    child: SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.inbox_outlined, size: 42, color: forest),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(detail, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}

class RowsView extends StatelessWidget {
  final Future<List<DbRow>> future;
  final Widget Function(List<DbRow>) builder;
  const RowsView({super.key, required this.future, required this.builder});
  @override
  Widget build(BuildContext context) => FutureBuilder<List<DbRow>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return EmptyState('No se pudo cargar', '${snapshot.error}');
      }
      if (!snapshot.hasData) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ),
        );
      }
      return builder(snapshot.data!);
    },
  );
}

class Metric extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const Metric(this.label, this.value, this.icon, {super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: MediaQuery.sizeOf(context).width < 600
        ? (MediaQuery.sizeOf(context).width - 48) / 2
        : 220,
    child: Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: forest),
          const SizedBox(height: 22),
          Text(
            value,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Color(0xFF73776F))),
        ],
      ),
    ),
  );
}

Future<bool?> editor(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext, void Function(void Function())) fields,
  required Future<void> Function() save,
  String button = 'Guardar',
}) async {
  final route = DialogRoute<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) =>
        _EditorDialog(title: title, fields: fields, save: save, button: button),
  );
  final result = await Navigator.of(context, rootNavigator: true).push(route);
  await route.completed;
  return result;
}

class _EditorDialog extends StatefulWidget {
  final String title, button;
  final Widget Function(BuildContext, void Function(void Function())) fields;
  final Future<void> Function() save;
  const _EditorDialog({
    required this.title,
    required this.fields,
    required this.save,
    required this.button,
  });
  @override
  State<_EditorDialog> createState() => _EditorDialogState();
}

class _EditorDialogState extends State<_EditorDialog> {
  bool busy = false;
  String? error;
  @override
  Widget build(BuildContext context) => PopScope<bool>(
    canPop: !busy,
    child: AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AbsorbPointer(
                absorbing: busy,
                child: widget.fields(context, setState),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: busy ? null : commit,
          child: Text(busy ? 'Guardando…' : widget.button),
        ),
      ],
    ),
  );
  Future<void> commit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.save();
      if (!mounted) return;
      setState(() => busy = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, true);
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = e is RuleError
              ? e.message
              : 'No se pudo guardar. Revisa los datos e intenta de nuevo.';
        });
      }
    }
  }
}

Widget spaced(List<Widget> children) => Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    for (var i = 0; i < children.length; i++) ...[
      if (i > 0) const SizedBox(height: 16),
      children[i],
    ],
  ],
);
Widget select<T>({
  required String label,
  Key? fieldKey,
  bool enabled = true,
  required T value,
  required List<(T, String)> options,
  required void Function(T) change,
}) => DropdownButtonFormField<T>(
  key: fieldKey ?? ValueKey('$label-$value'),
  initialValue: value,
  isExpanded: true,
  decoration: InputDecoration(labelText: label),
  items: options
      .map(
        (x) => DropdownMenuItem(
          value: x.$1,
          child: Text(x.$2, overflow: TextOverflow.ellipsis),
        ),
      )
      .toList(),
  onChanged: enabled
      ? (v) {
          if (v != null) change(v);
        }
      : null,
);
Future<void> message(
  BuildContext context,
  Future<void> Function() action,
  VoidCallback refresh,
) async {
  try {
    await action();
    refresh();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cambio guardado.')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is RuleError ? e.message : 'No se pudo completar la acción.',
          ),
        ),
      );
    }
  }
}

/// Moves actions below the text when a narrow layout cannot hold a full row.
class ResponsiveListTile extends StatelessWidget {
  final Widget? leading, title, subtitle, trailing;
  final EdgeInsetsGeometry? contentPadding;
  final VoidCallback? onTap;
  final bool isThreeLine;
  const ResponsiveListTile({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.contentPadding,
    this.onTap,
    this.isThreeLine = false,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth >= 480) {
        return ListTile(
          leading: leading,
          title: title,
          subtitle: subtitle,
          trailing: trailing,
          contentPadding: contentPadding,
          onTap: onTap,
          isThreeLine: isThreeLine,
        );
      }
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding:
              contentPadding ??
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 12)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title != null)
                          DefaultTextStyle.merge(
                            style: Theme.of(context).textTheme.titleMedium!,
                            child: title!,
                          ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 6),
                          DefaultTextStyle.merge(
                            style: Theme.of(context).textTheme.bodyMedium!,
                            child: subtitle!,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (trailing != null) ...[
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: trailing!),
              ],
            ],
          ),
        ),
      );
    },
  );
}
