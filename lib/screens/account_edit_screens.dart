import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations.dart';
import '../services/account_settings_service.dart';
import '../services/preview_identity.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/glass_panel.dart';
import '../widgets/page_background.dart';
import '../widgets/primary_button.dart';
import 'policy_screen.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.initialName,
    required this.imageUrl,
    this.service,
    this.picker,
  });

  final String initialName;
  final String? imageUrl;
  final AccountSettingsService? service;
  final ImagePicker? picker;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final _service = widget.service ?? AccountSettingsService();
  late final _picker = widget.picker ?? ImagePicker();
  late final List<String> _nameParts = widget.initialName.trim().split(
    RegExp(r'\s+'),
  );
  late final _firstName = TextEditingController(
    text: _nameParts.isEmpty ? '' : _nameParts.first,
  );
  late final _lastName = TextEditingController(
    text: _nameParts.length < 2 ? '' : _nameParts.skip(1).join(' '),
  );
  File? _image;
  bool _busy = false;

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (picked != null && mounted) setState(() => _image = File(picked.path));
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final first = _firstName.text.trim();
    final last = _lastName.text.trim();
    if (first.isEmpty || last.isEmpty) {
      _snack(l10n.firstAndLastNameRequired);
      return;
    }
    final name = '$first $last';
    setState(() => _busy = true);
    try {
      await _service.updateProfile(fullName: name, image: _image);
      // Keeps the preview stand-in in step with the edit, so the drawer does
      // not keep showing the old name while Firebase is missing.
      await PreviewIdentity.save(name: name);
      if (!mounted) return;
      _snack(l10n.profileUpdated);
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) _snack(l10n.settingsUpdateFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ImageProvider<Object>? avatarImage = _image != null
        ? FileImage(_image!)
        : widget.imageUrl?.isNotEmpty == true
        ? NetworkImage(widget.imageUrl!)
        : null;
    return _EditShell(
      title: l10n.editProfile,
      subtitle: l10n.editProfileSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 58,
                  backgroundColor: AppColors.accent(
                    context,
                  ).withValues(alpha: 0.15),
                  foregroundImage: avatarImage,
                  child: Icon(
                    Icons.person_outline_rounded,
                    size: 62,
                    color: AppColors.accent(context),
                  ),
                ),
                PositionedDirectional(
                  end: 0,
                  bottom: 0,
                  child: IconButton.filled(
                    key: const Key('edit-profile-photo'),
                    onPressed: _pickImage,
                    icon: const Icon(Icons.camera_alt_outlined),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _EditField(
            controller: _firstName,
            label: l10n.firstName,
            icon: Icons.badge_outlined,
            capitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          _EditField(
            controller: _lastName,
            label: l10n.lastName,
            icon: Icons.badge_outlined,
            capitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 24),
          PrimaryButton(label: l10n.saveChanges, onTap: _busy ? null : _save),
        ],
      ),
    );
  }
}

// `ChangeUsernameScreen` was removed. The app no longer has usernames — a user
// is identified by their display name and email alone, so there is nothing here
// to change. The `usernames/{name}` collection, the `claimUsername` Cloud
// Function and the `users.username` field went with it; see `DATA_MODEL.md`.

class ChangeEmailScreen extends StatefulWidget {
  const ChangeEmailScreen({
    super.key,
    required this.initialValue,
    this.service,
  });
  final String initialValue;
  final AccountSettingsService? service;

  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  late final _email = TextEditingController(text: widget.initialValue);
  final _password = TextEditingController();
  late final _service = widget.service ?? AccountSettingsService();
  bool _busy = false;

