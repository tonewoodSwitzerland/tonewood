// Model für Messen
class Fair {
  final String id;
  final String name;
  final String location;
  final String costCenterCode;
  final DateTime startDate;
  final DateTime endDate;
  final String country;
  final String city;
  final String address;
  final bool isActive;
  final String? notes;

  const Fair({
    required this.id,
    required this.name,
    required this.location,
    required this.costCenterCode,
    required this.startDate,
    required this.endDate,
    required this.country,
    required this.city,
    required this.address,
    this.isActive = true,
    this.notes,
  });
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'location': location,
    'costCenterCode': costCenterCode,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'country': country,
    'city': city,
    'address': address,
    'isActive': isActive,
    'notes': notes,
  };

  factory Fair.fromMap(Map<String, dynamic> map, String id) {
    return Fair(
      id: id,
      name: map['name'] ?? '',
      location: map['location'] ?? '',
      costCenterCode: map['costCenterCode'] ?? '',
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
      country: map['country'] ?? '',
      city: map['city'] ?? '',
      address: map['address'] ?? '',
      isActive: map['isActive'] ?? true,
      notes: map['notes'],
    );
  }
}