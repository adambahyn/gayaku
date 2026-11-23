import 'package:flutter/material.dart';

import 'color_theory_helper.dart';
import '../models/wardrobe.dart';

/// Color harmony between two garments on the HSV color wheel.
///
/// [score] is the raw harmony weight (0..1); the label is what the UI shows.
enum ColorHarmony {
  netral('Netral', 0.90),
  analog('Analog', 1.00),
  komplementer('Komplementer', 1.00),
  triadic('Triadic', 0.85),
  kontras('Kontras', 0.30);

  const ColorHarmony(this.label, this.score);

  final String label;
  final double score;
}

/// Shortest hue distance on the 360° wheel, 0..180.
double hueDistance(Color a, Color b) {
  final d = (HSVColor.fromColor(a).hue - HSVColor.fromColor(b).hue).abs();
  return d > 180 ? 360 - d : d;
}

/// Near-greyscale colors carry no hue, so they pair with anything.
bool isNeutral(Color c) {
  final hsv = HSVColor.fromColor(c);
  return hsv.saturation < 0.18 || hsv.value < 0.20 || hsv.value > 0.94;
}

ColorHarmony harmonyOf(Color a, Color b) {
  if (isNeutral(a) || isNeutral(b)) return ColorHarmony.netral;
  final d = hueDistance(a, b);
  if (d <= 30) return ColorHarmony.analog;
  if (d >= 150 && d <= 210) return ColorHarmony.komplementer;
  if ((d >= 105 && d < 150) || (d > 210 && d <= 255)) {
    return ColorHarmony.triadic;
  }
  return ColorHarmony.kontras;
}

/// Slots that stack on top of any outfit instead of competing with it.
const layeringCategories = {'Outerwear', 'Accessories'};

/// Two pieces of the same slot never pair — except layers, which stack.
bool canPair(WardrobeItem a, WardrobeItem b) =>
    a.category != b.category || layeringCategories.contains(a.category);

class MatchSuggestion {
  const MatchSuggestion({
    required this.item,
    required this.score,
    required this.reasons,
  });

  final WardrobeItem item;

  /// 0..1, higher is a better partner.
  final double score;

  /// Human-readable justifications, e.g. `['Komplementer', 'Cocok Formal']`.
  final List<String> reasons;

  int get percent => (score * 100).round();
}

class PairSubscores {
  const PairSubscores({
    required this.color,
    required this.formality,
    required this.occasion,
  });

  final double color;
  final double formality;
  final double occasion;
}

/// Weighted compatibility changes with the selected occasion.
/// Returns 0 for a pair that must not be worn together.
PairSubscores pairSubscores(
  WardrobeItem a,
  WardrobeItem b, {
  String occasion = 'Kasual',
  String colorHarmony = 'auto',
}) {
  if (a.id == b.id) {
    return const PairSubscores(color: 0, formality: 0, occasion: 0);
  }
  if (!canPair(a, b)) {
    return const PairSubscores(color: 0, formality: 0, occasion: 0);
  }

  final gap = (a.formality - b.formality).abs();
  final pairConsistency = (1 - gap / 4).clamp(0.0, 1.0);
  final targetFormality = switch (occasion) {
    'Formal' => 4.5,
    'Smart-Casual' => 3.5,
    'Kasual' => 2.0,
    'Sport' => 1.5,
    _ => 2.0,
  };
  final averageFormality = (a.formality + b.formality) / 2;
  final occasionFit = (1 - (averageFormality - targetFormality).abs() / 4)
      .clamp(0.0, 1.0);
  final formality = (pairConsistency + occasionFit) / 2;
  final occasionScore =
      a.occasions.contains(occasion) && b.occasions.contains(occasion)
      ? 1.0
      : (a.occasions.contains(occasion) || b.occasions.contains(occasion)
            ? 0.5
            : 0.0);
  return PairSubscores(
    color: colorHarmonyScore(
      a.dominantColorHex,
      b.dominantColorHex,
      colorHarmony,
    ),
    formality: formality,
    occasion: occasionScore,
  );
}

double pairScore(
  WardrobeItem a,
  WardrobeItem b, {
  String occasion = 'Kasual',
  String colorHarmony = 'auto',
}) {
  final subscores = pairSubscores(
    a,
    b,
    occasion: occasion,
    colorHarmony: colorHarmony,
  );
  if (subscores.color == 0 &&
      subscores.formality == 0 &&
      subscores.occasion == 0) {
    return 0;
  }

  final weights = switch (occasion) {
    'Formal' => (color: 0.30, formality: 0.50, occasion: 0.20),
    'Smart-Casual' => (color: 0.45, formality: 0.35, occasion: 0.20),
    'Kasual' || 'Sport' => (color: 0.55, formality: 0.20, occasion: 0.25),
    _ => (color: 0.50, formality: 0.30, occasion: 0.20),
  };
  return subscores.color * weights.color +
      subscores.formality * weights.formality +
      subscores.occasion * weights.occasion;
}

