import 'package:cloud_firestore/cloud_firestore.dart';

class RoundwoodItem {
  final String id;
  final String internalNumber;
  final String? originalNumber;
  final int year; // NEU: Jahrgang
  final String woodType;
  final String woodName;
  final String quality;
  final String qualityName;
  final double volume;
  final String? sprayColor; // UMBENANNT: war 'color'
  final String? plaketteColor; // NEU: Farbe Plakette
  final String? origin;
  final bool isMoonwood;
  final bool isFSC; // NEU: FSC-zertifiziert
  final String? remarks;
  final DateTime timestamp;
  final DateTime? cuttingDate;
  final List<String> purposes; // VEREINFACHT: direkte Liste der Verwendungszwecke
  final String? otherPurpose; // NEU: "andere" Freitext
  final bool isClosed; // NEU

  RoundwoodItem({
    required this.id,
    required this.internalNumber,
    this.originalNumber,
    required this.year,
    required this.woodType,
    required this.woodName,
    required this.quality,
    required this.qualityName,
    required this.volume,
    this.sprayColor,
    this.plaketteColor,
    this.origin,
    required this.isMoonwood,
    required this.isFSC,
    this.remarks,
    required this.timestamp,
    this.cuttingDate,
    required this.purposes,
    this.otherPurpose,
    required this.isClosed, // NEU
  });

  factory RoundwoodItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Timestamp mit Fallback
    final timestamp = data['timestamp'] != null
        ? (data['timestamp'] as Timestamp).toDate()
        : DateTime.now();

    // Jahr: neu oder aus Timestamp ableiten (Abwärtskompatibilität)
    final year = data['year'] ?? timestamp.year;

    // Spray Color: neues Feld oder Fallback auf altes 'color' Feld
    final sprayColor = data['spray_color'] ?? data['color'];

    // Purposes: neue Struktur oder Fallback auf alte purpose_names/purpose_codes
    List<String> purposes;
    if (data['purposes'] != null) {
      purposes = List<String>.from(data['purposes']);
    } else if (data['purpose_names'] != null) {
      purposes = List<String>.from(data['purpose_names']);
    } else if (data['purpose'] != null && data['purpose'].toString().isNotEmpty) {
      purposes = [data['purpose'].toString()];
    } else {
      purposes = [];
    }

    // Other Purpose: neues Feld oder Fallback auf altes additional_purpose
    final otherPurpose = data['other_purpose'] ?? data['additional_purpose'];

    return RoundwoodItem(
      id: doc.id,
      internalNumber: data['internal_number'] ?? '',
      originalNumber: data['original_number'],
      year: year,
      woodType: data['wood_type'] ?? '',
      woodName: data['wood_name'] ?? data['wood_type'] ?? '',
      quality: data['quality'] ?? '',
      qualityName: data['quality_name'] ?? data['quality'] ?? '',
      volume: (data['volume'] ?? 0.0).toDouble(),
      sprayColor: sprayColor,
      plaketteColor: data['plakette_color'],
      origin: data['origin'],
      isMoonwood: data['is_moonwood'] ?? false,
      isFSC: data['is_fsc'] ?? false,
      remarks: data['remarks'],
      timestamp: timestamp,
      cuttingDate: data['cutting_date'] != null
          ? (data['cutting_date'] as Timestamp).toDate()
          : null,
      purposes: purposes,
      otherPurpose: otherPurpose,
        isClosed: data['is_closed'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'internal_number': internalNumber,
      'original_number': originalNumber,
      'year': year,
      'wood_type': woodType,
      'wood_name': woodName,
      'quality': quality,
      'quality_name': qualityName,
      'volume': volume,
      'spray_color': sprayColor,
      'plakette_color': plaketteColor,
      'origin': origin,
      'is_moonwood': isMoonwood,
      'is_fsc': isFSC,
      'remarks': remarks,
      'timestamp': FieldValue.serverTimestamp(),
      'cutting_date': cuttingDate != null
          ? Timestamp.fromDate(cuttingDate!)
          : null,
      'purposes': purposes,
      'other_purpose': otherPurpose,
    };
  }

