// cost_center.dart
class CostCenter {
  final String id;
  final String code;
  final String name;
  final String description;
  final DateTime createdAt;

  CostCenter({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'name': name,
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }

  static CostCenter fromMap(Map<String, dynamic> map, String docId) {
    return CostCenter(
      id: docId,
      code: map['code'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}
