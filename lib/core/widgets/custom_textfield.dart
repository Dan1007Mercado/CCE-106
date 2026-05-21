import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  const CustomTextField({
    required this.controller,
    required this.label,
    super.key,
    this.hintText,
    this.validator,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.prefixIcon,
    this.suffixIcon,
    this.autofillHints,
    this.onFieldSubmitted,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.expands = false,
    this.alignPrefixIconToTop = false,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final String? Function(String?)? validator;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final Iterable<String>? autofillHints;
  final void Function(String)? onFieldSubmitted;
  final bool enabled;
  final bool readOnly;
  final int? maxLines;
  final int? minLines;
  final bool expands;
  final bool alignPrefixIconToTop;

  @override
  Widget build(BuildContext context) {
    final effectiveMinLines = obscureText || expands ? null : minLines;
    final effectiveMaxLines = obscureText
        ? 1
        : expands
        ? null
        : maxLines;
    final isMultiline =
        expands || (effectiveMaxLines != null && effectiveMaxLines > 1);
    final effectiveKeyboardType = isMultiline
        ? TextInputType.multiline
        : keyboardType;
    final effectiveTextInputAction = isMultiline
        ? TextInputAction.newline
        : textInputAction;
    final shouldTopAlignPrefix = isMultiline && alignPrefixIconToTop;

    return TextFormField(
      controller: controller,
      validator: validator,
      obscureText: obscureText,
      keyboardType: effectiveKeyboardType,
      textInputAction: effectiveTextInputAction,
      autofillHints: autofillHints,
      onFieldSubmitted: onFieldSubmitted,
      enabled: enabled,
      readOnly: readOnly,
      expands: expands,
      minLines: effectiveMinLines,
      maxLines: effectiveMaxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: prefixIcon == null
            ? null
            : shouldTopAlignPrefix
            ? Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Align(
                  alignment: Alignment.topCenter,
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Icon(prefixIcon),
                ),
              )
            : Icon(prefixIcon),
        prefixIconConstraints: shouldTopAlignPrefix
            ? const BoxConstraints(minWidth: 48, minHeight: 48)
            : null,
        suffixIcon: suffixIcon,
      ),
    );
  }
}
