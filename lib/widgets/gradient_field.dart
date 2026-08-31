import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'recessed_liquid_glass_field.dart';

/// Compatibility name retained for existing forms.
///
/// All inputs now render through the single recessed liquid-glass family.
class GradientField extends StatelessWidget {
  const GradientField({
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
    this.prefix,
    this.dark,
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
  final Widget? prefix;
  final bool? dark;

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
    prefix: prefix,
    dark: dark,
  );
}
