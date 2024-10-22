import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import für TextInputFormatter
import '../constants.dart';

class StandardTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final TextInputType keyboardType;
  final Function(String)? onChanged;
  final bool enabled;
  final int maxLines;
  const StandardTextField({
    required this.enabled,
    required this.maxLines,
    super.key,
    required this.controller,
    required this.labelText,
    this.keyboardType = TextInputType.text,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      maxLines: maxLines, // Setzt die Höhe des Textfelds auf 4 Zeilen

      enabled: enabled,
      style: smallTextField,
      controller: controller,
      keyboardType: keyboardType,
      onChanged: (value) {
        if (keyboardType == TextInputType.number && value.contains(',')) {
          final correctedValue = value.replaceAll(',', '.');
          controller.value = controller.value.copyWith(
            text: correctedValue,
            selection: TextSelection.collapsed(offset: correctedValue.length),
          );
          if (onChanged != null) {
            onChanged!(correctedValue);
          }
        } else {
          if (onChanged != null) {
            onChanged!(value);
          }
        }
      },
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: smallTextField,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: primaryAppColor, width: 2.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: primaryAppColor, width: 1.0),
        ),
      ),
      inputFormatters: keyboardType == TextInputType.number
          ? [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ]
          : [],
    );
  }
}

class StandardDropdown extends StatelessWidget {
  final String? value;
  final List<DropdownMenuItem<String>> items;
  final String labelText;
  final Function(String?) onChanged;

  const StandardDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.labelText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: smallTextField,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: primaryAppColor, width: 2.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: primaryAppColor, width: 1.0),
        ),
      ),
      value: value,
      items: items.map((item) {
        final displayText = item.value ?? ''; // Ensure it's non-null
        return DropdownMenuItem<String>(
          value: displayText,
          child: Text(
            displayText.length > 18 ? "${displayText.substring(0, 16)}.." : displayText,
            style: const TextStyle(color: Colors.black87),
          ),
        );
      }).toList(),
      onChanged: onChanged,
      dropdownColor: Colors.white,
      style: const TextStyle(color: Colors.black87),
      iconEnabledColor: Colors.black87,
    );


  }
}


class StandardButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final Icon? icon;

  const StandardButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon ?? const SizedBox.shrink(),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: primaryAppColor,
      ),
    );
  }
}
