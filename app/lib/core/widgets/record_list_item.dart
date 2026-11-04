import 'package:flutter/material.dart';

/// Places amounts below the title when a narrow row would truncate them.
class RecordListItem extends StatelessWidget {
  const RecordListItem({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.onTap,
  });

  final Widget leading;
  final String title;
  final Widget subtitle;
  final String amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 520 ||
            MediaQuery.textScalerOf(context).scale(14) > 18;
        final amountText = Text(
          amount,
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        );
        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            hoverColor: colorScheme.surfaceContainerHigh,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 17),
              child: Row(
                children: [
                  leading,
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: stacked ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        subtitle,
                        if (stacked) ...[const SizedBox(height: 9), amountText],
                      ],
                    ),
                  ),
                  if (!stacked) ...[const SizedBox(width: 16), amountText],
                  const SizedBox(width: 10),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
