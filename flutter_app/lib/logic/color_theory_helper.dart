/// HSV values derived from a garment's `#RRGGBB` dominant color.
class HsvColorValue {
  const HsvColorValue({
    required this.hue,
    required this.saturation,
    required this.value,
  });

  final double hue;
  final double saturation;
  final double value;

  factory HsvColorValue.fromHex(String hex) {
    final digits = hex.startsWith('#') ? hex.substring(1) : hex;
    if (!RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(digits)) {
      throw FormatException('Expected a color in #RRGGBB format.', hex);
    }

    final rgb = int.parse(digits, radix: 16);
    final red = ((rgb >> 16) & 0xFF) / 255;
    final green = ((rgb >> 8) & 0xFF) / 255;
    final blue = (rgb & 0xFF) / 255;
    final maximum = _max3(red, green, blue);
    final minimum = _min3(red, green, blue);
    final chroma = maximum - minimum;

    var hue = 0.0;
    if (chroma != 0) {
      if (maximum == red) {
        hue = 60 * (((green - blue) / chroma) % 6);
      } else if (maximum == green) {
        hue = 60 * ((blue - red) / chroma + 2);
      } else {
        hue = 60 * ((red - green) / chroma + 4);
      }
      if (hue < 0) hue += 360;
    }

    return HsvColorValue(
      hue: hue,
      saturation: maximum == 0 ? 0 : chroma / maximum,
      value: maximum,
    );
  }

  bool get isNeutral =>
      saturation <= 0.18 ||
      value <= 0.15 ||
      (value >= 0.90 && saturation <= 0.12);
}

const colorHarmonySchemes = [
  'monochrome',
  'analogous',
  'complementary',
  'triadic',
  'neutral',
];

/// Shortest distance between two hues, in degrees from 0 to 180.
double deltaHue(double first, double second) {
  final difference = (first - second).abs() % 360;
  return difference > 180 ? 360 - difference : difference;
}

/// Scores two garment colors for the selected harmony, from 0 to 1.
///
/// Neutral garments remain a strong match regardless of the selected scheme.
double colorHarmonyScore(String firstHex, String secondHex, String scheme) {
  if (scheme == 'auto') {
    return colorHarmonySchemes
        .map((option) => colorHarmonyScore(firstHex, secondHex, option))
        .reduce((best, score) => score > best ? score : best);
  }

  final first = HsvColorValue.fromHex(firstHex);
  final second = HsvColorValue.fromHex(secondHex);
  if (first.isNeutral || second.isNeutral) return 0.90;

  final distance = deltaHue(first.hue, second.hue);
  final range = switch (scheme) {
    'monochrome' => (minimum: 0.0, maximum: 15.0),
    'analogous' => (minimum: 15.0, maximum: 45.0),
    'complementary' => (minimum: 150.0, maximum: 180.0),
    'triadic' => (minimum: 110.0, maximum: 130.0),
    'neutral' => null,
    _ => throw ArgumentError.value(scheme, 'scheme', 'Unknown color harmony'),
  };
  if (range == null) return 0.35;
  if (distance >= range.minimum && distance <= range.maximum) return 1;

  final distanceToRange = distance < range.minimum
      ? range.minimum - distance
      : distance - range.maximum;
  return (1 - distanceToRange / 60).clamp(0.0, 1.0);
}

double _max3(double a, double b, double c) =>
    a > b ? (a > c ? a : c) : (b > c ? b : c);

double _min3(double a, double b, double c) =>
    a < b ? (a < c ? a : c) : (b < c ? b : c);
