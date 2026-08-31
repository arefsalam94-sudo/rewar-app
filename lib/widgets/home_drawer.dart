import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations.dart';
import '../screens/billing_payment_screen.dart';
import '../screens/car_rental_screen.dart';
import '../screens/explore_nature_screen.dart';
import '../screens/explore_tours_screen.dart';
import '../screens/flight_ticketing_screen.dart';
import '../screens/help_support_screen.dart';
import '../screens/hotel_screen.dart';
import '../screens/login_screen.dart';
import '../screens/my_bookings_screen.dart';
import '../screens/policy_screen.dart';
import '../screens/settings_screen.dart';
import '../services/auth_service.dart';
import '../services/profile_setup_service.dart';
import '../services/user_profile_service.dart';
import '../theme/app_colors.dart';
import 'glass_panel.dart';
import 'sign_in_required.dart';

/// The hamburger side drawer opened from the Home screen's top bar.
///
/// Anchored to the screen's **leading** edge — left in English, right in
/// Kurdish/Arabic — so it opens from the same side as the hamburger icon in
/// every language (`_TopBar`'s menu button is already `AlignmentDirectional
/// .centerStart`). The far (trailing) edge is a wavy silhouette per the
/// reference screenshot; opening plays a short ripple on that edge which
/// decays into the resting shape — see [_WavyEdgeClipper].
///
/// Services expands in place, and each of its five sub-items opens the same
/// screen as the matching Home journey card; Currency updates
/// `users.preferredCurrency`;
/// Billing/Payments, Settings, Policy, and Help/Support open their own
/// screens. The remaining destinations keep the "coming soon" treatment.
class HomeDrawer extends StatefulWidget {
  const HomeDrawer({
    super.key,
    required this.isGuest,
    this.displayName,
    this.userProfileService,
    this.authService,
    this.profileSetupService,
    this.picker,
  });

  final bool isGuest;
  final String? displayName;

  /// Injectable for tests; default to the real Firebase-backed services.
  final UserProfileService? userProfileService;
  final AuthService? authService;
  final ProfileSetupService? profileSetupService;
  final ImagePicker? picker;

  @override
  State<HomeDrawer> createState() => _HomeDrawerState();
}

