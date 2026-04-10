import 'package:flutter/material.dart';

class TwoOptionsSelector extends StatelessWidget {
  final bool isLeftSelected;
  final String leftLabel;
  final String rightLabel;
  final Color leftColor;
  final Color rightColor;
  final Function(bool isLeft) onChanged;

  const TwoOptionsSelector({
    super.key,
    required this.isLeftSelected,
    required this.leftLabel,
    required this.rightLabel,
    required this.onChanged,
    this.leftColor = const Color(0xFF00C48C),
    this.rightColor = const Color(0xFFFF4757),
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  color: isLeftSelected ? leftColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isLeftSelected
                      ? [
                          BoxShadow(
                            color: leftColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  leftLabel,
                  style: TextStyle(
                    color: isLeftSelected ? Colors.white : cs.onSurface.withOpacity(0.6),
                    fontWeight: isLeftSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  color: !isLeftSelected ? rightColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: !isLeftSelected
                      ? [
                          BoxShadow(
                            color: rightColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  rightLabel,
                  style: TextStyle(
                    color: !isLeftSelected ? Colors.white : cs.onSurface.withOpacity(0.6),
                    fontWeight: !isLeftSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
