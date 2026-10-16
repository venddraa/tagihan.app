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
          style: const TextStyle(fontWeight: FontWeight.w600),
        );
        return InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 18),
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
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 5),
                      subtitle,
                      if (stacked) ...[const SizedBox(height: 8), amountText],
                    ],
                  ),
                ),
                if (!stacked) ...[const SizedBox(width: 16), amountText],
                const SizedBox(width: 10),
                Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        );
      },
    );
  }
}