class _HomeDrawerState extends State<HomeDrawer>
    with SingleTickerProviderStateMixin {
  static const double _panelWidthFraction = 0.82;
  static const double _maxPanelWidth = 320;
  static const Duration _openDuration = Duration(milliseconds: 900);
  static const Duration _closeDuration = Duration(milliseconds: 420);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _openDuration,
    reverseDuration: _closeDuration,
  );
  late final Animation<double> _slide = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  late final UserProfileService _userProfileService =
      widget.userProfileService ?? UserProfileService();
  late final AuthService _authService = widget.authService ?? AuthService();
  late final ProfileSetupService _profileSetupService =
      widget.profileSetupService ?? ProfileSetupService();
  late final ImagePicker _picker = widget.picker ?? ImagePicker();

  Future<UserProfile?>? _profileFuture;
  File? _localAvatarFile;
  bool _servicesExpanded = false;
  bool _busy = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isGuest) _profileFuture = _userProfileService.fetchProfile();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    await _controller.reverse();
    if (mounted) Navigator.of(context).pop();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _placeholderTap() => _snack(AppLocalizations.of(context).comingSoon);

  void _toggleServices() =>
      setState(() => _servicesExpanded = !_servicesExpanded);

  /// Closes the drawer, then opens the Policy hub.
  ///
  /// The drawer is a dialog route, so it has to be dismissed first — leaving
  /// it open behind a full screen would trap the user's back gesture on the
  /// wrong route. The navigator is captured *before* [_close], because this
  /// widget is unmounted by the time it returns.
  ///
  /// Available to guests as well as signed-in users, on purpose: legal terms
  /// have to be readable by someone who has not agreed to them yet.
  Future<void> _onPolicyTap() async {
    final navigator = Navigator.of(context, rootNavigator: true);
    await _close();
    await navigator.push<void>(
      MaterialPageRoute<void>(builder: (_) => const PolicyScreen()),
    );
  }

  /// Closes the drawer, then opens Help & Support.
  ///
  /// Open to guests as well as signed-in users: someone who cannot sign in is
  /// exactly the person who needs the help centre.
  Future<void> _onHelpTap() async {
    final navigator = Navigator.of(context, rootNavigator: true);
    await _close();
    await navigator.push<void>(
      MaterialPageRoute<void>(builder: (_) => const HelpSupportScreen()),
    );
  }

  /// Closes the drawer, then opens Settings. Guests may preview device-level
  /// preferences and use the bottom button to return to Login.
  Future<void> _onSettingsTap() async {
    final navigator = Navigator.of(context, rootNavigator: true);
    await _close();
    await navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          isGuest: widget.isGuest,
          userProfileService: _userProfileService,
          authService: _authService,
        ),
      ),
    );
  }

  /// Closes the drawer, then opens one of the Services sub-items.
  ///
  /// These are the same five destinations as the Home dashboard's journey
  /// cards, so the drawer is a second route to them rather than a different
  /// experience — none of them needs `isGuest`, since browsing is open to
  /// everyone and the per-action gates live inside each screen.
  Future<void> _onServiceTap(WidgetBuilder builder) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    await _close();
    await navigator.push<void>(MaterialPageRoute<void>(builder: builder));
  }

  /// Closes the drawer, then opens My Bookings.
  ///
  /// A guest is pushed the same screen rather than being blocked at the drawer:
  /// bookings need an auth uid, so the screen itself explains that and offers
  /// a route to Login. Same precedent as Settings.
  Future<void> _onMyBookingsTap() async {
    final navigator = Navigator.of(context, rootNavigator: true);
    await _close();
    await navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MyBookingsScreen(isGuest: widget.isGuest),
      ),
    );
  }

  /// Opens Billing & Payments.
  ///
  /// `hasPaymentMethod` is written by the future payment backend, never by
  /// the client and selects the saved-method design when true.
  ///
  /// A guest is pushed the same screen rather than being stopped here with a
  /// snackbar: the screen explains why saved cards need an account and offers
  /// a route to Login. Same precedent as My Bookings and Settings.
  Future<void> _onBillingTap() async {
    if (widget.isGuest) {
      final navigator = Navigator.of(context, rootNavigator: true);
      await _close();
      await navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const BillingPaymentScreen(isGuest: true),
        ),
      );
      return;
    }

    final profile = await _profileFuture;
    if (!mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    await _close();
    await navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => BillingPaymentScreen(
          hasSavedMethods: profile?.hasPaymentMethod == true,
        ),
      ),
    );
  }

  // --- Avatar / photo --------------------------------------------------

  Future<void> _onAvatarTap() async {
    final l10n = AppLocalizations.of(context);
    // The avatar opens no screen of its own, so the guest gate is shown as a
    // sheet here rather than as a full page.
    if (widget.isGuest) {
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => SignInRequiredSheet(
          title: l10n.photoSignInTitle,
          body: l10n.photoSignInBody,
          icon: Icons.account_circle_outlined,
        ),
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final source = await showModalBottomSheet<_ImageAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ImageSourceSheet(dark: isDark),
    );
    if (source == null || !mounted) return;

    try {
      final picked = await _picker.pickImage(
        source: source == _ImageAction.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      final file = File(picked.path);
      setState(() {
        _busy = true;
        _localAvatarFile = file;
      });
      await _profileSetupService.updateProfilePhoto(file);
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(l10n.profilePhotoUpdated);
    } on ImageTooLargeException {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(l10n.imageTooLarge);
    } catch (e) {
      debugPrint('Profile photo update failed: $e');
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(l10n.profileSaveFailed);
    }
  }

  // --- Currency ----------------------------------------------------------

  Future<void> _onCurrencyTap() async {
    final l10n = AppLocalizations.of(context);
    if (widget.isGuest) {
      _snack(l10n.signInRequired);
      return;
    }

    final existing = await _profileFuture;
    if (!mounted) return;
    final current = existing?.currency ?? AppCurrency.usd;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = await showModalBottomSheet<AppCurrency>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _CurrencySheet(dark: isDark, current: current),
    );
    if (selected == null || selected == current || !mounted) return;

    setState(() => _busy = true);
    try {
      await _userProfileService.updateCurrency(selected);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _profileFuture = _userProfileService.fetchProfile();
      });
      _snack(l10n.currencyUpdated);
    } catch (e) {
      debugPrint('Currency update failed: $e');
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(l10n.currencyUpdateFailed);
    }
  }

  // --- Log out / log in ---------------------------------------------------

  Future<void> _onBottomButtonTap() async {
    if (widget.isGuest) {
      _goToLogin();
      return;
    }

    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await _authService.signOut();
      if (!mounted) return;
      _goToLogin();
    } catch (e) {
      debugPrint('Sign out failed: $e');
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(l10n.logOutFailed);
    }
  }

  /// Clears the whole navigation stack — signing out (or a guest choosing to
  /// log in) ends the session this drawer belongs to, so nothing behind it
  /// (Home, the dialog route itself) should remain reachable via back.
  void _goToLogin() {
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // --- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final panelWidth = math.min(
      _maxPanelWidth,
      screenWidth * _panelWidthFraction,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _close();
      },
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final linear = _controller.value.clamp(0.0, 1.0);
            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _busy ? null : _close,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.45 * linear),
                    ),
                  ),
                ),
                PositionedDirectional(
                  start: -panelWidth + panelWidth * _slide.value,
                  top: 0,
                  bottom: 0,
                  width: panelWidth,
                  child: Builder(
                    builder: (context) {
                      final edge = _WavyEdgeClipper(
                        rtl: isRtl,
                        progress: linear,
                      );
                      return CustomPaint(
                        foregroundPainter: _WavyEdgeBorderPainter(
                          clipper: edge,
                          color: Colors.white.withValues(
                            alpha: isDark ? 0.18 : 0.72,
                          ),
                        ),
                        child: ClipPath(
                          clipper: edge,
                          child: _panelSurface(isDark, panelWidth),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _panelSurface(bool isDark, double panelWidth) {
    final l10n = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.darkGlassTop, AppColors.darkForestFloor],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.pageGradientTop,
                  AppColors.pageGradientBottom,
                ],
              ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 56, 52, 20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    _buildProfileHeader(l10n, isDark),
                    const SizedBox(height: 20),
                    Divider(
                      color: (isDark ? Colors.white : AppColors.actionNavy)
                          .withValues(alpha: isDark ? 0.18 : 0.2),
                      height: 1,
                    ),
                    const SizedBox(height: 12),
                    _buildMenuList(l10n, isDark),
                    const SizedBox(height: 20),
                    _buildBottomButton(l10n, isDark),
                  ],
                ),
              ),
            ),
            PositionedDirectional(
              top: 10,
              end: 14,
              child: _CloseButton(
                isDark: isDark,
                tooltip: l10n.close,
                onTap: _busy ? null : _close,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(AppLocalizations l10n, bool isDark) {
    final accent = isDark ? AppColors.luminousMint : AppColors.actionNavy;
    final onAccent = isDark ? AppColors.darkOnPrimary : Colors.white;
    final headingColor = AppColors.heading(context);

    if (widget.isGuest) {
      return Column(
        children: [
          _Avatar(
            imageFile: null,
            imageUrl: null,
            accent: accent,
            onAccent: onAccent,
            editable: false,
            onTap: _onAvatarTap,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.guestUser,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: headingColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.guestDrawerPrompt,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.secondaryText(context),
            ),
          ),
        ],
      );
    }

    return FutureBuilder<UserProfile?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final name = (profile != null && profile.name.trim().isNotEmpty)
            ? profile.name
            : (widget.displayName?.trim().isNotEmpty == true
                  ? widget.displayName!
                  : l10n.dearUser);

        return Column(
          children: [
            _Avatar(
              imageFile: _localAvatarFile,
              imageUrl: profile?.profileImageUrl,
              accent: accent,
              onAccent: onAccent,
              editable: true,
              onTap: _onAvatarTap,
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: headingColor,
              ),
            ),
            if (profile?.email != null && profile!.email!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                profile.email!,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.secondaryText(context),
                ),
              ),
            ],
            if (profile?.phone != null && profile!.phone!.isNotEmpty) ...[
              const SizedBox(height: 2),
              // Phone numbers always read left-to-right, matching Register /
              // Forget Password.
              Text(
                profile.phone!,
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.secondaryText(context),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildMenuList(AppLocalizations l10n, bool isDark) {
    final accent = isDark ? AppColors.luminousMint : AppColors.actionNavy;
    final onAccent = isDark ? AppColors.darkOnPrimary : Colors.white;
    final connectorColor = (isDark ? Colors.white : AppColors.actionNavy)
        .withValues(alpha: isDark ? AppColors.darkBorderOpacity * 2 : 0.22);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MenuRow(
          icon: Icons.list_alt_rounded,
          label: l10n.services,
          accent: accent,
          onAccent: onAccent,
          onTap: _toggleServices,
          trailing: AnimatedRotation(
            turns: _servicesExpanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: Icon(Icons.keyboard_arrow_down_rounded, color: accent),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          // A genuinely conditional child (not AnimatedCrossFade's dual-child
          // approach) — collapsed means the sub-items aren't in the tree at
          // all, not just faded out, so they can't be tapped or found while
          // hidden.
          child: !_servicesExpanded
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ServiceSubItem(
                        icon: Icons.park_outlined,
                        label: l10n.exploreNature,
                        onTap: () =>
                            _onServiceTap((_) => const ExploreNatureScreen()),
                      ),
                      _ServiceSubItem(
                        icon: Icons.king_bed_outlined,
                        label: l10n.whereToStay,
                        onTap: () => _onServiceTap((_) => const HotelScreen()),
                      ),
                      _ServiceSubItem(
                        icon: Icons.directions_car_outlined,
                        label: l10n.carRental,
                        onTap: () =>
                            _onServiceTap((_) => const CarRentalScreen()),
                      ),
                      _ServiceSubItem(
                        icon: Icons.flight_takeoff_outlined,
                        label: l10n.flightTicketing,
                        onTap: () =>
                            _onServiceTap((_) => const FlightTicketingScreen()),
                      ),
                      _ServiceSubItem(
                        icon: Icons.festival_outlined,
                        label: l10n.exploreToursTitle,
                        onTap: () =>
                            _onServiceTap((_) => const ExploreToursScreen()),
                      ),
                    ],
                  ),
                ),
        ),
        _DashedConnector(color: connectorColor),
        _MenuRow(
          icon: Icons.calendar_month_outlined,
          label: l10n.myBookings,
          accent: accent,
          onAccent: onAccent,
          onTap: _onMyBookingsTap,
        ),
        _DashedConnector(color: connectorColor),
        _MenuRow(
          icon: Icons.credit_card_outlined,
          label: l10n.billingPayments,
          accent: accent,
          onAccent: onAccent,
          onTap: _onBillingTap,
        ),
        _DashedConnector(color: connectorColor),
        _MenuRow(
          icon: Icons.settings_outlined,
          label: l10n.settings,
          accent: accent,
          onAccent: onAccent,
          onTap: _onSettingsTap,
        ),
        _DashedConnector(color: connectorColor),
        _MenuRow(
          icon: Icons.attach_money_rounded,
          label: l10n.currency,
          accent: accent,
          onAccent: onAccent,
          onTap: _onCurrencyTap,
        ),
        _DashedConnector(color: connectorColor),
        _MenuRow(
          icon: Icons.shield_outlined,
          label: l10n.policy,
          accent: accent,
          onAccent: onAccent,
          onTap: _onPolicyTap,
        ),
        _DashedConnector(color: connectorColor),
        _MenuRow(
          icon: Icons.help_outline_rounded,
          label: l10n.helpSupport,
          accent: accent,
          onAccent: onAccent,
          onTap: _onHelpTap,
        ),
        _DashedConnector(color: connectorColor),
        _MenuRow(
          icon: Icons.info_outline_rounded,
          label: l10n.aboutUs,
          accent: accent,
          onAccent: onAccent,
          onTap: _placeholderTap,
        ),
        _DashedConnector(color: connectorColor),
        _MenuRow(
          icon: Icons.phone_outlined,
          label: l10n.contactWay,
          accent: accent,
          onAccent: onAccent,
          onTap: _placeholderTap,
        ),
      ],
    );
  }

  Widget _buildBottomButton(AppLocalizations l10n, bool isDark) {
    final accent = isDark ? AppColors.luminousMint : AppColors.actionNavy;
    final label = widget.isGuest ? l10n.logIn : l10n.logOut;

    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _busy ? null : _onBottomButtonTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: accent, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          foregroundColor: accent,
        ),
        icon: Icon(
          widget.isGuest ? Icons.login_rounded : Icons.logout_rounded,
          size: 20,
        ),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
    );
  }
}

