import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/locale_controller.dart';
import '../services/app_permissions.dart';
import '../services/auth_service.dart';
import '../services/settings_preferences.dart';
import '../services/user_profile_service.dart';
import '../theme/app_colors.dart';
import '../theme/theme_controller.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/glass_panel.dart';
import '../widgets/page_background.dart';
import '../widgets/theme_mode_toggle.dart';
import 'login_screen.dart';
import 'account_edit_screens.dart';
import 'policy_screen.dart';

/// Settings hub opened from the Home drawer.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.isGuest = false,
    this.userProfileService,
    this.authService,
    this.preferences,
    this.requestNotificationPermission,
  });

  final bool isGuest;
  final UserProfileService? userProfileService;
  final AuthService? authService;
  final SettingsPreferences? preferences;
  final Future<bool> Function()? requestNotificationPermission;

  static const String backgroundAsset = PolicyScreen.backgroundAsset;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final UserProfileService _profileService =
      widget.userProfileService ?? UserProfileService();
  late final AuthService _authService = widget.authService ?? AuthService();
  late final SettingsPreferences _preferences =
      widget.preferences ?? const SettingsPreferences();
  late final Future<bool> Function() _requestNotificationPermission =
      widget.requestNotificationPermission ??
      AppPermissions.requestNotifications;

  late Future<UserProfile?> _profileFuture;

  bool _notificationsEnabled = true;
  bool _notificationBusy = true;
  bool _logoutBusy = false;
  String _units = 'km';
  _PreferenceSection? _expandedPreference;

  @override
  void initState() {
    super.initState();
    _profileFuture = widget.isGuest
        ? Future<UserProfile?>.value(UserProfileService.bundledProfile())
        : _profileService.fetchProfile();
    _restoreNotifications();
    _restoreUnits();
  }

  Future<void> _restoreUnits() async {
    final units = await _preferences.units();
    if (mounted) setState(() => _units = units);
  }

  Future<void> _open(Widget page) async {
    if (widget.isGuest) {
      _snack(AppLocalizations.of(context).signInRequired);
      return;
    }
    final changed = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute<bool>(builder: (_) => page));
    if (changed == true && mounted) {
      setState(() => _profileFuture = _profileService.fetchProfile());
    }
  }

  void _togglePreference(_PreferenceSection preference) {
    if (preference == _PreferenceSection.currency && widget.isGuest) {
      _snack(AppLocalizations.of(context).signInRequired);
      return;
    }
    setState(() {
      _expandedPreference = _expandedPreference == preference
          ? null
          : preference;
    });
  }

  Future<void> _selectLanguage(String selected) async {
    await _preferences.setLanguageCode(selected);
    if (!widget.isGuest) {
      try {
        await _profileService.updateLanguage(selected);
      } catch (error) {
        debugPrint('Language account sync failed: $error');
      }
    }
    appLocale.value = Locale(selected);
  }

  Future<void> _selectCurrency(
    AppCurrency selected,
    AppCurrency current,
  ) async {
    if (selected == current) return;
    try {
      await _profileService.updateCurrency(selected);
      if (mounted) {
        setState(() => _profileFuture = _profileService.fetchProfile());
      }
    } catch (_) {
      if (mounted) _snack(AppLocalizations.of(context).settingsUpdateFailed);
    }
  }

  Future<void> _selectUnits(String selected) async {
    await _preferences.setUnits(selected);
    if (mounted) setState(() => _units = selected);
  }

  Future<void> _restoreNotifications() async {
    final enabled = await _preferences.notificationsEnabled();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = enabled;
      _notificationBusy = false;
    });
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _comingSoon() => _snack(AppLocalizations.of(context).comingSoon);

  Future<void> _setNotifications(bool enabled) async {
    if (_notificationBusy) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _notificationBusy = true);

    if (enabled) {
      final granted = await _requestNotificationPermission();
      if (!mounted) return;
      if (!granted) {
        setState(() => _notificationBusy = false);
        _snack(l10n.notificationsPermissionDenied);
        return;
      }
    }

    try {
      await _preferences.setNotificationsEnabled(enabled);
      if (!mounted) return;
      setState(() {
        _notificationsEnabled = enabled;
        _notificationBusy = false;
      });
    } catch (error) {
      debugPrint('Notification preference update failed: $error');
      if (!mounted) return;
      setState(() => _notificationBusy = false);
      _snack(l10n.notificationsUpdateFailed);
    }
  }

  Future<void> _logOut() async {
    if (_logoutBusy) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _logoutBusy = true);

    try {
      if (!widget.isGuest) await _authService.signOut();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (error) {
      debugPrint('Settings logout failed: $error');
      if (!mounted) return;
      setState(() => _logoutBusy = false);
      _snack(l10n.logOutFailed);
    }
  }

  String _languageName(AppLocalizations l10n) =>
      switch (Localizations.localeOf(context).languageCode) {
        'ku' => l10n.languageKurdish,
        'ar' => l10n.languageArabic,
        _ => l10n.languageEnglish,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PageBackground(
        imageAsset: SettingsScreen.backgroundAsset,
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 6, 16, bottomInset + 22),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SettingsHeader(title: l10n.settings),
                      const SizedBox(height: 16),
                      FutureBuilder<UserProfile?>(
                        future: _profileFuture,
                        builder: (context, snapshot) {
                          final profile =
                              snapshot.data ??
                              UserProfileService.bundledProfile();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _ProfileCard(
                                profile: profile,
                                onTap: () => _open(
                                  EditProfileScreen(
                                    initialName: profile.name,
                                    imageUrl: profile.profileImageUrl,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 22),
                              _SectionTitle(l10n.settingsAccount),
                              const SizedBox(height: 8),
                              _SettingsGroup(
                                children: [
                                  // The User name row was removed with the
                                  // username feature — a user is identified by
                                  // their display name (edited on the profile
                                  // card above) and their email.
                                  _SettingsRow(
                                    icon: Icons.mail_outline_rounded,
                                    label: l10n.email,
                                    value:
                                        profile.email ?? 'Saraahmad@gmail.com',
                                    onTap: () => _open(
                                      ChangeEmailScreen(
                                        initialValue: profile.email ?? '',
                                      ),
                                    ),
                                  ),
                                  _SettingsRow(
                                    icon: Icons.phone_outlined,
                                    label: l10n.phoneNumber,
                                    value: profile.phone ?? '+964 750 777 7777',
                                    forceValueLtr: true,
                                    onTap: () => _open(
                                      ChangePhoneScreen(
                                        initialValue: profile.phone ?? '',
                                      ),
                                    ),
                                  ),
                                  _SettingsRow(
                                    icon: Icons.lock_outline_rounded,
                                    label: l10n.settingsChangePassword,
                                    onTap: () =>
                                        _open(const ChangePasswordScreen()),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 22),
                              _SectionTitle(l10n.settingsPreferences),
                              const SizedBox(height: 8),
                              _SettingsGroup(
                                children: [
                                  _SettingsRow(
                                    icon: Icons.notifications_none_rounded,
                                    label: l10n.settingsNotifications,
                                    onTap: _notificationBusy
                                        ? null
                                        : () => _setNotifications(
                                            !_notificationsEnabled,
                                          ),
                                    trailing: Switch(
                                      key: const ValueKey(
                                        'settings-notifications-switch',
                                      ),
                                      value: _notificationsEnabled,
                                      onChanged: _notificationBusy
                                          ? null
                                          : _setNotifications,
                                      activeThumbColor: Colors.white,
                                      activeTrackColor: AppColors.accent(
                                        context,
                                      ),
                                    ),
                                  ),
                                  _SettingsRow(
                                    icon: Icons.palette_outlined,
                                    label: l10n.settingsTheme,
                                    trailing: ValueListenableBuilder<bool>(
                                      valueListenable: appDarkMode,
                                      builder: (context, isDark, _) =>
                                          ThemeModeToggle(
                                            isDark: isDark,
                                            compact: true,
                                            onChanged:
                                                ThemePreference.setDarkMode,
                                          ),
                                    ),
                                  ),
                                  _ExpandableSettingsRow(
                                    row: _SettingsRow(
                                      icon: Icons.language_rounded,
                                      label: l10n.settingsLanguage,
                                      value: _languageName(l10n),
                                      expandable: true,
                                      expanded:
                                          _expandedPreference ==
                                          _PreferenceSection.language,
                                      onTap: () => _togglePreference(
                                        _PreferenceSection.language,
                                      ),
                                    ),
                                    expanded:
                                        _expandedPreference ==
                                        _PreferenceSection.language,
                                    child: _InlineChoiceList<String>(
                                      current: Localizations.localeOf(
                                        context,
                                      ).languageCode,
                                      choices: {
                                        'ku': l10n.languageKurdish,
                                        'en': l10n.languageEnglish,
                                        'ar': l10n.languageArabic,
                                      },
                                      onSelected: _selectLanguage,
                                    ),
                                  ),
                                  _ExpandableSettingsRow(
                                    row: _SettingsRow(
                                      icon: Icons.paid_outlined,
                                      label: l10n.currency,
                                      value: profile.currency.code,
                                      forceValueLtr: true,
                                      expandable: true,
                                      expanded:
                                          _expandedPreference ==
                                          _PreferenceSection.currency,
                                      onTap: () => _togglePreference(
                                        _PreferenceSection.currency,
                                      ),
                                    ),
                                    expanded:
                                        _expandedPreference ==
                                        _PreferenceSection.currency,
                                    child: _InlineChoiceList<AppCurrency>(
                                      current: profile.currency,
                                      choices: const {
                                        AppCurrency.usd: 'USD',
                                        AppCurrency.iqd: 'IQD',
                                        AppCurrency.eur: 'EUR',
                                      },
                                      onSelected: (selected) => _selectCurrency(
                                        selected,
                                        profile.currency,
                                      ),
                                    ),
                                  ),
                                  _ExpandableSettingsRow(
                                    row: _SettingsRow(
                                      icon: Icons.straighten_rounded,
                                      label: l10n.settingsUnits,
                                      value: _units == 'mi'
                                          ? l10n.milesShort
                                          : l10n.kilometersShort,
                                      expandable: true,
                                      expanded:
                                          _expandedPreference ==
                                          _PreferenceSection.units,
                                      onTap: () => _togglePreference(
                                        _PreferenceSection.units,
                                      ),
                                    ),
                                    expanded:
                                        _expandedPreference ==
                                        _PreferenceSection.units,
                                    child: _InlineChoiceList<String>(
                                      current: _units,
                                      choices: {
                                        'km': l10n.kilometers,
                                        'mi': l10n.miles,
                                      },
                                      onSelected: _selectUnits,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 22),
                              _SectionTitle(l10n.settingsSecurityLegal),
                              const SizedBox(height: 8),
                              _SettingsGroup(
                                children: [
                                  _SettingsRow(
                                    icon: Icons.gpp_good_outlined,
                                    label: l10n.settingsSecurityPrivacy,
                                    onTap: _comingSoon,
                                  ),
                                  _SettingsRow(
                                    icon: Icons.delete_outline_rounded,
                                    label: l10n.settingsDeleteAccount,
                                    onTap: _comingSoon,
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      Align(
                        child: SizedBox(
                          width: 200,
                          height: 50,
                          child: _LogoutButton(
                            label: l10n.logOut,
                            busy: _logoutBusy,
                            onTap: _logOut,
                          ),
                        ),
                      ),
                    ],
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

enum _PreferenceSection { language, currency, units }

/// Inline selector shared by Language, Currency and Units.
class _InlineChoiceList<T> extends StatelessWidget {
  const _InlineChoiceList({
    required this.current,
    required this.choices,
    required this.onSelected,
  });

  final T current;
  final Map<T, String> choices;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(50, 0, 8, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in choices.entries)
          _ChoiceOption(
            label: entry.value,
            selected: entry.key == current,
            onTap: () => onSelected(entry.key),
          ),
      ],
    ),
  );
}

class _ChoiceOption extends StatelessWidget {
  const _ChoiceOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent(context).withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected
                        ? AppColors.selectionAccent(context)
                        : AppColors.heading(context),
                  ),
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: AppColors.selectionAccent(context),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      textDirection: TextDirection.ltr,
      children: [
        GlassBackButton(onTap: () => Navigator.of(context).maybePop()),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textDirection: Directionality.of(context),
            style: TextStyle(
              fontSize: 28,
              height: 36 / 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.02 * 28,
              color: AppColors.heading(context),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile, required this.onTap});

  final UserProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accent(context);
    return GlassPanel(
      borderRadius: 28,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 12, 14),
            child: Row(
              children: [
                _ProfileAvatar(url: profile.profileImageUrl, accent: accent),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.heading(context),
                        ),
                      ),
                      if (profile.phone?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          profile.phone!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                _ForwardChevron(color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.url, required this.accent});

  final String? url;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    Widget fallback() =>
        Icon(Icons.person_outline_rounded, size: 38, color: accent);

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: 0.12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.62),
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: url?.trim().isNotEmpty == true
            ? Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback(),
              )
            : fallback(),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: TextStyle(
      fontSize: 20,
      height: 26 / 20,
      fontWeight: FontWeight.w700,
      color: AppColors.heading(context),
    ),
  );
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => GlassPanel(
    borderRadius: 28,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: Column(
      children: [
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index != children.length - 1) const _FadingDivider(),
        ],
      ],
    ),
  );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
    this.trailing,
    this.forceValueLtr = false,
    this.expandable = false,
    this.expanded = false,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool forceValueLtr;
  final bool expandable;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accent(context);
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: accent.withValues(alpha: 0.55),
                width: 1.2,
              ),
              color: Colors.white.withValues(alpha: 0.10),
            ),
            child: Icon(icon, size: 20, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          if (value != null) ...[
            const SizedBox(width: 8),
            Expanded(
              flex: 5,
              child: Text(
                value!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                textDirection: forceValueLtr ? TextDirection.ltr : null,
                style: TextStyle(
                  fontSize: 14.5,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ] else if (onTap != null) ...[
            const SizedBox(width: 8),
            if (expandable)
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 24,
                  color: accent,
                ),
              )
            else
              _ForwardChevron(color: accent),
          ],
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: content,
      ),
    );
  }
}

