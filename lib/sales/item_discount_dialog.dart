import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/discount.dart';

class ItemDiscountDialog extends StatefulWidget {
  final String itemId;
  final double originalAmount;
  final Discount? currentDiscount;
  final String currency;
  final Map<String, double> exchangeRates;
  final String Function(double) formatPrice;

  const ItemDiscountDialog({
    Key? key,
    required this.itemId,
    required this.originalAmount,
    required this.currentDiscount,
    required this.currency,
    required this.exchangeRates,
    required this.formatPrice,
  }) : super(key: key);

  @override
  State<ItemDiscountDialog> createState() => _ItemDiscountDialogState();
}

class _ItemDiscountDialogState extends State<ItemDiscountDialog> {
  late TextEditingController percentageController;
  late TextEditingController absoluteController;
  late TextEditingController targetAmountController;

  bool _isUpdating = false;
  String _lastEdited = 'none';

  @override
  void initState() {
    super.initState();

    percentageController = TextEditingController(
        text: widget.currentDiscount?.percentage.toString() ?? '0.0'
    );
    absoluteController = TextEditingController(
        text: widget.currentDiscount?.absolute.toString() ?? '0.0'
    );
    targetAmountController = TextEditingController();

    // Initialisiere Zielbetrag
    if (widget.currentDiscount != null) {
      if (widget.currentDiscount!.percentage > 0) {
        _lastEdited = 'percentage';
        final discount = widget.originalAmount * (widget.currentDiscount!.percentage / 100);
        targetAmountController.text = (widget.originalAmount - discount).toStringAsFixed(2);
      } else if (widget.currentDiscount!.absolute > 0) {
        _lastEdited = 'absolute';
        final discount = widget.currentDiscount!.absolute;
        targetAmountController.text = (widget.originalAmount - discount).toStringAsFixed(2);
      } else {
        targetAmountController.text = widget.originalAmount.toStringAsFixed(2);
      }
    } else {
      targetAmountController.text = widget.originalAmount.toStringAsFixed(2);
    }

    percentageController.addListener(_onPercentageChanged);
    absoluteController.addListener(_onAbsoluteChanged);
    targetAmountController.addListener(_onTargetChanged);
  }

  void _onPercentageChanged() {
    if (_isUpdating) return;
    _isUpdating = true;
    _lastEdited = 'percentage';

    final percentage = double.tryParse(percentageController.text) ?? 0;
    final discount = widget.originalAmount * (percentage / 100);
    final newAmount = widget.originalAmount - discount;

    absoluteController.text = discount.toStringAsFixed(2);
    targetAmountController.text = newAmount.toStringAsFixed(2);

    _isUpdating = false;
  }

  void _onAbsoluteChanged() {
    if (_isUpdating) return;
    _isUpdating = true;
    _lastEdited = 'absolute';

    final absolute = double.tryParse(absoluteController.text) ?? 0;
    final percentage = widget.originalAmount > 0 ? (absolute / widget.originalAmount) * 100 : 0;
    final newAmount = widget.originalAmount - absolute;

    percentageController.text = percentage.toStringAsFixed(2);
    targetAmountController.text = newAmount.toStringAsFixed(2);

    _isUpdating = false;
  }

  void _onTargetChanged() {
    if (_isUpdating) return;
    _isUpdating = true;
    _lastEdited = 'target';

    final targetAmount = double.tryParse(targetAmountController.text) ?? widget.originalAmount;
    final discount = widget.originalAmount - targetAmount;
    final percentage = widget.originalAmount > 0 ? (discount / widget.originalAmount) * 100 : 0;

    absoluteController.text = discount.toStringAsFixed(2);
    percentageController.text = percentage.toStringAsFixed(2);

    _isUpdating = false;
  }

  @override
  void dispose() {
    percentageController.removeListener(_onPercentageChanged);
    absoluteController.removeListener(_onAbsoluteChanged);
    targetAmountController.removeListener(_onTargetChanged);
    percentageController.dispose();
    absoluteController.dispose();
    targetAmountController.dispose();
    super.dispose();
  }

  Future<void> _saveDiscount() async {
    double percentageValue = 0.0;
    double absoluteValue = 0.0;

    if (_lastEdited == 'percentage') {
      percentageValue = double.tryParse(percentageController.text) ?? 0;
      absoluteValue = 0.0;
    } else {
      absoluteValue = double.tryParse(absoluteController.text) ?? 0;
      if (widget.currency != 'CHF') {
        absoluteValue = absoluteValue / widget.exchangeRates[widget.currency]!;
      }
      percentageValue = 0.0;
    }

    // Firestore Update
    await FirebaseFirestore.instance
        .collection('temporary_basket')
        .doc(widget.itemId)
        .update({
      'discount': {
        'percentage': percentageValue,
        'absolute': absoluteValue,
      },
      'discount_timestamp': FieldValue.serverTimestamp(),
    });

    // Schließe Dialog und gib die neuen Werte zurück
    if (mounted) {
      Navigator.of(context).pop(Discount(
        percentage: percentageValue,
        absolute: absoluteValue,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rabatt'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Ursprungsbetrag:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    widget.formatPrice(widget.originalAmount),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: percentageController,
              decoration: const InputDecoration(
                labelText: 'Rabatt %',
                suffixText: '%',
                border: OutlineInputBorder(),
                helperText: 'Prozentuale Ermäßigung',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: absoluteController,
              decoration: InputDecoration(
                labelText: 'Rabatt ${widget.currency}',
                suffixText: widget.currency,
                border: const OutlineInputBorder(),
                helperText: 'Absoluter Rabattbetrag',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            TextFormField(
              controller: targetAmountController,
              decoration: InputDecoration(
                labelText: 'Neuer Betrag ${widget.currency}',
                suffixText: widget.currency,
                border: const OutlineInputBorder(),
                helperText: 'Gewünschter Endbetrag',
                filled: true,
                fillColor: Colors.green[50],
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: _saveDiscount,
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}