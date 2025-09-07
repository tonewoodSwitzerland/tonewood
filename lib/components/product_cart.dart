import 'package:flutter/material.dart';

import '../services/icon_helper.dart';

class ProductCard extends StatelessWidget {
  final String barcode;
  final Map<String, dynamic>? productData;

  const ProductCard({
    Key? key,
    required this.barcode,
    required this.productData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (productData == null) {
      return Center(
        child: Column(
          children: [
            getAdaptiveIcon(iconName: 'error', defaultIcon:
              Icons.error,
              size: 64,
              color: Colors.orange,
            ),
            SizedBox(height: 16),
            Text(
              'Produktinformationen nicht gefunden.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                getAdaptiveIcon(iconName: 'qr_code',defaultIcon:Icons.qr_code),
                const SizedBox(width: 8),
                Text(
                  'Barcode: $barcode',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            _buildInfoRow('Produkt', productData!['product']),
            _buildInfoRow('Instrument', productData!['instrument']),
            _buildInfoRow('Bauteil', productData!['part']),
            _buildInfoRow('Holzart', productData!['wood_type']),
            _buildInfoRow('Größe', productData!['size']),
            _buildInfoRow('Qualität', productData!['quality']),
            _buildInfoRow('Bestand', productData!['quantity']?.toString() ?? '0'),
            _buildInfoRow('Preis CHF', '${productData!['price_CHF']} CHF'),
            const Divider(),
            _buildBooleanRow('Thermobehandelt', productData!['thermally_treated'] ?? false),
            _buildBooleanRow('Haselfichte', productData!['haselfichte'] ?? false),
            _buildBooleanRow('Mondholz', productData!['moonwood'] ?? false),
            _buildBooleanRow('FSC 100%', productData!['FSC_100'] ?? false),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value ?? 'N/A'),
          ),
        ],
      ),
    );
  }

  Widget _buildBooleanRow(String label, bool value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          value? getAdaptiveIcon(iconName: 'check_circle', defaultIcon:Icons.check_circle,color: Colors.green):
          getAdaptiveIcon(iconName: 'cancel', defaultIcon:Icons.cancel,color: Colors.red),

          const SizedBox(width: 8),
          Text(value ? 'Ja' : 'Nein'),
        ],
      ),
    );
  }
}
