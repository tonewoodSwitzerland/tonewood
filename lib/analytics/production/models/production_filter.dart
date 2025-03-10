class ProductionFilter {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? timeRange;
  final List<String>? woodTypes;
  final List<String>? parts;
  final List<String>? instruments;
  final List<String>? qualities;
  final bool? isMoonwood;
  final bool? isHaselfichte;
  final bool? isThermallyTreated;
  final bool? isFSC;  // FSC-100 Filter
  final List<String>? years; // Added years list for filtering by year

  const ProductionFilter({
    this.startDate,
    this.endDate,
    this.timeRange,
    this.woodTypes,
    this.parts,
    this.instruments,
    this.qualities,
    this.isMoonwood,
    this.isHaselfichte,
    this.isThermallyTreated,
    this.isFSC,
    this.years, // Added years parameter
  });

  ProductionFilter copyWith({
    DateTime? startDate,
    DateTime? endDate,
    String? timeRange,
    List<String>? woodTypes,
    List<String>? instruments,
    List<String>? parts,
    List<String>? qualities,
    List<String>? years, // Added years parameter to copyWith
    bool? isMoonwood,
    bool? isHaselfichte,
    bool? isThermallyTreated,
    bool? isFSC,
  }) {
    return ProductionFilter(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      timeRange: timeRange ?? this.timeRange,
      parts:  parts ?? this. parts,
      years: years ?? this.years, // Include years in copyWith
      woodTypes: woodTypes ?? this.woodTypes,
     instruments:  instruments ?? this. instruments,
      qualities: qualities ?? this.qualities,
      isMoonwood: isMoonwood ?? this.isMoonwood,
      isHaselfichte: isHaselfichte ?? this.isHaselfichte,
      isThermallyTreated: isThermallyTreated ?? this.isThermallyTreated,
      isFSC: isFSC ?? this.isFSC,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};

    if (startDate != null) map['startDate'] = startDate;
    if (endDate != null) map['endDate'] = endDate;
    if (timeRange != null) map['timeRange'] = timeRange;
    if (woodTypes?.isNotEmpty ?? false) map['woodTypes'] = woodTypes;
    if (instruments?.isNotEmpty ?? false) map['instruments'] = instruments;
    if (parts?.isNotEmpty ?? false) map['parts'] = parts;
    if (qualities?.isNotEmpty ?? false) map['qualities'] = qualities;
    if (years?.isNotEmpty ?? false) map['years'] = years; // Add years to map
    if (isMoonwood == true) map['isMoonwood'] = true;
    if (isHaselfichte == true) map['isHaselfichte'] = true;
    if (isThermallyTreated == true) map['isThermallyTreated'] = true;
    if (isFSC == true) map['isFSC'] = true;

    return map;
  }

  bool get isEmpty =>
      startDate == null &&
          endDate == null &&
          timeRange == null &&
          (woodTypes?.isEmpty ?? true) &&
          (instruments?.isEmpty ?? true) &&
          (parts?.isEmpty ?? true) &&
          (qualities?.isEmpty ?? true) &&
          (years?.isEmpty ?? true) && // Add years check to isEmpty
          isMoonwood != true &&
          isHaselfichte != true &&
          isThermallyTreated != true &&
          isFSC != true;
}