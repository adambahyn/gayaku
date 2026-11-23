import 'package:flutter/material.dart';

void showSuccessSnackBar(BuildContext context, String message) {
  const backgroundColor = Color(0xFFEAF7EE);
  const foregroundColor = Color(0xFF1E5631);
  const borderColor = Color(0xFFB7E4C7);

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderColor, width: 1),
        ),
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: foregroundColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: foregroundColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}
