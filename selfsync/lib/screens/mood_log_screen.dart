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
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _currentMoodRating = 5;
  bool _isInputExpanded = false;
  bool _isKeyboardVisible = false;
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
  final Map<String, GlobalKey> _dateKeys = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
  void didChangeMetrics() {
    super.didChangeMetrics();
    final bottomInset = WidgetsBinding.instance.platformDispatcher.views.first.viewInsets.bottom;

    // Keyboard is visible if bottom inset > 0
    final isKeyboardNowVisible = bottomInset > 0;

    if (_isKeyboardVisible != isKeyboardNowVisible) {
      setState(() {
        _isKeyboardVisible = isKeyboardNowVisible;
      });

      if (_isKeyboardVisible) {
        // Keyboard is opening - wait for it to finish before showing slider
        AppLogger.debug('Keyboard opening - waiting to show slider', tag: 'MoodLog');
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _isKeyboardVisible && _messageController.text.isEmpty) {
            setState(() {
              _isInputExpanded = true;
            });
          }
        });
      } else {
        // Keyboard is closing - hide slider immediately
        AppLogger.debug('Keyboard closing - hiding slider', tag: 'MoodLog');
        setState(() {
          _isInputExpanded = false;
        });
      }
    }
  }

  @override
  void dispose() {
    AppLogger.lifecycle('MoodLogScreen disposing', tag: 'MoodLog');
    WidgetsBinding.instance.removeObserver(this);
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
    final dateKey = DateFormat('yyyy-MM-dd').format(date);

    if (_dateKeys.containsKey(dateKey)) {
      final context = _dateKeys[dateKey]!.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    }

    _fadeController.forward();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) {
      AppLogger.warning('Attempted to send empty message', tag: 'MoodLog');
      return;
    }

    final message = _messageController.text.trim();
    final rating = _currentMoodRating;

    AppLogger.data('Adding mood entry',
        details: 'Rating: $rating, Message length: ${message.length}',
        tag: 'MoodLog'
    );

    // Add mood entry using MoodService
    widget.moodService.addEntry(message, rating);
    AppLogger.success('Mood entry added successfully', tag: 'MoodLog');

    // Clear input and reset state
    _messageController.clear();
    setState(() {
      _isInputExpanded = false;
      _currentMoodRating = 5;
    });

    // Provide haptic feedback
    HapticFeedback.mediumImpact();

    // Scroll to bottom to show new entry
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Color _getMoodColor(int rating) {
    if (rating <= 3) {
      return Colors.red;
    } else if (rating <= 5) {
      return Colors.orange;
    } else if (rating <= 7) {
      return Colors.yellow.shade700;
    } else {
      return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isToday = _selectedStartDate == null ||
        (_selectedStartDate!.year == now.year &&
            _selectedStartDate!.month == now.month &&
            _selectedStartDate!.day == now.day);

    return GestureDetector(
      // CRITICAL: Dismiss keyboard when tapping outside
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(theme),

              // Calendar area
              SizeTransition(
                sizeFactor: CurvedAnimation(
                  parent: _calendarExpandController,
                  curve: Curves.easeInOutCubic,
                ),
                child: _buildCalendarArea(theme),
              ),

              // Main content
              Expanded(
                child: _buildMessageList(theme),
              ),

              // Input area - only show for current day
              if (isToday)
                _buildInputArea(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top row with hamburger and title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    // Dismiss keyboard before opening drawer
                    FocusScope.of(context).unfocus();
                    setState(() {
                      _isInputExpanded = false;
                    });
                    widget.drawerController.open();
                  },
                  child: const Icon(Icons.menu_rounded),
                ),
                const SizedBox(width: 16),
                const Text('💜', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Mood Diary',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom row with centered calendar button
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Center(
              child: GestureDetector(
                onTap: () {
                  // Dismiss keyboard before toggling calendar
                  FocusScope.of(context).unfocus();
                  setState(() {
                    _isInputExpanded = false;
                    if (_isCalendarExpanded) {
                      _calendarExpandController.reverse();
                      _isCalendarExpanded = false;
                      _closePickers();
                    } else {
                      _calendarExpandController.forward();
                      _isCalendarExpanded = true;
                    }
                  });
                },
                child: AnimatedRotation(
                  turns: _isCalendarExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    Icons.expand_more_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarArea(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Month/Year selector
          _buildMonthYearSelector(theme),

          // Month picker
          SizeTransition(
            sizeFactor: CurvedAnimation(
              parent: _monthPickerController,
              curve: Curves.easeInOutCubic,
            ),
            child: _isMonthPickerVisible ? _buildMonthPicker(theme) : const SizedBox.shrink(),
          ),

          // Year picker
          SizeTransition(
            sizeFactor: CurvedAnimation(
              parent: _yearPickerController,
              curve: Curves.easeInOutCubic,
            ),
            child: _isYearPickerVisible ? _buildYearPicker(theme) : const SizedBox.shrink(),
          ),

          // Calendar grid
          if (!_isMonthPickerVisible && !_isYearPickerVisible)
            _buildCalendarGrid(theme),

          // Selected date range display
          if (_selectedStartDate != null)
            _buildSelectedDateDisplay(theme),
        ],
      ),
    );
  }

  Widget _buildMonthYearSelector(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Month selector button
          GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
              setState(() {
                _isInputExpanded = false;
              });
              _showMonthPicker();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _isMonthPickerVisible
                    ? theme.colorScheme.primary.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('MMMM').format(_selectedCalendarMonth),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _isMonthPickerVisible
                          ? theme.colorScheme.primary
                          : null,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _isMonthPickerVisible ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: _isMonthPickerVisible
                        ? theme.colorScheme.primary
                        : null,
                  ),
                ],
              ),
            ),
          ),

          // Year selector button
          GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
              setState(() {
                _isInputExpanded = false;
              });
              _showYearPicker();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _isYearPickerVisible
                    ? theme.colorScheme.primary.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_selectedCalendarMonth.year}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _isYearPickerVisible
                          ? theme.colorScheme.primary
                          : null,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _isYearPickerVisible ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: _isYearPickerVisible
                        ? theme.colorScheme.primary
                        : null,
                  ),
                ],
              ),
            ),
          ),

          // Close picker button
          if (_isMonthPickerVisible || _isYearPickerVisible)
            IconButton(
              onPressed: () {
                FocusScope.of(context).unfocus();
                setState(() {
                  _isInputExpanded = false;
                });
                _closePickers();
              },
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Close picker',
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildMonthPicker(ThemeData theme) {
    return Container(
      height: 200,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListWheelScrollView.useDelegate(
        controller: _monthScrollController,
        itemExtent: 50,
        perspective: 0.005,
        diameterRatio: 1.2,
        physics: const FixedExtentScrollPhysics(),
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, index) {
            if (index < 0 || index >= _availableMonths.length) return null;
            final month = _availableMonths[index];
            final isSelected = month.month == _selectedCalendarMonth.month &&
                month.year == _selectedCalendarMonth.year;

            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedCalendarMonth = month;
                  _closePickers();
                });
              },
              child: Center(
                child: Text(
                  DateFormat('MMMM yyyy').format(month),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            );
          },
          childCount: _availableMonths.length,
        ),
      ),
    );
  }

  Widget _buildYearPicker(ThemeData theme) {
    return Container(
      height: 200,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListWheelScrollView.useDelegate(
        controller: _yearScrollController,
        itemExtent: 50,
        perspective: 0.005,
        diameterRatio: 1.2,
        physics: const FixedExtentScrollPhysics(),
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, index) {
            if (index < 0 || index >= _availableYears.length) return null;
            final year = _availableYears[index];
            final isSelected = year == _selectedCalendarMonth.year;

            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedCalendarMonth = DateTime(_availableYears[index], _selectedCalendarMonth.month);
                  _closePickers();
                });
              },
              child: Center(
                child: Text(
                  '$year',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            );
          },
          childCount: _availableYears.length,
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(ThemeData theme) {
    final firstDayOfMonth = DateTime(_selectedCalendarMonth.year, _selectedCalendarMonth.month, 1);
    final lastDayOfMonth = DateTime(_selectedCalendarMonth.year, _selectedCalendarMonth.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final startingWeekday = firstDayOfMonth.weekday % 7;

    // Get mood entries for this month
    final monthEntries = widget.moodService.entries.where((entry) {
      return entry.timestamp.year == _selectedCalendarMonth.year &&
          entry.timestamp.month == _selectedCalendarMonth.month;
    }).toList();

    // Create a map of day -> average mood
    final dayMoodMap = <int, double>{};
    for (var entry in monthEntries) {
      final day = entry.timestamp.day;
      if (!dayMoodMap.containsKey(day)) {
        dayMoodMap[day] = 0;
      }
      dayMoodMap[day] = dayMoodMap[day]! + entry.moodRating;
    }

    // Calculate averages
    final dayCountMap = <int, int>{};
    for (var entry in monthEntries) {
      final day = entry.timestamp.day;
      dayCountMap[day] = (dayCountMap[day] ?? 0) + 1;
    }
    for (var day in dayMoodMap.keys) {
      dayMoodMap[day] = dayMoodMap[day]! / dayCountMap[day]!;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Weekday headers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          // Calendar days
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: 42, // 6 rows * 7 days
            itemBuilder: (context, index) {
              final dayNumber = index - startingWeekday + 1;

              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox.shrink();
              }

              final date = DateTime(_selectedCalendarMonth.year, _selectedCalendarMonth.month, dayNumber);
              final isToday = date.year == DateTime.now().year &&
                  date.month == DateTime.now().month &&
                  date.day == DateTime.now().day;
              final hasMoodData = dayMoodMap.containsKey(dayNumber);
              final avgMood = dayMoodMap[dayNumber];

              final isSelected = _selectedStartDate != null &&
                  date.year == _selectedStartDate!.year &&
                  date.month == _selectedStartDate!.month &&
                  date.day == _selectedStartDate!.day;

              final isInRange = _selectedStartDate != null &&
                  _selectedEndDate != null &&
                  date.isAfter(_selectedStartDate!) &&
                  date.isBefore(_selectedEndDate!);

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (_selectedStartDate == null) {
                      _selectedStartDate = date;
                      _selectedEndDate = null;
                    } else if (_selectedEndDate == null) {
                      if (date.isBefore(_selectedStartDate!)) {
                        _selectedEndDate = _selectedStartDate;
                        _selectedStartDate = date;
                      } else {
                        _selectedEndDate = date;
                      }
                    } else {
                      _selectedStartDate = date;
                      _selectedEndDate = null;
                    }
                  });

                  _loadDateRange(_selectedStartDate, _selectedEndDate);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected || isInRange
                        ? theme.colorScheme.primary.withValues(alpha: 0.2)
                        : hasMoodData
                        ? _getMoodColor(avgMood!.round()).withValues(alpha: 0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isToday
                        ? Border.all(
                      color: theme.colorScheme.primary,
                      width: 2,
                    )
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '$dayNumber',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : hasMoodData
                            ? _getMoodColor(avgMood!.round())
                            : theme.colorScheme.onSurface.withValues(alpha: 0.6),
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

  Widget _buildSelectedDateDisplay(ThemeData theme) {
    String dateText;
    if (_selectedEndDate != null) {
      dateText = '${DateFormat('MMM d').format(_selectedStartDate!)} - ${DateFormat('MMM d, yyyy').format(_selectedEndDate!)}';
    } else {
      dateText = DateFormat('MMMM d, yyyy').format(_selectedStartDate!);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              dateText,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _selectedStartDate = null;
                _selectedEndDate = null;
              });
              _loadDateRange(null, null);
            },
            icon: Icon(
              Icons.close_rounded,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Clear selection',
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(ThemeData theme) {
    List<MoodEntry> entriesToShow;

    if (_selectedStartDate != null) {
      // Filter entries based on selection
      if (_selectedEndDate != null) {
        // Date range
        entriesToShow = widget.moodService.entries.where((entry) {
          final entryDate = DateTime(entry.timestamp.year, entry.timestamp.month, entry.timestamp.day);
          final start = DateTime(_selectedStartDate!.year, _selectedStartDate!.month, _selectedStartDate!.day);
          final end = DateTime(_selectedEndDate!.year, _selectedEndDate!.month, _selectedEndDate!.day);
          return (entryDate.isAtSameMomentAs(start) ||
              entryDate.isAfter(start)) &&
              (entryDate.isAtSameMomentAs(end) ||
                  entryDate.isBefore(end));
        }).toList();
      } else {
        // Single date
        entriesToShow = widget.moodService.entries.where((entry) {
          return entry.timestamp.year == _selectedStartDate!.year &&
              entry.timestamp.month == _selectedStartDate!.month &&
              entry.timestamp.day == _selectedStartDate!.day;
        }).toList();
      }
    } else {
      // Show all entries
      entriesToShow = widget.moodService.entries;
    }

    if (entriesToShow.isEmpty) {
      return _buildEmptyState(theme);
    }

    // Group entries by date
    final groupedEntries = <String, List<MoodEntry>>{};
    for (var entry in entriesToShow) {
      final dateKey = DateFormat('yyyy-MM-dd').format(entry.timestamp);
      if (!groupedEntries.containsKey(dateKey)) {
        groupedEntries[dateKey] = [];
        _dateKeys[dateKey] = GlobalKey();
      }
      groupedEntries[dateKey]!.add(entry);
    }

    // Sort date keys in chronological order (OLDEST first) so newest appears at bottom
    final sortedDateKeys = groupedEntries.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    return FadeTransition(
      opacity: _fadeController,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: sortedDateKeys.length,
        itemBuilder: (context, index) {
          final dateKey = sortedDateKeys[index];
          final entries = groupedEntries[dateKey]!;
          final date = DateTime.parse(dateKey);

          return Container(
            key: _dateKeys[dateKey],
            margin: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date header
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _formatDateHeader(date),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),

                // Entries for this date
                ...entries.map((entry) => _buildMessageBubble(entry, theme)),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final entryDate = DateTime(date.year, date.month, date.day);

    if (entryDate == today) {
      return 'Today';
    } else if (entryDate == yesterday) {
      return 'Yesterday';
    } else if (entryDate.year == today.year) {
      return DateFormat('MMMM d').format(date);
    } else {
      return DateFormat('MMMM d, yyyy').format(date);
    }
  }

  Widget _buildMessageBubble(MoodEntry entry, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
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
        children: [
          Row(
            children: [
              // Mood emoji
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getMoodColor(entry.moodRating).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  MoodEntry.getMoodEmoji(entry.moodRating),
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: 12),

              // Mood info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${entry.moodRating}/10',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _getMoodColor(entry.moodRating),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getMoodColor(entry.moodRating)
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            MoodEntry.getMoodLabel(entry.moodRating),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _getMoodColor(entry.moodRating),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 4),
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

          if (entry.message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                entry.message,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
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
    return GestureDetector(
      // Prevent taps inside input area from dismissing keyboard
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
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
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mood slider - animated height
              ClipRect(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  height: _isInputExpanded ? 80 : 0,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _isInputExpanded ? 1 : 0,
                    child: _isInputExpanded
                        ? SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: SizedBox(
                        height: 80,
                        child: Row(
                          children: [
                            Text(
                              MoodEntry.getMoodEmoji(_currentMoodRating),
                              style: const TextStyle(fontSize: 32),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
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
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: _getMoodColor(_currentMoodRating),
                                      inactiveTrackColor: _getMoodColor(_currentMoodRating)
                                          .withValues(alpha: 0.2),
                                      thumbColor: _getMoodColor(_currentMoodRating),
                                      overlayColor: _getMoodColor(_currentMoodRating)
                                          .withValues(alpha: 0.3),
                                      trackHeight: 4.0,
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 10.0,
                                      ),
                                      overlayShape: const RoundSliderOverlayShape(
                                        overlayRadius: 20.0,
                                      ),
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
                                        HapticFeedback.selectionClick();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),

              // Text input row
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
        ),
      ),
    );
  }
}