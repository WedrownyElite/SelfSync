import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/crash_log_service.dart';
import '../services/crash_handler.dart';

class ErrorScreen extends StatefulWidget {
  final FlutterErrorDetails? errorDetails;
  final CrashLog? crashLog;
  final VoidCallback? onRetry;
  final VoidCallback? onGoHome;

  const ErrorScreen({
    super.key,
    this.errorDetails,
    this.crashLog,
    this.onRetry,
    this.onGoHome,
  });

  @override
  State<ErrorScreen> createState() => _ErrorScreenState();
}

class _ErrorScreenState extends State<ErrorScreen> {
  bool _isSending = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const Spacer(flex: 1),

                      // Error icon with animation
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: child,
                          );
                        },
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.bug_report_rounded,
                            size: 56,
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      Text(
                        'Oops! Something went wrong',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 12),

                      Text(
                        'The app encountered an unexpected error. You can help us fix it by sending a crash report.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 24),

                      // Error details card (collapsible)
                      if (widget.crashLog != null || widget.errorDetails != null)
                        _ErrorDetailsCard(
                          crashLog: widget.crashLog,
                          errorDetails: widget.errorDetails,
                          theme: theme,
                        ),

                      const Spacer(flex: 2),

                      // Action buttons
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Send crash report button
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
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
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                backgroundColor: theme.colorScheme.primary,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Secondary actions row
                          Row(
                            children: [
                              if (widget.onRetry != null)
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _isSending ? null : widget.onRetry,
                                    icon: const Icon(Icons.refresh_rounded, size: 20),
                                    label: const Text('Retry'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                              if (widget.onRetry != null && widget.onGoHome != null)
                                const SizedBox(width: 12),
                              if (widget.onGoHome != null)
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _isSending ? null : widget.onGoHome,
                                    icon: const Icon(Icons.home_rounded, size: 20),
                                    label: const Text('Go Home'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // Dismiss without sending
                          TextButton(
                            onPressed: _isSending ? null : () => _dismissWithoutSending(context),
                            child: Text(
                              'Dismiss without sending',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _sendCrashReport(BuildContext context, ThemeData theme) async {
    final crashLogService = CrashLogService();
    final log = widget.crashLog ?? crashLogService.pendingCrashLog;

    // Capture messenger before async gap
    final messenger = ScaffoldMessenger.of(context);

    if (log == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No crash log available to send'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    final success = await CrashHandler.sendCrashReport(log);

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

      // Navigate away after successful send
      if (widget.onGoHome != null) {
        widget.onGoHome!();
      }
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

  void _dismissWithoutSending(BuildContext context) {
    CrashLogService().clearPendingCrashLog();

    if (widget.onGoHome != null) {
      widget.onGoHome!();
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }
}

class _ErrorDetailsCard extends StatefulWidget {
  final CrashLog? crashLog;
  final FlutterErrorDetails? errorDetails;
  final ThemeData theme;

  const _ErrorDetailsCard({
    this.crashLog,
    this.errorDetails,
    required this.theme,
  });

  @override
  State<_ErrorDetailsCard> createState() => _ErrorDetailsCardState();
}

class _ErrorDetailsCardState extends State<_ErrorDetailsCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final errorText = widget.crashLog?.error ??
        widget.errorDetails?.exceptionAsString() ??
        'Unknown error';

    final stackTrace = widget.crashLog?.stackTrace ??
        widget.errorDetails?.stack?.toString() ??
        'No stack trace';

    return Container(
      decoration: BoxDecoration(
        color: widget.theme.colorScheme.errorContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.theme.colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.code_rounded,
                    size: 18,
                    color: widget.theme.colorScheme.error,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Error Details',
                      style: widget.theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    onPressed: () => _copyToClipboard(context, errorText, stackTrace),
                    tooltip: 'Copy to clipboard',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: widget.theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Text(
                    'Error:',
                    style: widget.theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: widget.theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      errorText,
                      style: widget.theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 10,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Stack Trace:',
                    style: widget.theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: widget.theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 100,
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        stackTrace,
                        style: widget.theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          fontSize: 9,
                          color: widget.theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String error, String stackTrace) {
    final fullText = 'Error: $error\n\nStack Trace:\n$stackTrace';
    Clipboard.setData(ClipboardData(text: fullText));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Error details copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }
}