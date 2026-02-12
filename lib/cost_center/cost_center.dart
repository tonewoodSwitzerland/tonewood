import 'package:cloud_firestore/cloud_firestore.dart';

/// Modell für Kostenstellen
class CostCenter {
  final String id;
  final String code;
  final String name;
  final String description;
  final DateTime createdAt;
  final bool isActive;

  CostCenter({
    required this.id,
    required this.code,
    required this.name,
    this.description = '',
    required this.createdAt,
    this.isActive = true,
  });

  factory CostCenter.fromMap(Map<String, dynamic> map, String id) {
    return CostCenter(
      id: id,
      code: map['code'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'name': name,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
    };
  }

  CostCenter copyWith({
    String? id,
    String? code,
    String? name,
    String? description,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return CostCenter(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}