/// محدوده مختصاتی استان‌ها و شهرهای ایران
/// مقادیر استان‌های اصلی مطابق منطق ذخیره‌شده در بک‌اند (`boundsByState` / `stateBounds`) است.
class RegionBox {
  final double latMin;
  final double latMax;
  final double lonMin;
  final double lonMax;

  const RegionBox({
    required this.latMin,
    required this.latMax,
    required this.lonMin,
    required this.lonMax,
  });

  bool contains(double lat, double lon) {
    return lat >= latMin &&
        lat <= latMax &&
        lon >= lonMin &&
        lon <= lonMax;
  }
}

String _norm(String raw) {
  return raw
      .trim()
      .replaceAll('ي', 'ی')
      .replaceAll('ك', 'ک')
      .replaceAll('‌', ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
}

/// محدوده استان — همان مختصات قبلی سیستم + پوشش بقیه استان‌ها
const Map<String, RegionBox> kIranStateBounds = {
  'آذربایجان شرقی': RegionBox(latMin: 37.5, latMax: 38.9, lonMin: 45.5, lonMax: 47.5),
  'آذربایجان غربی': RegionBox(latMin: 36.0, latMax: 39.8, lonMin: 44.0, lonMax: 47.4),
  'اردبیل': RegionBox(latMin: 37.2, latMax: 39.7, lonMin: 47.2, lonMax: 48.9),
  'اصفهان': RegionBox(latMin: 30.7, latMax: 34.6, lonMin: 49.5, lonMax: 55.5),
  'البرز': RegionBox(latMin: 35.6, latMax: 36.4, lonMin: 50.4, lonMax: 51.6),
  'ایلام': RegionBox(latMin: 32.0, latMax: 34.3, lonMin: 45.5, lonMax: 48.1),
  'بوشهر': RegionBox(latMin: 27.2, latMax: 30.3, lonMin: 50.2, lonMax: 52.9),
  'تهران': RegionBox(latMin: 35.4, latMax: 35.9, lonMin: 51.0, lonMax: 51.7),
  'چهارمحال بختیاری': RegionBox(latMin: 31.1, latMax: 32.9, lonMin: 49.5, lonMax: 51.5),
  'چهارمحال و بختیاری': RegionBox(latMin: 31.1, latMax: 32.9, lonMin: 49.5, lonMax: 51.5),
  'خراسان جنوبی': RegionBox(latMin: 30.5, latMax: 34.2, lonMin: 57.0, lonMax: 61.2),
  'خراسان رضوی': RegionBox(latMin: 35.5, latMax: 37.5, lonMin: 58.0, lonMax: 60.0),
  'خراسان شمالی': RegionBox(latMin: 36.6, latMax: 38.3, lonMin: 55.9, lonMax: 58.3),
  'خوزستان': RegionBox(latMin: 29.9, latMax: 33.1, lonMin: 47.6, lonMax: 50.6),
  'زنجان': RegionBox(latMin: 35.5, latMax: 37.2, lonMin: 47.4, lonMax: 49.5),
  'سمنان': RegionBox(latMin: 34.4, latMax: 37.2, lonMin: 51.8, lonMax: 57.0),
  'سیستان و بلوچستان': RegionBox(latMin: 25.0, latMax: 31.5, lonMin: 58.8, lonMax: 63.4),
  'فارس': RegionBox(latMin: 27.0, latMax: 31.5, lonMin: 51.0, lonMax: 55.0),
  'قزوین': RegionBox(latMin: 35.4, latMax: 36.8, lonMin: 48.7, lonMax: 50.6),
  'قم': RegionBox(latMin: 34.3, latMax: 35.2, lonMin: 50.3, lonMax: 51.7),
  'کردستان': RegionBox(latMin: 34.7, latMax: 36.5, lonMin: 45.4, lonMax: 48.2),
  'کرمان': RegionBox(latMin: 28.0, latMax: 31.5, lonMin: 55.0, lonMax: 58.0),
  'کرمانشاه': RegionBox(latMin: 33.7, latMax: 35.3, lonMin: 45.4, lonMax: 48.1),
  'کهگیلویه و بویراحمد': RegionBox(latMin: 30.0, latMax: 31.6, lonMin: 50.0, lonMax: 51.8),
  'کهکیلویه و بویراحمد': RegionBox(latMin: 30.0, latMax: 31.6, lonMin: 50.0, lonMax: 51.8),
  'گلستان': RegionBox(latMin: 36.6, latMax: 38.2, lonMin: 53.8, lonMax: 56.4),
  'گیلان': RegionBox(latMin: 36.6, latMax: 38.5, lonMin: 48.5, lonMax: 50.6),
  'لرستان': RegionBox(latMin: 32.6, latMax: 34.4, lonMin: 46.8, lonMax: 50.1),
  'مازندران': RegionBox(latMin: 35.8, latMax: 36.9, lonMin: 50.3, lonMax: 54.2),
  'مرکزی': RegionBox(latMin: 33.4, latMax: 35.6, lonMin: 48.9, lonMax: 51.1),
  'هرمزگان': RegionBox(latMin: 25.4, latMax: 28.6, lonMin: 52.6, lonMax: 59.2),
  'همدان': RegionBox(latMin: 34.0, latMax: 35.8, lonMin: 47.8, lonMax: 49.6),
  'یزد': RegionBox(latMin: 29.6, latMax: 33.2, lonMin: 52.8, lonMax: 56.4),
};

/// محدوده شهرستان‌هایی که قبلاً در سیستم ذخیره شده / شهرهای مرکز اتحادیه
const Map<String, RegionBox> kIranCityBounds = {
  'مشهد': RegionBox(latMin: 36.1, latMax: 36.5, lonMin: 59.3, lonMax: 59.8),
  'تهران': RegionBox(latMin: 35.55, latMax: 35.85, lonMin: 51.15, lonMax: 51.60),
  'اصفهان': RegionBox(latMin: 32.50, latMax: 32.85, lonMin: 51.50, lonMax: 51.85),
  'شیراز': RegionBox(latMin: 29.50, latMax: 29.80, lonMin: 52.40, lonMax: 52.70),
  'تبریز': RegionBox(latMin: 38.00, latMax: 38.20, lonMin: 46.20, lonMax: 46.45),
  'کرمان': RegionBox(latMin: 30.20, latMax: 30.40, lonMin: 56.95, lonMax: 57.20),
  'اهواز': RegionBox(latMin: 31.20, latMax: 31.45, lonMin: 48.55, lonMax: 48.80),
  'قم': RegionBox(latMin: 34.55, latMax: 34.75, lonMin: 50.80, lonMax: 51.00),
  'کرج': RegionBox(latMin: 35.75, latMax: 35.90, lonMin: 50.85, lonMax: 51.10),
  'رشت': RegionBox(latMin: 37.22, latMax: 37.35, lonMin: 49.52, lonMax: 49.70),
  'یزد': RegionBox(latMin: 31.80, latMax: 32.00, lonMin: 54.28, lonMax: 54.48),
};

RegionBox? regionBoxFor({String? state, String? city}) {
  final cityName = _norm(city ?? '');
  final stateName = _norm(state ?? '');
  if (cityName.isNotEmpty && kIranCityBounds.containsKey(cityName)) {
    return kIranCityBounds[cityName];
  }
  if (stateName.isNotEmpty && kIranStateBounds.containsKey(stateName)) {
    return kIranStateBounds[stateName];
  }
  return null;
}
