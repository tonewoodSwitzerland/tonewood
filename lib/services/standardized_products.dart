// Model für standardisierte Produkte
class StandardizedProduct {
  final String id; // Firebase Document ID
  final String articleNumber; // 4-stellige Artikelnummer
  final String productName;
  final String instrument;
  final int parts;
  final ProductDimensions dimensions;
  final int thicknessClass;
  final MeasurementText measurementText;
  final VolumeData volume;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  StandardizedProduct({
    required this.id,
    required this.articleNumber,
    required this.productName,
    required this.instrument,
    required this.parts,
    required this.dimensions,
    required this.thicknessClass,
    required this.measurementText,
    required this.volume,
    this.createdAt,
    this.updatedAt,
  });

  factory StandardizedProduct.fromMap(Map<String, dynamic> map, String id) {
    return StandardizedProduct(
      id: id,
      articleNumber: map['articleNumber'] ?? '',
      productName: map['productName'] ?? '',
      instrument: map['instrument'] ?? '',
      parts: map['parts'] ?? 0,
      dimensions: ProductDimensions.fromMap(map['dimensions'] ?? {}),
      thicknessClass: map['thicknessClass'] ?? 0,
      measurementText: MeasurementText.fromMap(map['measurementText'] ?? {}),
      volume: VolumeData.fromMap(map['volume'] ?? {}),
      createdAt: map['createdAt']?.toDate(),
      updatedAt: map['updatedAt']?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'articleNumber': articleNumber,
      'productName': productName,
      'instrument': instrument,
      'parts': parts,
      'dimensions': dimensions.toMap(),
      'thicknessClass': thicknessClass,
      'measurementText': measurementText.toMap(),
      'volume': volume.toMap(),
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // Kopie mit Änderungen
  StandardizedProduct copyWith({
    String? id,
    String? articleNumber,
    String? productName,
    String? instrument,
    int? parts,
    ProductDimensions? dimensions,
    int? thicknessClass,
    MeasurementText? measurementText,
    VolumeData? volume,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StandardizedProduct(
      id: id ?? this.id,
      articleNumber: articleNumber ?? this.articleNumber,
      productName: productName ?? this.productName,
      instrument: instrument ?? this.instrument,
      parts: parts ?? this.parts,
      dimensions: dimensions ?? this.dimensions,
      thicknessClass: thicknessClass ?? this.thicknessClass,
      measurementText: measurementText ?? this.measurementText,
      volume: volume ?? this.volume,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Für CSV Export
  String toCsvRow() {
    return '$articleNumber,$productName,$instrument,$parts,'
        '${dimensions.length.standard},${dimensions.length.addition},${dimensions.length.withAddition},'
        '${dimensions.width.standard},${dimensions.width.addition},${dimensions.width.withAddition},'
        '${dimensions.thickness.value},${dimensions.thickness.value2 ?? ""},'
        '$thicknessClass,'
        '"${measurementText.standard}","${measurementText.withAddition}",'
        '${volume.mm3Standard},${volume.mm3WithAddition},'
        '${volume.dm3Standard},${volume.dm3WithAddition}';
  }

  // CSV Header
  static String getCsvHeader() {
    return 'Artikelnummer,Produkt,Instrument,Teile,'
        'x\',x+,x\'\',' // Länge
        'y\',y+,y\'\',' // Breite
        'z(1)/o,(z2),' // Dicke
        'DKl,'
        'Masse\',Masse\'\',' // Maßtext
        'mm3\',mm3\'\',' // Volumen mm³
        'dm3\',dm3\'\''; // Volumen dm³
  }
}

class ProductDimensions {
  final DimensionData length; // x
  final DimensionData width; // y
  final ThicknessData thickness; // z

  ProductDimensions({
    required this.length,
    required this.width,
    required this.thickness,
  });

  factory ProductDimensions.fromMap(Map<String, dynamic> map) {
    return ProductDimensions(
      length: DimensionData.fromMap(map['length'] ?? {}),
      width: DimensionData.fromMap(map['width'] ?? {}),
      thickness: ThicknessData.fromMap(map['thickness'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'length': length.toMap(),
      'width': width.toMap(),
      'thickness': thickness.toMap(),
    };
  }
}

class DimensionData {
  final double standard; // Basismaß
  final double addition; // Zumaß
  final double withAddition; // Maß mit Zumaß

  DimensionData({
    required this.standard,
    required this.addition,
    required this.withAddition,
  });

  factory DimensionData.fromMap(Map<String, dynamic> map) {
    return DimensionData(
      standard: (map['standard'] ?? 0).toDouble(),
      addition: (map['addition'] ?? 0).toDouble(),
      withAddition: (map['withAddition'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'standard': standard,
      'addition': addition,
      'withAddition': withAddition,
    };
  }
}

class ThicknessData {
  final double value; // Hauptdicke oder Durchmesser bei runden Teilen
  final double? value2; // Zweite Dicke bei Trapezform

  ThicknessData({
    required this.value,
    this.value2,
  });

  factory ThicknessData.fromMap(Map<String, dynamic> map) {
    return ThicknessData(
      value: (map['value'] ?? 0).toDouble(),
      value2: map['value2'] != null ? (map['value2']).toDouble() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'value': value,
      if (value2 != null) 'value2': value2,
    };
  }
}

class MeasurementText {
  final String standard; // Maßtext Standard
  final String withAddition; // Maßtext mit Zumaß

  MeasurementText({
    required this.standard,
    required this.withAddition,
  });

  factory MeasurementText.fromMap(Map<String, dynamic> map) {
    return MeasurementText(
      standard: map['standard'] ?? '',
      withAddition: map['withAddition'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'standard': standard,
      'withAddition': withAddition,
    };
  }
}

class VolumeData {
  final double mm3Standard;
  final double mm3WithAddition;
  final double dm3Standard;
  final double dm3WithAddition;

  VolumeData({
    required this.mm3Standard,
    required this.mm3WithAddition,
    required this.dm3Standard,
    required this.dm3WithAddition,
  });

  factory VolumeData.fromMap(Map<String, dynamic> map) {
    return VolumeData(
      mm3Standard: (map['mm3_standard'] ?? 0).toDouble(),
      mm3WithAddition: (map['mm3_withAddition'] ?? 0).toDouble(),
      dm3Standard: (map['dm3_standard'] ?? 0).toDouble(),
      dm3WithAddition: (map['dm3_withAddition'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mm3_standard': mm3Standard,
      'mm3_withAddition': mm3WithAddition,
      'dm3_standard': dm3Standard,
      'dm3_withAddition': dm3WithAddition,
    };
  }
}