import 'package:flutter/material.dart';
import '../services/mood_service.dart';
import '../models/mood_entry.dart';
import 'package:intl/intl.dart';

enum DisplayMode {
  solid,
  circle,
  gradient,
}

class CalendarScreen extends StatefulWidget {
  final MoodService moodService;
  final Function(DateTime)? onDateSelected;

  const CalendarScreen({
    super.key,
    required this.moodService,
    this.onDateSelected,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final int currentYear = DateTime.now().year;

  // Cache for mood data
  Map<String, _DayMoodData> _moodCache = {};
  bool _needsRebuild = false;

  // Display mode
  DisplayMode _displayMode = DisplayMode.solid;

  // Pre-calculated month data
  late List<_MonthData> _monthsData;

  // Scroll position tracking
  static double? _savedScrollPosition;
  static bool _hasVisitedBefore = false;
  bool _hasScrolledToCurrentMonth = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    // Pre-calculate all month data
    _monthsData = List.generate(12, (index) {
      final month = index + 1;
      return _MonthData(
        month: month,
        year: currentYear,
        days: _getDaysInMonth(currentYear, month),
        startingWeekday: _getStartingWeekday(currentYear, month),
        monthName: DateFormat('MMMM').format(DateTime(currentYear, month)),
      );
    });

    _buildMoodCache();
    widget.moodService.addListener(_onMoodServiceUpdate);

    // Scroll to position after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScrollPosition();
    });

