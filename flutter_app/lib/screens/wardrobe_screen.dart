import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/wardrobe.dart';
import '../theme/app_theme.dart';
import '../widgets/home_bottom_nav.dart';
import '../widgets/placeholder_image.dart';
import '../widgets/wardrobe_item_card.dart';
import 'add_item_stub.dart';

/// Wardrobe catalog: header, search, category chips and a two-column grid.
///
/// UI only — the chips and search box hold local state, nothing is persisted.
class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key, this.items = wardrobeItems});

  final List<WardrobeItem> items;

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  String _category = wardrobeCategories.first;

  void _onNavTap(int index) {
    switch (index) {
      case 0:
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      case 1:
        break;
      case 2:
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AddItemStub()),
        );
      default:
        showComingSoon(context, index == 3 ? 'Planner' : 'Profile');
    }
  }

  List<WardrobeItem> get _visible => _category == wardrobeCategories.first
      ? widget.items
      : widget.items.where((i) => i.category == _category).toList();

  @override
  Widget build(BuildContext context) {
    final items = _visible;
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(itemCount: widget.items.length),
                    const SizedBox(height: 20),
                    const _SearchRow(),
                    const SizedBox(height: 16),
                    _CategoryChips(
                      selected: _category,
                      onSelected: (c) => setState(() => _category = c),
                    ),
                    const SizedBox(height: 16),
                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                            'Nothing in this category yet.',
                            style: TextStyle(color: AppColors.taupe),
                          ),
                        ),
                      )
                    else
                      GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.75,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          for (final item in items)
                            WardrobeItemCard(item: item),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: HomeBottomNav(currentIndex: 1, onTap: _onNavTap),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.itemCount});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Wardrobe',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.espresso,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Total $itemCount items',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.taupe,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Add item',
          onPressed: () => showComingSoon(context, 'Add item'),
          icon: const Icon(Icons.add),
          color: AppColors.espresso,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            minimumSize: const Size(48, 48),
          ),
        ),
      ],
    );
  }
}

class _SearchRow extends StatelessWidget {
  const _SearchRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.all(Radius.circular(26)),
              border: Border.all(color: AppColors.beige),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, size: 20, color: AppColors.taupe),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    textInputAction: TextInputAction.search,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.espresso,
                    ),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: 'Search your clothes...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.taupe,
                      ),
                    ),
                    onSubmitted: (value) => showComingSoon(
                      context,
                      value.trim().isEmpty ? 'Search' : 'Search "$value"',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          tooltip: 'Filter',
          onPressed: () => showComingSoon(context, 'Filter'),
          icon: const Icon(Icons.tune, size: 22),
          color: AppColors.espresso,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            minimumSize: const Size(52, 52),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: wardrobeCategories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final label = wardrobeCategories[index];
          final active = label == selected;
          return GestureDetector(
            onTap: () => onSelected(label),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: active ? AppColors.tan : Colors.white,
                borderRadius: const BorderRadius.all(Radius.circular(22)),
                border: active ? null : Border.all(color: AppColors.beige),
              ),
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? Colors.white : AppColors.taupe,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
