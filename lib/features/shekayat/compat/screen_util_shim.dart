/// جایگزینی سبک برای flutter_screenutil — کمی فشرده‌تر برای دسکتاپ
extension ShekayatScreenNum on num {
  double get w => toDouble() * 0.85;
  double get h => toDouble() * 0.8;
  double get sp => toDouble() * 0.92;
  double get r => toDouble() * 0.85;
}
