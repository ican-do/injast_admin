class DasteMazaya {
  final int id;
  final String title;
  final String? description;

  const DasteMazaya({
    required this.id,
    required this.title,
    this.description,
  });

  factory DasteMazaya.fromJson(Map<String, dynamic> json) => DasteMazaya(
        id: json['id_cat'] ?? json['id'] ?? 0,
        title: json['name_cat'] ?? '',
        description: json['description'],
      );
}

class StepMazaya {
  final int id;
  final int number;
  final String title;
  final String? description;

  const StepMazaya({
    required this.id,
    required this.number,
    required this.title,
    this.description,
  });

  factory StepMazaya.fromJson(Map<String, dynamic> json) => StepMazaya(
        id: json['id_step'] ?? json['id'] ?? 0,
        number: json['step_number'] ?? 1,
        title: json['step_title'] ?? '',
        description: json['step_desc'],
      );
}

class MazayaItem {
  final int id;
  final int categoryId;
  final String title;
  final String? shortDesc;
  final String? fullDescRaw;
  final String categoryTitle;
  final String? iconName;
  final DateTime? createdAt;

  const MazayaItem({
    required this.id,
    required this.categoryId,
    required this.title,
    this.shortDesc,
    required this.categoryTitle,
    this.fullDescRaw,
    this.iconName,
    this.createdAt,
  });

  factory MazayaItem.fromJson(Map<String, dynamic> json) => MazayaItem(
        id: json['id_benefit'] ?? json['id'] ?? 0,
        categoryId: json['id_cat'] ?? 0,
        title: json['title'] ?? '',
        shortDesc: json['short_desc'],
        fullDescRaw: json['full_desc'],
        categoryTitle: json['name_cat'] ?? '',
        iconName: json['icon_name'],
        createdAt: DateTime.tryParse(
          json['datetime_benefit'] ?? json['created_at'] ?? '',
        ),
      );
}

class MazayaDetail extends MazayaItem {
  final String fullDesc;
  final List<StepMazaya> steps;

  MazayaDetail({
    required super.id,
    required super.categoryId,
    required super.title,
    required this.fullDesc,
    super.shortDesc,
    super.fullDescRaw,
    required super.categoryTitle,
    super.iconName,
    super.createdAt,
    this.steps = const [],
  });

  factory MazayaDetail.fromJson(Map<String, dynamic> json) => MazayaDetail(
        id: json['id_benefit'] ?? 0,
        categoryId: json['id_cat'] ?? 0,
        title: json['title'] ?? '',
        shortDesc: json['short_desc'],
        fullDescRaw: json['full_desc'],
        fullDesc: json['full_desc'] ?? '',
        categoryTitle: json['name_cat'] ?? '',
        iconName: json['icon_name'],
        createdAt: DateTime.tryParse(
          json['datetime_benefit'] ?? json['created_at'] ?? '',
        ),
        steps: (json['steps'] as List<dynamic>? ?? [])
            .map((e) => StepMazaya.fromJson(e))
            .toList(),
      );
}