    // Save scroll position when scrolling
    _scrollController.addListener(_saveScrollPosition);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_saveScrollPosition);
    _scrollController.dispose();
    widget.moodService.removeListener(_onMoodServiceUpdate);
    super.dispose();
  }

  void _saveScrollPosition() {
    if (_scrollController.hasClients) {
      _savedScrollPosition = _scrollController.position.pixels;
    }
  }

  void _initializeScrollPosition() {
    if (!_scrollController.hasClients) return;

    if (_hasVisitedBefore && _savedScrollPosition != null) {
      // Restore previous scroll position
      _scrollController.jumpTo(_savedScrollPosition!);
    } else if (!_hasScrolledToCurrentMonth) {
      // First visit - scroll to current month
      _scrollToCurrentMonth();
      _hasVisitedBefore = true;
      _hasScrolledToCurrentMonth = true;
    }
  }

  void _scrollToCurrentMonth() {
    if (!_scrollController.hasClients) return;

    final currentMonth = DateTime.now().month;

    // Calculate approximate position for current month
    // Each month card is roughly 380px (including margin)
    // Add header heights: main header (72px) + day header (48px) + top padding (16px) = 136px
    final monthCardHeight = 380.0;
    final headerHeight = 136.0;
    final targetPosition = (currentMonth - 1) * monthCardHeight - headerHeight;

    // Ensure we don't scroll past the end
    final maxScroll = _scrollController.position.maxScrollExtent;
    final scrollTo = targetPosition.clamp(0.0, maxScroll);

    _scrollController.animateTo(
      scrollTo,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOutCubic,
    );
  }

  List<DateTime> _getDaysInMonth(int year, int month) {
    final lastDay = DateTime(year, month + 1, 0);
    return List.generate(
      lastDay.day,
          (i) => DateTime(year, month, i + 1),
      growable: false,
    );
  }

  int _getStartingWeekday(int year, int month) {
    final firstDay = DateTime(year, month, 1);
    return firstDay.weekday - 1;
  }

  void _onMoodServiceUpdate() {
    if (!mounted) return;

    _needsRebuild = true;
    // Increased debounce for better performance
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted && _needsRebuild) {
        _buildMoodCache();
        if (mounted) {
          setState(() {
            _needsRebuild = false;
          });
        }
      }
    });
  }

  void _buildMoodCache() {
    final newCache = <String, _DayMoodData>{};

    // Group entries by date
    for (var entry in widget.moodService.entries) {
      if (entry.timestamp.year != currentYear) continue;

      final key =
          '${entry.timestamp.year}-${entry.timestamp.month}-${entry.timestamp.day}';

      if (!newCache.containsKey(key)) {
        newCache[key] = _DayMoodData(
          date: DateTime(entry.timestamp.year, entry.timestamp.month,
              entry.timestamp.day),
          entries: [],
        );
      }

      newCache[key]!.entries.add(entry);
    }

    // Calculate averages and colors once
    for (var data in newCache.values) {
      final sum = data.entries.fold<int>(0, (sum, e) => sum + e.moodRating);
      data.averageMood = sum / data.entries.length;
      data.emoji = MoodEntry.getMoodEmoji(data.averageMood.round());
      data.solidColor = _getMoodColorForAverage(data.averageMood);
      data.gradientColors = _getMoodGradientForAverage(data.averageMood);
    }

    _moodCache = newCache;
  }

  Color _getMoodColorForAverage(double avgMood) {
    if (avgMood <= 2) return const Color(0x59F44336);
    if (avgMood <= 4) return const Color(0x59FF9800);
    if (avgMood <= 6) return const Color(0x59FFC107);
    if (avgMood <= 8) return const Color(0x598BC34A);
    return const Color(0x594CAF50);
  }

  List<Color> _getMoodGradientForAverage(double avgMood) {
    if (avgMood <= 2) {
      return const [Color(0xFFFF6B6B), Color(0xFFEE5A6F)];
    } else if (avgMood <= 4) {
      return const [Color(0xFFFFA726), Color(0xFFFB8C00)];
    } else if (avgMood <= 6) {
      return const [Color(0xFFFFCA28), Color(0xFFFFA000)];
    } else if (avgMood <= 8) {
      return const [Color(0xFF9CCC65), Color(0xFF7CB342)];
    } else {
      return const [Color(0xFF66BB6A), Color(0xFF43A047)];
    }
  }

  _DayMoodData? _getMoodDataForDate(DateTime date) {
    final key = '${date.year}-${date.month}-${date.day}';
    return _moodCache[key];
  }

  void _navigateToDiary(DateTime date) {
    // Call the callback to notify parent to switch tabs and load date
    if (widget.onDateSelected != null) {
      widget.onDateSelected!(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, theme),

            // Static day header
            _buildDayHeader(theme),

            // Scrollable calendar months
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 80,
                ),
                itemCount: 12,
                cacheExtent: 3000,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: true,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  return _MonthSection(
                    key: ValueKey('month_${_monthsData[index].month}'),
                    monthData: _monthsData[index],
                    getMoodData: _getMoodDataForDate,
                    theme: theme,
                    displayMode: _displayMode,
                    onDateTap: _navigateToDiary,
                  );
                },
              ),
            ),

            // Mode selector at bottom
            _buildModeSelector(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildDayHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        children: [
          Expanded(child: _DayLabel('M')),
          Expanded(child: _DayLabel('T')),
          Expanded(child: _DayLabel('W')),
          Expanded(child: _DayLabel('T')),
          Expanded(child: _DayLabel('F')),
          Expanded(child: _DayLabel('S')),
          Expanded(child: _DayLabel('S')),
        ],
      ),
    );
  }

  Widget _buildModeSelector(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildModeButton(
              icon: Icons.stop_rounded,
              label: 'Solid',
              mode: DisplayMode.solid,
              theme: theme,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildModeButton(
              icon: Icons.circle_outlined,
              label: 'Circle',
              mode: DisplayMode.circle,
              theme: theme,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildModeButton(
              icon: Icons.gradient_rounded,
              label: 'Gradient',
              mode: DisplayMode.gradient,
              theme: theme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required IconData icon,
    required String label,
    required DisplayMode mode,
    required ThemeData theme,
  }) {
    final isSelected = _displayMode == mode;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _displayMode = mode;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.15)
                : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(
              color: theme.colorScheme.primary,
              width: 2,
            )
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color:
                isSelected ? theme.colorScheme.primary : Colors.grey[600],
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color:
                  isSelected ? theme.colorScheme.primary : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Calendar',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Year $currentYear',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Const widget for day labels
class _DayLabel extends StatelessWidget {
  final String day;

  const _DayLabel(this.day);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        day,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
        ),
      ),
    );
  }
}

// Pre-calculated month data
class _MonthData {
  final int month;
  final int year;
  final List<DateTime> days;
  final int startingWeekday;
  final String monthName;

  _MonthData({
    required this.month,
    required this.year,
    required this.days,
    required this.startingWeekday,
    required this.monthName,
  });
}

// Cached mood data per day
class _DayMoodData {
  final DateTime date;
  final List<MoodEntry> entries;
  double averageMood = 0;
  String emoji = '';
  Color solidColor = Colors.grey;
  List<Color> gradientColors = [];

  _DayMoodData({
    required this.date,
    required this.entries,
  });
}

// Optimized month section widget
class _MonthSection extends StatelessWidget {
  final _MonthData monthData;
  final _DayMoodData? Function(DateTime) getMoodData;
  final ThemeData theme;
  final DisplayMode displayMode;
  final Function(DateTime) onDateTap;

