import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/mood_entry.dart';
import '../services/mood_service.dart';

class MoodLogScreen extends StatefulWidget {
  final MoodService moodService;
  final DateTime? initialDate;

  const MoodLogScreen({
    super.key,
    required this.moodService,
    this.initialDate,
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

  // Date navigation
  List<String>? _focusedDateRange;
  List<String>? _allSortedKeys;
  // ignore: unused_field
  String? _targetDateKey;
  int? _targetIndexInFocused;
  bool _isLoadingMore = false;
  bool _isJumpingToDate = false; // Flag to prevent auto-loading during date jump
  final Map<String, GlobalKey> _dateKeys = {};

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _calendarExpandController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // If we have an initial date, scroll to it
    if (widget.initialDate != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToDate(widget.initialDate!);
      });
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _fadeController.forward();
      }
    });

    widget.moodService.addListener(_onMoodServiceUpdate);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _fadeController.dispose();
    _calendarExpandController.dispose();
    widget.moodService.removeListener(_onMoodServiceUpdate);
    super.dispose();
  }

  void _onMoodServiceUpdate() {
    if (mounted) {
      setState(() {});
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  void _submitEntry() {
    if (_messageController.text.trim().isEmpty) return;

    widget.moodService.addEntry(
      _messageController.text.trim(),
      _currentMoodRating,
    );

    _messageController.clear();
    setState(() {
      _currentMoodRating = 5;
      _isInputExpanded = false;
    });
  }

  void _toggleCalendar() {
    setState(() {
      _isCalendarExpanded = !_isCalendarExpanded;
    });

    if (_isCalendarExpanded) {
      _calendarExpandController.forward();
    } else {
      _calendarExpandController.reverse();
    }
  }

  void _scrollToDate(DateTime date) async {
    final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    // Get all entries and group by date
    final entries = widget.moodService.entries;
    final groupedEntries = <String, List<MoodEntry>>{};
    for (var entry in entries) {
      final key = '${entry.timestamp.year}-${entry.timestamp.month.toString().padLeft(2, '0')}-${entry.timestamp.day.toString().padLeft(2, '0')}';
      groupedEntries.putIfAbsent(key, () => []);
      groupedEntries[key]!.add(entry);
    }

    // Check if the date has entries
    if (!groupedEntries.containsKey(dateKey)) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No entries found for ${DateFormat('MMM d, yyyy').format(date)}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // Close calendar
    if (_isCalendarExpanded) {
      _toggleCalendar();
    }

    // Disable dynamic loading completely
    _isJumpingToDate = true;

    // Fade out
    await _fadeController.reverse();

    if (!mounted) return;

    // Show ONLY the selected date - disable all the fancy loading
    _dateKeys.clear();
    _focusedDateRange = [dateKey];
    _allSortedKeys = null; // Disable dynamic loading by clearing this
    _targetDateKey = dateKey;
    _targetIndexInFocused = 0;
    _isLoadingMore = false;

    setState(() {});

    // Fade in
    await _fadeController.forward();
  }

  List<DateTime> _getAvailableMonths() {
    final months = <DateTime>{};
    for (var entry in widget.moodService.entries) {
      months.add(DateTime(entry.timestamp.year, entry.timestamp.month));
    }
    return months.toList()..sort((a, b) => b.compareTo(a));
  }

  bool _hasEntriesForDate(DateTime date) {
    return widget.moodService.entries.any((entry) =>
    entry.timestamp.year == date.year &&
        entry.timestamp.month == date.month &&
        entry.timestamp.day == date.day);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = widget.moodService.entries;
    final isFilteredView = _focusedDateRange != null && _focusedDateRange!.length == 1;

    // Check if the filtered date is today
    bool isViewingToday = false;
    if (isFilteredView && _focusedDateRange!.isNotEmpty) {
      final dateKey = _focusedDateRange![0];
      final parts = dateKey.split('-');
      if (parts.length == 3) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);
        final today = DateTime.now();
        isViewingToday = year == today.year && month == today.month && day == today.day;
      }
    }

    final shouldShowInput = !isFilteredView || isViewingToday;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              _buildExpandableCalendar(theme),

              // Messages List
              Expanded(
                child: FadeTransition(
                  opacity: _fadeController,
                  child: entries.isEmpty
                      ? _buildEmptyState()
                      : _buildMessagesList(entries),
                ),
              ),

              // Input Area - show when not in filtered view OR when viewing today
              if (shouldShowInput) _buildInputArea(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isFilteredView = _focusedDateRange != null && _focusedDateRange!.length == 1;

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
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Diary',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      isFilteredView
                          ? 'Viewing single date'
                          : '${widget.moodService.entries.length} entries',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Calendar expand button
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _toggleCalendar,
            child: AnimatedRotation(
              turns: _isCalendarExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 300),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 28,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableCalendar(ThemeData theme) {
    final isFilteredView = _focusedDateRange != null && _focusedDateRange!.length == 1;

    return SizeTransition(
      sizeFactor: CurvedAnimation(
        parent: _calendarExpandController,
        curve: Curves.easeOutCubic,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(
              color: Colors.grey[200]!,
              width: 1,
            ),
          ),
        ),
        child: Column(
          children: [
            // "View All" button (show when in filtered view)
            if (isFilteredView) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Material(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _focusedDateRange = null;
                        _allSortedKeys = null;
                        _targetDateKey = null;
                        _targetIndexInFocused = null;
                        _isJumpingToDate = false;
                      });
                      _toggleCalendar();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.list_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'View All Entries',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: Colors.grey[200]),
            ],

            // Year/Month selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Previous month
                  IconButton(
                    onPressed: () {
                      final availableMonths = _getAvailableMonths();
                      final currentIndex = availableMonths.indexWhere((m) =>
                      m.year == _selectedCalendarMonth.year &&
                          m.month == _selectedCalendarMonth.month);

                      if (currentIndex < availableMonths.length - 1) {
                        setState(() {
                          _selectedCalendarMonth = availableMonths[currentIndex + 1];
                        });
                      }
                    },
                    icon: const Icon(Icons.chevron_left_rounded),
                    color: theme.colorScheme.primary,
                  ),

                  Expanded(
                    child: Center(
                      child: Text(
                        DateFormat('MMMM yyyy').format(_selectedCalendarMonth),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  // Next month
                  IconButton(
                    onPressed: () {
                      final availableMonths = _getAvailableMonths();
                      final currentIndex = availableMonths.indexWhere((m) =>
                      m.year == _selectedCalendarMonth.year &&
                          m.month == _selectedCalendarMonth.month);

                      if (currentIndex > 0) {
                        setState(() {
                          _selectedCalendarMonth = availableMonths[currentIndex - 1];
                        });
                      }
                    },
                    icon: const Icon(Icons.chevron_right_rounded),
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),

            // Day labels
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
                  return Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 8),

            // Calendar grid
            _buildCalendarGrid(theme),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(ThemeData theme) {
    // Get days in selected month
    final firstDay = DateTime(_selectedCalendarMonth.year, _selectedCalendarMonth.month, 1);
    final lastDay = DateTime(_selectedCalendarMonth.year, _selectedCalendarMonth.month + 1, 0);
    final daysInMonth = lastDay.day;
    final startWeekday = firstDay.weekday - 1; // Monday = 0

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final weeks = <Widget>[];
    int dayCount = 1;

    for (int week = 0; week < 6; week++) {
      final weekDays = <Widget>[];

      for (int weekday = 0; weekday < 7; weekday++) {
        if ((week == 0 && weekday < startWeekday) || dayCount > daysInMonth) {
          weekDays.add(const Expanded(child: SizedBox()));
        } else {
          final date = DateTime(_selectedCalendarMonth.year, _selectedCalendarMonth.month, dayCount);
          final hasEntries = _hasEntriesForDate(date);
          final isToday = date.year == todayDate.year &&
              date.month == todayDate.month &&
              date.day == todayDate.day;

          weekDays.add(
            Expanded(
              child: GestureDetector(
                onTap: hasEntries ? () => _scrollToDate(date) : null,
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: hasEntries
                        ? theme.colorScheme.primary.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isToday
                        ? Border.all(
                      color: theme.colorScheme.primary,
                      width: 2,
                    )
                        : null,
                  ),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Center(
                      child: Text(
                        '$dayCount',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                          color: hasEntries
                              ? theme.colorScheme.primary
                              : Colors.grey[400],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          dayCount++;
        }
      }

      weeks.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: weekDays),
        ),
      );

      if (dayCount > daysInMonth) break;
    }

    return Column(children: weeks);
  }

  Widget _buildMessagesList(List<MoodEntry> entries) {
    // Group entries by date
    final groupedEntries = <String, List<MoodEntry>>{};
    for (var entry in entries) {
      final dateKey = '${entry.timestamp.year}-${entry.timestamp.month.toString().padLeft(2, '0')}-${entry.timestamp.day.toString().padLeft(2, '0')}';
      groupedEntries.putIfAbsent(dateKey, () => []);
      groupedEntries[dateKey]!.add(entry);
    }

    // Use focused range if available, otherwise show all
    final List<String> sortedDateKeys;
    if (_focusedDateRange != null) {
      sortedDateKeys = _focusedDateRange!;
    } else {
      sortedDateKeys = groupedEntries.keys.toList()
        ..sort((a, b) => b.compareTo(a));
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // Don't do dynamic loading if we're jumping to a specific date
        if (_isJumpingToDate) return false;

        // Only handle dynamic loading if we're in focused mode
        if (_focusedDateRange != null && _allSortedKeys != null && !_isLoadingMore) {
          if (notification is ScrollUpdateNotification) {
            final metrics = notification.metrics;

            // Near top (scroll position < 1000) - load newer dates
            if (metrics.pixels < 1000) {
              final firstKey = _focusedDateRange!.first;
              final indexInAll = _allSortedKeys!.indexOf(firstKey);

              // Only load if there are dates before
              if (indexInAll > 0) {
                _isLoadingMore = true;

                final addCount = (indexInAll).clamp(0, 10);
                final newKeys = _allSortedKeys!.sublist(indexInAll - addCount, indexInAll);

                setState(() {
                  _focusedDateRange = [...newKeys, ..._focusedDateRange!];
                  // Update target index
                  if (_targetIndexInFocused != null) {
                    _targetIndexInFocused = _targetIndexInFocused! + newKeys.length;
                  }
                });

                // Reset flag after a delay
                Future.delayed(const Duration(milliseconds: 500), () {
                  _isLoadingMore = false;
                });
              }
            }

            // Near bottom (within 1000px of max) - load older dates
            if (metrics.pixels > metrics.maxScrollExtent - 1000) {
              final lastKey = _focusedDateRange!.last;
              final indexInAll = _allSortedKeys!.indexOf(lastKey);

              if (indexInAll < _allSortedKeys!.length - 1) {
                _isLoadingMore = true;

                final addCount = (_allSortedKeys!.length - indexInAll - 1).clamp(0, 10);
                final newKeys = _allSortedKeys!.sublist(indexInAll + 1, indexInAll + 1 + addCount);

                setState(() {
                  _focusedDateRange = [..._focusedDateRange!, ...newKeys];
                });

                Future.delayed(const Duration(milliseconds: 500), () {
                  _isLoadingMore = false;
                });
              }
            }
          }
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        reverse: true,
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        itemCount: sortedDateKeys.length,
        itemBuilder: (context, dateIndex) {
          final dateKey = sortedDateKeys[dateIndex];
          final dateEntries = groupedEntries[dateKey]!;

          // Sort entries within the day (oldest first)
          dateEntries.sort((a, b) => a.timestamp.compareTo(b.timestamp));

          final date = dateEntries.first.timestamp;

          // Create or get key for this date
          _dateKeys.putIfAbsent(dateKey, () => GlobalKey());

          return Column(
            key: _dateKeys[dateKey],
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDateSeparator(date),
              const SizedBox(height: 12),
              ...dateEntries.map((moodEntry) {
                return _buildMessageBubble(moodEntry, 0);
              }),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final entryDate = DateTime(date.year, date.month, date.day);

    String dateText;
    if (entryDate == today) {
      dateText = 'Today';
    } else if (entryDate == yesterday) {
      dateText = 'Yesterday';
    } else {
      dateText = DateFormat('EEEE, MMMM d, yyyy').format(date);
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          dateText,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mood_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Start tracking your mood',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Share how you\'re feeling and rate your mood',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(MoodEntry entry, int index) {
    final delay = index * 50;
    Theme.of(context);

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + delay),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mood Emoji Avatar (NOT affected by swipe)
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _getMoodColor(entry.moodRating).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  MoodEntry.getMoodEmoji(entry.moodRating),
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Message Content (WITH swipe-to-delete, clipped)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Clipped container for swipe effect
                  ClipRect(
                    child: Stack(
                      children: [
                        // Red delete background (shows when message slides left)
                        Positioned.fill(
                          child: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.delete_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),

                        // Dismissible message bubble
                        Dismissible(
                          key: Key(entry.id),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (direction) async {
                            // Unfocus to prevent keyboard from reopening
                            FocusScope.of(context).unfocus();

                            // Small delay to let keyboard close
                            await Future.delayed(const Duration(milliseconds: 100));

                            return await _showDeleteDialog(entry);
                          },
                          onDismissed: (direction) => _deleteEntry(entry),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                // Unfocus when tapping message
                                FocusScope.of(context).unfocus();
                              },
                              onLongPress: () async {
                                // Unfocus to prevent keyboard from reopening
                                FocusScope.of(context).unfocus();

                                // Small delay to let keyboard close
                                await Future.delayed(const Duration(milliseconds: 100));

                                final shouldDelete = await _showDeleteDialog(entry);
                                if (shouldDelete == true) {
                                  _deleteEntry(entry);
                                }
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Ink(
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
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getMoodColor(entry.moodRating)
                                                  .withValues(alpha: 0.1),
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
                                          const SizedBox(width: 8),
                                          Text(
                                            '${entry.moodRating}/10',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: _getMoodColor(entry.moodRating),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        entry.message,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Timestamp (NOT affected by swipe)
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      _formatTimestamp(entry.timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showDeleteDialog(MoodEntry entry) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this mood entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteEntry(MoodEntry entry) {
    widget.moodService.deleteEntry(entry.id);

    // If we're in filtered view and no more entries for this date, go back to all
    if (_focusedDateRange != null && _focusedDateRange!.length == 1) {
      final dateKey = _focusedDateRange![0];
      final stillHasEntries = widget.moodService.entries.any((e) {
        final key = '${e.timestamp.year}-${e.timestamp.month.toString().padLeft(2, '0')}-${e.timestamp.day.toString().padLeft(2, '0')}';
        return key == dateKey;
      });

      if (!stillHasEntries) {
        setState(() {
          _focusedDateRange = null;
          _allSortedKeys = null;
          _targetDateKey = null;
          _targetIndexInFocused = null;
          _isJumpingToDate = false;
        });
      }
    }
  }

  Widget _buildInputArea(ThemeData theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mood Slider - only show when input is expanded
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: _isInputExpanded
                ? Column(
              children: [
                Row(
                  children: [
                    Text(
                      MoodEntry.getMoodEmoji(_currentMoodRating),
                      style: const TextStyle(fontSize: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mood: $_currentMoodRating/10',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            MoodEntry.getMoodLabel(_currentMoodRating),
                            style: TextStyle(
                              fontSize: 12,
                              color: _getMoodColor(_currentMoodRating),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 8,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 10,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 20,
                    ),
                    activeTrackColor: _getMoodColor(_currentMoodRating),
                    inactiveTrackColor:
                    _getMoodColor(_currentMoodRating).withValues(alpha: 0.2),
                    thumbColor: _getMoodColor(_currentMoodRating),
                    overlayColor:
                    _getMoodColor(_currentMoodRating).withValues(alpha: 0.2),
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
                const SizedBox(height: 12),
              ],
            )
                : const SizedBox.shrink(),
          ),

          // Text Input
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Focus(
                    onFocusChange: (hasFocus) {
                      setState(() {
                        _isInputExpanded = hasFocus;
                      });
                    },
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'How are you feeling?',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  onTap: _submitEntry,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getMoodColor(int rating) {
    if (rating <= 2) return Colors.red;
    if (rating <= 4) return Colors.orange;
    if (rating <= 6) return Colors.amber;
    if (rating <= 8) return Colors.lightGreen;
    return Colors.green;
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${DateFormat('h:mm a').format(timestamp)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, h:mm a').format(timestamp);
    }
  }
}