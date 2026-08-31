import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations.dart';
import '../services/app_permissions.dart';
import '../services/profile_setup_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/glass_panel.dart';
import '../widgets/gradient_field.dart';
import '../widgets/page_background.dart';
import '../widgets/preview_mode_banner.dart';
import '../widgets/primary_button.dart';
import 'register_complete_screen.dart';

/// Phase 1 — Account Setup (all 3 languages, light + dark).
///
/// Final step of registration, reached once the phone number has been
/// verified: an optional profile picture and the display name, which is
/// pre-filled with the name given on Register.
///
/// The name written here updates `users.name` — it is a display name, not a
/// unique handle, so no uniqueness check is involved.
class AccountSetupScreen extends StatefulWidget {
  const AccountSetupScreen({
    super.key,
    this.initialName = '',
    this.service,
    this.picker,
    this.requestPermissionsOnOpen = true,
  });

  /// The full name captured on Register, shown pre-filled and editable.
  final String initialName;

  final ProfileSetupService? service;
  final ImagePicker? picker;

  /// Off in tests, where there is no OS to answer the prompts.
  final bool requestPermissionsOnOpen;

  @override
  State<AccountSetupScreen> createState() => _AccountSetupScreenState();
}

class _AccountSetupScreenState extends State<AccountSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController = TextEditingController(
    text: widget.initialName,
  );
  late final ProfileSetupService _service =
      widget.service ?? ProfileSetupService();
  late final ImagePicker _picker = widget.picker ?? ImagePicker();

  File? _imageFile;
  bool _submitting = false;
  String? _errorText;

  bool get _darkMode => appDarkMode.value;

  @override
  void initState() {
    super.initState();
    if (widget.requestPermissionsOnOpen) {
      // Requested up front by explicit decision — see AppPermissions.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppPermissions.requestAll();
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // --- Image picking -------------------------------------------------------

  Future<void> _showImageSourceSheet() async {
    FocusScope.of(context).unfocus();
    final source = await showModalBottomSheet<_ImageAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _ImageSourceSheet(dark: _darkMode, canRemove: _imageFile != null),
    );
    if (source == null || !mounted) return;

    switch (source) {
      case _ImageAction.camera:
        await _pickImage(fromCamera: true);
      case _ImageAction.gallery:
        await _pickImage(fromCamera: false);
      case _ImageAction.remove:
        setState(() {
          _imageFile = null;
          _errorText = null;
        });
    }
  }

  Future<void> _pickImage({required bool fromCamera}) async {
    final l10n = AppLocalizations.of(context);

    // Even with the up-front request, re-check here: the user may have
    // declined then, or revoked it in Settings since.
    final granted = await AppPermissions.requestForImageSource(
      fromCamera: fromCamera,
    );
    if (!mounted) return;
    if (!granted) {
      setState(() {
        _errorText = fromCamera
            ? l10n.cameraPermissionDenied
            : l10n.galleryPermissionDenied;
      });
      return;
    }

    try {
      final picked = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        // Downscale on device: a modern phone photo is 4-12 MB, far more
        // than an avatar needs, and uploading it whole is slow and costly.
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      setState(() {
        _imageFile = File(picked.path);
        _errorText = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = l10n.imagePickFailed);
    }
  }

  // --- Submit --------------------------------------------------------------

  Future<void> _onCreateAccount() async {
    final l10n = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      final displayName = _nameController.text.trim();
      final imageUrl = await _service.completeSetup(
        displayName: displayName,
        imageFile: _imageFile,
      );
      if (!mounted) return;
      setState(() => _submitting = false);

      // Replace this route: registration is finished, so Back must not
      // return to a setup step that has already been saved.
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RegisterCompleteScreen(
            displayName: displayName,
            imageFile: _imageFile,
            imageUrl: imageUrl,
          ),
        ),
      );
    } on ImageTooLargeException {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorText = l10n.imageTooLarge;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorText = l10n.profileSaveFailed;
      });
    }
  }

  String? _validateName(String? value, AppLocalizations l10n) {
    final name = (value ?? '').trim();
    if (name.isEmpty) return l10n.usernameRequired;
    if (name.length < 2) return l10n.usernameTooShort;
    return null;
  }

  // --- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: appDarkMode,
      builder: (context, _, _) => _buildScreen(context),
    );
  }

  Widget _buildScreen(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = _darkMode
        ? AppTheme.darkForLocale(Localizations.localeOf(context))
        : AppTheme.lightForLocale(Localizations.localeOf(context));
    final colorScheme = theme.colorScheme;

    return Theme(
      data: theme,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: PageBackground(
          dark: _darkMode,
          imageAsset: 'assets/images/account Image.webp',
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                // Same insets as Login so the back button doesn't move.
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 32,
                  ),
                  child: IntrinsicHeight(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 82,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: GlassBackButton(
                                dark: _darkMode,
                                onTap: () => Navigator.of(context).maybePop(),
                              ),
                            ),
                          ),
                          Text(
                            l10n.accountSetup,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 38,
                              height: 1.05,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            l10n.accountSetupSubtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              height: 1.35,
                              color: AppColors.secondaryText(context),
                            ),
                          ),
                          const PreviewModeBanner(
                            message:
                                'Preview mode: the profile will not '
                                'really be saved.',
                          ),
                          const SizedBox(height: 40),
                          Center(
                            child: _AvatarPicker(
                              imageFile: _imageFile,
                              dark: _darkMode,
                              onTap: _showImageSourceSheet,
                            ),
                          ),
                          const SizedBox(height: 44),
                          GradientField(
                            controller: _nameController,
                            hint: l10n.username,
                            prefixIcon: Icons.person_outline,
                            dark: _darkMode,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _onCreateAccount(),
                            validator: (value) => _validateName(value, l10n),
                          ),
                          if (_errorText != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              _errorText!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colorScheme.error,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const Spacer(),
                          const SizedBox(height: 32),
                          PrimaryButton(
                            label: l10n.createAccount,
                            dark: _darkMode,
                            onTap: _submitting ? null : _onCreateAccount,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The circular avatar with its upload badge.
class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({
    required this.imageFile,
    required this.dark,
    required this.onTap,
  });

  final File? imageFile;
  final bool dark;
  final VoidCallback onTap;

  static const double _size = 190;
  static const double _badge = 56;

  @override
  Widget build(BuildContext context) {
    final accent = dark ? AppColors.luminousMint : AppColors.actionNavy;
    // The badge is filled with Luminous Mint in dark mode, so its icon takes
    // the `on-primary` token (DESIGN dark.md → Text & Legibility).
    final onAccent = dark ? AppColors.darkOnPrimary : Colors.white;

    return SizedBox(
      width: _size + 12,
      height: _size + 12,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: GestureDetector(
              onTap: onTap,
              child: GlassPanel(
                borderRadius: _size,
                dark: dark,
                child: SizedBox(
                  width: _size,
                  height: _size,
                  child: imageFile == null
                      ? Icon(Icons.person_outline, size: 84, color: accent)
                      : ClipOval(
                          child: Image.file(
                            imageFile!,
                            fit: BoxFit.cover,
                            width: _size,
                            height: _size,
                          ),
                        ),
                ),
              ),
            ),
          ),
          // Upload badge, overlapping the circle's lower-right edge.
          PositionedDirectional(
            bottom: 6,
            end: 0,
            child: Semantics(
              button: true,
              label: AppLocalizations.of(context).takePhoto,
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
                      Icons.file_upload_outlined,
                      color: onAccent,
                      size: 26,
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

enum _ImageAction { camera, gallery, remove }

/// Glass bottom sheet offering camera, gallery, and remove.
class _ImageSourceSheet extends StatelessWidget {
  const _ImageSourceSheet({required this.dark, required this.canRemove});

  final bool dark;
  final bool canRemove;

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
              if (canRemove)
                ListTile(
                  leading: Icon(Icons.delete_outline, color: colorScheme.error),
                  title: Text(
                    l10n.removePhoto,
                    style: TextStyle(color: colorScheme.error),
                  ),
                  onTap: () => Navigator.of(context).pop(_ImageAction.remove),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
