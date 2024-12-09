class SalesFilter {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? timeRange;
  final double? minAmount;
  final double? maxAmount;
  final List<String>? selectedFairs;  // Plural und optional

  final List<String>? selectedProducts;
  final List<String>? woodTypes;    // Neu
  final List<String>? parts;        // Neu
  final List<String>? qualities;    // Neu
  final List<String>? selectedCustomers; // Neu hinzugefügt
  SalesFilter({
    this.startDate,
    this.endDate,
    this.timeRange,
    this.minAmount,
    this.maxAmount,
    this.selectedFairs,

    this.selectedProducts,
    this.woodTypes,
    this.parts,
    this.qualities,
    this.selectedCustomers,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};

    if (startDate != null) map['startDate'] = startDate;
    if (endDate != null) map['endDate'] = endDate;
    if (timeRange != null) map['timeRange'] = timeRange;
    if (minAmount != null) map['minAmount'] = minAmount;
    if (maxAmount != null) map['maxAmount'] = maxAmount;
    if (selectedFairs != null) map['selectedFair'] = selectedFairs;
    if (selectedProducts != null) map['selectedProduct'] = selectedProducts;
    if (woodTypes?.isNotEmpty ?? false) map['woodTypes'] = woodTypes;
    if (parts?.isNotEmpty ?? false) map['parts'] = parts;
    if (qualities?.isNotEmpty ?? false) map['qualities'] = qualities;
    if (selectedCustomers != null) map['selectedCustomer'] = selectedCustomers;
    return map;
  }

  SalesFilter copyWith({
    DateTime? startDate,
    DateTime? endDate,
    String? timeRange,
    double? minAmount,
    double? maxAmount,
    List<String>? selectedFairs,
    List<String>? selectedProducts,
    List<String>? woodTypes,
    List<String>? parts,
    List<String>? qualities,
    List<String>? selectedCustomers,
  }) {
    return SalesFilter(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      timeRange: timeRange ?? this.timeRange,
      minAmount: minAmount ?? this.minAmount,
      maxAmount: maxAmount ?? this.maxAmount,
      selectedFairs: selectedFairs ?? this.selectedFairs,
      selectedProducts: selectedProducts ?? this.selectedProducts,
      woodTypes: woodTypes ?? this.woodTypes,
      parts: parts ?? this.parts,
      qualities: qualities ?? this.qualities,
      selectedCustomers: selectedCustomers ?? this.selectedCustomers,
    );

  }
}