  Future<void> _continue() async {
    final l10n = AppLocalizations.of(context);
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim())) {
      _snack(l10n.enterValidEmail);
      return;
    }
    if (_password.text.isEmpty) {
      _snack(l10n.reauthenticationFailed);
      return;
    }
    setState(() => _busy = true);
    try {
      await _service.confirmEmailIdentity(
        currentEmail: _email.text,
        currentPassword: _password.text,
      );
      if (!mounted) return;
      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => NewEmailVerificationScreen(service: _service),
        ),
      );
      if (changed == true && mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) _snack(l10n.reauthenticationFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _EditShell(
      title: l10n.changeEmail,
      subtitle: l10n.confirmEmailIdentitySubtitle,
      child: Column(
        children: [
          _EditField(
            controller: _email,
            label: l10n.currentEmail,
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          _EditField(
            controller: _password,
            label: l10n.currentPassword,
            icon: Icons.lock_outline_rounded,
            obscure: true,
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: l10n.continueLabel,
            onTap: _busy ? null : _continue,
          ),
        ],
      ),
    );
  }
}

/// Step two of changing an email: prove ownership of the proposed address
/// with the six-digit code sent by the backend.
class NewEmailVerificationScreen extends StatefulWidget {
  const NewEmailVerificationScreen({super.key, this.service});

  final AccountSettingsService? service;

  @override
  State<NewEmailVerificationScreen> createState() =>
      _NewEmailVerificationScreenState();
}

