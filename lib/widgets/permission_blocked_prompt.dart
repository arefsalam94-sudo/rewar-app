import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/app_permissions.dart';

/// Offers the user a way out of a **permanently denied** permission.
///
/// Uses the SnackBar-with-action pattern the permission messages on these
/// screens already use, so nothing about the visual design changes — the only
/// difference is that this one carries an action.
///
/// ## Nothing opens settings on its own
///
/// Leaving the app is a jarring thing to do to someone unprompted, so this
/// only ever *offers*. The user taps "Open Settings" or ignores it; ignoring
/// it dismisses the bar and leaves them exactly where they were, with the
/// explanation still shown by the calling screen.
///
/// [reason] is the permission-specific line the screen already had
/// (e.g. "Camera access is off…"); the generic blocked sentence is appended so
/// the user learns *why* asking again will not help.
Future<void> showPermissionBlockedPrompt(
  BuildContext context, {
  required String reason,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('$reason ${l10n.permissionBlocked}'),
        // Long enough to read two sentences and decide, and it stays until
        // dismissed if the user is reading.
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: l10n.permissionOpenSettings,
          onPressed: AppPermissions.openSettings,
        ),
      ),
    );
}
