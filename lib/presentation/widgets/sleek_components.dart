import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const PremiumCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.05) ?? Colors.white.withOpacity(0.05),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class NeonButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isFullWidth;

  const NeonButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isFullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16),
      ),
    );

    if (isFullWidth) {
      return SizedBox(
        width: double.infinity,
        child: button,
      );
    }
    return button;
  }
}

class SleekTextField extends StatelessWidget {
  final String label;
  final String? hintText;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  final Widget? prefix;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final bool readOnly;

  const SleekTextField({
    super.key,
    required this.label,
    this.hintText,
    this.controller,
    this.keyboardType,
    this.prefixIcon,
    this.prefix,
    this.inputFormatters,
    this.onChanged,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          readOnly: readOnly,
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          style: GoogleFonts.manrope(color: Theme.of(context).textTheme.bodyLarge?.color),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.3)),
            filled: true,
            fillColor: Theme.of(context).cardTheme.color,
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: Theme.of(context).colorScheme.primary, size: 20) : null,
            prefix: prefix,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class SleekButton extends StatelessWidget {
  final VoidCallback? onTap;
  final String label;
  final bool isSecondary;
  final bool isFullWidth;

  const SleekButton({
    super.key,
    required this.onTap,
    required this.label,
    this.isSecondary = false,
    this.isFullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: onTap == null
          ? Colors.grey.withOpacity(0.1)
          : (isSecondary 
              ? (Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white.withOpacity(0.05) 
                  : Colors.black.withOpacity(0.05)) 
              : Theme.of(context).colorScheme.primary),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: isSecondary 
                    ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black) 
                    : Colors.black,
              ),
            ),
          ),
        ),
      ),
    );

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}
