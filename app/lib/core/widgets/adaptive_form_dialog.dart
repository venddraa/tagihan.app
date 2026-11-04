import 'package:flutter/material.dart';

/// Keeps forms spacious on phones and bounded on desktop windows.
class AdaptiveFormDialog extends StatelessWidget {
  const AdaptiveFormDialog({
    super.key,
    required this.child,
    required this.maxHeight,
  });

  final Widget child;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 600) {
      return Dialog.fullscreen(child: SafeArea(child: child));
    }
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 620, maxHeight: maxHeight),
        child: child,
      ),
    );
  }
}

class AdaptiveFormHeader extends StatelessWidget {
  const AdaptiveFormHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onClose,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final compact =
        mediaQuery.size.width < 400 ||
        mediaQuery.size.height - mediaQuery.viewInsets.bottom < 480;
    return Padding(
      padding: compact
          ? const EdgeInsets.fromLTRB(16, 8, 8, 8)
          : const EdgeInsets.fromLTRB(24, 20, 12, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 36 : 40,
            height: compact ? 36 : 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 21,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge,
                ),
                if (!compact) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Tutup',
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class AdaptiveFormActions extends StatelessWidget {
  const AdaptiveFormActions({
    super.key,
    required this.saveKey,
    required this.saving,
    required this.onCancel,
    required this.onSave,
  });

  final Key saveKey;
  final bool saving;
  final VoidCallback? onCancel;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final compact =
        mediaQuery.size.width < 400 ||
        mediaQuery.size.height - mediaQuery.viewInsets.bottom < 480;
    final cancel = TextButton(onPressed: onCancel, child: const Text('Batal'));
    final save = FilledButton.icon(
      key: saveKey,
      onPressed: onSave,
      icon: saving
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.check_rounded),
      label: Text(saving ? 'Menyimpan…' : 'Simpan'),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1),
        Padding(
          padding: compact
              ? const EdgeInsets.fromLTRB(12, 6, 12, 8)
              : const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 420) {
                return Row(
                  children: [
                    Expanded(child: cancel),
                    const SizedBox(width: 12),
                    Expanded(child: save),
                  ],
                );
              }
              return Align(
                alignment: Alignment.centerRight,
                child: Wrap(spacing: 12, children: [cancel, save]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class FormSectionLabel extends StatelessWidget {
  const FormSectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
