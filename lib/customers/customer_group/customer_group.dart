import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CustomerGroup {
  final String id;
  final String name;
  final String? description;
  final String colorHex; // Hex-Farbcode z.B. "#FF5722"
  final int sortOrder;
  final DateTime createdAt;

  CustomerGroup({
    required this.id,
    required this.name,
    this.description,
    this.colorHex = '#607D8B', // Default: Blaugrau
    this.sortOrder = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Farbe als Color-Objekt
  Color get color {
    try {
      final hex = colorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (e) {
      return Colors.blueGrey;
    }
  }

  factory CustomerGroup.fromMap(Map<String, dynamic> map, String id) {
    return CustomerGroup(
      id: id,
      name: map['name'] ?? '',
      description: map['description'],
      colorHex: map['colorHex'] ?? '#607D8B',
      sortOrder: map['sortOrder'] ?? 0,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'colorHex': colorHex,
      'sortOrder': sortOrder,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  CustomerGroup copyWith({
    String? id,
    String? name,
    String? description,
    String? colorHex,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return CustomerGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      colorHex: colorHex ?? this.colorHex,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Vordefinierte Standardgruppen
  static List<CustomerGroup> get defaultGroups => [
    CustomerGroup(
      id: '',
      name: 'Akustische Gitarre',
      description: 'Kunden für akustische Gitarren und Tonewood',
      colorHex: '#8B4513', // Braun
      sortOrder: 1,
    ),
    CustomerGroup(
      id: '',
      name: 'Streichinstrumente',
      description: 'Kunden für Geigen, Celli, Kontrabässe etc.',
      colorHex: '#B22222', // Dunkelrot
      sortOrder: 2,
    ),
    CustomerGroup(
      id: '',
      name: 'E-Gitarre',
      description: 'Kunden für elektrische Gitarren',
      colorHex: '#4169E1', // Königsblau
      sortOrder: 3,
    ),
    CustomerGroup(
      id: '',
      name: 'Weitere Zupfinstrumente',
      description: 'Mandolinen, Ukulelen, Banjos etc.',
      colorHex: '#2E8B57', // Meergrün
      sortOrder: 4,
    ),
    CustomerGroup(
      id: '',
      name: 'Resonanzholz',
      description: 'Kunden für Resonanzholz allgemein',
      colorHex: '#DAA520', // Goldgelb
      sortOrder: 5,
    ),
    CustomerGroup(
      id: '',
      name: 'Zubehör / Spezial',
      description: 'Zubehör und Spezialanfertigungen',
      colorHex: '#708090', // Schiefergrau
      sortOrder: 6,
    ),
    CustomerGroup(
      id: '',
      name: 'Mix',
      description: 'Kunden mit gemischten Interessen (Gitarre und Streichinstrumente)',
      colorHex: '#9932CC', // Dunkelviolett
      sortOrder: 7,
    ),
  ];

  // Verfügbare Farben für die Auswahl
  static List<String> get availableColors => [
    '#8B4513', // Braun
    '#B22222', // Dunkelrot
    '#4169E1', // Königsblau
    '#2E8B57', // Meergrün
    '#DAA520', // Goldgelb
    '#708090', // Schiefergrau
    '#9932CC', // Dunkelviolett
    '#FF5722', // Deep Orange
    '#E91E63', // Pink
    '#00BCD4', // Cyan
    '#4CAF50', // Grün
    '#FF9800', // Orange
    '#795548', // Braun
    '#607D8B', // Blaugrau
    '#3F51B5', // Indigo
  ];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is CustomerGroup &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;
}