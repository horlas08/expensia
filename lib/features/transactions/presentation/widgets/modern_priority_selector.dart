import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:easy_localization/easy_localization.dart';

class ModernPrioritySelector extends StatelessWidget {
  final int selectedPriority; // 1: Basic, 2: Normal, 3: Entertainment
  final ValueChanged<int> onChanged;

  const ModernPrioritySelector({
    super.key,
    required this.selectedPriority,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            'transaction.priority'.tr(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: cs.onSurface.withOpacity(0.6),
            ),
          ),
        ),
        Row(
          children: [
            _PriorityCard(
              priority: 1,
              label: 'transaction.priority_basic'.tr(),
              icon: Icons.star_outline_rounded,
              color: const Color(0xFF00C48C),
              isSelected: selectedPriority == 1,
              onTap: () => onChanged(1),
            ),
            const SizedBox(width: 12),
            _PriorityCard(
              priority: 2,
              label: 'transaction.priority_normal'.tr(),
              icon: Icons.star_half_rounded,
              color: const Color(0xFFFF9800),
              isSelected: selectedPriority == 2,
              onTap: () => onChanged(2),
            ),
            const SizedBox(width: 12),
            _PriorityCard(
              priority: 3,
              label: 'transaction.priority_entertainment'.tr(),
              icon: Icons.stars_rounded,
              color: const Color(0xFFFF4757),
              isSelected: selectedPriority == 3,
              onTap: () => onChanged(3),
            ),
          ],
        ),
      ],
    );
  }
}

class _PriorityCard extends StatelessWidget {
  final int priority;
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _PriorityCard({
    required this.priority,
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: isSelected ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected ? color : cs.surfaceContainerLow.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.35),
                        blurRadius: 15,
                        spreadRadius: 1,
                        offset: const Offset(0, 6),
                      )
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : color.withOpacity(0.7),
                  size: 24,
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : cs.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
