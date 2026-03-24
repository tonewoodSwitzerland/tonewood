class SalesFilter {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? timeRange;
  final double? minAmount;
  final double? maxAmount;
  final List<String>? selectedFairs;
  final List<String>? selectedProducts;
  final List<String>? woodTypes;
  final List<String>? parts;
  final List<String>? qualities;
  final List<String>? selectedCustomers;
  final List<String>? instruments;
  final List<String>? costCenters;
  final List<String>? distributionChannels;
  final List<String>? countries;

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
    this.instruments,
    this.costCenters,
    this.distributionChannels,
    this.countries,
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
    if (instruments?.isNotEmpty ?? false) map['instruments'] = instruments;
    if (costCenters?.isNotEmpty ?? false) map['costCenters'] = costCenters;
    if (distributionChannels?.isNotEmpty ?? false) map['distributionChannels'] = distributionChannels;
    if (countries?.isNotEmpty ?? false) map['countries'] = countries;
    return map;
  }

  // Sentinel-Objekt: wird als Parameter übergeben, um explizit null zu setzen
  static const _unset = Object();

  SalesFilter copyWith({
    Object? startDate = _unset,
    Object? endDate = _unset,
    Object? timeRange = _unset,
    Object? minAmount = _unset,
    Object? maxAmount = _unset,
    Object? selectedFairs = _unset,
    Object? selectedProducts = _unset,
    Object? woodTypes = _unset,
    Object? parts = _unset,
    Object? qualities = _unset,
    Object? selectedCustomers = _unset,
    Object? instruments = _unset,
    Object? costCenters = _unset,
    Object? distributionChannels = _unset,
    Object? countries = _unset,
  }) {
    return SalesFilter(
      startDate:            identical(startDate, _unset)            ? this.startDate            : startDate as DateTime?,
      endDate:              identical(endDate, _unset)              ? this.endDate              : endDate as DateTime?,
      timeRange:            identical(timeRange, _unset)            ? this.timeRange            : timeRange as String?,
      minAmount:            identical(minAmount, _unset)            ? this.minAmount            : minAmount as double?,
      maxAmount:            identical(maxAmount, _unset)            ? this.maxAmount            : maxAmount as double?,
      selectedFairs:        identical(selectedFairs, _unset)        ? this.selectedFairs        : selectedFairs as List<String>?,
      selectedProducts:     identical(selectedProducts, _unset)     ? this.selectedProducts     : selectedProducts as List<String>?,
      woodTypes:            identical(woodTypes, _unset)            ? this.woodTypes            : woodTypes as List<String>?,
      parts:                identical(parts, _unset)                ? this.parts                : parts as List<String>?,
      qualities:            identical(qualities, _unset)            ? this.qualities            : qualities as List<String>?,
      selectedCustomers:    identical(selectedCustomers, _unset)    ? this.selectedCustomers    : selectedCustomers as List<String>?,
      instruments:          identical(instruments, _unset)          ? this.instruments          : instruments as List<String>?,
      costCenters:          identical(costCenters, _unset)          ? this.costCenters          : costCenters as List<String>?,
      distributionChannels: identical(distributionChannels, _unset) ? this.distributionChannels : distributionChannels as List<String>?,
      countries:            identical(countries, _unset)            ? this.countries            : countries as List<String>?,
    );
  }
}