import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/icon_helper.dart';

/// Zeigt den Roundwood-Selection als Sheet (Mobile) oder Dialog (Desktop)
void showRoundwoodSelection({
  required BuildContext context,
  required String productId,
  required Map<String, dynamic> productData,
  required Function(int quantity, String? roundwoodId, Map<String, dynamic>? roundwoodData) onConfirm,
}) {
  final isMobile = MediaQuery.of(context).size.width < 600;

  if (isMobile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.95,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => _RoundwoodSelectionContent(
          productId: productId,
          productData: productData,
          onConfirm: onConfirm,
          scrollController: scrollController,
          isSheet: true,
        ),
      ),
    );
  } else {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 600,
          height: MediaQuery.of(context).size.height * 0.85,
          child: _RoundwoodSelectionContent(
            productId: productId,
            productData: productData,
            onConfirm: onConfirm,
            isSheet: false,
          ),
        ),
      ),
    );
  }
}

class _RoundwoodSelectionContent extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> productData;
  final Function(int, String?, Map<String, dynamic>?) onConfirm;
  final ScrollController? scrollController;
  final bool isSheet;

  const _RoundwoodSelectionContent({
    required this.productId,
    required this.productData,
    required this.onConfirm,
    this.scrollController,
    required this.isSheet,
  });

  @override
  State<_RoundwoodSelectionContent> createState() => _RoundwoodSelectionContentState();
}

class _RoundwoodSelectionContentState extends State<_RoundwoodSelectionContent> {
  final _quantityController = TextEditingController();
  final _searchController = TextEditingController();

  String? _selectedRoundwoodId;
  Map<String, dynamic>? _selectedRoundwoodData;
  List<Map<String, dynamic>> _roundwoodList = [];
  List<Map<String, dynamic>> _filteredList = [];
  bool _isLoading = true;
  bool _skipRoundwood = false;
  int? _selectedYear;
  List<int> _availableYears = [];

  @override
  void initState() {
    super.initState();
    _loadRoundwood();
  }

  Future<void> _loadRoundwood() async {
    setState(() => _isLoading = true);

    try {
      final woodCode = widget.productData['wood_code'] as String?;
      Query query = FirebaseFirestore.instance.collection('roundwood');

      if (woodCode != null && woodCode.isNotEmpty) {
        query = query.where('wood_type', isEqualTo: woodCode);
      }

      final snapshot = await query.orderBy('year', descending: true).get();

      final years = <int>{};
      final list = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final year = data['year'] as int?;
        if (year != null) years.add(year);

        return {
          'id': doc.id,
          'internal_number': data['internal_number'] ?? '',
          'year': year ?? DateTime.now().year,
          'original_number': data['original_number'] ?? '',
          'wood_name': data['wood_name'] ?? '',
          'wood_type': data['wood_type'] ?? '',
          'quality': data['quality'] ?? '',
          'is_moonwood': data['is_moonwood'] ?? false,
          'is_fsc': data['is_fsc'] ?? false,
          'volume': data['volume'],
          'origin': data['origin'] ?? '',
        };
      }).toList();

