import 'package:flutter/material.dart';

class ModernNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final GlobalKey? calendarKey;
  final GlobalKey? diaryKey;
  final GlobalKey? trendsKey;

  const ModernNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.calendarKey,
    this.diaryKey,
    this.trendsKey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                context: context,
                icon: Icons.calendar_month_rounded,
                label: 'Calendar',
                index: 0,
                isSelected: currentIndex == 0,
                color: theme.colorScheme.secondary,
                itemKey: calendarKey,
              ),
              _buildNavItem(
                context: context,
                icon: Icons.edit_note_rounded,
                label: 'Diary',
                index: 1,
                isSelected: currentIndex == 1,
                color: theme.colorScheme.primary,
                itemKey: diaryKey,
              ),
              _buildNavItem(
                context: context,
                icon: Icons.insights_rounded,
                label: 'Trends',
                index: 2,
                isSelected: currentIndex == 2,
                color: const Color(0xFF4CAF50),
                itemKey: trendsKey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required int index,
    required bool isSelected,
    required Color color,
    GlobalKey? itemKey,
  }) {
    return Expanded(
      child: InkWell(
        key: itemKey,
        onTap: () => onTap(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: isSelected ? color : Colors.grey[400],
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? color : Colors.grey[400],
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}