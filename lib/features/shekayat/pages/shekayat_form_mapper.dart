/// نگاشت داده‌های پرونده به فیلدهای فرم — اطلاعات ثبت‌شده توسط شاکی ثابت می‌ماند
class ShekayatFormMapper {
  ShekayatFormMapper._();

  static bool isLinked(Map<String, dynamic> c) {
    final id = c['linked_parvandeh_id']?.toString() ?? c['id_store']?.toString() ?? '0';
    return id.isNotEmpty && id != '0';
  }

  static String? _val(dynamic v) {
    final s = v?.toString().trim() ?? '';
    if (s.isEmpty || s == '0' || s == '-') return null;
    return s;
  }

  static ({String name, String family}) _splitOwner(String? owner, {String? fallbackFamily}) {
    if (owner == null || owner.isEmpty) {
      return (name: '', family: fallbackFamily ?? '');
    }
    final parts = owner.split(RegExp(r'\s+'));
    if (parts.length == 1) return (name: parts.first, family: fallbackFamily ?? '');
    return (name: parts.first, family: parts.sublist(1).join(' '));
  }

  /// فیلدهای متشاکی — همیشه از داده‌های ثبت‌شده توسط شاکی (بدون جایگزینی با واحد متصل)
  static Map<String, String> respondentFields(Map<String, dynamic> c) {
    final rawUnit = _val(c['name_store']);
    final rawFamily = _val(c['family_store']);
    final rawOwner = _val(c['name_malek_store']);
    final rawMob = _val(c['mob_store']);
    final rawTel = _val(c['tel_store']);
    final rawAddr = _val(c['address_store']);
    final rawMeli = _val(c['code_meli_store']);

    final owner = _splitOwner(rawOwner, fallbackFamily: rawFamily);
    var mob = rawMob ?? '';
    if (mob.isEmpty && rawTel != null) mob = rawTel;

    return {
      'motName': owner.name,
      'motFamily': owner.family,
      'motMeli': rawMeli ?? '',
      'motStore': rawUnit ?? '',
      'motMob': mob,
      'motAddr': rawAddr ?? '',
      if (isLinked(c)) 'linkedNote': 'متصل به واحد صنفی (اطلاعات متشاکی تغییر نکرده است)',
    };
  }

  static String shakiFullName(Map<String, dynamic> c) =>
      '${c['name_shaki'] ?? ''} ${c['family_shaki'] ?? ''}'.trim();

  static String moteshakiFullName(Map<String, dynamic> c) {
    final fields = respondentFields(c);
    return '${fields['motName'] ?? ''} ${fields['motFamily'] ?? ''}'.trim();
  }
}