      setState(() {
        _roundwoodList = list;
        _filteredList = list;
        _availableYears = years.toList()..sort((a, b) => b.compareTo(a));
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Laden: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _filterList() {
    final search = _searchController.text.toLowerCase();
    setState(() {
      _filteredList = _roundwoodList.where((item) {
        if (_selectedYear != null && item['year'] != _selectedYear) return false;
        if (search.isNotEmpty) {
          final internalNumber = (item['internal_number'] as String).toLowerCase();
          final originalNumber = (item['original_number'] as String).toLowerCase();
          final origin = (item['origin'] as String).toLowerCase();
          return internalNumber.contains(search) || originalNumber.contains(search) || origin.contains(search);
        }
        return true;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: const Radius.circular(16),
          bottom: widget.isSheet ? Radius.zero : const Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: CustomScrollView(
              controller: widget.scrollController,
              slivers: [
                SliverToBoxAdapter(child: _buildProductInfo()),
                SliverToBoxAdapter(child: _buildFilters()),
                if (!_skipRoundwood)
                  _isLoading
                      ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
                      : _filteredList.isEmpty
                      ? SliverFillRemaining(child: _buildEmptyState())
                      : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildRoundwoodItem(_filteredList[index]),
                        childCount: _filteredList.length,
                      ),
                    ),
                  ),
                SliverToBoxAdapter(child: _buildQuantityInput()),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F4A29).withOpacity(0.05),
        borderRadius: BorderRadius.vertical(top: const Radius.circular(16)),
      ),
      child: Column(
        children: [
          if (widget.isSheet)
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F4A29).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: getAdaptiveIcon(iconName: 'forest', defaultIcon: Icons.forest, color: const Color(0xFF0F4A29)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Produktionseingang',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F4A29))),
                    Text('Stamm zuordnen & Menge eingeben', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                  ],
                ),
              ),
              IconButton(
                icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductInfo() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.productData['product_name'] ?? 'Unbekanntes Produkt',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text('${widget.productData['quality_name']} • ${widget.productData['wood_name']}',
                    style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 4),
                Text(widget.productId, style: TextStyle(fontSize: 12, color: Colors.grey[500], fontFamily: 'monospace')),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0F4A29).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('${widget.productData['price_CHF']} CHF',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F4A29))),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          CheckboxListTile(
            title: const Text('Ohne Stamm-Zuordnung buchen'),
            subtitle: const Text('Kann später nachgetragen werden'),
            value: _skipRoundwood,
            onChanged: (value) {
              setState(() {
                _skipRoundwood = value ?? false;
                if (_skipRoundwood) {
                  _selectedRoundwoodId = null;
                  _selectedRoundwoodData = null;
                }
              });
            },
            activeColor: const Color(0xFF0F4A29),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          if (!_skipRoundwood) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Stamm suchen...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    onChanged: (_) => _filterList(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    value: _selectedYear,
                    decoration: InputDecoration(
                      hintText: 'Jahr',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Alle')),
                      ..._availableYears.map((year) => DropdownMenuItem<int>(value: year, child: Text('$year'))),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedYear = value);
                      _filterList();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('Keine Stämme gefunden', style: TextStyle(color: Colors.grey[600])),
          if (widget.productData['wood_name'] != null)
            Text('für Holzart "${widget.productData['wood_name']}"',
                style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildRoundwoodItem(Map<String, dynamic> item) {
    final isSelected = _selectedRoundwoodId == item['id'];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isSelected ? const Color(0xFF0F4A29) : Colors.grey[200]!, width: isSelected ? 2 : 1),
      ),
      color: isSelected ? const Color(0xFF0F4A29).withOpacity(0.05) : null,
      child: InkWell(
        onTap: () => setState(() {
          _selectedRoundwoodId = item['id'];
          _selectedRoundwoodData = item;
        }),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Radio<String>(
                value: item['id'],
                groupValue: _selectedRoundwoodId,
                onChanged: (v) => setState(() {
                  _selectedRoundwoodId = v;
                  _selectedRoundwoodData = item;
                }),
                activeColor: const Color(0xFF0F4A29),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('${item['internal_number']}/${item['year']}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        if (item['original_number']?.isNotEmpty == true) ...[
                          const SizedBox(width: 8),
                          Text('(${item['original_number']})', style: TextStyle(color: Colors.grey[600])),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      children: [
                        Text(item['wood_name'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                        if (item['quality']?.isNotEmpty == true)
                          Text(' • Qual. ${item['quality']}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                        if (item['origin']?.isNotEmpty == true)
                          Text(' • ${item['origin']}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (item['is_moonwood'] == true) _buildTag('Mondholz', Colors.purple),
                  if (item['is_fsc'] == true) _buildTag('FSC', Colors.green),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildQuantityInput() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              getAdaptiveIcon(iconName: 'add_box', defaultIcon: Icons.add_box, color: const Color(0xFF0F4A29)),
              const SizedBox(width: 8),
              const Text('Menge', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _quantityController,
            decoration: InputDecoration(
              hintText: 'Menge eingeben',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: true,
              fillColor: Colors.white,
              suffixText: widget.productData['unit'] ?? 'Stk',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final canConfirm = _quantityController.text.isNotEmpty && (_skipRoundwood || _selectedRoundwoodId != null);
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, widget.isSheet ? MediaQuery.of(context).padding.bottom + 16 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Abbrechen'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: canConfirm ? _confirm : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F4A29),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  getAdaptiveIcon(iconName: 'save', defaultIcon: Icons.save, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Text('Buchen', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirm() {
    final quantity = int.tryParse(_quantityController.text) ?? 0;
    if (quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte gültige Menge eingeben'), backgroundColor: Colors.red),
      );
      return;
    }
    Navigator.pop(context);
    widget.onConfirm(quantity, _skipRoundwood ? null : _selectedRoundwoodId, _skipRoundwood ? null : _selectedRoundwoodData);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}