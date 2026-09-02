import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import 'murkot_boot_screen.dart';

/// Session hydrate overlay — same visual as the HTML / Flutter boot screen.
class SessionBootOverlay extends StatelessWidget {
  const SessionBootOverlay({
    super.key,
    this.failed = false,
    this.allowContinueWhileLoading = false,
    this.onContinue,
    this.onRetry,
  });

  final bool failed;

  /// After a soft timeout the parent may offer "open app anyway".
  final bool allowContinueWhileLoading;
  final VoidCallback? onContinue;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final slow = !failed && allowContinueWhileLoading;

    return MurkotBootScreen(
      title: strings.loadingMurkot,
      subtitle: failed
          ? strings.sessionBootFailedSubtitle
          : slow
              ? strings.sessionBootSlowSubtitle
              : strings.platformTagline,
      onContinue: (failed || slow) ? onContinue : null,
      onRetry: failed ? onRetry : null,
      continueLabel: strings.continueAnyway,
    );
  }
}
