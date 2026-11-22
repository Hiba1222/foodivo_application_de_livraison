// All money is Tunisian dinar stored as integer MILLIMES (1 TND = 1000), like the website.
const deliveryFee = 2500;

/// 7500 -> "7.500 TND"
String formatPrice(int millimes) => '${(millimes / 1000).toStringAsFixed(3)} TND';
