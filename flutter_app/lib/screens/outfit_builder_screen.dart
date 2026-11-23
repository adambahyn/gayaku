import 'package:flutter/material.dart';

import '../logic/outfit_matcher.dart';
import '../logic/rule_based_recommender.dart';
import '../models/wardrobe.dart';
import '../state/outfit_store.dart';
import '../state/wardrobe_store.dart';
import '../theme/app_theme.dart';
import '../widgets/placeholder_image.dart';
import '../widgets/note.dart';

/// Build or edit one combination by hand, slot per slot.
///
/// A live [outfitScore] meter plus a threshold slider for manual and
/// recommendation-based outfit assembly.
class OutfitBuilderScreen extends StatefulWidget {
  const OutfitBuilderScreen({super.key, this.existing, this.catalog});

  /// Pass a saved outfit to edit it in place; null creates a new one.
  final SavedOutfit? existing;

  /// Overrides the store with a fixed catalog, for tests. Null — the app's
  /// case — follows [wardrobeItems].
  final List<WardrobeItem>? catalog;

  @override
  State<OutfitBuilderScreen> createState() => _OutfitBuilderScreenState();
}

class _OutfitBuilderScreenState extends State<OutfitBuilderScreen> {
  late final TextEditingController _name;
  late List<WardrobeItem> _picked;
  WardrobeItem? _anchorTop;
  WardrobeItem? _anchorBottom;
  bool _hasGenerated = false;
  late double _threshold;
  String _occasion = 'Kasual';

  /// The garments offered per slot: the injected override, else the live store.
  List<WardrobeItem> get _catalog => widget.catalog ?? wardrobeItems.value;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _picked = existing?.itemsOf(_catalog) ?? [];
    _anchorTop = _picked.where((item) => item.category == 'Tops').firstOrNull;
    _anchorBottom = _picked
        .where((item) => item.category == 'Bottoms')
        .firstOrNull;
    _hasGenerated = existing != null;
    _threshold = existing?.threshold ?? 0.6;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  List<String> get _slots => wardrobeSlots;

  double get _score => outfitScore(_picked, occasion: _occasion);

  /// One item per slot; outerwear and accessories are optional layers.
  bool _isOptional(String slot) => slot == 'Outerwear' || slot == 'Accessories';

  WardrobeItem? _at(String slot) =>
      _picked.where((i) => i.category == slot).firstOrNull;

  WardrobeItem? _anchorAt(String slot) => switch (slot) {
    'Tops' => _anchorTop,
    'Bottoms' => _anchorBottom,
    _ => null,
  };

  bool _isAnchor(String slot) => _anchorAt(slot) != null;

  List<WardrobeItem> _compatibleCandidates(String slot) {
    if (_isAnchor(slot)) return const [];
    final activeItems = _picked.where((item) => item.category != slot).toList();
    if (activeItems.isEmpty) return const [];
    final anchorIds = {
      if (_anchorTop != null) _anchorTop!.id,
      if (_anchorBottom != null) _anchorBottom!.id,
    };
    final candidates = _catalog
        .where(
          (item) =>
              item.category == slot &&
              !anchorIds.contains(item.id) &&
              activeItems.every(
                (active) =>
                    pairScore(active, item, occasion: _occasion) >= _threshold,
              ),
        )
        .toList();
    candidates.sort((a, b) {
      double fit(WardrobeItem candidate) => activeItems.fold(
        0.0,
        (score, active) =>
            score + pairScore(active, candidate, occasion: _occasion),
      );
      return fit(b).compareTo(fit(a));
    });
    return candidates;
  }

  bool _hasCompatibleCandidate(String slot) =>
      _compatibleCandidates(slot).isNotEmpty;

  void _setAnchor(String slot, WardrobeItem item) {
    setState(() {
      if (slot == 'Tops') {
        _anchorTop = item;
      } else if (slot == 'Bottoms') {
        _anchorBottom = item;
      }
      _hasGenerated = false;
      _picked = [?_anchorTop, ?_anchorBottom];
    });
  }

