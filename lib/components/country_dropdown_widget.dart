import 'package:flutter/material.dart';
import '../services/countries.dart';
import '../services/icon_helper.dart';

class CountryDropdown extends StatefulWidget {
  final TextEditingController countryController;
  final TextEditingController countryCodeController;
  final bool isRequired;
  final String label;
  final FormFieldValidator<Country>? validator;
  final BorderRadius? borderRadius;

  const CountryDropdown({
    Key? key,
    required this.countryController,
    required this.countryCodeController,
    this.isRequired = true,
    this.label = 'Land',
    this.validator,
    this.borderRadius,
  }) : super(key: key);

  @override
  State<CountryDropdown> createState() => _CountryDropdownState();
}

class _CountryDropdownState extends State<CountryDropdown> {
  Country? _selectedCountry;

  @override
  void initState() {
    super.initState();

    // Initialisiere das ausgewählte Land basierend auf dem Controller
    _initSelectedCountry();
  }

  void _initSelectedCountry() {
    // Stelle sicher, dass ein passender Ländercode gesetzt ist
    if (widget.countryController.text.isNotEmpty) {
      _selectedCountry = Countries.getCountryByName(widget.countryController.text);
      if (_selectedCountry != null && widget.countryCodeController.text.isEmpty) {
        widget.countryCodeController.text = _selectedCountry!.code;
      }
    }

    // Umgekehrt: Wenn ein Code gesetzt ist, aber kein Land, dann das Land ermitteln
    else if (widget.countryCodeController.text.isNotEmpty) {
      _selectedCountry = Countries.getCountryByCode(widget.countryCodeController.text);
      if (_selectedCountry != null && _selectedCountry!.name != "Unbekannt") {
        widget.countryController.text = _selectedCountry!.name;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<Country>(
      decoration: InputDecoration(
        labelText: '${widget.label} ${widget.isRequired ? '*' : ''}',
        border: OutlineInputBorder(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(4),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Icon(
            Icons.flag,
            color: Colors.grey.shade600,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(4),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(4),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
      ),
      value: _selectedCountry,
      items: _buildDropdownItems(),
      onChanged: (Country? country) {
        if (country != null) {
          setState(() {
            _selectedCountry = country;
            widget.countryController.text = country.name;
            widget.countryCodeController.text = country.code;
          });
        }
      },
      validator: widget.validator ?? _defaultValidator,
      isExpanded: true,
      icon:  getAdaptiveIcon(iconName: 'arrow_drop_down',defaultIcon:Icons.arrow_drop_down),
      iconSize: 24,
      elevation: 16,
      style: const TextStyle(color: Colors.black),
      dropdownColor: Colors.white,
    );
  }

  String? _defaultValidator(Country? country) {
    if (widget.isRequired && (country == null)) {
      return 'Bitte ${widget.label} auswählen';
    }
    return null;
  }

  List<DropdownMenuItem<Country>> _buildDropdownItems() {
    final List<DropdownMenuItem<Country>> items = [];

    // Beliebte Länder am Anfang
    for (var country in Countries.popularCountries) {
      items.add(DropdownMenuItem<Country>(
        value: country,
        child: Text(country.name),
      ));
    }

    // Trennlinie
    if (Countries.popularCountries.isNotEmpty) {
      items.add(DropdownMenuItem<Country>(
        enabled: false,
        child: Divider(color: Colors.grey.shade300, height: 1),
      ));
    }

    // Alle anderen Länder
    for (var country in Countries.allCountries) {
      if (!Countries.popularCountries.contains(country)) {
        items.add(DropdownMenuItem<Country>(
          value: country,
          child: Text(country.name),
        ));
      }
    }

    return items;
  }
}