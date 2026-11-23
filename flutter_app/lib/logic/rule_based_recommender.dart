import '../models/wardrobe.dart';
import 'outfit_matcher.dart';

/// A complete outfit scored against its anchor item and target occasion.
class OutfitRecommendation {
  const OutfitRecommendation({
    required this.items,
    required this.totalScore,
    required this.colorScore,
    required this.formalityScore,
    required this.occasionScore,
    required this.stylingReason,
  });

  final List<WardrobeItem> items;
  final double totalScore;
  final double colorScore;
  final double formalityScore;
  final double occasionScore;
  final String stylingReason;
}

/// On-device outfit generation and scoring. It only uses the wardrobe passed
/// by the caller; no network or external inference service is involved.
class RuleBasedRecommender {
  const RuleBasedRecommender();

  static const occasions = ['Formal', 'Smart-Casual', 'Kasual', 'Sport'];
  static const colorHarmonies = [
    'monochrome',
    'analogous',
    'complementary',
    'triadic',
    'neutral',
  ];

  List<OutfitRecommendation> recommendWithBestHarmony({
    required List<WardrobeItem> anchors,
    required List<WardrobeItem> wardrobe,
    required String occasion,
    double threshold = 0.6,
  }) => recommendWithAnchors(
    anchors: anchors,
    wardrobe: wardrobe,
    occasion: occasion,
    colorHarmony: 'auto',
    threshold: threshold,
  );

  List<OutfitRecommendation> recommend({
    required WardrobeItem anchor,
    required List<WardrobeItem> wardrobe,
    required String occasion,
    required String colorHarmony,
    double threshold = 0.6,
  }) => recommendWithAnchors(
    anchors: [anchor],
    wardrobe: wardrobe,
    occasion: occasion,
    colorHarmony: colorHarmony,
    threshold: threshold,
  );

  List<OutfitRecommendation> recommendWithAnchors({
    required List<WardrobeItem> anchors,
    required List<WardrobeItem> wardrobe,
    required String occasion,
    required String colorHarmony,
    double threshold = 0.6,
  }) {
    if (!occasions.contains(occasion)) {
      throw ArgumentError.value(occasion, 'occasion', 'Unknown occasion');
    }
    if (colorHarmony != 'auto' && !colorHarmonies.contains(colorHarmony)) {
      throw ArgumentError.value(
        colorHarmony,
        'colorHarmony',
        'Unknown color harmony',
      );
    }
    if (threshold < 0 || threshold > 1) {
      throw RangeError.range(threshold, 0, 1, 'threshold');
    }
    if (anchors.isEmpty) return const [];
    if (anchors.any(
          (item) => item.category != 'Tops' && item.category != 'Bottoms',
        ) ||
        anchors.map((item) => item.category).toSet().length != anchors.length ||
        anchors.map((item) => item.id).toSet().length != anchors.length) {
      throw ArgumentError.value(
        anchors,
        'anchors',
        'Choose one unique Tops item, one unique Bottoms item, or one of each',
      );
    }

    final anchorCategories = anchors.map((item) => item.category).toSet();
    final requiredCategories = [
      for (final category in ['Tops', 'Bottoms'])
        if (!anchorCategories.contains(category)) category,
    ];
    final optionalCategories = [
      for (final category in ['Outerwear', 'Shoes', 'Accessories'])
        if (!anchorCategories.contains(category)) category,
    ];
    final optionLists = <List<WardrobeItem?>>[
      for (final category in [...requiredCategories, ...optionalCategories])
        _categoryOptions(
          category,
          wardrobe,
          anchors: anchors,
          required: requiredCategories.contains(category),
          occasion: occasion,
          colorHarmony: colorHarmony,
        ),
    ];
    if (optionLists.any((options) => options.isEmpty)) return const [];

    final candidates = <OutfitRecommendation>[];
    void build(int slotIndex, List<WardrobeItem> selected) {
      if (slotIndex == optionLists.length) {
        candidates.add(
          _score(selected, occasion: occasion, colorHarmony: colorHarmony),
        );
        return;
      }

      for (final candidate in optionLists[slotIndex]) {
        if (candidate == null) {
          build(slotIndex + 1, selected);
        } else if (!selected.any((item) => item.id == candidate.id)) {
          build(slotIndex + 1, [...selected, candidate]);
        }
      }
    }

    build(0, anchors);
    candidates.sort((a, b) => b.totalScore.compareTo(a.totalScore));

    final passing = candidates
        .where((recommendation) => recommendation.totalScore >= threshold)
        .toList();
    return passing.isNotEmpty ? passing : candidates.take(3).toList();
  }

  List<WardrobeItem?> _categoryOptions(
    String category,
    List<WardrobeItem> wardrobe, {
    required List<WardrobeItem> anchors,
    required bool required,
    required String occasion,
    required String colorHarmony,
  }) {
    final options = wardrobe
        .where(
          (item) =>
              item.category == category &&
              !anchors.any((anchor) => anchor.id == item.id),
        )
        .toList();
    if (options.isEmpty) return required ? const [] : [null];

    options.sort((a, b) {
      final scoreA = _score(
        [...anchors, a],
        occasion: occasion,
        colorHarmony: colorHarmony,
      ).totalScore;
      final scoreB = _score(
        [...anchors, b],
        occasion: occasion,
        colorHarmony: colorHarmony,
      ).totalScore;
      return scoreB.compareTo(scoreA);
    });
    return options.take(8).toList();
  }

  OutfitRecommendation _score(
    List<WardrobeItem> items, {
    required String occasion,
    required String colorHarmony,
  }) {
    final subscores = outfitSubscores(
      items,
      occasion: occasion,
      colorHarmony: colorHarmony,
    );
    final formalityScore = subscores.formality;
    final colorScore = subscores.color;
    final occasionScore = subscores.occasion;
    final weights = switch (occasion) {
      'Formal' => (color: 0.30, formality: 0.50, occasion: 0.20),
      'Smart-Casual' => (color: 0.45, formality: 0.35, occasion: 0.20),
      'Kasual' || 'Sport' => (color: 0.55, formality: 0.20, occasion: 0.25),
      _ => (color: 0.50, formality: 0.30, occasion: 0.20),
    };
    final totalScore =
        colorScore * weights.color +
        formalityScore * weights.formality +
        occasionScore * weights.occasion;
    final partner = items[1];
    final harmonyLabel = switch (colorHarmony) {
      'auto' => 'terbaik otomatis',
      'monochrome' => 'monokromatik',
      'analogous' => 'analog',
      'complementary' => 'komplementer',
      'triadic' => 'triadik',
      _ => 'netral',
    };
    final firstColor = _colorLabel(items.first);
    final partnerColor = _colorLabel(partner);
    final reason =
        'Kombinasi warna $harmonyLabel $firstColor & $partnerColor '
        'dengan tingkat formalitas ${formalityScore >= 0.8 ? 'seimbang' : 'bervariasi'} '
        'untuk $occasion';

    return OutfitRecommendation(
      items: List.unmodifiable(items),
      totalScore: totalScore.clamp(0.0, 1.0),
      colorScore: colorScore,
      formalityScore: formalityScore,
      occasionScore: occasionScore,
      stylingReason: reason,
    );
  }

  String _colorLabel(WardrobeItem item) => item.colorName.isNotEmpty
      ? item.colorName.toLowerCase()
      : item.dominantColorHex;
}
