import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/logic/color_theory_helper.dart';
import 'package:flutter_app/logic/outfit_matcher.dart';
import 'package:flutter_app/logic/rule_based_recommender.dart';
import 'package:flutter_app/models/wardrobe.dart';

const _redTop = WardrobeItem(
  id: 'red-top',
  name: 'Atasan Merah',
  category: 'Tops',
  colorName: 'Merah',
  color: Color(0xFFFF0000),
  formality: 4,
  occasions: ['Formal', 'Smart-Casual'],
  imagePath: '',
);

const _greenBottom = WardrobeItem(
  id: 'green-bottom',
  name: 'Celana Hijau',
  category: 'Bottoms',
  colorName: 'Hijau',
  color: Color(0xFF00FF00),
  formality: 4,
  occasions: ['Formal'],
  imagePath: '',
);

const _blueBottom = WardrobeItem(
  id: 'blue-bottom',
  name: 'Celana Biru',
  category: 'Bottoms',
  colorName: 'Biru',
  color: Color(0xFF0000FF),
  formality: 2,
  occasions: ['Kasual'],
  imagePath: '',
);

void main() {
  group('HSV color theory', () {
    test('converts #RRGGBB to hue, saturation and value', () {
      final red = HsvColorValue.fromHex('#FF0000');
      final green = HsvColorValue.fromHex('00FF00');

      expect(red.hue, 0);
      expect(red.saturation, 1);
      expect(red.value, 1);
      expect(green.hue, 120);
      expect(deltaHue(350, 10), 20);
      expect(() => HsvColorValue.fromHex('#+ABCDE'), throwsFormatException);
    });

    test('detects beige as neutral and keeps it harmonious', () {
      expect(HsvColorValue.fromHex('#E8DECE').isNeutral, isTrue);
      expect(colorHarmonyScore('#E8DECE', '#FF0000', 'complementary'), 0.90);
    });

    test('scores the requested hue relationship', () {
      expect(colorHarmonyScore('#FF0000', '#00FF00', 'triadic'), 1);
      expect(colorHarmonyScore('#FF0000', '#00FF00', 'monochrome'), 0);
    });

    test('auto selects the highest score among all harmony schemes', () {
      final expected = RuleBasedRecommender.colorHarmonies
          .map((scheme) => colorHarmonyScore('#FF0000', '#0000FF', scheme))
          .reduce((a, b) => a > b ? a : b);
      expect(colorHarmonyScore('#FF0000', '#0000FF', 'auto'), expected);
    });
  });

  group('RuleBasedRecommender', () {
    const recommender = RuleBasedRecommender();

    test('uses target occasion and balances formality', () {
      final results = recommender.recommend(
        anchor: _redTop,
        wardrobe: [_redTop, _greenBottom, _blueBottom],
        occasion: 'Formal',
        colorHarmony: 'triadic',
        threshold: 0.8,
      );

      expect(results, hasLength(1));
      expect(results.single.items.map((item) => item.id), [
        'red-top',
        'green-bottom',
      ]);
      expect(results.single.occasionScore, 1);
      expect(results.single.formalityScore, closeTo(0.9375, 0.001));
      expect(results.single.totalScore, closeTo(0.96875, 0.001));
      expect(results.single.stylingReason, contains('Formal'));

      final fallback = recommender.recommend(
        anchor: _redTop,
        wardrobe: [_redTop, _greenBottom, _blueBottom],
        occasion: 'Formal',
        colorHarmony: 'monochrome',
        threshold: 1,
      );
      final mismatched = fallback.singleWhere(
        (result) => result.items.any((item) => item.id == 'blue-bottom'),
      );
      expect(mismatched.occasionScore, closeTo(0.5, 0.001));
      expect(mismatched.formalityScore, closeTo(0.5625, 0.001));
      expect(mismatched.totalScore, closeTo(0.38125, 0.001));
    });

    test(
      'returns top three below threshold and requires the paired category',
      () {
        final results = recommender.recommend(
          anchor: _redTop,
          wardrobe: [
            _redTop,
            _blueBottom,
            const WardrobeItem(
              id: 'green-bottom',
              name: 'Celana Hijau',
              category: 'Bottoms',
              color: Color(0xFF00FF00),
              formality: 2,
              occasions: ['Kasual'],
              imagePath: '',
            ),
            const WardrobeItem(
              id: 'yellow-bottom',
              name: 'Celana Kuning',
              category: 'Bottoms',
              color: Color(0xFFFFFF00),
              formality: 1,
              occasions: ['Sport'],
              imagePath: '',
            ),
          ],
          occasion: 'Sport',
          colorHarmony: 'monochrome',
          threshold: 1,
        );
        final noPartner = recommender.recommend(
          anchor: _redTop,
          wardrobe: [_redTop],
          occasion: 'Kasual',
          colorHarmony: 'neutral',
        );

        expect(results, hasLength(3));
        expect(
          results,
          everyElement(
            predicate<OutfitRecommendation>(
              (result) =>
                  result.items.any((item) => item.category == 'Bottoms'),
            ),
          ),
        );
        expect(noPartner, isEmpty);
      },
    );

    test('keeps both selected anchors and fills available remaining slots', () {
      const outerwear = WardrobeItem(
        id: 'jacket',
        name: 'Jaket',
        category: 'Outerwear',
        color: Color(0xFFFF0000),
        formality: 4,
        occasions: ['Formal'],
        imagePath: '',
      );
      const shoes = WardrobeItem(
        id: 'shoes',
        name: 'Sepatu',
        category: 'Shoes',
        color: Color(0xFF00FF00),
        formality: 4,
        occasions: ['Formal'],
        imagePath: '',
      );
      const accessory = WardrobeItem(
        id: 'accessory',
        name: 'Aksesori',
        category: 'Accessories',
        color: Color(0xFF0000FF),
        formality: 4,
        occasions: ['Formal'],
        imagePath: '',
      );
      final results = recommender.recommendWithAnchors(
        anchors: [_redTop, _greenBottom],
        wardrobe: [_redTop, _greenBottom, outerwear, shoes, accessory],
        occasion: 'Formal',
        colorHarmony: 'triadic',
        threshold: 0,
      );

      expect(results, hasLength(1));
      expect(results.single.items.map((item) => item.category).toSet(), {
        'Tops',
        'Bottoms',
        'Outerwear',
        'Shoes',
        'Accessories',
      });
      expect(results.single.items.take(2), [_redTop, _greenBottom]);
    });

    test(
      'auto recommendation uses the same outfit score as the score card',
      () {
        final recommendation = recommender
            .recommendWithBestHarmony(
              anchors: [_redTop],
              wardrobe: [_redTop, _greenBottom, _blueBottom],
              occasion: 'Formal',
              threshold: 0,
            )
            .first;
        final scoreDetails = outfitSubscores(
          recommendation.items,
          occasion: 'Formal',
        );

        expect(
          recommendation.totalScore,
          closeTo(outfitScore(recommendation.items, occasion: 'Formal'), 1e-10),
        );
        expect(recommendation.colorScore, closeTo(scoreDetails.color, 1e-10));
        expect(
          recommendation.formalityScore,
          closeTo(scoreDetails.formality, 1e-10),
        );
        expect(
          recommendation.occasionScore,
          closeTo(scoreDetails.occasion, 1e-10),
        );
      },
    );
  });
}
