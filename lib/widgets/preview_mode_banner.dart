import 'package:flutter/material.dart';

import '../services/password_reset_service.dart';
import '../theme/app_colors.dart';

/// Loud, debug-only marker shown on screens whose backend calls are being
/// faked because Firebase isn't configured yet.
///
/// Renders nothing at all when the backend is real, and can never appear in a
/// release build — [PasswordResetService.isPreviewMode] is gated on
/// `kDebugMode`.
class PreviewModeBanner extends StatelessWidget {
  const PreviewModeBanner({super.key, required this.message});

  /// What is being faked on this particular screen.
  final String message;

  @override
  Widget build(BuildContext context) {
    if (!PasswordResetService.isPreviewMode) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warningBannerFill.withValues(
          alpha: AppColors.warningBannerFillOpacity,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warningBannerBorder, width: 1.2),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 20,
            color: AppColors.warningBannerIcon,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                height: 1.3,
                fontWeight: FontWeight.w600,
                color: AppColors.warningBannerText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