class _NewEmailVerificationScreenState
    extends State<NewEmailVerificationScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  late final _service = widget.service ?? AccountSettingsService();
  bool _codeSent = false;
  bool _busy = false;

  bool get _hasValidEmail =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());

  Future<void> _sendCode() async {
    final l10n = AppLocalizations.of(context);
    if (!_hasValidEmail) {
      _snack(l10n.enterValidEmail);
      return;
    }
    setState(() => _busy = true);
    try {
      await _service.sendEmailChangeCode(_email.text);
      if (!mounted) return;
      setState(() => _codeSent = true);
      _snack(l10n.verificationCodeSent);
    } catch (_) {
      if (mounted) _snack(l10n.settingsUpdateFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final l10n = AppLocalizations.of(context);
    if (!_hasValidEmail) {
      _snack(l10n.enterValidEmail);
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(_code.text.trim())) {
      _snack(l10n.invalidVerificationCode);
      return;
    }
    setState(() => _busy = true);
    try {
      await _service.confirmEmailChangeCode(
        newEmail: _email.text,
        code: _code.text.trim(),
      );
      if (!mounted) return;
      _snack(l10n.emailUpdated);
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) _snack(l10n.invalidVerificationCode);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _EditShell(
      title: l10n.changeEmail,
      subtitle: l10n.newEmailVerificationSubtitle,
      child: Column(
        children: [
          _EditField(
            controller: _email,
            label: l10n.newEmail,
            icon: Icons.mark_email_unread_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          _EditField(
            controller: _code,
            label: l10n.verificationCode,
            icon: Icons.password_rounded,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: _codeSent ? l10n.verifyAndSave : l10n.sendCode,
            onTap: _busy ? null : (_codeSent ? _verify : _sendCode),
          ),
        ],
      ),
    );
  }
}

class ChangePhoneScreen extends StatefulWidget {
  const ChangePhoneScreen({
    super.key,
    required this.initialValue,
    this.service,
  });
  final String initialValue;
  final AccountSettingsService? service;

  @override
  State<ChangePhoneScreen> createState() => _ChangePhoneScreenState();
}

class _ChangePhoneScreenState extends State<ChangePhoneScreen> {
  late final _phone = TextEditingController(text: widget.initialValue);
  final _code = TextEditingController();
  late final _service = widget.service ?? AccountSettingsService();
  String? _verificationId;
  bool _busy = false;

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    if (!_phone.text.trim().startsWith('+')) {
      _snack(l10n.phoneInternationalFormat);
      return;
    }
    setState(() => _busy = true);
    try {
      await _service.startPhoneVerification(
        phone: _phone.text,
        codeSent: (id) {
          if (!mounted) return;
          setState(() {
            _verificationId = id;
            _busy = false;
          });
          _snack(l10n.verificationCodeSent);
        },
        completed: () {
          if (mounted) Navigator.of(context).pop(true);
        },
        failed: (_) {
          if (mounted) {
            setState(() => _busy = false);
            _snack(l10n.settingsUpdateFailed);
          }
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        _snack(l10n.settingsUpdateFailed);
      }
    }
  }

  Future<void> _verify() async {
    setState(() => _busy = true);
    try {
      await _service.confirmPhoneCode(
        verificationId: _verificationId!,
        code: _code.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) _snack(AppLocalizations.of(context).invalidVerificationCode);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _EditShell(
      title: l10n.changePhoneNumber,
      subtitle: l10n.changePhoneSubtitle,
      child: Column(
        children: [
          _EditField(
            controller: _phone,
            label: l10n.newPhoneNumber,
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          if (_verificationId != null) ...[
            const SizedBox(height: 16),
            _EditField(
              controller: _code,
              label: l10n.verificationCode,
              icon: Icons.sms_outlined,
              keyboardType: TextInputType.number,
            ),
          ],
          const SizedBox(height: 24),
          PrimaryButton(
            label: _verificationId == null ? l10n.sendCode : l10n.verifyAndSave,
            onTap: _busy ? null : (_verificationId == null ? _send : _verify),
          ),
        ],
      ),
    );
  }
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, this.service});
  final AccountSettingsService? service;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  late final _service = widget.service ?? AccountSettingsService();
  bool _busy = false;

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (_next.text.length < 8 ||
        !RegExp(r'[A-Z]').hasMatch(_next.text) ||
        !RegExp(r'[a-z]').hasMatch(_next.text) ||
        !RegExp(r'[^A-Za-z0-9]').hasMatch(_next.text)) {
      _snack(l10n.passwordChangeRules);
      return;
    }
    if (_next.text != _confirm.text) {
      _snack(l10n.passwordsDontMatch);
      return;
    }
    setState(() => _busy = true);
    try {
      await _service.changePassword(
        currentPassword: _current.text,
        newPassword: _next.text,
      );
      if (!mounted) return;
      _snack(l10n.passwordUpdated);
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) _snack(l10n.reauthenticationFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _EditShell(
      title: l10n.settingsChangePassword,
      subtitle: l10n.passwordChangeRules,
      child: Column(
        children: [
          _EditField(
            controller: _current,
            label: l10n.currentPassword,
            icon: Icons.lock_outline,
            obscure: true,
          ),
          const SizedBox(height: 16),
          _EditField(
            controller: _next,
            label: l10n.newPassword,
            icon: Icons.password_rounded,
            obscure: true,
          ),
          const SizedBox(height: 16),
          _EditField(
            controller: _confirm,
            label: l10n.confirmPassword,
            icon: Icons.password_rounded,
            obscure: true,
          ),
          const SizedBox(height: 24),
          PrimaryButton(label: l10n.saveChanges, onTap: _busy ? null : _save),
        ],
      ),
    );
  }
}

// `_SimpleAccountEditor` went with `ChangeUsernameScreen`, its only caller.
// The remaining editors each build on `_EditShell` directly because they need
// more than one field or a multi-step flow.

class _EditShell extends StatelessWidget {
  const _EditShell({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: PageBackground(
      imageAsset: PolicyScreen.backgroundAsset,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: GlassBackButton(
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: AppColors.heading(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.secondaryText(context),
              ),
            ),
            const SizedBox(height: 28),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: GlassPanel(
                  borderRadius: 28,
                  padding: const EdgeInsets.all(24),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _EditField extends StatelessWidget {
  const _EditField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscure = false,
    this.capitalization = TextCapitalization.none,
  });
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final TextCapitalization capitalization;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    obscureText: obscure,
    textCapitalization: capitalization,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.55),
          width: 1.2,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.accent(context), width: 1.8),
      ),
    ),
  );
}