  // Hilfsmethode: Alle Verwendungszwecke als String
  String get purposesDisplay {
    final allPurposes = [...purposes];
    if (otherPurpose != null && otherPurpose!.isNotEmpty) {
      allPurposes.add(otherPurpose!);
    }
    return allPurposes.join(', ');
  }
}

class RoundwoodFilter {
  final List<String>? woodTypes;
  final List<String>? qualities;
  final List<String>? purposes; // VEREINFACHT
  final String? origin;
  final double? volumeMin;
  final double? volumeMax;
  final bool? isMoonwood;
  final bool? isFSC; // NEU
  final int? year; // NEU: Filter nach Jahrgang
  final DateTime? startDate;
  final DateTime? endDate;
  final String? timeRange;
  final bool? showClosed; // NEU: null = alle, false = nur offene, true = nur geschlossene

  RoundwoodFilter({
    this.woodTypes,
    this.qualities,
    this.purposes,
    this.origin,
    this.volumeMin,
    this.volumeMax,
    this.isMoonwood,
    this.isFSC,
    this.year,
    this.startDate,
    this.endDate,
    this.timeRange,
    this.showClosed,
  });

  Map<String, dynamic> toMap() {
    return {
      if (woodTypes != null && woodTypes!.isNotEmpty) 'wood_types': woodTypes,
      if (qualities != null && qualities!.isNotEmpty) 'qualities': qualities,
      if (purposes != null && purposes!.isNotEmpty) 'purposes': purposes,
      if (origin != null) 'origin': origin,
      if (volumeMin != null) 'volume_min': volumeMin,
      if (volumeMax != null) 'volume_max': volumeMax,
      if (isMoonwood != null) 'is_moonwood': isMoonwood,
      if (isFSC != null) 'is_fsc': isFSC,
      if (year != null) 'year': year,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (timeRange != null) 'time_range': timeRange,
      if (showClosed != null) 'show_closed': showClosed,
    };
  }

  RoundwoodFilter copyWith({
    List<String>? woodTypes,
    List<String>? qualities,
    List<String>? purposes,
    String? origin,
    double? volumeMin,
    double? volumeMax,
    bool? isMoonwood,
    bool? isFSC,
    int? year,
    DateTime? startDate,
    DateTime? endDate,
    String? timeRange,
    bool? showClosed,  // ← NEU
    bool clearWoodTypes = false,
    bool clearQualities = false,
    bool clearPurposes = false,
    bool clearOrigin = false,
    bool clearVolume = false,
    bool clearMoonwood = false,
    bool clearFSC = false,
    bool clearYear = false,
    bool clearDates = false,
  bool clearShowClosed = false,
  }) {
    return RoundwoodFilter(
      woodTypes: clearWoodTypes ? null : (woodTypes ?? this.woodTypes),
      qualities: clearQualities ? null : (qualities ?? this.qualities),
      purposes: clearPurposes ? null : (purposes ?? this.purposes),
      origin: clearOrigin ? null : (origin ?? this.origin),
      volumeMin: clearVolume ? null : (volumeMin ?? this.volumeMin),
      volumeMax: clearVolume ? null : (volumeMax ?? this.volumeMax),
      isMoonwood: clearMoonwood ? null : (isMoonwood ?? this.isMoonwood),
      isFSC: clearFSC ? null : (isFSC ?? this.isFSC),
      year: clearYear ? null : (year ?? this.year),
      startDate: clearDates ? null : (startDate ?? this.startDate),
      endDate: clearDates ? null : (endDate ?? this.endDate),
      timeRange: clearDates ? null : (timeRange ?? this.timeRange),
      showClosed: clearShowClosed ? null : (showClosed ?? this.showClosed),
    );
  }
}