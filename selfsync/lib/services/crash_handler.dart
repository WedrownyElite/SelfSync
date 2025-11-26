import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'crash_log_service.dart';
import 'email_service.dart';
import 'auth_service.dart';

/// Global crash handler that can show error UI from anywhere
class CrashHandler {
  static final CrashHandler _instance = CrashHandler._internal();
  factory CrashHandler() => _instance;
  CrashHandler._internal();

  static GlobalKey<NavigatorState>? _navigatorKey;
  static VoidCallback? _onRestart;
  static bool _isShowingError = false;
  static bool _isRestarting = false;

  /// Initialize with navigator key and restart callback
  static void initialize({
    required GlobalKey<NavigatorState> navigatorKey,
    required VoidCallback onRestart,
  }) {
    _navigatorKey = navigatorKey;
    _onRestart = onRestart;
  }

  /// Handle a crash and show the error screen
  static void handleCrash(Object error, StackTrace? stackTrace) {
    // Prevent multiple error screens or handling during restart
    if (_isShowingError || _isRestarting) return;
    _isShowingError = true;

    // Create crash log
    final crashLog = CrashLogService().createCrashLog(error, stackTrace);

    // IMPORTANT: Defer showing dialog until after current frame completes
    // This prevents issues when crash happens during gesture handling
    SchedulerBinding.instance.addPostFrameCallback((_) {
      // Additional safety delay to ensure gesture system is unlocked
      Future.delayed(const Duration(milliseconds: 100), () {
        _showCrashUI(crashLog);
      });
    });
  }

  static void _showCrashUI(CrashLog crashLog) {
    // Try to show error dialog via navigator
    if (_navigatorKey?.currentState != null && _navigatorKey!.currentContext != null) {
      try {
        _showErrorDialog(_navigatorKey!.currentState!.context, crashLog);
      } catch (e) {
        // If dialog fails, show fatal error screen
        _showFatalErrorScreen(crashLog);
      }
    } else {
      // Fallback: show fatal error screen
      _showFatalErrorScreen(crashLog);
    }
  }

  static void _showErrorDialog(BuildContext context, CrashLog crashLog) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CrashDialog(
        crashLog: crashLog,
        onRestart: () {
          _isShowingError = false;
          Navigator.of(context).pop();
          _performRestart();
        },
        onExit: () {
          SystemNavigator.pop();
        },
        onDismiss: () {
          _isShowingError = false;
          Navigator.of(context).pop();
        },
      ),
    );
  }

  static void _performRestart() {
    if (_isRestarting) return;
    _isRestarting = true;

    // Delay restart to ensure UI is cleaned up
    Future.delayed(const Duration(milliseconds: 200), () {
      _isRestarting = false;
      _onRestart?.call();
    });
  }

  static void _showFatalErrorScreen(CrashLog crashLog) {
    // Use addPostFrameCallback to ensure we're not in middle of a build
    SchedulerBinding.instance.addPostFrameCallback((_) {
      runApp(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: _FatalErrorScreen(
            crashLog: crashLog,
            onRestart: () {
              _isShowingError = false;
              _performRestart();
            },
            onExit: () {
              SystemNavigator.pop();
            },
          ),
        ),
      );
    });
  }

  /// Reset error state (call after successful recovery)
  static void reset() {
    _isShowingError = false;
    _isRestarting = false;
  }

  /// Send crash report via email service
  static Future<bool> sendCrashReport(CrashLog crashLog) async {
    // Try to get user email from auth service
    String userEmail = 'anonymous@selfsync.app';
    try {
      final authService = AuthService();
      userEmail = authService.currentUser?.email ?? userEmail;
    } catch (_) {
      // Ignore auth errors when sending crash report
    }

    final success = await EmailService.sendBugReport(
      userEmail: userEmail,
      title: '[CRASH REPORT] ${_truncate(crashLog.error, 50)}',
      description: '''
**Crash Report**

**Error:**
${crashLog.error}

**Screen:** ${crashLog.screenName ?? 'Unknown'}

**Timestamp:** ${crashLog.timestamp.toIso8601String()}

**Additional Context:**
${crashLog.additionalContext?.entries.map((e) => '${e.key}: ${e.value}').join('\n') ?? 'None'}
''',
      stepsToReproduce: '''
**Stack Trace:**
${crashLog.stackTrace}
''',
      deviceInfo: crashLog.deviceInfo ?? 'Unknown device',
      appVersion: crashLog.appVersion ?? 'Unknown version',
    );

    if (success) {
      await CrashLogService().clearPendingCrashLog();
    }

    return success;
  }

  static String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}