  void _remove(String slot) {
    if (_isAnchor(slot)) return;
    setState(() {
      _picked = _picked.where((i) => i.category != slot).toList();
    });
  }

  void _refreshSlot(String slot) {
    if (_isAnchor(slot)) return;
    final candidates = _compatibleCandidates(slot);
    if (candidates.isEmpty) {
      setState(() {
        _picked = _picked.where((item) => item.category != slot).toList();
      });
      showNote(context, 'Belum ada kandidat $slot yang cocok');
      return;
    }

    final current = _at(slot);
    final currentIndex = current == null
        ? -1
        : candidates.indexWhere((item) => item.id == current.id);
    final nextIndex = currentIndex < 0
        ? 0
        : (currentIndex + 1) % candidates.length;
    final replacement = candidates[nextIndex];
    if (current != null && replacement.id == current.id) {
      showNote(context, 'Sudah tidak ada kandidat lain untuk $slot');
      return;
    }
    setState(() {
      _picked = [
        ..._picked.where((item) => item.category != slot),
        replacement,
      ];
    });
  }

  Future<void> _pick(String slot) async {
    final options = _catalog.where((i) => i.category == slot).toList();
    if (options.isEmpty) {
      showNote(context, 'Belum ada item $slot');
      return;
    }
    final chosen = await showModalBottomSheet<WardrobeItem>(
      context: context,
      backgroundColor: AppColors.of(context).sheet,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
      builder: (context) => _PickerSheet(slot: slot, options: options),
    );
    if (chosen != null) _setAnchor(slot, chosen);
  }

  Future<void> _pickAnchor(String slot) async {
    await _pick(slot);
  }

  void _clearAnchor(String slot) {
    setState(() {
      if (slot == 'Tops') {
        _anchorTop = null;
      } else if (slot == 'Bottoms') {
        _anchorBottom = null;
      }
      _hasGenerated = false;
      _picked = [?_anchorTop, ?_anchorBottom];
    });
  }

  void _recommend() {
    setState(() {
      _hasGenerated = true;
    });
    final anchors = [
      _anchorTop,
      _anchorBottom,
    ].whereType<WardrobeItem>().toList();
    if (anchors.isEmpty) {
      showNote(context, 'Pilih atasan, bawahan, atau keduanya terlebih dahulu');
      return;
    }
    final recommendations = const RuleBasedRecommender()
        .recommendWithBestHarmony(
          anchors: anchors,
          wardrobe: _catalog,
          occasion: _occasion,
          threshold: _threshold,
        );
    if (recommendations.isEmpty) {
      setState(() {
        _picked = anchors;
      });
      showNote(
        context,
        'Belum ada pakaian yang cocok untuk melengkapi pilihan ini',
      );
      return;
    }
    final first = recommendations.first.items;
    final filtered = <WardrobeItem>[
      for (final item in first)
        if (_isAnchor(item.category) ||
            first
                .where((other) => other.category != item.category)
                .every(
                  (other) =>
                      pairScore(other, item, occasion: _occasion) >= _threshold,
                ))
          item,
    ];
    setState(() {
      _picked = filtered;
    });
  }