// --- Wavy edge -------------------------------------------------------------

/// Clips the drawer panel's trailing edge into a wavy silhouette.
///
/// [progress] drives a travelling ripple whose amplitude peaks halfway
/// through the transition and returns to zero at either end. The resting
/// silhouette keeps three deep, rounded lobes like the supplied reference.
class _WavyEdgeClipper extends CustomClipper<Path> {
  const _WavyEdgeClipper({required this.rtl, required this.progress});

  final bool rtl;
  final double progress;

  static const double _restingInset = 25;
  static const double _baseAmplitude = 21;
  static const double _rippleAmplitude = 17;
  static const double _corner = 26;
  static const int _samples = 72;

  @override
  Path getClip(Size size) {
    final straightX = rtl ? size.width : 0.0;
    // Points from the straight (hinge) edge toward the wavy one.
    final dir = rtl ? -1.0 : 1.0;
    final baseWavyX = rtl ? 0.0 : size.width;

    double waveX(double y) {
      final t = (size.height == 0 ? 0.0 : y / size.height).clamp(0.0, 1.0);
      final settled =
          _restingInset +
          math.sin(t * math.pi * 5.4 - math.pi / 2) * _baseAmplitude;
      final envelope = math.sin(progress * math.pi);
      final travelling =
          math.sin(t * math.pi * 8 - progress * math.pi * 2) *
          _rippleAmplitude *
          envelope;
      final inset = (settled + travelling).clamp(2.0, 58.0).toDouble();
      return baseWavyX - dir * inset;
    }

    final path = Path()
      ..moveTo(straightX, _corner)
      ..quadraticBezierTo(straightX, 0, straightX + dir * _corner, 0)
      ..lineTo(waveX(0), 0);

    for (var i = 1; i <= _samples; i++) {
      final y = size.height * i / _samples;
      path.lineTo(waveX(y), y);
    }

    path
      ..lineTo(straightX + dir * _corner, size.height)
      ..quadraticBezierTo(
        straightX,
        size.height,
        straightX,
        size.height - _corner,
      )
      ..close();

    return path;
  }

