import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_recessed_glass_field.dart';
import 'liquid_glass_surface.dart';

/// The one Login/Register field shell: a real, independent canonical
/// Liquid Glass surface per field (`GlassLayer.surface`), the v2 field color
/// tokens, and no drop shadow (fields on these two screens stack closer
/// together than the shared shadow's own blur radius — see
/// [RecessedLiquidGlassField.dropShadow]).
///
/// Login and Register both call this instead of [AppRecessedGlassField]
/// directly with the same arguments repeated at every call site, so there is
/// exactly one place that can define — or accidentally drift — that
/// geometry/material combination.
class AuthGlassField extends StatelessWidget {
  const AuthGlassField({
    super.key,
    required this.controller,
    required this.hint,
    required this.dark,
    this.prefixIcon,
    this.prefix,
    this.suffix,
    this.obscureText = false,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.validator,
    this.autofocus = false,
    this.focusNode,
  });

  final TextEditingController controller;
  final String hint;
  final bool dark;
  final IconData? prefixIcon;
  final Widget? prefix;
  final Widget? suffix;
  final bool obscureText;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return AppRecessedGlassField(
      controller: controller,
      hint: hint,
      dark: dark,
      prefixIcon: prefixIcon,
      prefix: prefix,
      suffix: suffix,
      obscureText: obscureText,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      validator: validator,
      autofocus: autofocus,
      focusNode: focusNode,
      useV2FieldColors: true,
      useCanonicalGlass: true,
      layer: GlassLayer.surface,
      dropShadow: false,
    );
  }
}
