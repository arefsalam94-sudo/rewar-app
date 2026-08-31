import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'recessed_liquid_glass_field.dart';

/// Backward-compatible name for the app's single recessed input component.
class AppRecessedGlassField extends StatelessWidget {
  const AppRecessedGlassField({
    super.key,
    required this.controller,
    required this.hint,
    this.prefixIcon,
    this.obscureText = false,
    this.suffix,
    this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
    this.keyboardType,
    this.inputFormatters,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.autofocus = false,
    this.focusNode,
    this.prefix,
    this.dark,
    this.compact = false,
  });

  final TextEditingController controller;
  final String hint;
  final IconData? prefixIcon;
  final bool obscureText;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final FocusNode? focusNode;
  final Widget? prefix;
  final bool? dark;

  /// Half-width layouts (the Explore Tours search row) shrink the type size
  /// only — see [RecessedLiquidGlassField.compact].
  final bool compact;

  static const double radius = RecessedLiquidGlassField.radius;

  @override
  Widget build(BuildContext context) => RecessedLiquidGlassField(
    controller: controller,
    hint: hint,
    prefixIcon: prefixIcon,
    obscureText: obscureText,
    suffix: suffix,
    validator: validator,
    textInputAction: textInputAction,
    onFieldSubmitted: onFieldSubmitted,
    keyboardType: keyboardType,
    inputFormatters: inputFormatters,
    readOnly: readOnly,
    onTap: onTap,
    onChanged: onChanged,
    autofocus: autofocus,
    focusNode: focusNode,
    prefix: prefix,
    dark: dark,
    compact: compact,
  );
}
