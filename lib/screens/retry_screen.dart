import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

/// Full-screen "something is wrong, try again" state: no connection, or a page
/// that failed to load. Replaces the bare white screen the app used to leave.
class RetryScreen extends StatelessWidget {
  const RetryScreen({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.retryLabel,
    required this.onRetry,
    this.rtl = false,
  });

  factory RetryScreen.offline(AppStrings s, {required VoidCallback onRetry}) =>
      RetryScreen(
        icon: Icons.wifi_off,
        title: s.offlineTitle,
        body: s.offlineBody,
        retryLabel: s.retry,
        onRetry: onRetry,
        rtl: s.isRtl,
      );

  factory RetryScreen.loadFailed(AppStrings s, {required VoidCallback onRetry}) =>
      RetryScreen(
        icon: Icons.cloud_off,
        title: s.failedTitle,
        body: s.failedBody,
        retryLabel: s.retry,
        onRetry: onRetry,
        rtl: s.isRtl,
      );

  final IconData icon;
  final String title;
  final String body;
  final String retryLabel;
  final VoidCallback onRetry;
  final bool rtl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: ColoredBox(
        color: theme.colorScheme.surface,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 80,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(retryLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown instead of a white screen while the first page is still on its way
/// after the splash has gone.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(label, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