class _CrashDialog extends StatefulWidget {
  final CrashLog crashLog;
  final VoidCallback onRestart;
  final VoidCallback onExit;
  final VoidCallback onDismiss;

  const _CrashDialog({
    required this.crashLog,
    required this.onRestart,
    required this.onExit,
    required this.onDismiss,
  });

  @override
  State<_CrashDialog> createState() => _CrashDialogState();
}

class _CrashDialogState extends State<_CrashDialog> {
  bool _isSending = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      child: AlertDialog(
        icon: Icon(
          Icons.error_rounded,
          color: theme.colorScheme.error,
          size: 48,
        ),
        title: const Text('Something Went Wrong'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The app encountered an unexpected error.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.bug_report_rounded,
                    size: 16,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.crashLog.error.length > 100
                          ? '${widget.crashLog.error.substring(0, 100)}...'
                          : widget.crashLog.error,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 10,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'What would you like to do?',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Send crash report
              FilledButton.icon(
                onPressed: _isSending ? null : () => _sendCrashReport(context, theme),
                icon: _isSending
                    ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.onPrimary,
                    ),
                  ),
                )
                    : const Icon(Icons.send_rounded),
                label: Text(_isSending ? 'Sending...' : 'Send Crash Report'),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 8),

              // Restart app
              OutlinedButton.icon(
                onPressed: _isSending ? null : widget.onRestart,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Restart App'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 8),

              // Try to continue
              OutlinedButton.icon(
                onPressed: _isSending ? null : widget.onDismiss,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Try to Continue'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),

              // Exit app
              TextButton.icon(
                onPressed: _isSending ? null : widget.onExit,
                icon: Icon(
                  Icons.exit_to_app_rounded,
                  color: _isSending ? theme.colorScheme.onSurface.withValues(alpha: 0.3) : theme.colorScheme.error,
                ),
                label: Text(
                  'Exit App',
                  style: TextStyle(
                    color: _isSending ? theme.colorScheme.onSurface.withValues(alpha: 0.3) : theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _sendCrashReport(BuildContext context, ThemeData theme) async {
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isSending = true;
    });

    final success = await CrashHandler.sendCrashReport(widget.crashLog);

    if (!mounted) return;

    setState(() {
      _isSending = false;
    });

    if (success) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Crash report sent. Thank you for helping us improve!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Failed to send crash report. Please try again.'),
          backgroundColor: theme.colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _FatalErrorScreen extends StatefulWidget {
  final CrashLog crashLog;
  final VoidCallback onRestart;
  final VoidCallback onExit;

  const _FatalErrorScreen({
    required this.crashLog,
    required this.onRestart,
    required this.onExit,
  });

  @override
  State<_FatalErrorScreen> createState() => _FatalErrorScreenState();
}

class _FatalErrorScreenState extends State<_FatalErrorScreen> {
  bool _isSending = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Error icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_rounded,
                  size: 56,
                  color: Colors.red,
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'App Crashed',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              Text(
                'A fatal error occurred and the app needs to restart.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // Error preview
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  widget.crashLog.error.length > 150
                      ? '${widget.crashLog.error.substring(0, 150)}...'
                      : widget.crashLog.error,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Colors.black87,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const Spacer(),

              // Send crash report
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSending ? null : _sendCrashReport,
                  icon: _isSending
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : const Icon(Icons.send_rounded),
                  label: Text(_isSending ? 'Sending...' : 'Send Crash Report'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Restart app
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isSending ? null : widget.onRestart,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Restart App'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Exit app
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isSending ? null : widget.onExit,
                  icon: const Icon(Icons.exit_to_app_rounded),
                  label: const Text('Exit App'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    foregroundColor: Colors.red,
                    side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendCrashReport() async {
    setState(() {
      _isSending = true;
    });

    final success = await CrashHandler.sendCrashReport(widget.crashLog);

    if (!mounted) return;

    setState(() {
      _isSending = false;
    });

    // Show simple feedback since we don't have scaffold messenger
    if (success) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
          title: const Text('Report Sent'),
          content: const Text('Thank you for helping us improve the app!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.error_rounded, color: Colors.red, size: 48),
          title: const Text('Failed to Send'),
          content: const Text('Could not send the crash report. Please try again or restart the app.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}