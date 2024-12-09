import 'package:cloud_firestore/cloud_firestore.dart';

class RoundwoodItem {
  final String id;
  final String internalNumber;
  final String? originalNumber;
  final String woodType;
  final String woodName;
  final String quality;
  final String qualityName;
  final double volume;
  final String? color;
  final String? origin;
  final String? purpose;
  final bool isMoonwood;
  final String? remarks;
  final DateTime timestamp;
  final DateTime? cuttingDate;
  final List<String> purposeCodes;
  final List<String>? purposeNames;
  final String? additionalPurpose; // Neu hinzugefügt

  RoundwoodItem({
    required this.id,
    required this.internalNumber,
    this.originalNumber,
    required this.woodType,
    required this.woodName,
    required this.quality,
    required this.qualityName,
    required this.volume,
    this.color,
    this.origin,
    this.purpose,
    required this.isMoonwood,
    this.remarks,
    required this.timestamp,
    this.cuttingDate,
    required this.purposeCodes,
    this.purposeNames,
    this.additionalPurpose, // Neu hinzugefügt
  });

  factory RoundwoodItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Timestamp-Conversion mit Fallback
    final timestamp = data['timestamp'] != null
        ? (data['timestamp'] as Timestamp).toDate()
        : DateTime.now();

    return RoundwoodItem(
      id: doc.id,
      internalNumber: data['internal_number'] ?? '',
      originalNumber: data['original_number'],
      woodType: data['wood_type'] ?? '',
      woodName: data['wood_name'] ?? '',
      quality: data['quality'] ?? '',
      qualityName: data['quality_name'] ?? '',
      volume: (data['volume'] ?? 0.0).toDouble(),
      color: data['color'],
      origin: data['origin'],
      purpose: data['purpose'],
      isMoonwood: data['is_moonwood'] ?? false,
      remarks: data['remarks'],
      timestamp: timestamp,
      cuttingDate: data['cutting_date'] != null
          ? (data['cutting_date'] as Timestamp).toDate()
          : null,
      purposeCodes: List<String>.from(data['purpose_codes'] ?? []),
      purposeNames: data['purpose_names'] != null
          ? List<String>.from(data['purpose_names'])
          : null,
      additionalPurpose: data['additional_purpose'], // Neu hinzugefügt
    );

  }

  Map<String, dynamic> toMap() {
    return {
      'internal_number': internalNumber,
      'original_number': originalNumber,
      'wood_type': woodType,
      'wood_name': woodName,
      'quality': quality,
      'quality_name': qualityName,
      'volume': volume,
      'color': color,
      'origin': origin,
      'purpose': purpose,
      'is_moonwood': isMoonwood,
      'remarks': remarks,
      'timestamp': FieldValue.serverTimestamp(),
      'cutting_date': cuttingDate != null
          ? Timestamp.fromDate(cuttingDate!)
          : null,
      'purpose_codes': purposeCodes,
      'purpose_names': purposeNames,
      'additional_purpose': additionalPurpose, // Neu hinzugefügt
    };
  }
}

class RoundwoodFilter {
  final List<String>? woodTypes;
  final List<String>? qualities;
  final List<String>? purposeCodes;
  final String? additionalPurpose;
  final String? origin;
  final double? volumeMin;
  final double? volumeMax;
  final bool? isMoonwood;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? timeRange;

  RoundwoodFilter({
    this.woodTypes,
    this.qualities,
    this.purposeCodes,
    this.additionalPurpose,
    this.origin,
    this.volumeMin,
    this.volumeMax,
    this.isMoonwood,
    this.startDate,
    this.endDate,
    this.timeRange,
  });

  Map<String, dynamic> toMap() {
    return {
      if (woodTypes != null) 'wood_types': woodTypes,
      if (qualities != null) 'qualities': qualities,
      if (purposeCodes != null) 'purpose_codes': purposeCodes,
      if (additionalPurpose != null) 'additional_purpose': additionalPurpose,
      if (origin != null) 'origin': origin,
      if (volumeMin != null) 'volume_min': volumeMin,
      if (volumeMax != null) 'volume_max': volumeMax,
      if (isMoonwood != null) 'is_moonwood': isMoonwood,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (timeRange != null) 'time_range': timeRange,
    };
  }
}