  @override
  bool shouldReclip(covariant _WavyEdgeClipper oldClipper) =>
      oldClipper.progress != progress || oldClipper.rtl != rtl;
}

class _WavyEdgeBorderPainter extends CustomPainter {
  const _WavyEdgeBorderPainter({required this.clipper, required this.color});

  final _WavyEdgeClipper clipper;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      clipper.getClip(size),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _WavyEdgeBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.clipper.progress != clipper.progress ||
      oldDelegate.clipper.rtl != clipper.rtl;
}

// --- Small pieces ------------------------------------------------------

class _CloseButton extends StatelessWidget {
  const _CloseButton({
    required this.isDark,
    required this.tooltip,
    required this.onTap,
  });

  final bool isDark;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fill = isDark ? AppColors.luminousMint : AppColors.actionNavy;
    final onFill = isDark ? AppColors.darkOnPrimary : Colors.white;

    return Semantics(
      button: true,
      label: tooltip,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: Material(
            color: fill,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 36,
                height: 36,
                child: Icon(Icons.close_rounded, color: onFill, size: 20),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.imageFile,
    required this.imageUrl,
    required this.accent,
    required this.onAccent,
    required this.editable,
    required this.onTap,
  });

  final File? imageFile;
  final String? imageUrl;
  final Color accent;
  final Color onAccent;
  final bool editable;
  final VoidCallback onTap;