  const _MonthSection({
    super.key,
    required this.monthData,
    required this.getMoodData,
    required this.theme,
    required this.displayMode,
    required this.onDateTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Month header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              monthData.monthName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),

          // Calendar grid
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _CalendarGrid(
              monthData: monthData,
              getMoodData: getMoodData,
              theme: theme,
              displayMode: displayMode,
              onDateTap: onDateTap,
            ),
          ),
        ],
      ),
    );
  }
}

// Optimized calendar grid
class _CalendarGrid extends StatelessWidget {
  final _MonthData monthData;
  final _DayMoodData? Function(DateTime) getMoodData;
  final ThemeData theme;
  final DisplayMode displayMode;
  final Function(DateTime) onDateTap;

  const _CalendarGrid({
    required this.monthData,
    required this.getMoodData,
    required this.theme,
    required this.displayMode,
    required this.onDateTap,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    int dayIndex = 0;

    final totalDays = monthData.startingWeekday + monthData.days.length;
    final totalWeeks = (totalDays / 7).ceil();

    final today = DateTime.now();

    for (int week = 0; week < totalWeeks; week++) {
      final weekCells = <Widget>[];

      for (int weekday = 0; weekday < 7; weekday++) {
        final cellIndex = week * 7 + weekday;

        if (cellIndex < monthData.startingWeekday) {
          weekCells.add(
            const Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: SizedBox.shrink(),
              ),
            ),
          );
        } else if (dayIndex < monthData.days.length) {
          final date = monthData.days[dayIndex];
          final isToday = date.year == today.year &&
              date.month == today.month &&
              date.day == today.day;

          weekCells.add(
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: _DayCell(
                  date: date,
                  isToday: isToday,
                  moodData: getMoodData(date),
                  theme: theme,
                  displayMode: displayMode,
                  onTap: onDateTap,
                ),
              ),
            ),
          );
          dayIndex++;
        } else {
          weekCells.add(
            const Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: SizedBox.shrink(),
              ),
            ),
          );
        }
      }

      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: weekCells),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }
}

// Highly optimized day cell with tap functionality
class _DayCell extends StatelessWidget {
  final DateTime date;
  final bool isToday;
  final _DayMoodData? moodData;
  final ThemeData theme;
  final DisplayMode displayMode;
  final Function(DateTime) onTap;

  const _DayCell({
    required this.date,
    required this.isToday,
    required this.moodData,
    required this.theme,
    required this.displayMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasEntry = moodData != null;

    return GestureDetector(
      onTap: hasEntry ? () => onTap(date) : null,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: displayMode == DisplayMode.circle
            ? _buildCircleMode(hasEntry)
            : displayMode == DisplayMode.gradient
            ? _buildGradientMode(hasEntry)
            : _buildSolidMode(hasEntry),
      ),
    );
  }

  Widget _buildSolidMode(bool hasEntry) {
    final moodColor = hasEntry ? moodData!.solidColor : const Color(0xFFF5F5F5);
    final moodEmoji = hasEntry ? moodData!.emoji : '';

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: moodColor,
        borderRadius: BorderRadius.circular(8),
        border: isToday
            ? Border.all(
          color: theme.colorScheme.primary,
          width: 2,
        )
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
              color: hasEntry ? Colors.grey[800] : Colors.grey[400],
            ),
          ),
          if (hasEntry) ...[
            const SizedBox(height: 2),
            Text(
              moodEmoji,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCircleMode(bool hasEntry) {
    final borderColor =
    hasEntry ? moodData!.solidColor.withValues(alpha: 1.0) : const Color(0xFFE0E0E0);

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isToday ? theme.colorScheme.primary : borderColor,
          width: isToday ? 3 : 4,
        ),
        color: isToday
            ? theme.colorScheme.primary.withValues(alpha: 0.05)
            : Colors.transparent,
      ),
      child: Center(
        child: Text(
          '${date.day}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: hasEntry ? Colors.grey[800] : Colors.grey[400],
          ),
        ),
      ),
    );
  }

  Widget _buildGradientMode(bool hasEntry) {
    final gradientColors = hasEntry
        ? moodData!.gradientColors
        : const [Color(0xFFEEEEEE), Color(0xFFE0E0E0)];
    final moodEmoji = hasEntry ? moodData!.emoji : '';

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: isToday
            ? Border.all(
          color: theme.colorScheme.primary,
          width: 2,
        )
            : null,
        boxShadow: hasEntry
            ? [
          BoxShadow(
            color: gradientColors[0].withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
              color: hasEntry ? Colors.white : Colors.grey[500],
            ),
          ),
          if (hasEntry) ...[
            const SizedBox(height: 2),
            Text(
              moodEmoji,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}