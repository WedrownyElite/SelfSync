import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/mood_entry.dart';
import '../services/mood_service.dart';
import '../widgets/side_drawer.dart';
import '../utils/app_logger.dart';
import '../services/theme_service.dart';

class MoodLogScreen extends StatefulWidget {
  final MoodService moodService;
  final DateTime? initialDate;
  final SideDrawerController drawerController;
  final ThemeService themeService;

  const MoodLogScreen({
    super.key,
    required this.moodService,
    this.initialDate,
    required this.drawerController,
    required this.themeService,
  });

  @override
  State<MoodLogScreen> createState() => _MoodLogScreenState();
}

class _MoodLogScreenState extends State<MoodLogScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _currentMoodRating = 5;
  bool _isInputExpanded = false;
  late AnimationController _fadeController;
  late AnimationController _calendarExpandController;

  // Calendar state
  bool _isCalendarExpanded = false;
  DateTime _selectedCalendarMonth = DateTime.now();

  // Date range selection
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;

  // Month/Year picker state
  bool _isMonthPickerVisible = false;
  bool _isYearPickerVisible = false;
  late AnimationController _monthPickerController;
  late AnimationController _yearPickerController;
  late AnimationController _itemScaleController;
  final ScrollController _monthScrollController = ScrollController();
  final ScrollController _yearScrollController = ScrollController();

  // Available dates with mood data
  List<DateTime> _availableMonths = [];
  List<int> _availableYears = [];

  // Date navigation
  bool _isJumpingToDate = false;
  final Map<String, GlobalKey> _dateKeys = {};

  @override
  void initState() {
    super.initState();
    AppLogger.lifecycle('MoodLogScreen initialized', tag: 'MoodLog');
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _calendarExpandController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _monthPickerController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _yearPickerController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _itemScaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    // Calculate available months and years from mood data
    _calculateAvailableDates();
    AppLogger.data('Available dates calculated',
        details: '${_availableMonths.length} months, ${_availableYears.length} years',
        tag: 'MoodLog'
    );

    // If we have an initial date, scroll to it
    if (widget.initialDate != null) {
      AppLogger.info(
          'Opening with initial date: ${DateFormat('yyyy-MM-dd').format(widget.initialDate!)}',
          tag: 'MoodLog'
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToDate(widget.initialDate!);
      });
    } else {
      // Start animations and scroll to bottom to show most recent messages
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fadeController.forward();
        // Scroll to bottom after a short delay to ensure list is built
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      });
    }

    widget.moodService.addListener(_onMoodServiceUpdate);
    AppLogger.debug('Listening to MoodService updates', tag: 'MoodLog');
  }

  void _calculateAvailableDates() {
    final entries = widget.moodService.entries;
    if (entries.isEmpty) {
      // Default to current month/year if no entries
      _availableMonths = [DateTime.now()];
      _availableYears = [DateTime.now().year];
      return;
    }

    // Get all unique months with data
    final monthsSet = <String>{};
    final yearsSet = <int>{};

    for (var entry in entries) {
      final monthKey = DateFormat('yyyy-MM').format(entry.timestamp);
      monthsSet.add(monthKey);
      yearsSet.add(entry.timestamp.year);
    }

    // Add current month even if no data
    monthsSet.add(DateFormat('yyyy-MM').format(DateTime.now()));
    yearsSet.add(DateTime.now().year);

    // Convert to sorted list of DateTimes
    _availableMonths = monthsSet.map((key) {
      final parts = key.split('-');
      return DateTime(int.parse(parts[0]), int.parse(parts[1]));
    }).toList()..sort((a, b) => b.compareTo(a)); // Newest first

    _availableYears = yearsSet.toList()..sort((a, b) => b.compareTo(a));
  }

  void _showMonthPicker() {
    HapticFeedback.lightImpact();
    AppLogger.debug('Opening month picker', tag: 'MoodLog.Calendar');
    setState(() {
      _isMonthPickerVisible = true;
      _isYearPickerVisible = false;
    });
    _monthPickerController.forward();
    _yearPickerController.reverse();
  }

  void _showYearPicker() {
    HapticFeedback.lightImpact();
    AppLogger.debug('Opening year picker', tag: 'MoodLog.Calendar');
    setState(() {
      _isYearPickerVisible = true;
      _isMonthPickerVisible = false;
    });
    _yearPickerController.forward();
    _monthPickerController.reverse();
  }

  void _closePickers() {
    AppLogger.debug('Closing date pickers', tag: 'MoodLog.Calendar');
    setState(() {
      _isMonthPickerVisible = false;
      _isYearPickerVisible = false;
    });
    _monthPickerController.reverse();
    _yearPickerController.reverse();
  }

  @override
  void dispose() {
    AppLogger.lifecycle('MoodLogScreen disposing', tag: 'MoodLog');
    _messageController.dispose();
    _scrollController.dispose();
    _fadeController.dispose();
    _calendarExpandController.dispose();
    _monthPickerController.dispose();
    _yearPickerController.dispose();
    _itemScaleController.dispose();
    _monthScrollController.dispose();
    _yearScrollController.dispose();
    widget.moodService.removeListener(_onMoodServiceUpdate);
    super.dispose();
  }

  void _onMoodServiceUpdate() {
    AppLogger.debug('MoodService update received, recalculating dates', tag: 'MoodLog');
    _calculateAvailableDates();
    if (mounted) setState(() {});
  }

  void _loadDateRange(DateTime? startDate, DateTime? endDate) {
    // Log date range selection
    if (startDate != null && endDate != null) {
      AppLogger.data('Date range selected',
          details: '${DateFormat('yyyy-MM-dd').format(startDate)} to ${DateFormat('yyyy-MM-dd').format(endDate)}',
          tag: 'MoodLog.Calendar'
      );
    } else if (startDate != null) {
      AppLogger.data('Single date selected',
          details: DateFormat('yyyy-MM-dd').format(startDate),
          tag: 'MoodLog.Calendar'
      );
    } else {
      AppLogger.debug('Date selection cleared', tag: 'MoodLog.Calendar');
    }
  }

  void _scrollToDate(DateTime date) {
    AppLogger.debug(
        'Scrolling to date: ${DateFormat('yyyy-MM-dd').format(date)}',
        tag: 'MoodLog'
    );
    _isJumpingToDate = true;
    final dateKey = DateFormat('yyyy-MM-dd').format(date);

    if (_dateKeys.containsKey(dateKey)) {
      final context = _dateKeys[dateKey]!.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        ).then((_) {
          _isJumpingToDate = false;
        });
      }
    }

    _fadeController.forward();
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) {
      AppLogger.warning('Attempted to send empty message', tag: 'MoodLog');
      return;
    }

    final message = _messageController.text.trim();
    final rating = _currentMoodRating;

    AppLogger.separator(label: 'MOOD ENTRY SUBMISSION');
    AppLogger.data('Creating mood entry',
        details: 'Rating: $rating/10, Message length: ${message.length} chars',
        tag: 'MoodLog'
    );

    widget.moodService.addEntry(
      _messageController.text.trim(),
      _currentMoodRating,
    );

    _messageController.clear();
    setState(() {
      _isInputExpanded = false;
    });

    // Scroll to bottom to show new entry (chat style)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Color _getMoodColor(int rating) {
    return getMoodColorFromRating(rating, widget.themeService.getMoodGradient());
  }

  Map<String, List<MoodEntry>> _groupEntriesByDate() {
    final grouped = <String, List<MoodEntry>>{};
    for (var entry in widget.moodService.entries) {
      final dateKey = DateFormat('yyyy-MM-dd').format(entry.timestamp);
      grouped.putIfAbsent(dateKey, () => []).add(entry);
    }
    // Sort entries within each date group (oldest first within the day)
    grouped.forEach((key, entries) {
      entries.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    });
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final groupedEntries = _groupEntriesByDate();
    final sortedDates = groupedEntries.keys.toList();

    // Check if user is viewing today or a filtered date
    final isViewingToday = _selectedStartDate == null && _selectedEndDate == null;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(theme, sortedDates),
                _buildCalendar(theme), // Always render for smooth animation
                Expanded(
                  child: _buildMessageList(theme, groupedEntries, sortedDates),
                ),
                // Animated input area - only visible when viewing today
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return SizeTransition(
                      sizeFactor: animation,
                      axisAlignment: -1.0,
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    );
                  },
                  child: isViewingToday
                      ? _buildInputArea(theme)
                      : const SizedBox.shrink(),
                ),
              ],
            ),

            // Month Picker Overlay
            if (_isMonthPickerVisible || _monthPickerController.isAnimating)
              _buildPickerOverlay(
                theme: theme,
                size: size,
                controller: _monthPickerController,
                items: _availableMonths,
                scrollController: _monthScrollController,
                isMonth: true,
              ),

            // Year Picker Overlay
            if (_isYearPickerVisible || _yearPickerController.isAnimating)
              _buildPickerOverlay(
                theme: theme,
                size: size,
                controller: _yearPickerController,
                items: _availableYears,
                scrollController: _yearScrollController,
                isMonth: false,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerOverlay({
    required ThemeData theme,
    required Size size,
    required AnimationController controller,
    required List<dynamic> items,
    required ScrollController scrollController,
    required bool isMonth,
  }) {
    // Create a FixedExtentScrollController for the wheel
    final wheelController = FixedExtentScrollController(
      initialItem: isMonth
          ? _availableMonths.indexWhere((m) =>
      m.year == _selectedCalendarMonth.year &&
          m.month == _selectedCalendarMonth.month)
          : _availableYears.indexOf(_selectedCalendarMonth.year),
    );

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onTap: _closePickers,
            child: Container(
              color: Colors.black.withValues(alpha: 0.5 * controller.value),
              child: Center(
                child: Transform.scale(
                  scale: 0.9 + (0.1 * controller.value),
                  child: Opacity(
                    opacity: controller.value,
                    child: Container(
                      width: size.width * 0.75,
                      height: 250,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Header bar
                          Container(
                            height: 50,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey.withValues(alpha: 0.2),
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isMonth ? 'Select Month' : 'Select Year',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    HapticFeedback.mediumImpact();
                                    final selectedIndex = wheelController.selectedItem;

                                    if (selectedIndex >= 0 && selectedIndex < items.length) {
                                      setState(() {
                                        if (isMonth) {
                                          final selectedMonth = items[selectedIndex] as DateTime;
                                          _selectedCalendarMonth = DateTime(
                                            selectedMonth.year,
                                            selectedMonth.month,
                                            _selectedCalendarMonth.day,
                                          );
                                        } else {
                                          _selectedCalendarMonth = DateTime(
                                            items[selectedIndex] as int,
                                            _selectedCalendarMonth.month,
                                            _selectedCalendarMonth.day,
                                          );
                                        }
                                      });
                                    }

                                    _closePickers();
                                    _scrollToDate(_selectedCalendarMonth);
                                  },
                                  child: Text(
                                    'Done',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Wheel picker
                          Expanded(
                            child: Stack(
                              children: [
                                // Selection indicator
                                Center(
                                  child: Container(
                                    height: 40,
                                    margin: const EdgeInsets.symmetric(horizontal: 30),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),

                                // ListWheelScrollView
                                ListWheelScrollView.useDelegate(
                                  controller: wheelController,
                                  itemExtent: 40,
                                  diameterRatio: 1.5,
                                  perspective: 0.003,
                                  physics: const FixedExtentScrollPhysics(),
                                  onSelectedItemChanged: (_) {
                                    HapticFeedback.selectionClick();
                                  },
                                  childDelegate: ListWheelChildBuilderDelegate(
                                    builder: (context, index) {
                                      if (index < 0 || index >= items.length) {
                                        return null;
                                      }

                                      final item = items[index];
                                      return Center(
                                        child: Text(
                                          isMonth
                                              ? DateFormat('MMMM yyyy').format(item as DateTime)
                                              : item.toString(),
                                          style: theme.textTheme.bodyLarge?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      );
                                    },
                                    childCount: items.length,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(ThemeData theme, List<String> sortedDates) {
    final entryCount = widget.moodService.entries.length;

    return FadeTransition(
      opacity: _fadeController,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface, // White surface to match app theme
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    HamburgerMenuButton(controller: widget.drawerController),
                    const SizedBox(width: 12),
                    Text(
                      'Mood Diary',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$entryCount ${entryCount == 1 ? 'entry' : 'entries'}',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                // Calendar expand button at bottom center
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isCalendarExpanded = !_isCalendarExpanded;
                    });
                    if (_isCalendarExpanded) {
                      _calendarExpandController.forward();
                    } else {
                      _calendarExpandController.reverse();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: AnimatedRotation(
                      turns: _isCalendarExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(ThemeData theme) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      child: SizeTransition(
        sizeFactor: CurvedAnimation(
          parent: _calendarExpandController,
          curve: Curves.easeOutCubic,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface, // White surface to match app theme
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.1),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Month/Year selector with tappable elements
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // Previous month button
                    IconButton(
                      onPressed: () {
                        final currentIndex = _availableMonths.indexWhere((m) =>
                        m.year == _selectedCalendarMonth.year &&
                            m.month == _selectedCalendarMonth.month
                        );

                        if (currentIndex < _availableMonths.length - 1) {
                          setState(() {
                            _selectedCalendarMonth = _availableMonths[currentIndex + 1];
                          });
                        }
                      },
                      icon: const Icon(Icons.chevron_left_rounded),
                      color: theme.colorScheme.primary,
                    ),

                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Tappable month
                          Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              onTap: _showMonthPicker,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      DateFormat('MMMM').format(_selectedCalendarMonth),
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_drop_down_rounded,
                                      color: theme.colorScheme.primary,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Tappable year
                          Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              onTap: _showYearPicker,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _selectedCalendarMonth.year.toString(),
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_drop_down_rounded,
                                      color: theme.colorScheme.primary,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Next month button
                    IconButton(
                      onPressed: () {
                        final currentIndex = _availableMonths.indexWhere((m) =>
                        m.year == _selectedCalendarMonth.year &&
                            m.month == _selectedCalendarMonth.month
                        );

                        if (currentIndex > 0) {
                          setState(() {
                            _selectedCalendarMonth = _availableMonths[currentIndex - 1];
                          });
                        }
                      },
                      icon: const Icon(Icons.chevron_right_rounded),
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),

              // Calendar grid
              _buildCalendarGrid(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(ThemeData theme) {
    final daysInMonth = DateTime(
      _selectedCalendarMonth.year,
      _selectedCalendarMonth.month + 1,
      0,
    ).day;

    final firstDayOfWeek = DateTime(
      _selectedCalendarMonth.year,
      _selectedCalendarMonth.month,
      1,
    ).weekday;

    return Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
          // Range selection toggle
          Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedStartDate != null && _selectedEndDate != null
                  ? '${DateFormat('MMM d').format(_selectedStartDate!)} - ${DateFormat('MMM d').format(_selectedEndDate!)}'
                  : _selectedStartDate != null
                  ? DateFormat('MMM d, yyyy').format(_selectedStartDate!)
                  : 'Select dates',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (_selectedStartDate != null || _selectedEndDate != null)
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedStartDate = null;
                    _selectedEndDate = null;
                  });
                  // Show all entries when cleared
                  _loadDateRange(null, null);
                },
                child: Text(
                  'Clear',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Day labels
        Row(
          children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
            return Expanded(
              child: Center(
                child: Text(
                  day,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),

        // Calendar days grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: 35, // 5 weeks
          itemBuilder: (context, index) {
            final dayOffset = index - firstDayOfWeek + 2;
            if (dayOffset < 1 || dayOffset > daysInMonth) {
              return const SizedBox();
            }

            final date = DateTime(
              _selectedCalendarMonth.year,
              _selectedCalendarMonth.month,
              dayOffset,
            );

            final dateKey = DateFormat('yyyy-MM-dd').format(date);
            final groupedEntries = _groupEntriesByDate();
            final hasEntries = groupedEntries.containsKey(dateKey);
            final isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == dateKey;

            // Check if date is selected or in range
            bool isSelected = false;
            bool isInRange = false;
            bool isRangeStart = false;
            bool isRangeEnd = false;

            if (_selectedStartDate != null) {
              final startDateKey = DateFormat('yyyy-MM-dd').format(_selectedStartDate!);
              isRangeStart = dateKey == startDateKey;

              if (_selectedEndDate != null) {
                final endDateKey = DateFormat('yyyy-MM-dd').format(_selectedEndDate!);
                isRangeEnd = dateKey == endDateKey;
                isInRange = date.isAfter(_selectedStartDate!) &&
                    date.isBefore(_selectedEndDate!);
              } else {
                isSelected = isRangeStart;
              }
            }

            return GestureDetector(
              onTap: () {
                setState(() {
                  if (_selectedStartDate == null) {
                    // First selection
                    _selectedStartDate = date;
                    _loadDateRange(date, null);
                  } else if (_selectedEndDate == null) {
                    // Second selection
                    if (date.isBefore(_selectedStartDate!)) {
                      // Swap if selecting earlier date
                      _selectedEndDate = _selectedStartDate;
                      _selectedStartDate = date;
                    } else if (date.isAfter(_selectedStartDate!)) {
                      _selectedEndDate = date;
                    } else {
                      // Same date clicked again - deselect
                      _selectedStartDate = null;
                      _loadDateRange(null, null);
                      return;
                    }
                    _loadDateRange(_selectedStartDate, _selectedEndDate);
                  } else {
                    // Both dates selected - check which date was tapped
                    final startDateKey = DateFormat('yyyy-MM-dd').format(
                        _selectedStartDate!);
                    final endDateKey = DateFormat('yyyy-MM-dd').format(
                        _selectedEndDate!);
                    final tappedDateKey = DateFormat('yyyy-MM-dd').format(date);

                    if (tappedDateKey == startDateKey) {
                      // Tapped start date - deselect it, keep end as new single selection
                      _selectedStartDate = _selectedEndDate;
                      _selectedEndDate = null;
                      _loadDateRange(_selectedStartDate, null);
                    } else if (tappedDateKey == endDateKey) {
                      // Tapped end date - deselect it, keep start as single selection
                      _selectedEndDate = null;
                      _loadDateRange(_selectedStartDate, null);
                    } else {
                      // Tapped a different date - start new selection
                      _selectedStartDate = date;
                      _selectedEndDate = null;
                      _loadDateRange(date, null);
                    }
                  }
                  });
                },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isRangeStart || isRangeEnd
                          ? theme.colorScheme.primary
                          : isInRange
                          ? theme.colorScheme.primary.withValues(alpha: 0.3)
                          : isSelected
                          ? theme.colorScheme.primary.withValues(alpha: 0.5)
                          : hasEntries
                          ? theme.colorScheme.primary.withValues(alpha: 0.1)
                          : isToday
                          ? theme.colorScheme.secondary.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: isToday && !isRangeStart && !isRangeEnd ? Border.all(
                        color: theme.colorScheme.secondary,
                        width: 2,
                      ) : null,
                    ),
                    child: Center(
                      child: Text(
                        dayOffset.toString(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: (isRangeStart || isRangeEnd)
                              ? FontWeight.bold
                              : hasEntries
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: (isRangeStart || isRangeEnd)
                              ? Colors.white
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            ],
            ),
            );
          }

          Widget _buildMessageList(
          ThemeData theme,
          Map<String, List<MoodEntry>> groupedEntries,
          List<String> sortedDates,
        ) {
    if (widget.moodService.entries.isEmpty) {
    return _buildEmptyState(theme);
    }

    // Filter dates based on selection
    List<String> filteredDates = sortedDates;
    if (_selectedStartDate != null) {
    if (_selectedEndDate != null) {
    // Range selected - filter dates within range
    filteredDates = sortedDates.where((dateKey) {
    final date = DateTime.parse(dateKey);
    return (date.isAtSameMomentAs(_selectedStartDate!) ||
    date.isAfter(_selectedStartDate!)) &&
    (date.isAtSameMomentAs(_selectedEndDate!) ||
    date.isBefore(_selectedEndDate!.add(const Duration(days: 1))));
    }).toList();
    } else {
    // Single date selected
    final selectedDateKey = DateFormat('yyyy-MM-dd').format(_selectedStartDate!);
    filteredDates = sortedDates.where((dateKey) => dateKey == selectedDateKey).toList();
    }
    }

    // Sort dates in ascending order (oldest first) for chat-style display
    filteredDates.sort((a, b) => a.compareTo(b));

    // Show a message if no entries in selected range
    if (filteredDates.isEmpty && (_selectedStartDate != null || _selectedEndDate != null)) {
    return Center(
    child: Padding(
    padding: const EdgeInsets.all(40),
    child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
    Icon(
    Icons.calendar_today_rounded,
    size: 48,
    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
    ),
    const SizedBox(height: 16),
    Text(
    'No entries found',
    style: theme.textTheme.titleLarge?.copyWith(
    fontWeight: FontWeight.bold,
    ),
    ),
    const SizedBox(height: 8),
    Text(
    _selectedEndDate != null
    ? 'No mood entries between\n${DateFormat('MMM d').format(_selectedStartDate!)} and ${DateFormat('MMM d').format(_selectedEndDate!)}'
        : 'No mood entries on\n${DateFormat('MMMM d, yyyy').format(_selectedStartDate!)}',
    textAlign: TextAlign.center,
    style: theme.textTheme.bodyMedium?.copyWith(
    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
    ),
    ),
    ],
    ),
    ),
    );
    }

    // Scroll to bottom after frame is built to show newest messages (only if no date filter)
    if (_selectedStartDate == null && _selectedEndDate == null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scrollController.hasClients && !_isJumpingToDate) {
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
    });
    }

    return ListView.builder(
    controller: _scrollController,
    padding: const EdgeInsets.only(top: 16, bottom: 16),
    itemCount: filteredDates.length,
    itemBuilder: (context, index) {
    final dateKey = filteredDates[index];
    final entries = groupedEntries[dateKey]!;
    final date = DateTime.parse(dateKey);

    // Create a key for this date section
    _dateKeys[dateKey] = GlobalKey();

    return FadeTransition(
    key: _dateKeys[dateKey],
    opacity: _fadeController,
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    // Date header
    Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    child: Text(
    _formatDateHeader(date),
    style: theme.textTheme.bodySmall?.copyWith(
    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
    fontWeight: FontWeight.w600,
    ),
    ),
    ),
    // Entries for this date (already sorted oldest to newest within the day)
    ...entries.map((entry) => _buildMessageBubble(theme, entry)),
    ],
    ),
    );
    },
    );
    }

        String _formatDateHeader(DateTime date) {
      final now = DateTime.now();
      final difference = now.difference(date).inDays;

      if (difference == 0) return 'Today';
      if (difference == 1) return 'Yesterday';
      if (difference < 7) return DateFormat('EEEE').format(date);
      return DateFormat('MMMM d, yyyy').format(date);
    }

    Widget _buildMessageBubble(ThemeData theme, MoodEntry entry) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Emoji avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: getMoodColorFromRating(entry.moodRating, widget.themeService.getMoodGradient()).withValues(alpha: 0.2),
                border: Border.all(
                  color: getMoodColorFromRating(entry.moodRating, widget.themeService.getMoodGradient()),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  MoodEntry.getMoodEmoji(entry.moodRating),
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Message bubble
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface, // White message bubbles as per design
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.message,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getMoodColor(entry.moodRating)
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${entry.moodRating}/10',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _getMoodColor(entry.moodRating),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('h:mm a').format(entry.timestamp),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildEmptyState(ThemeData theme) {
      return Center(
        child: FadeTransition(
          opacity: _fadeController,
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('💭', style: TextStyle(fontSize: 40)),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'No mood entries yet',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start tracking your mood by\nadding your first entry below',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget _buildInputArea(ThemeData theme) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface, // White surface to match app theme
          border: Border(
            top: BorderSide(
              color: theme.dividerColor.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: _isInputExpanded ? 80 : 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isInputExpanded ? 1 : 0,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          MoodEntry.getMoodEmoji(_currentMoodRating),
                          style: const TextStyle(fontSize: 32),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Mood: $_currentMoodRating/10',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getMoodColor(_currentMoodRating)
                                          .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      MoodEntry.getMoodLabel(_currentMoodRating),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _getMoodColor(_currentMoodRating),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: _getMoodColor(_currentMoodRating),
                                  inactiveTrackColor: _getMoodColor(_currentMoodRating)
                                      .withValues(alpha: 0.2),
                                  thumbColor: _getMoodColor(_currentMoodRating),
                                  overlayColor: _getMoodColor(_currentMoodRating)
                                      .withValues(alpha: 0.3),
                                ),
                                child: Slider(
                                  value: _currentMoodRating.toDouble(),
                                  min: 1,
                                  max: 10,
                                  divisions: 9,
                                  onChanged: (value) {
                                    setState(() {
                                      _currentMoodRating = value.round();
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'How are you feeling?',
                      filled: true,
                      fillColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        _isInputExpanded = true;
                      });
                    },
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.secondary,
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send_rounded),
                    color: theme.colorScheme.surface,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
  }