  static const double _size = 84;
  static const double _badge = 30;

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (imageFile != null) {
      content = ClipOval(
        child: Image.file(
          imageFile!,
          fit: BoxFit.cover,
          width: _size,
          height: _size,
        ),
      );
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      content = ClipOval(
        child: Image.network(
          imageUrl!,
          fit: BoxFit.cover,
          width: _size,
          height: _size,
          errorBuilder: (context, error, stackTrace) =>
              Icon(Icons.person_outline, size: 44, color: accent),
        ),
      );
    } else {
      content = Icon(Icons.person_outline, size: 44, color: accent);
    }

    return SizedBox(
      width: _size + 10,
      height: _size + 10,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: GestureDetector(
              // Tappable in both states. A guest has no photo to edit, but the
              // tap is what surfaces the sign-in gate explaining why — it used
              // to be inert, which left the guest branch of the handler
              // unreachable. [editable] still controls the camera badge below,
              // so the affordance stays signed-in only.
              onTap: onTap,
              child: Container(
                width: _size,
                height: _size,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: Center(child: content),
              ),
            ),
          ),
          if (editable)
            PositionedDirectional(
              bottom: 2,
              end: 0,
              child: Semantics(
                button: true,
                child: Material(
                  color: accent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: onTap,
                    customBorder: const CircleBorder(),
                    child: SizedBox(
                      width: _badge,
                      height: _badge,
                      child: Icon(
                        Icons.camera_alt_outlined,
                        color: onAccent,
                        size: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DashedConnector extends StatelessWidget {
  const _DashedConnector({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 12,
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 19),
        child: CustomPaint(
          size: const Size(2, 12),
          painter: _DashedLinePainter(color),
        ),
      ),
    ),
  );
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    const dash = 3.0;
    const gap = 3.0;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, math.min(y + dash, size.height)),
        paint,
      );
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onAccent,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final Color onAccent;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.actionNavy;

    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent,
                  ),
                  child: Icon(icon, size: 18, color: onAccent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceSubItem extends StatelessWidget {
  const _ServiceSubItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.luminousMint : AppColors.actionNavy;
    final textColor = isDark
        ? Colors.white.withValues(alpha: AppColors.darkSecondaryTextOpacity)
        : AppColors.secondaryText(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 52, top: 5, bottom: 5),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 24),
          child: Row(
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 10),
              // Per DESIGN_SYSTEM.md's "text next to text must be allowed to
              // shrink" rule — the panel is only ~320dp wide, and the icon
              // column eats into that further.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
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
}

// --- Currency sheet ----------------------------------------------------

class _CurrencySheet extends StatelessWidget {
  const _CurrencySheet({required this.dark, required this.current});

  final bool dark;
  final AppCurrency current;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final accent = dark ? AppColors.luminousMint : AppColors.actionNavy;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GlassPanel(
          borderRadius: 28,
          dark: dark,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Text(
                  l10n.selectCurrency,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              for (final option in AppCurrency.values)
                ListTile(
                  leading: Icon(Icons.attach_money_rounded, color: accent),
                  title: Text(switch (option) {
                    AppCurrency.usd => l10n.currencyUSD,
                    AppCurrency.iqd => l10n.currencyIQD,
                    AppCurrency.eur => l10n.currencyEUR,
                  }, style: TextStyle(color: colorScheme.onSurface)),
                  trailing: option == current
                      ? Icon(Icons.check_rounded, color: accent)
                      : null,
                  onTap: () => Navigator.of(context).pop(option),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Photo source sheet --------------------------------------------------

enum _ImageAction { camera, gallery }

class _ImageSourceSheet extends StatelessWidget {
  const _ImageSourceSheet({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final accent = dark ? AppColors.luminousMint : AppColors.actionNavy;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GlassPanel(
          borderRadius: 28,
          dark: dark,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_camera_outlined, color: accent),
                title: Text(
                  l10n.takePhoto,
                  style: TextStyle(color: colorScheme.onSurface),
                ),
                onTap: () => Navigator.of(context).pop(_ImageAction.camera),
              ),
              ListTile(
                leading: Icon(Icons.photo_library_outlined, color: accent),
                title: Text(
                  l10n.chooseFromGallery,
                  style: TextStyle(color: colorScheme.onSurface),
                ),
                onTap: () => Navigator.of(context).pop(_ImageAction.gallery),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
