import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/email_service.dart';
import '../services/analytics_service.dart';
import '../utils/app_logger.dart';

class BugReportScreen extends StatefulWidget {
  final AnalyticsService analyticsService;

  const BugReportScreen({
    super.key,
    required this.analyticsService,
  });

  @override
  State<BugReportScreen> createState() => _BugReportScreenState();
}

class _BugReportScreenState extends State<BugReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _stepsController = TextEditingController();

  bool _isLoading = false;
  bool _rememberEmail = true;

  static const String _savedEmailKey = 'bug_report_email';

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
    widget.analyticsService.trackScreenView('bug_report');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _stepsController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString(_savedEmailKey);
      if (savedEmail != null && savedEmail.isNotEmpty) {
        setState(() {
          _emailController.text = savedEmail;
        });
        AppLogger.info('Loaded saved email for bug report', tag: 'BugReport');
      }
    } catch (e) {
      AppLogger.error('Failed to load saved email', error: e, tag: 'BugReport');
    }
  }

  Future<void> _saveEmail() async {
    if (_rememberEmail && _emailController.text.isNotEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_savedEmailKey, _emailController.text);
        AppLogger.info('Saved email for future bug reports', tag: 'BugReport');
      } catch (e) {
        AppLogger.error('Failed to save email', error: e, tag: 'BugReport');
      }
    }
  }

  String _getDeviceInfo() {
    if (kIsWeb) {
      return 'Platform: Web Browser';
    } else if (Platform.isAndroid) {
      return 'Platform: Android';
    } else if (Platform.isIOS) {
      return 'Platform: iOS';
    } else if (Platform.isMacOS) {
      return 'Platform: macOS';
    } else if (Platform.isWindows) {
      return 'Platform: Windows';
    } else if (Platform.isLinux) {
      return 'Platform: Linux';
    } else {
      return 'Platform: Unknown';
    }
  }

  Future<void> _submitBugReport() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Save email if remember is checked
      await _saveEmail();

      final success = await EmailService.sendBugReport(
        userEmail: _emailController.text.trim(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        stepsToReproduce: _stepsController.text.trim().isEmpty
            ? 'Not provided'
            : _stepsController.text.trim(),
        deviceInfo: _getDeviceInfo(),
        appVersion: '1.0.0',
      );

      if (!mounted) return;

      if (success) {
        widget.analyticsService.trackEvent('bug_report_submitted');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Bug report sent successfully! Thank you for your feedback.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );

        // Go back to settings
        Navigator.of(context).pop();
      } else {
        throw Exception('Failed to send bug report');
      }
    } catch (e) {
      AppLogger.error('Failed to submit bug report', error: e, tag: 'BugReport');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to send bug report. Please try again or email support@oddologyinc.com directly.'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _submitBugReport,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoCard(theme),
                      const SizedBox(height: 24),
                      _buildEmailField(theme),
                      const SizedBox(height: 16),
                      _buildRememberEmailCheckbox(theme),
                      const SizedBox(height: 24),
                      _buildTitleField(theme),
                      const SizedBox(height: 24),
                      _buildDescriptionField(theme),
                      const SizedBox(height: 24),
                      _buildStepsField(theme),
                      const SizedBox(height: 32),
                      _buildSubmitButton(theme),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            tooltip: 'Back',
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.bug_report_rounded,
            color: theme.colorScheme.primary,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Report a Bug',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Help us improve Self Sync',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: theme.colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Please provide as much detail as possible to help us identify and fix the issue quickly.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailField(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Email *',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          enabled: !_isLoading,
          decoration: InputDecoration(
            hintText: 'email@example.com',
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your email';
            }
            if (!EmailService.isValidEmail(value.trim())) {
              return 'Please enter a valid email';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildRememberEmailCheckbox(ThemeData theme) {
    return Row(
      children: [
        SizedBox(
          height: 20,
          width: 20,
          child: Checkbox(
            value: _rememberEmail,
            onChanged: _isLoading
                ? null
                : (value) {
              setState(() {
                _rememberEmail = value ?? true;
              });
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Remember my email for future reports',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTitleField(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bug Title *',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _titleController,
          enabled: !_isLoading,
          maxLength: 100,
          decoration: InputDecoration(
            hintText: 'Brief description of the issue',
            prefixIcon: const Icon(Icons.title_rounded),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a bug title';
            }
            if (value.trim().length < 5) {
              return 'Title must be at least 5 characters';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDescriptionField(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description *',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'What happened? What did you expect to happen?',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          enabled: !_isLoading,
          maxLines: 6,
          maxLength: 1000,
          decoration: InputDecoration(
            hintText: 'Describe the bug in detail...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            alignLabelWithHint: true,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please describe the bug';
            }
            if (value.trim().length < 10) {
              return 'Description must be at least 10 characters';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildStepsField(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Steps to Reproduce (Optional)',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Help us recreate the issue',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _stepsController,
          enabled: !_isLoading,
          maxLines: 5,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: '1. Open the app\n2. Tap on...\n3. Notice that...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _isLoading ? null : _submitBugReport,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.colorScheme.onPrimary,
            ),
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.send_rounded, size: 20),
            const SizedBox(width: 8),
            Text(
              'Submit Bug Report',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}