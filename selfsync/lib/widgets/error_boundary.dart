import 'package:flutter/material.dart';
import '../services/crash_log_service.dart';
import '../screens/error_screen.dart';

class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final String? screenName;
  final VoidCallback? onRetry;
  final VoidCallback? onGoHome;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.screenName,
    this.onRetry,
    this.onGoHome,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  bool _hasError = false;
  CrashLog? _crashLog;

  @override
  void initState() {
    super.initState();
    if (widget.screenName != null) {
      CrashLogService().setCurrentScreen(widget.screenName!);
    }
  }

  @override
  void didUpdateWidget(ErrorBoundary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.screenName != null && widget.screenName != oldWidget.screenName) {
      CrashLogService().setCurrentScreen(widget.screenName!);
    }
  }

  void _retry() {
    setState(() {
      _hasError = false;
      _crashLog = null;
    });
    widget.onRetry?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return ErrorScreen(
        crashLog: _crashLog,
        onRetry: widget.onRetry != null ? _retry : null,
        onGoHome: widget.onGoHome,
      );
    }

    return widget.child;
  }
}