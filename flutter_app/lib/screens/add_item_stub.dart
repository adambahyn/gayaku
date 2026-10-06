import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Placeholder destination for the scan action. No camera UI yet.
class AddItemStub extends StatelessWidget {
  const AddItemStub({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Text(
          'Add New Item',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: AppColors.espresso,
          ),
        ),
      ),
      body: Center(
        child: Text(
          'Add-item flow coming soon.',
          style: GoogleFonts.inter(color: AppColors.taupe),
        ),
      ),
    );
  }
}