  Future<void> _save() async {
    if (_at('Tops') == null || _at('Bottoms') == null) {
      showNote(
        context,
        'Pastikan atasan (Tops) dan bawahan (Bottoms) terisi sebelum menyimpan',
      );
      return;
    }
    if (_score < _threshold) {
      showNote(context, 'Skor kombinasi belum memenuhi batas minimum');
      return;
    }

    final enteredName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nama Kombinasi'),
        content: TextField(
          controller: _name,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nama kombinasi, mis. Kuliah Senin',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(_name.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (enteredName == null) return;
    final name = enteredName.trim();

    try {
      await saveOutfit(
        SavedOutfit(
          id: widget.existing?.id ?? newOutfitId(),
          name: name.isEmpty ? 'Kombinasi Baru' : name,
          itemIds: _picked.map((i) => i.id).toList(),
          threshold: _threshold,
          favorite: widget.existing?.favorite ?? false,
          createdAt: widget.existing?.createdAt,
        ),
      );
    } on OutfitException catch (e) {
      if (mounted) showNote(context, e.message);
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final hasRequiredCategories = _at('Tops') != null && _at('Bottoms') != null;
    final canSave = hasRequiredCategories && _score >= _threshold;

    return Scaffold(
      backgroundColor: palette.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TopBar(editing: widget.existing != null),
                    const SizedBox(height: 16),
                    _RecommendationControls(
                      top: _anchorTop,
                      bottom: _anchorBottom,
                      occasion: _occasion,
                      threshold: _threshold,
                      onPickAnchor: _pickAnchor,
                      onClearAnchor: _clearAnchor,
                      onOccasion: (value) => setState(() {
                        _occasion = value;
                      }),
                      onThreshold: (value) => setState(() {
                        _threshold = value;
                      }),
                      onRecommend: _recommend,
                    ),
                    const SizedBox(height: 16),
                    _ScoreCard(
                      score: _score,
                      threshold: _threshold,
                      subscores: outfitSubscores(_picked, occasion: _occasion),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Hasil Kombinasi',
                      style: textTheme.headlineSmall!.copyWith(
                        fontWeight: FontWeight.w700,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final slot in _slots) ...[
                      _SlotRow(
                        key: ValueKey('result-$slot'),
                        slot: slot,
                        item: _at(slot),
                        optional: _isOptional(slot),
                        locked: _isAnchor(slot),
                        hasGenerated: _hasGenerated,
                        emptyCompatible:
                            _hasGenerated &&
                            _at(slot) == null &&
                            _hasCompatibleCandidate(slot),
                        onPick: null,
                        onClear: () => _remove(slot),
                        onRefresh: () => _refreshSlot(slot),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_hasGenerated && !canSave)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        !hasRequiredCategories
                            ? 'Atasan (Tops) dan Bawahan (Bottoms) Wajib Terisi'
                            : 'Skor kombinasi belum memenuhi batas minimum',
                        style: textTheme.labelMedium!.copyWith(
                          color: palette.actionInk,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: canSave ? _save : null,
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(
                        widget.existing == null
                            ? 'Simpan Kombinasi'
                            : 'Simpan Perubahan',
                        style: textTheme.labelLarge!.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.action,
                        foregroundColor: palette.onAction,
                        disabledBackgroundColor: palette.surfaceMuted,
                        disabledForegroundColor: palette.inkMuted,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.panel,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.editing});

  final bool editing;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        IconButton(
          tooltip: 'Kembali',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, size: 22),
          color: palette.ink,
          style: IconButton.styleFrom(
            backgroundColor: palette.sheet,
            minimumSize: const Size(44, 44),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            editing ? 'Edit Kombinasi' : 'Kombinasi Baru',
            style: textTheme.titleLarge!.copyWith(
              fontWeight: FontWeight.w600,
              color: palette.ink,
            ),
          ),
        ),
      ],
    );
  }
}

/// Live match meter and category subscores for the current combination.
class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.score,
    required this.threshold,
    required this.subscores,
  });

  final double score;
  final double threshold;
  final PairSubscores subscores;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final percent = (score * 100).round();
    final meets = score >= threshold;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: AppRadius.panel,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$percent%',
                style: textTheme.headlineLarge!.copyWith(
                  fontWeight: FontWeight.w700,
                  color: palette.ink,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    meets ? 'Memenuhi target' : 'Di bawah target',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelMedium!.copyWith(
                      fontWeight: FontWeight.w400,
                      color: palette.inkMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: AppRadius.chip,
            child: LinearProgressIndicator(
              value: score,
              minHeight: 8,
              backgroundColor: palette.accentTint,
              valueColor: AlwaysStoppedAnimation(palette.actionInk),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SubscoreChip(label: 'Warna', value: subscores.color),
              _SubscoreChip(label: 'Formalitas', value: subscores.formality),
              _SubscoreChip(label: 'Acara', value: subscores.occasion),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecommendationControls extends StatelessWidget {
  const _RecommendationControls({
    required this.top,
    required this.bottom,
    required this.occasion,
    required this.threshold,
    required this.onPickAnchor,
    required this.onClearAnchor,
    required this.onOccasion,
    required this.onThreshold,
    required this.onRecommend,
  });

  final WardrobeItem? top;
  final WardrobeItem? bottom;
  final String occasion;
  final double threshold;
  final ValueChanged<String> onPickAnchor;
  final ValueChanged<String> onClearAnchor;
  final ValueChanged<String> onOccasion;
  final ValueChanged<double> onThreshold;
  final VoidCallback onRecommend;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: AppRadius.panel,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pilih pakaian utama',
            style: textTheme.labelLarge!.copyWith(
              fontWeight: FontWeight.w600,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pilih atasan, bawahan, atau keduanya.',
            style: textTheme.labelMedium!.copyWith(
              fontWeight: FontWeight.w400,
              color: palette.inkMuted,
            ),
          ),
          const SizedBox(height: 8),
          _SlotRow(
            key: const ValueKey('recommendation-top'),
            slot: 'Tops',
            item: top,
            optional: false,
            onPick: () => onPickAnchor('Tops'),
            onClear: () => onClearAnchor('Tops'),
          ),
          const SizedBox(height: 8),
          _SlotRow(
            key: const ValueKey('recommendation-bottom'),
            slot: 'Bottoms',
            item: bottom,
            optional: false,
            onPick: () => onPickAnchor('Bottoms'),
            onClear: () => onClearAnchor('Bottoms'),
          ),
          const SizedBox(height: 8),
          Text(
            'Acara',
            style: textTheme.labelLarge!.copyWith(
              fontWeight: FontWeight.w600,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 6),
          RadioGroup<String>(
            groupValue: occasion,
            onChanged: (value) {
              if (value != null) onOccasion(value);
            },
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 2,
              childAspectRatio: 2.4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final option in RuleBasedRecommender.occasions)
                  InkWell(
                    onTap: () => onOccasion(option),
                    borderRadius: AppRadius.chip,
                    child: Row(
                      children: [
                        Radio<String>(
                          value: option,
                          fillColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.selected)
                                ? palette.action
                                : palette.inkMuted,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            _occasionDisplayName(option),
                            style: textTheme.labelMedium!.copyWith(
                              color: palette.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Target Keserasian',
            style: textTheme.labelLarge!.copyWith(
              fontWeight: FontWeight.w600,
              color: palette.ink,
            ),
          ),
          Text(
            'Minimal skor kecocokan warna, formalitas, dan acara.',
            style: textTheme.labelMedium!.copyWith(
              fontWeight: FontWeight.w400,
              color: palette.inkMuted,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: threshold,
                  min: 0.50,
                  max: 0.95,
                  divisions: 9,
                  activeColor: palette.actionInk,
                  inactiveColor: palette.accentTint,
                  label: '${(threshold * 100).round()}%',
                  onChanged: onThreshold,
                ),
              ),
              Text(
                '${(threshold * 100).round()}%',
                style: textTheme.labelLarge!.copyWith(
                  fontWeight: FontWeight.w500,
                  color: palette.inkMuted,
                ),
              ),
            ],
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onRecommend,
              // icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Buat Kombinasi'),
              style: FilledButton.styleFrom(
                backgroundColor: palette.action,
                foregroundColor: palette.onAction,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.chip,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _occasionDisplayName(String value) =>
    value == 'Smart-Casual' ? 'Smart Casual' : value;

class _SubscoreChip extends StatelessWidget {
  const _SubscoreChip({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: palette.accentTint,
        borderRadius: AppRadius.chip,
      ),
      child: Text(
        '$label ${(value * 100).round()}%',
        style: textTheme.labelMedium!.copyWith(
          fontWeight: FontWeight.w600,
          color: palette.ink,
        ),
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    super.key,
    required this.slot,
    required this.item,
    required this.optional,
    this.locked = false,
    this.hasGenerated = false,
    this.emptyCompatible = false,
    this.onPick,
    required this.onClear,
    this.onRefresh,
  });

  final String slot;
  final WardrobeItem? item;
  final bool optional;
  final bool locked;
  final bool hasGenerated;
  final bool emptyCompatible;
  final VoidCallback? onPick;
  final VoidCallback onClear;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final chosen = item;
    return GestureDetector(
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.sheet,
          borderRadius: AppRadius.field,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: AppRadius.chip,
              child: SizedBox(
                width: 52,
                height: 52,
                child: chosen == null
                    ? Container(
                        color: palette.surfaceMuted,
                        child: Icon(
                          onPick == null ? Icons.checkroom_outlined : Icons.add,
                          size: 18,
                          color: palette.inkMuted,
                        ),
                      )
                    : PlaceholderImage(
                        imagePath: chosen.imagePath,
                        icon: Icons.checkroom_outlined,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slot + (optional ? '' : ''),
                    style: textTheme.labelMedium!.copyWith(
                      fontWeight: FontWeight.w400,
                      color: palette.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    chosen?.name ??
                        (onPick == null
                            ? !hasGenerated
                                  ? 'Belum dibuat'
                                  : emptyCompatible
                                  ? 'Slot dikosongkan'
                                  : 'Tidak ada item yg cocok'
                            : 'Pilih item'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium!.copyWith(
                      fontWeight: FontWeight.w500,
                      color: chosen == null ? palette.inkMuted : palette.ink,
                    ),
                  ),
                ],
              ),
            ),
            if (chosen != null && locked)
              Icon(Icons.lock_outline, size: 20, color: palette.inkMuted)
            else if (chosen == null &&
                onPick == null &&
                hasGenerated &&
                emptyCompatible)
              IconButton(
                tooltip: 'Refresh $slot',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 18),
                color: palette.inkMuted,
              )
            else if (chosen != null && onPick == null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Refresh $slot',
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh, size: 18),
                    color: palette.inkMuted,
                  ),
                  IconButton(
                    tooltip: 'Hapus dari kombinasi',
                    onPressed: onClear,
                    icon: const Icon(Icons.close, size: 18),
                    color: palette.inkMuted,
                  ),
                ],
              )
            else if (chosen != null)
              IconButton(
                tooltip: 'Hapus dari kombinasi',
                onPressed: onClear,
                icon: const Icon(Icons.close, size: 18),
                color: palette.inkMuted,
              ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet listing every catalog item of one slot.
class _PickerSheet extends StatelessWidget {
  const _PickerSheet({required this.slot, required this.options});

  final String slot;
  final List<WardrobeItem> options;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.accentTint,
                      borderRadius: AppRadius.pill,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Pilih $slot',
                  style: textTheme.titleLarge!.copyWith(
                    fontWeight: FontWeight.w600,
                    color: palette.ink,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (context, index) {
                final item = options[index];
                return ListTile(
                  onTap: () => Navigator.of(context).pop(item),
                  leading: ClipRRect(
                    borderRadius: AppRadius.chip,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: PlaceholderImage(
                        imagePath: item.imagePath,
                        icon: Icons.checkroom_outlined,
                      ),
                    ),
                  ),
                  title: Text(
                    item.name,
                    style: textTheme.bodyMedium!.copyWith(
                      fontWeight: FontWeight.w500,
                      color: palette.ink,
                    ),
                  ),
                  subtitle: Text(
                    '${item.colorName} • Formalitas ${item.formality}/5',
                    style: textTheme.labelLarge!.copyWith(
                      fontWeight: FontWeight.w500,
                      color: palette.inkMuted,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
