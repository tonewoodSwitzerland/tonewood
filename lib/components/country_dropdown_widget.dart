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
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initSelectedCountry();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _initSelectedCountry() {
    if (widget.countryController.text.isNotEmpty) {
      _selectedCountry = Countries.getCountryByName(widget.countryController.text);
      if (_selectedCountry != null && widget.countryCodeController.text.isEmpty) {
        widget.countryCodeController.text = _selectedCountry!.code;
      }
    } else if (widget.countryCodeController.text.isNotEmpty) {
      _selectedCountry = Countries.getCountryByCode(widget.countryCodeController.text);
      if (_selectedCountry != null && _selectedCountry!.name != "Unbekannt") {
        widget.countryController.text = _selectedCountry!.name;
      }
    }
  }

  List<Country> _getFilteredCountries(String query) {
    if (query.isEmpty) {
      // Zeige beliebte Länder zuerst, dann alle anderen
      return [
        ...Countries.popularCountries,
        ...Countries.allCountries.where((c) => !Countries.popularCountries.contains(c)),
      ];
    }

    final queryLower = query.toLowerCase();
    final List<Country> filtered = Countries.allCountries.where((country) {
      return country.name.toLowerCase().contains(queryLower) ||
          country.code.toLowerCase().contains(queryLower);
    }).toList();

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Country>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        return _getFilteredCountries(textEditingValue.text);
      },
      displayStringForOption: (Country country) => country.name,
      onSelected: (Country country) {
        setState(() {
          _selectedCountry = country;
          widget.countryController.text = country.name;
          widget.countryCodeController.text = country.code;
        });
      },
      initialValue: _selectedCountry != null
          ? TextEditingValue(text: _selectedCountry!.name)
          : null,
      fieldViewBuilder: (
          BuildContext context,
          TextEditingController textEditingController,
          FocusNode focusNode,
          VoidCallback onFieldSubmitted,
          ) {
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: '${widget.label} ${widget.isRequired ? '*' : ''}',
            hintText: 'Suche nach Land oder Code (z.B. "CH", "Schweiz")',
            border: OutlineInputBorder(
              borderRadius: widget.borderRadius ?? BorderRadius.circular(4),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            prefixIcon: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: getAdaptiveIcon(
                iconName: 'flag',
                defaultIcon: Icons.flag,
                color: Colors.grey.shade600,
              ),
            ),
            suffixIcon: textEditingController.text.isNotEmpty
                ? IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                textEditingController.clear();
                setState(() {
                  _selectedCountry = null;
                  widget.countryController.clear();
                  widget.countryCodeController.clear();
                });
              },
            )
                : getAdaptiveIcon(
              iconName: 'search',
              defaultIcon: Icons.search,
              color: Colors.grey.shade600,
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
          validator: (value) {
            if (widget.isRequired && (value == null || value.isEmpty)) {
              return 'Bitte ${widget.label} auswählen';
            }
            if (widget.validator != null) {
              return widget.validator!(_selectedCountry);
            }
            return null;
          },
        );
      },
      optionsViewBuilder: (
          BuildContext context,
          AutocompleteOnSelected<Country> onSelected,
          Iterable<Country> options,
          ) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 300),
              width: MediaQuery.of(context).size.width - 32,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final Country country = options.elementAt(index);
                  final bool isPopular = Countries.popularCountries.contains(country);

                  return ListTile(
                    leading: Text(
                      country.code,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    title: Text(country.name),
                    trailing: isPopular
                        ? Icon(Icons.star, color: Colors.amber.shade700, size: 16)
                        : null,
                    onTap: () {
                      onSelected(country);
                    },
                    dense: true,
                    hoverColor: Colors.grey.shade100,
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}