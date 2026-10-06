import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Editable pill search bar. Submitting shows a snackbar with the query.
class OccasionSearchBar extends StatefulWidget {
  const OccasionSearchBar({super.key});

  @override
  State<OccasionSearchBar> createState() => _OccasionSearchBarState();
}

class _OccasionSearchBarState extends State<OccasionSearchBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.beige,
        borderRadius: BorderRadius.all(Radius.circular(32)),
      ),
      child: TextField(
        controller: _controller,
        textInputAction: TextInputAction.search,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.espresso,
        ),
        decoration: InputDecoration(
          hintText: 'Search by occasion, style, or item…',
          hintStyle: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.taupe,
          ),
          prefixIcon: const Icon(Icons.search, color: AppColors.taupe),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
        onSubmitted: (value) {
          final query = value.trim();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                query.isEmpty
                    ? 'Search coming soon'
                    : 'Searching for "$query"',
              ),
            ),
          );
        },
      ),
    );
  }
}
