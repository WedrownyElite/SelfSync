import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/mood_entry.dart';
import '../services/mood_service.dart';
import '../widgets/side_drawer.dart';
import '../utils/app_logger.dart';
import '../services/theme_service.dart';
import '../utils/performance_test_helper.dart';

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
  bool _showScrollToBottomButton = false;
  Timer? _sliderExpansionTimer;
  bool _isDialogOpen = false;
  late AnimationController _fadeController;
  late AnimationController _calendarExpandController;

  // Commonly used formatters
  static final _dateKeyFormat = DateFormat('yyyy-MM-dd');
  static final _timeFormat = DateFormat('h:mm a');
  static final _monthYearFormat = DateFormat('yyyy-MM');
  static final _monthFormat = DateFormat('MMMM');
  static final _fullDateFormat = DateFormat('MMMM d, yyyy');
  static final _dateWithoutYearFormat = DateFormat('MMMM d');

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

  // Calendar mood data cache - stores multiple months
  final Map<String, Map<int, double>> _cachedDayMoodMap = {};

  Timer? _scrollDebounceTimer;

  // Cache variables
  Map<String, List<MoodEntry>>? _cachedGroupedEntries;
  List<String>? _cachedSortedDateKeys;
  DateTime? _lastCacheUpdate;

  // Edit state
  String? _editingEntryId;
  // ignore: unused_field
  int _editingMoodRating = 5;

  // Track newly submitted message for animation
  String? _newlySubmittedEntryId;

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

    // If we have an initial date, set it as the selected date filter
    if (widget.initialDate != null) {
      AppLogger.info(
          'Setting initial date filter: ${DateFormat('yyyy-MM-dd').format(widget.initialDate!)}',
          tag: 'MoodLog'
      );

      // Set the date as a single-day selection
      _selectedStartDate = DateTime(
        widget.initialDate!.year,
        widget.initialDate!.month,
        widget.initialDate!.day,
      );
      _selectedEndDate = null; // Single date, not a range

      // Set the calendar month to show the selected date (if user expands it)
      _selectedCalendarMonth = DateTime(
        widget.initialDate!.year,
        widget.initialDate!.month,
      );

      AppLogger.success('Date filter applied (calendar collapsed)', tag: 'MoodLog');
    }

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

    // Add scroll listener to detect if user is at bottom
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    // Cancel existing timer
    _scrollDebounceTimer?.cancel();

    // Debounce scroll updates to every 100ms
    _scrollDebounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (!mounted || !_scrollController.hasClients) return;

      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      final threshold = 200.0;

      final shouldShow = (maxScroll - currentScroll) > threshold;

      if (shouldShow != _showScrollToBottomButton) {
        setState(() {
          _showScrollToBottomButton = shouldShow;
        });
      }
    });
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
      final monthKey = _monthYearFormat.format(entry.timestamp);
      monthsSet.add(monthKey);
      yearsSet.add(entry.timestamp.year);
    }

    // Add current month even if no data
    monthsSet.add(_monthYearFormat.format(DateTime.now()));
    yearsSet.add(DateTime.now().year);

    // Convert to sorted list of DateTimes
    _availableMonths = monthsSet.map((key) {
      final parts = key.split('-');
      return DateTime(int.parse(parts[0]), int.parse(parts[1]));
    }).toList()..sort((a, b) => b.compareTo(a)); // Newest first

    _availableYears = yearsSet.toList()..sort((a, b) => b.compareTo(a));
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

    // Don't respond to metrics changes when a dialog is open
    if (_isDialogOpen) {
      return;
    }

    final bottomInset = WidgetsBinding.instance.platformDispatcher.views.first.viewInsets.bottom;

    // Keyboard is visible if bottom inset > 0
    final isKeyboardNowVisible = bottomInset > 0;

    if (_isKeyboardVisible != isKeyboardNowVisible) {
      setState(() {
        _isKeyboardVisible = isKeyboardNowVisible;
      });

      if (_isKeyboardVisible) {
        // ... timer code ...
        _sliderExpansionTimer = Timer(const Duration(milliseconds: 150), () {
          if (mounted &&
              _isKeyboardVisible &&
              _messageController.text.isEmpty &&
              _editingEntryId == null &&
              !_isDialogOpen) {
            // Use setState without animation
            if (mounted) {
              _isInputExpanded = true;
              setState(() {});
            }
          }
        });
      } else {
        // Instant hide when keyboard closes
        _sliderExpansionTimer?.cancel();
        _isInputExpanded = false;
        setState(() {});
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
    _scrollDebounceTimer?.cancel();
    _sliderExpansionTimer?.cancel();
    widget.moodService.removeListener(_onMoodServiceUpdate);
    super.dispose();
  }

  void _onMoodServiceUpdate() {
    AppLogger.debug('MoodService update received, recalculating dates', tag: 'MoodLog');
    _calculateAvailableDates();

    // Clear cached mood data when service updates
    _cachedDayMoodMap.clear();

    // Clear message list cache
    _cachedGroupedEntries = null;
    _cachedSortedDateKeys = null;
    _lastCacheUpdate = null;

    AppLogger.info('Cleared mood data cache', tag: 'MoodLog.Calendar');
    if (mounted) setState(() {});
  }

  void _loadDateRange(DateTime? startDate, DateTime? endDate) {
    // Log date range selection
    if (startDate != null && endDate != null) {
      AppLogger.data('Date range selected',
          details: '${_dateKeyFormat.format(startDate)} to ${_dateKeyFormat.format(endDate)}',
          tag: 'MoodLog.Calendar'
      );
    } else if (startDate != null) {
      AppLogger.data('Single date selected',
          details: _dateKeyFormat.format(startDate),
          tag: 'MoodLog.Calendar'
      );
    } else {
      AppLogger.debug('Date selection cleared', tag: 'MoodLog.Calendar');
    }
  }

  void _scrollToDate(DateTime date) {
    AppLogger.debug(
        'Scrolling to date: ${_dateKeyFormat.format(date)}',
        tag: 'MoodLog'
    );
    final dateKey = _dateKeyFormat.format(date);

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

    // Capture the ID of the newly added entry (it's the first one after adding)
    if (widget.moodService.entries.isNotEmpty) {
      _newlySubmittedEntryId = widget.moodService.entries.first.id;
      AppLogger.success('Mood entry added successfully - ID: $_newlySubmittedEntryId', tag: 'MoodLog');

      // Clear the animation flag after animation completes
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _newlySubmittedEntryId = null;
          });
        }
      });
    }

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
    PerformanceTestHelper.recordBuild('MoodLogScreen');

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
          child: Stack(
            children: [
              Column(
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

// Scroll to bottom button with smooth animations
              if (isToday)
                Positioned(
                  bottom: 90, // Just above the input area
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    ignoring: !_showScrollToBottomButton,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _showScrollToBottomButton ? 1.0 : 0.0,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 200),
                        scale: _showScrollToBottomButton ? 1.0 : 0.8,
                        curve: Curves.easeOutCubic,
                        child: Center(
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(20),
                            color: theme.colorScheme.primary,
                            child: InkWell(
                              onTap: () {
                                // Use jumpTo instead of animateTo for large distances
                                if (_scrollController.hasClients) {
                                  final currentPosition = _scrollController.position.pixels;
                                  final maxPosition = _scrollController.position.maxScrollExtent;
                                  final distance = maxPosition - currentPosition;

                                  // If distance is large (more than 2000px), jump directly
                                  if (distance > 2000) {
                                    _scrollController.jumpTo(maxPosition);
                                  } else {
                                    // Otherwise animate smoothly
                                    _scrollController.animateTo(
                                      maxPosition,
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeOutCubic,
                                    );
                                  }
                                }
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: theme.colorScheme.onPrimary,
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
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
    return Stack(
      children: [
        Container(
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

              // Calendar grid (always show, pickers overlay it)
              _buildCalendarGrid(theme),

              // Selected date range display
              if (_selectedStartDate != null)
                _buildSelectedDateDisplay(theme),
            ],
          ),
        ),

        // Month picker overlay
        if (_isMonthPickerVisible)
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: _buildMonthPicker(theme),
          ),

        // Year picker overlay
        if (_isYearPickerVisible)
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: _buildYearPicker(theme),
          ),
      ],
    );
  }

  Widget _buildMonthYearSelector(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Left arrow
          IconButton(
            icon: Icon(
              Icons.chevron_left_rounded,
              color: theme.colorScheme.primary,
            ),
            onPressed: () {
              setState(() {
                _selectedCalendarMonth = DateTime(
                  _selectedCalendarMonth.year,
                  _selectedCalendarMonth.month - 1,
                );
              });
            },
          ),

          // Month button
          Expanded(
            child: GestureDetector(
              onTap: () {
                FocusScope.of(context).unfocus();
                setState(() {
                  _isInputExpanded = false;
                  _isMonthPickerVisible = !_isMonthPickerVisible;
                  if (_isMonthPickerVisible) {
                    _isYearPickerVisible = false;
                    _monthPickerController.forward();
                    _yearPickerController.reverse();
                  } else {
                    _monthPickerController.reverse();
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _isMonthPickerVisible
                      ? theme.colorScheme.primary.withValues(alpha: 0.15)
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isMonthPickerVisible
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  _monthFormat.format(_selectedCalendarMonth),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _isMonthPickerVisible
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Year button
          Expanded(
            child: GestureDetector(
              onTap: () {
                FocusScope.of(context).unfocus();
                setState(() {
                  _isInputExpanded = false;
                  _isYearPickerVisible = !_isYearPickerVisible;
                  if (_isYearPickerVisible) {
                    _isMonthPickerVisible = false;
                    _yearPickerController.forward();
                    _monthPickerController.reverse();
                  } else {
                    _yearPickerController.reverse();
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _isYearPickerVisible
                      ? theme.colorScheme.primary.withValues(alpha: 0.15)
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isYearPickerVisible
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  '${_selectedCalendarMonth.year}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _isYearPickerVisible
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),

          // Right arrow
          IconButton(
            icon: Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.primary,
            ),
            onPressed: () {
              setState(() {
                _selectedCalendarMonth = DateTime(
                  _selectedCalendarMonth.year,
                  _selectedCalendarMonth.month + 1,
                );
              });
            },
          ),

          // Clear button (only show if date range selected)
          if (_selectedStartDate != null || _selectedEndDate != null)
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedStartDate = null;
                  _selectedEndDate = null;
                });
                _loadDateRange(null, null);

                // Check scroll position and update button visibility after clearing filter
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    final maxScroll = _scrollController.position.maxScrollExtent;
                    final currentScroll = _scrollController.position.pixels;
                    final threshold = 200.0;
                    final shouldShow = (maxScroll - currentScroll) > threshold;

                    if (shouldShow != _showScrollToBottomButton) {
                      setState(() {
                        _showScrollToBottomButton = shouldShow;
                      });
                    }
                  }
                });
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(
                'Clear',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMonthPicker(ThemeData theme) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: ListWheelScrollView(
          controller: FixedExtentScrollController(
            initialItem: _selectedCalendarMonth.month - 1,
          ),
          itemExtent: 50,
          diameterRatio: 1.5,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: (index) {
            AppLogger.debug('Month wheel scrolled to index: $index', tag: 'MoodLog.Calendar');
            HapticFeedback.selectionClick();
            setState(() {
              _selectedCalendarMonth = DateTime(
                _selectedCalendarMonth.year,
                index + 1,
              );
            });
          },
          children: List.generate(12, (index) {
            final month = DateTime(_selectedCalendarMonth.year, index + 1);
            final isSelected = index == _selectedCalendarMonth.month - 1;

            return Center(
              child: Text(
                _monthFormat.format(month),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: isSelected ? 18 : 16,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildYearPicker(ThemeData theme) {
    final currentYear = DateTime.now().year;

    // Get earliest year from mood data, or use 2020 as fallback
    final earliestYear = widget.moodService.entries.isEmpty
        ? currentYear - 10
        : widget.moodService.entries.map((e) => e.timestamp.year).reduce((a, b) => a < b ? a : b);

    // Only years from earliest data year to current year (no future)
    final years = List.generate(
      currentYear - earliestYear + 1,
          (i) => earliestYear + i,
    );

    final initialIndex = years.indexOf(_selectedCalendarMonth.year);

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: ListWheelScrollView(
          controller: FixedExtentScrollController(
            initialItem: initialIndex >= 0 ? initialIndex : years.length - 1,
          ),
          itemExtent: 50,
          diameterRatio: 1.5,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: (index) {
            AppLogger.debug('Year wheel scrolled to: ${years[index]}', tag: 'MoodLog.Calendar');
            HapticFeedback.selectionClick();
            setState(() {
              _selectedCalendarMonth = DateTime(
                years[index],
                _selectedCalendarMonth.month,
              );
            });
          },
          children: List.generate(years.length, (index) {
            final year = years[index];
            final isSelected = year == _selectedCalendarMonth.year;

            return Center(
              child: Text(
                '$year',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: isSelected ? 18 : 16,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Map<int, double> _getDayMoodMapForMonth() {
    final monthKey = '${_selectedCalendarMonth.year}-${_selectedCalendarMonth.month}';

    AppLogger.debug('Getting mood data for month: $monthKey', tag: 'MoodLog.Calendar');

    // Return cached data if available
    if (_cachedDayMoodMap.containsKey(monthKey)) {
      AppLogger.success('Using cached mood data for $monthKey', tag: 'MoodLog.Calendar');
      return _cachedDayMoodMap[monthKey]!;
    }

    AppLogger.warning('Cache miss - calculating mood data for $monthKey', tag: 'MoodLog.Calendar');
    final startTime = DateTime.now();

    // Calculate mood data for this month
    final monthEntries = widget.moodService.entries.where((entry) {
      return entry.timestamp.year == _selectedCalendarMonth.year &&
          entry.timestamp.month == _selectedCalendarMonth.month;
    }).toList();

    AppLogger.data('Entries found', details: '${monthEntries.length}', tag: 'MoodLog.Calendar');

    final dayMoodMap = <int, double>{};
    final dayCountMap = <int, int>{};

    for (var entry in monthEntries) {
      final day = entry.timestamp.day;
      dayMoodMap[day] = (dayMoodMap[day] ?? 0) + entry.moodRating;
      dayCountMap[day] = (dayCountMap[day] ?? 0) + 1;
    }

    // Calculate averages
    for (var day in dayMoodMap.keys) {
      dayMoodMap[day] = dayMoodMap[day]! / dayCountMap[day]!;
    }

    final duration = DateTime.now().difference(startTime).inMilliseconds;
    AppLogger.info('Mood calculation took ${duration}ms', tag: 'MoodLog.Calendar');

    // Cache the result (store multiple months, limit to 12 months to avoid memory issues)
    _cachedDayMoodMap[monthKey] = dayMoodMap;
    if (_cachedDayMoodMap.length > 12) {
      // Remove oldest entry
      final oldestKey = _cachedDayMoodMap.keys.first;
      _cachedDayMoodMap.remove(oldestKey);
      AppLogger.debug('Removed oldest cache entry: $oldestKey', tag: 'MoodLog.Calendar');
    }

    return dayMoodMap;
  }

  Widget _buildCalendarGrid(ThemeData theme) {
    AppLogger.debug('Building calendar grid', tag: 'MoodLog.Calendar');
    final buildStart = DateTime.now();

    final firstDayOfMonth = DateTime(_selectedCalendarMonth.year, _selectedCalendarMonth.month, 1);
    final lastDayOfMonth = DateTime(_selectedCalendarMonth.year, _selectedCalendarMonth.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final startingWeekday = firstDayOfMonth.weekday % 7;
    final now = DateTime.now();

    // Get cached mood data
    final dayMoodMap = _getDayMoodMapForMonth();

    final buildDuration = DateTime.now().difference(buildStart).inMilliseconds;
    AppLogger.info('Calendar grid build took ${buildDuration}ms', tag: 'MoodLog.Calendar');

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
              final isToday = date.year == now.year &&
                  date.month == now.month &&
                  date.day == now.day;
              final hasMoodData = dayMoodMap.containsKey(dayNumber);
              final avgMood = dayMoodMap[dayNumber];

              final isSelected = _selectedStartDate != null &&
                  date.year == _selectedStartDate!.year &&
                  date.month == _selectedStartDate!.month &&
                  date.day == _selectedStartDate!.day;

              final isInRange = _selectedStartDate != null &&
                  _selectedEndDate != null &&
                  date.isAfter(_selectedStartDate!) &&
                  !date.isAfter(_selectedEndDate!);

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
                    color: hasMoodData
                        ? _getMoodColor(avgMood!.round()).withValues(alpha: 0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: (isSelected || isInRange)
                        ? Border.all(
                      color: theme.colorScheme.primary,
                      width: 2,
                    )
                        : isToday
                        ? Border.all(
                      color: theme.colorScheme.tertiary,
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
      dateText = _fullDateFormat.format(_selectedStartDate!);
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

              // Check scroll position and update button visibility after clearing filter
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollController.hasClients) {
                  final maxScroll = _scrollController.position.maxScrollExtent;
                  final currentScroll = _scrollController.position.pixels;
                  final threshold = 200.0;
                  final shouldShow = (maxScroll - currentScroll) > threshold;

                  if (shouldShow != _showScrollToBottomButton) {
                    setState(() {
                      _showScrollToBottomButton = shouldShow;
                    });
                  }
                }
              });
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

    // Check if we need to recalculate grouping
    final now = DateTime.now();
    final needsRecalc = _cachedGroupedEntries == null ||
        _lastCacheUpdate == null ||
        now.difference(_lastCacheUpdate!).inMilliseconds > 100;

    Map<String, List<MoodEntry>> groupedEntries;
    List<String> sortedDateKeys;

    if (needsRecalc) {
      // Group entries by date
      groupedEntries = <String, List<MoodEntry>>{};
      for (var entry in entriesToShow) {
        final dateKey = _dateKeyFormat.format(entry.timestamp);
        if (!groupedEntries.containsKey(dateKey)) {
          groupedEntries[dateKey] = [];
          _dateKeys[dateKey] = GlobalKey();
        }
        groupedEntries[dateKey]!.add(entry);
      }

      // Sort entries within each day
      groupedEntries.forEach((key, entries) {
        entries.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      });

      // Sort date keys in chronological order (OLDEST first) so newest appears at bottom
      sortedDateKeys = groupedEntries.keys.toList()
        ..sort((a, b) => a.compareTo(b));

      // Cache the results
      _cachedGroupedEntries = groupedEntries;
      _cachedSortedDateKeys = sortedDateKeys;
      _lastCacheUpdate = now;
    } else {
      groupedEntries = _cachedGroupedEntries!;
      sortedDateKeys = _cachedSortedDateKeys!;
    }

    return FadeTransition(
      opacity: _fadeController,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: sortedDateKeys.length,
        // Add these optimizations:
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        cacheExtent: 1000, // Cache 1000px ahead
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
                ...entries.map((entry) {
                  final isNewlySubmitted = entry.id == _newlySubmittedEntryId;

                  Widget messageBubble = RepaintBoundary(
                    child: _buildMessageBubble(entry, theme),
                  );

                  // Wrap new messages with slide-up and fade-in animation
                  if (isNewlySubmitted) {
                    return TweenAnimationBuilder<double>(
                      key: ValueKey('anim_${entry.id}'),
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 30 * (1 - value)), // Slide up from 30px below
                          child: Opacity(
                            opacity: value, // Fade in
                            child: child,
                          ),
                        );
                      },
                      child: messageBubble,
                    );
                  }

                  return messageBubble;
                }),
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
      return _dateWithoutYearFormat.format(date);
    } else {
      return _fullDateFormat.format(date);
    }
  }

  void _startEditing(MoodEntry entry) {
    setState(() {
      _editingEntryId = entry.id;
      _editingMoodRating = entry.moodRating;
      _currentMoodRating = entry.moodRating;
      _messageController.text = entry.message;
      _isInputExpanded = true;
    });

    // Focus the text field
    FocusScope.of(context).requestFocus(FocusNode());

    AppLogger.info('Started editing entry: ${entry.id}', tag: 'MoodLog');
  }

  void _cancelEdit() {
    setState(() {
      _editingEntryId = null;
      _messageController.clear();
      _isInputExpanded = false;
      _currentMoodRating = 5;
    });

    AppLogger.info('Cancelled editing', tag: 'MoodLog');
  }

  void _saveEdit() {
    if (_editingEntryId == null || _messageController.text.trim().isEmpty) {
      return;
    }

    final message = _messageController.text.trim();
    final rating = _currentMoodRating;

    AppLogger.data('Updating mood entry',
        details: 'ID: $_editingEntryId, Rating: $rating',
        tag: 'MoodLog'
    );

    widget.moodService.updateEntry(_editingEntryId!, message, rating);
    AppLogger.success('Mood entry updated successfully', tag: 'MoodLog');

    _cancelEdit();
    HapticFeedback.mediumImpact();
  }

  void _deleteEntry(MoodEntry entry) {
    // Cancel any pending slider expansion
    _sliderExpansionTimer?.cancel();

    // Mark that we're opening a dialog
    setState(() {
      _isDialogOpen = true;
      _isInputExpanded = false;
    });

    // Unfocus to prevent keyboard from appearing after dialog
    FocusScope.of(context).unfocus();

    // Add a small delay to ensure unfocus completes
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete Entry'),
          content: const Text('Are you sure you want to delete this mood entry?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                widget.moodService.deleteEntry(entry.id);
                Navigator.pop(dialogContext);
                HapticFeedback.mediumImpact();
                AppLogger.success('Mood entry deleted', tag: 'MoodLog');
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      ).then((_) {
        if (mounted) {
          // Mark dialog as closed
          setState(() {
            _isDialogOpen = false;
          });

          // Ensure keyboard stays closed and cancel any pending expansions
          _sliderExpansionTimer?.cancel();
          FocusScope.of(context).unfocus();

          // Additional safeguard: unfocus again after a short delay
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              FocusScope.of(context).unfocus();
            }
          });
        }
      });
    });
  }

  void _showContextMenu(BuildContext context, MoodEntry entry, Offset position) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        overlay.size.width - position.dx,
        overlay.size.height - position.dy,
      ),
      items: [
        PopupMenuItem(
          child: Row(
            children: [
              Icon(Icons.edit_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              const Text('Edit'),
            ],
          ),
          onTap: () {
            // Delay to allow menu to close first
            Future.delayed(const Duration(milliseconds: 100), () {
              _startEditing(entry);
            });
          },
        ),
        PopupMenuItem(
          child: Row(
            children: [
              const Icon(Icons.delete_rounded, size: 20, color: Colors.red),
              const SizedBox(width: 12),
              const Text('Delete', style: TextStyle(color: Colors.red)),
            ],
          ),
          onTap: () {
            Future.delayed(const Duration(milliseconds: 100), () {
              _deleteEntry(entry);
            });
          },
        ),
      ],
    );
  }

  Widget _buildMessageBubble(MoodEntry entry, ThemeData theme) {
    return RepaintBoundary(
      child: Dismissible(
        key: ValueKey(entry.id), // ValueKey is more efficient than Key
        direction: DismissDirection.startToEnd,
        dismissThresholds: const {
          DismissDirection.startToEnd: 0.4, // Require 40% swipe
        },
        confirmDismiss: (direction) async {
          // Unfocus immediately when swipe is detected
          FocusScope.of(context).unfocus();

          HapticFeedback.mediumImpact();
          _deleteEntry(entry);
          return false; // Don't actually dismiss, let the dialog handle it
        },
        background: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerLeft,
          child: const Icon(
            Icons.delete_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        child: GestureDetector(
          onLongPressStart: (details) {
            // Unfocus when long press detected
            FocusScope.of(context).unfocus();

            HapticFeedback.mediumImpact();
            _showContextMenu(context, entry, details.globalPosition);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: _editingEntryId == entry.id
                  ? Border.all(
                color: theme.colorScheme.primary,
                width: 2,
              )
                  : null,
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
                              const Icon(
                                Icons.access_time_rounded,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _timeFormat.format(entry.timestamp),
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
          ),
        ),
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
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOutCubic,
                  height: _isInputExpanded ? 80 : 0,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
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
                    child: Focus(
                      skipTraversal: _isDialogOpen,
                      canRequestFocus: !_isDialogOpen,
                      child: TextField(
                        controller: _messageController,
                        maxLines: 6,
                        minLines: 1,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: _editingEntryId != null
                              ? 'Edit your message...'
                              : 'How are you feeling?',
                          filled: true,
                          fillColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          // Disable animations on the input decoration
                          floatingLabelBehavior: FloatingLabelBehavior.never,
                        ),
                        onSubmitted: (_) {
                          if (_editingEntryId != null) {
                            _saveEdit();
                          } else {
                            _sendMessage();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Cancel button when editing
                  if (_editingEntryId != null) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: _cancelEdit,
                        icon: const Icon(Icons.close_rounded),
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Send/Save button
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
                      onPressed: _editingEntryId != null ? _saveEdit : _sendMessage,
                      icon: Icon(_editingEntryId != null ? Icons.check_rounded : Icons.send_rounded),
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