PairSubscores outfitSubscores(
  List<WardrobeItem> items, {
  String occasion = 'Kasual',
  String colorHarmony = 'auto',
}) {
  if (items.length < 2) {
    return const PairSubscores(color: 0, formality: 0, occasion: 0);
  }
  var color = 0.0;
  var formality = 0.0;
  var occasionScore = 0.0;
  var pairs = 0;
  for (var i = 0; i < items.length; i++) {
    for (var j = i + 1; j < items.length; j++) {
      final subscore = pairSubscores(
        items[i],
        items[j],
        occasion: occasion,
        colorHarmony: colorHarmony,
      );
      color += subscore.color;
      formality += subscore.formality;
      occasionScore += subscore.occasion;
      pairs++;
    }
  }
  if (pairs == 0) {
    return const PairSubscores(color: 0, formality: 0, occasion: 0);
  }
  return PairSubscores(
    color: color / pairs,
    formality: formality / pairs,
    occasion: occasionScore / pairs,
  );
}

MatchSuggestion? _score(
  WardrobeItem base,
  WardrobeItem other, {
  String occasion = 'Kasual',
}) {
  final score = pairScore(base, other, occasion: occasion);
  if (score == 0) return null;

  final harmony = harmonyOf(base.color, other.color);
  final gap = (base.formality - other.formality).abs();
  final shared = base.occasions.where(other.occasions.contains).toList();

  final reasons = <String>[harmony.label];
  if (gap <= 1) reasons.add('Formalitas seimbang');
  if (shared.isNotEmpty) reasons.add('Cocok ${shared.first}');
  return MatchSuggestion(item: other, score: score, reasons: reasons);
}

/// Every compatible item, best first.
List<MatchSuggestion> recommendMatches(
  WardrobeItem base,
  List<WardrobeItem> all, {
  int limit = 20,
  String occasion = 'Kasual',
}) {
  final out =
      all.map((o) => _score(base, o, occasion: occasion)).nonNulls.toList()
        ..sort((a, b) => b.score.compareTo(a.score));
  return out.take(limit).toList();
}

/// One best partner per complementary slot, so the detail page reads as a
/// complete outfit instead of four near-identical bottoms.
List<MatchSuggestion> outfitFor(
  WardrobeItem base,
  List<WardrobeItem> all, {
  int limit = 4,
}) {
  final seen = <String>{};
  final out = <MatchSuggestion>[];
  for (final m in recommendMatches(base, all)) {
    if (seen.add(m.item.category)) out.add(m);
    if (out.length == limit) break;
  }
  return out;
}

/// Overall compatibility of a hand-built set: mean of every pair's score.
///
/// A conflicting pair (two tops, or the same item twice) scores 0, so the
/// number drops instead of silently ignoring the clash.
double outfitScore(
  List<WardrobeItem> items, {
  String occasion = 'Kasual',
  String colorHarmony = 'auto',
}) {
  if (items.length < 2) return 0;
  var sum = 0.0;
  var pairs = 0;
  for (var i = 0; i < items.length; i++) {
    for (var j = i + 1; j < items.length; j++) {
      sum += pairScore(
        items[i],
        items[j],
        occasion: occasion,
        colorHarmony: colorHarmony,
      );
      pairs++;
    }
  }
  return pairs == 0 ? 0 : sum / pairs;
}

/// The pair dragging the set down, or null for fewer than two items.
({WardrobeItem a, WardrobeItem b, double score})? weakestPair(
  List<WardrobeItem> items, {
  String occasion = 'Kasual',
}) {
  ({WardrobeItem a, WardrobeItem b, double score})? worst;
  for (var i = 0; i < items.length; i++) {
    for (var j = i + 1; j < items.length; j++) {
      final s = pairScore(items[i], items[j], occasion: occasion);
      if (worst == null || s < worst.score) {
        worst = (a: items[i], b: items[j], score: s);
      }
    }
  }
  return worst;
}

/// A one-item swap that lifts [outfitScore] towards [threshold].
class SwapSuggestion {
  const SwapSuggestion({
    required this.index,
    required this.from,
    required this.to,
    required this.newScore,
  });

  /// Position in the outfit's item list that gets replaced.
  final int index;
  final WardrobeItem from;
  final WardrobeItem to;

  /// [outfitScore] of the set after the swap.
  final double newScore;

  int get gainPercent => (newScore * 100).round();
}

/// Up to [limit] swaps that raise the score, best first.
///
/// Empty when the set already meets [threshold] — nothing to recommend.
List<SwapSuggestion> improveOutfit(
  List<WardrobeItem> items,
  List<WardrobeItem> catalog, {
  required double threshold,
  int limit = 3,
  String occasion = 'Kasual',
}) {
  final current = outfitScore(items, occasion: occasion);
  if (current >= threshold || items.length < 2) return const [];

  final used = items.map((i) => i.name).toSet();
  final out = <SwapSuggestion>[];
  for (var i = 0; i < items.length; i++) {
    for (final candidate in catalog) {
      if (used.contains(candidate.name)) continue;
      final trial = [...items]..[i] = candidate;
      final score = outfitScore(trial, occasion: occasion);
      if (score > current) {
        out.add(
          SwapSuggestion(
            index: i,
            from: items[i],
            to: candidate,
            newScore: score,
          ),
        );
      }
    }
  }
  out.sort((a, b) => b.newScore.compareTo(a.newScore));
  return out.take(limit).toList();
}