class _ExpandableSettingsRow extends StatelessWidget {
  const _ExpandableSettingsRow({
    required this.row,
    required this.expanded,
    required this.child,
  });

  final Widget row;
  final bool expanded;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      row,
      ClipRect(
        child: AnimatedSize(
          alignment: Alignment.topCenter,
          duration: const Duration(milliseconds: 280),
          reverseDuration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: expanded
              ? Column(children: [const _FadingDivider(), child])
              : const SizedBox(width: double.infinity),
        ),
      ),
    ],
  );
}

class _ForwardChevron extends StatelessWidget {
  const _ForwardChevron({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Icon(
    Directionality.of(context) == TextDirection.rtl
        ? Icons.chevron_left_rounded
        : Icons.chevron_right_rounded,
    size: 24,
    color: color,
  );
}

class _FadingDivider extends StatelessWidget {
  const _FadingDivider();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : AppColors.actionNavy;
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0),
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({
    required this.label,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? AppColors.luminousMint : AppColors.actionNavy;
    final foreground = isDark ? AppColors.darkOnPrimary : Colors.white;
    return ElevatedButton.icon(
      onPressed: busy ? null : onTap,
      icon: busy
          ? SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: foreground,
              ),
            )
          : const Icon(Icons.logout_rounded),
      label: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: background.withValues(alpha: 0.55),
        disabledForegroundColor: foreground.withValues(alpha: 0.85),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
