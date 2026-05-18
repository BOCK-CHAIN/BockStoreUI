import 'package:flutter/material.dart';
import 'bock_colors.dart';

InputDecoration bockInput({
  required String hint,
  required IconData icon,
  Widget? suffix,
  bool isDark = true,
}) {
  final fill = isDark ? BockColors.surfaceDark : const Color(0xFFF4F2FA);
  final border = isDark ? BockColors.borderDark : BockColors.borderLight;
  final hintColor = isDark
      ? BockColors.textSecondaryDark.withValues(alpha: 0.5)
      : BockColors.textSecondaryLight.withValues(alpha: 0.5);

  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: hintColor, fontSize: 14),
    prefixIcon: Icon(icon, color: BockColors.purple, size: 20),
    suffixIcon: suffix,
    filled: true,
    fillColor: fill,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: BockColors.purple, width: 1.8),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: BockColors.error, width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: BockColors.error, width: 1.8),
    ),
  );
}

BoxDecoration bockCard({bool isDark = true, bool elevated = false}) =>
    BoxDecoration(
      color: isDark ? BockColors.cardDark : BockColors.cardLight,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: isDark ? BockColors.borderDark : BockColors.borderLight,
      ),
      boxShadow: elevated
          ? [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.35)
                    : BockColors.purple.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ]
          : [],
    );

Widget bockLabel(String text, {bool isDark = true}) => Text(
  text,
  style: TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: isDark
        ? BockColors.textSecondaryDark
        : BockColors.textSecondaryLight,
    letterSpacing: 0.4,
  ),
);

Widget bockSectionHeader(String title, {bool isDark = true}) => Text(
  title,
  style: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: isDark ? BockColors.textPrimaryDark : BockColors.textPrimaryLight,
    letterSpacing: -0.2,
  ),
);

Widget bockChip(IconData icon, String label, {bool isDark = true}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
  decoration: BoxDecoration(
    color: isDark
        ? BockColors.purpleDim.withValues(alpha: 0.4)
        : BockColors.purple.withValues(alpha: 0.08),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: BockColors.purple.withValues(alpha: 0.25)),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: BockColors.purpleLight),
      const SizedBox(width: 5),
      Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isDark
              ? BockColors.textPrimaryDark.withValues(alpha: 0.85)
              : BockColors.textPrimaryLight,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  ),
);

ButtonStyle bockPrimaryButton({double radius = 14}) => ElevatedButton.styleFrom(
  backgroundColor: BockColors.purple,
  foregroundColor: Colors.white,
  disabledBackgroundColor: BockColors.purple.withValues(alpha: 0.4),
  elevation: 0,
  shadowColor: Colors.transparent,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
);
