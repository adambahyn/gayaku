/// Domain models for the wardrobe home screen.
///
/// A [Look] is a styled outfit suggestion rendered as "Today's Look".
/// A [WardrobeItem] is a single owned garment rendered in "Recently Added".
/// A Look may reference multiple WardrobeItems but is not itself one.
library;

class Look {
  const Look({
    required this.title,
    required this.subtitle,
    required this.styleTag,
    required this.imagePath,
  });

  final String title;
  final String subtitle;

  /// Short occasion label shown as a pill on the look card.
  final String styleTag;
  final String imagePath;
}

class WardrobeItem {
  const WardrobeItem({
    required this.name,
    required this.category,
    required this.imagePath,
    this.brand = '',
  });

  final String name;
  final String category;
  final String imagePath;

  /// Optional maker label, rendered as `Category • Brand` under the name.
  final String brand;
}

/// Catalog shown on the Wardrobe screen, grouped by the chips below.
const wardrobeItems = <WardrobeItem>[
  WardrobeItem(
    name: 'Silk Blouse',
    category: 'Tops',
    brand: 'Zara',
    imagePath: 'assets/images/silk_blouse.jpg',
  ),
  WardrobeItem(
    name: 'Beige Trench',
    category: 'Outerwear',
    brand: 'Burberry',
    imagePath: 'assets/images/beige_trench.jpg',
  ),
  WardrobeItem(
    name: 'Classic Sneakers',
    category: 'Shoes',
    brand: 'Nike',
    imagePath: 'assets/images/classic_sneakers.jpg',
  ),
  WardrobeItem(
    name: 'Gold Link Chain',
    category: 'Accessories',
    brand: 'Mejuri',
    imagePath: 'assets/images/gold_link_chain.jpg',
  ),
  WardrobeItem(
    name: 'Straight Leg Jeans',
    category: 'Bottoms',
    brand: "Levi's",
    imagePath: 'assets/images/straight_leg_jeans.jpg',
  ),
  WardrobeItem(
    name: 'Linen Shirt',
    category: 'Tops',
    brand: 'Uniqlo',
    imagePath: 'assets/images/linen_shirt.jpg',
  ),
];

/// Chip labels: the leading chip clears the category filter.
const wardrobeCategories = <String>[
  'All Items',
  'Tops',
  'Bottoms',
  'Outerwear',
  'Shoes',
  'Accessories',
];

/// Sample content for the static home screen.
const todaysLook = Look(
  title: 'Effortless Linen Dress',
  subtitle: 'Breezy layers for a warm afternoon out',
  styleTag: 'Casual Chic',
  imagePath: 'assets/images/todays_look.jpg',
);

const recentItems = <WardrobeItem>[
  WardrobeItem(
    name: 'White Sneakers',
    category: 'Shoes',
    imagePath: 'assets/images/white_sneakers.jpg',
  ),
  WardrobeItem(
    name: 'Gold Chain',
    category: 'Accessories',
    imagePath: 'assets/images/gold_chain.jpg',
  ),
  WardrobeItem(
    name: 'Silk Blouse',
    category: 'Tops',
    imagePath: 'assets/images/silk_blouse.jpg',
  ),
];
