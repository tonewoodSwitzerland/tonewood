import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/country_dropdown_widget.dart';
import 'customer.dart';
import 'customer_cache_service.dart';
import 'customer_export_service.dart';
import '../services/icon_helper.dart';

import 'package:intl/intl.dart';

import 'customer_filter_dialog.dart';
import 'customer_filter_favorite_sheet.dart';
import 'customer_filter_service.dart';
import 'customer_group/customer_group_selection_widget.dart';
import 'customer_label_print_screen.dart';
import 'customer_management_screen.dart';


/// Zentrale Klasse für alle Kundenfunktionen
class CustomerSelectionSheet {
  /// Zeigt die Kundenauswahl als ModalBottomSheet an
  static Future<Customer?> show(BuildContext context, {Customer? currentCustomer}) async {
    final Customer? selectedCustomer = await showModalBottomSheet<Customer?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _CustomerSelectionBottomSheet(initialCustomer: currentCustomer);  // NEU
      },
    );

    return selectedCustomer;
  }

  /// Zeigt den Kundenverwaltungsbildschirm an
  static void showCustomerManagementScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CustomerManagementScreen(),
      ),
    );
  }


  /// Zeigt einen Dialog zum Bearbeiten eines Kunden an
  static Future<bool> showEditCustomerDialog(BuildContext context, Customer customer) async {
    final customerDoc = await FirebaseFirestore.instance
        .collection('customers')
        .doc(customer.id)
        .get();

    if (!customerDoc.exists) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kunde nicht gefunden'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }

    // Erstelle Customer-Objekt mit aktuellen Daten
    final currentCustomer = Customer.fromMap(customerDoc.data()!, customerDoc.id);
    bool wasUpdated = false; // ← NEU!
    bool _isFavorite = currentCustomer.isFavorite;

    print( currentCustomer.houseNumber);

    final formKey = GlobalKey<FormState>();
    final companyController = TextEditingController(text: currentCustomer.company);
    final firstNameController = TextEditingController(text: currentCustomer.firstName);
    final lastNameController = TextEditingController(text: currentCustomer.lastName);
    final streetController = TextEditingController(text: currentCustomer.street);
    final houseNumberController = TextEditingController(text: currentCustomer.houseNumber);
    final zipCodeController = TextEditingController(text: currentCustomer.zipCode);
    final cityController = TextEditingController(text: currentCustomer.city);
    final provinceController = TextEditingController(text: currentCustomer.province); // NEU

    final countryController = TextEditingController(text: currentCustomer.country);
    final countryCodeController = TextEditingController(text: currentCustomer.countryCode);
    final emailController = TextEditingController(text: currentCustomer.email);
    final phone1Controller = TextEditingController(text: currentCustomer.phone1);
    final phone2Controller = TextEditingController(text: currentCustomer.phone2);
    final vatNumberController = TextEditingController(text: currentCustomer.vatNumber);
    final eoriNumberController = TextEditingController(text: currentCustomer.eoriNumber);
    final languageController = TextEditingController(text: currentCustomer.language);
    final christmasLetterController = TextEditingController(text: currentCustomer.wantsChristmasCard ? 'JA' : 'NEIN');
    final notesController = TextEditingController(text: currentCustomer.notes);
    final addressSupplementController = TextEditingController(text: currentCustomer.addressSupplement ?? '');
    final districtPOBoxController = TextEditingController(text: currentCustomer.districtPOBox ?? '');

    // Lieferadresse
    final shippingCompanyController = TextEditingController(text: currentCustomer.shippingCompany);
    final shippingFirstNameController = TextEditingController(text: currentCustomer.shippingFirstName);
    final shippingLastNameController = TextEditingController(text: currentCustomer.shippingLastName);
    final shippingStreetController = TextEditingController(text: currentCustomer.shippingStreet);
    final shippingHouseNumberController = TextEditingController(text: currentCustomer.shippingHouseNumber);
    final shippingZipCodeController = TextEditingController(text: currentCustomer.shippingZipCode);
    final shippingProvinceController = TextEditingController(text: currentCustomer.shippingProvince); // NEU

    final shippingCityController = TextEditingController(text: currentCustomer.shippingCity);
    final shippingCountryController = TextEditingController(text: currentCustomer.shippingCountry);
    final shippingCountryCodeController = TextEditingController(text: currentCustomer.shippingCountryCode);
    final shippingEmailController = TextEditingController(text: currentCustomer.shippingEmail);
    final shippingPhoneController = TextEditingController(text: currentCustomer.shippingPhone);

    List<String> _selectedGroupIds = List<String>.from(currentCustomer.customerGroupIds);


    // NEU: Zusätzliche Adresszeilen initialisieren
    final List<TextEditingController> additionalAddressLines =
    currentCustomer.additionalAddressLines
        .map((line) => TextEditingController(text: line))
        .toList();

    final List<TextEditingController> shippingAdditionalAddressLines =
    currentCustomer.shippingAdditionalAddressLines
        .map((line) => TextEditingController(text: line))
        .toList();

    bool _useShippingAddress = currentCustomer.hasDifferentShippingAddress;
    bool showVatOnDocuments = currentCustomer.showVatOnDocuments ?? false;
    bool showEoriOnDocuments = currentCustomer.showEoriOnDocuments ?? false;
    bool showCustomFieldOnDocuments = currentCustomer.showCustomFieldOnDocuments ?? false;
    bool _showFirstName = currentCustomer.firstName.isNotEmpty;
    bool _showHouseNumber = currentCustomer.houseNumber.isNotEmpty; // NEU

    bool _showShippingFirstName = (currentCustomer.shippingFirstName ?? '').isNotEmpty;
    bool _showGroupError = false;

    final customFieldTitleController = TextEditingController(text: currentCustomer.customFieldTitle);
    final customFieldValueController = TextEditingController(text: currentCustomer.customFieldValue);

    Widget buildAddressLinesSection(
        BuildContext context, // NEU: Context als Parameter

        List<TextEditingController> controllers,
        StateSetter setState,
        String labelPrefix,
        ) {
      return Column(
        children: [
          ...controllers.asMap().entries.map((entry) {
            final index = entry.key;
            final controller = entry.value;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: '$labelPrefix ${index + 1}',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        prefixIcon: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: getAdaptiveIcon(
                            iconName: 'notes',
                            defaultIcon: Icons.notes,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Theme.of(context).primaryColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        controller.dispose();
                        controllers.removeAt(index);
                      });
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: getAdaptiveIcon(
                        iconName: 'delete',
                        defaultIcon: Icons.delete,
                        color: Colors.red.shade700,
                        size: 20,
                      ),
                    ),
                    tooltip: 'Zeile entfernen',
                  ),
                ],
              ),
            );
          }).toList(),

          // Button zum Hinzufügen weiterer Zeilen
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                controllers.add(TextEditingController());
              });
            },
            icon: getAdaptiveIcon(
              iconName: 'add',
              defaultIcon: Icons.add,
              size: 20,
              color: Theme.of(context).primaryColor,
            ),
            label: const Text('Weitere Zeile hinzufügen'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              side: BorderSide(
                color: Theme.of(context).primaryColor.withOpacity(0.5),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      );
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      spreadRadius: 0.5,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Drag-Indikator
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 8),
                      child: Container(
                        width: 50,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    // Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                      child: Row(
                        children: [
                          // Icon vor dem Titel
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: getAdaptiveIcon(
                              iconName: 'edit_note',
                              defaultIcon: Icons.edit_note,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Kunde bearbeiten',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),

                          const Spacer(),
                          // NEU: Favoriten-Toggle
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _isFavorite = !_isFavorite;
                              });
                            },
                            icon: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: _isFavorite
                                    ? Colors.amber.shade100
                                    : Colors.grey.shade200,
                                shape: BoxShape.circle,
                              ),
                              child: getAdaptiveIcon(
                                iconName: _isFavorite ? 'star' : 'star_border',
                                defaultIcon: _isFavorite ? Icons.star : Icons.star_border,
                                size: 24,
                                color: _isFavorite ? Colors.amber.shade700 : Colors.grey,
                              ),
                            ),
                            tooltip: _isFavorite ? 'Als Favorit entfernen' : 'Als Favorit markieren',
                          ),

                          // Schließen-Button
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                shape: BoxShape.circle,
                              ),
                              child: getAdaptiveIcon(
                                iconName: 'close',
                                defaultIcon: Icons.close,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Hauptinhalt
                    Expanded(
                      child: Form(
                        key: formKey,
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 5, 20, 20),
                          children: [
                            // Unternehmensdaten
                            buildSectionCard(
                              context,
                              title: 'Unternehmensdaten',
                              icon: 'business',
                              defaultIcon: Icons.business,
                              iconColor: Colors.blue,
                              child: Column(
                                children: [
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: companyController,
                                    decoration: InputDecoration(
                                      labelText: 'Firma',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      prefixIcon: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        child: getAdaptiveIcon(
                                          iconName: 'domain',
                                          defaultIcon: Icons.domain,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Info-Box
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        getAdaptiveIcon(
                                          iconName: 'info',
                                          defaultIcon: Icons.info,
                                          size: 16,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Aktiviere die Checkboxen, um die jeweiligen Felder im Dokumentenkopf anzuzeigen',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // MwSt-Nummer mit Checkbox
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: vatNumberController,
                                          decoration: InputDecoration(
                                            labelText: 'MwSt-Nummer / UID',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            filled: true,
                                            fillColor: Colors.grey.shade50,
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(color: Colors.grey.shade300),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        children: [
                                          Checkbox(
                                            value: showVatOnDocuments,
                                            onChanged: (value) {
                                              setState(() {
                                                showVatOnDocuments = value ?? false;
                                              });
                                            },
                                          ),
                                          Text(
                                            'Anzeigen',
                                            style: TextStyle(fontSize: 10),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 16),

                                  // EORI-Nummer mit Checkbox
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: eoriNumberController,
                                          decoration: InputDecoration(
                                            labelText: 'EORI-Nummer',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            filled: true,
                                            fillColor: Colors.grey.shade50,
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(color: Colors.grey.shade300),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        children: [
                                          Checkbox(
                                            value: showEoriOnDocuments,
                                            onChanged: (value) {
                                              setState(() {
                                                showEoriOnDocuments = value ?? false;
                                              });
                                            },
                                          ),
                                          Text(
                                            'Anzeigen',
                                            style: TextStyle(fontSize: 10),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 24),

                                  // Zusatzfeld mit Checkbox
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            getAdaptiveIcon(
                                              iconName: 'add_box',
                                              defaultIcon: Icons.add_box,
                                              size: 18,
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Zusätzliches Feld (z.B. CPF/CNPJ)',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Theme.of(context).colorScheme.primary,
                                                ),
                                              ),
                                            ),
                                            Checkbox(
                                              value: showCustomFieldOnDocuments,
                                              onChanged: (value) {
                                                setState(() {
                                                  showCustomFieldOnDocuments = value ?? false;
                                                });
                                              },
                                            ),
                                            Text(
                                              'Anzeigen',
                                              style: TextStyle(fontSize: 10),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        TextFormField(
                                          controller: customFieldTitleController,
                                          decoration: InputDecoration(
                                            labelText: 'Feldbezeichnung',
                                            hintText: 'z.B. Sendungsnummer, CPF/CNPJ, Tracking-ID',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            isDense: true,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller: customFieldValueController,
                                          decoration: InputDecoration(
                                            labelText: 'Wert',
                                            hintText: 'z.B. 94838101, ABC-123456',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            isDense: true,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Kontaktperson
                            // Kontaktperson
                            buildSectionCard(
                              context,
                              title: 'Kontaktperson',
                              icon: 'contacts',
                              defaultIcon: Icons.contacts,
                              iconColor: Colors.green,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 16),
                                  // Name (ehemals Nachname)
                                  TextFormField(
                                    controller: lastNameController,
                                    decoration: InputDecoration(
                                      labelText: 'Name',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      prefixIcon: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        child: getAdaptiveIcon(
                                          iconName: 'person',
                                          defaultIcon: Icons.person,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // Vorname optional
                                  if (_showFirstName) ...[
                                    TextFormField(
                                      controller: firstNameController,
                                      decoration: InputDecoration(
                                        labelText: 'Vorname',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                                        ),
                                        suffixIcon: IconButton(
                                          icon: getAdaptiveIcon(
                                            iconName: 'close',
                                            defaultIcon: Icons.close,
                                            size: 18,
                                            color: Colors.grey,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _showFirstName = false;
                                              firstNameController.clear();
                                            });
                                          },
                                          tooltip: 'Vorname entfernen',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ] else ...[
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            _showFirstName = true;
                                          });
                                        },
                                        icon: getAdaptiveIcon(
                                          iconName: 'add',
                                          defaultIcon: Icons.add,
                                          size: 16,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                        label: const Text('Vorname hinzufügen (optional)'),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  // E-Mail
                                  TextFormField(
                                    controller: emailController,
                                    decoration: InputDecoration(
                                      labelText: 'E-Mail *',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      prefixIcon: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        child: getAdaptiveIcon(
                                          iconName: 'email',
                                          defaultIcon: Icons.email,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value?.isEmpty == true) {
                                        return 'Bitte E-Mail eingeben';
                                      }
                                      if (!value!.contains('@')) {
                                        return 'Bitte gültige E-Mail eingeben';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  // Telefon 1
                                  TextFormField(
                                    controller: phone1Controller,
                                    decoration: InputDecoration(
                                      labelText: 'Telefon 1 *',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      prefixIcon: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        child: getAdaptiveIcon(
                                          iconName: 'phone',
                                          defaultIcon: Icons.phone,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                                      ),
                                    ),
                                    validator: (value) => value?.isEmpty == true ? 'Bitte Telefonnummer eingeben' : null,
                                  ),
                                  const SizedBox(height: 16),
                                  // Telefon 2
                                  TextFormField(
                                    controller: phone2Controller,
                                    decoration: InputDecoration(
                                      labelText: 'Telefon 2',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      prefixIcon: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        child: getAdaptiveIcon(
                                          iconName: 'phone',
                                          defaultIcon: Icons.phone,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Rechnungsadresse
                            buildSectionCard(
                              context,
                              title: 'Rechnungsadresse',
                              icon: 'location_on',
                              defaultIcon: Icons.location_on,
                              iconColor: Colors.red,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 16),
                                  // Straße und Nr.
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: TextFormField(
                                          controller: streetController,
                                          decoration: InputDecoration(
                                            labelText: 'Straße *',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            filled: true,
                                            fillColor: Colors.grey.shade50,
                                            prefixIcon: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 12),
                                              child: getAdaptiveIcon(
                                                iconName: 'add_road',
                                                defaultIcon: Icons.add_road,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(color: Colors.grey.shade300),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                                            ),
                                          ),
                                          validator: (value) => value?.isEmpty == true ? 'Bitte Straße eingeben' : null,
                                        ),
                                      ),

                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Hausnummer optional
                                  if (_showHouseNumber) ...[
                                    TextFormField(
                                      controller: houseNumberController,
                                      decoration: InputDecoration(
                                        labelText: 'Hausnummer',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                        prefixIcon: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          child: getAdaptiveIcon(
                                            iconName: 'tag',
                                            defaultIcon: Icons.tag,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                                        ),
                                        suffixIcon: IconButton(
                                          icon: getAdaptiveIcon(
                                            iconName: 'close',
                                            defaultIcon: Icons.close,
                                            size: 18,
                                            color: Colors.grey,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _showHouseNumber = false;
                                              houseNumberController.clear();
                                            });
                                          },
                                          tooltip: 'Hausnummer entfernen',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ] else ...[
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            _showHouseNumber = true;
                                          });
                                        },
                                        icon: getAdaptiveIcon(
                                          iconName: 'add',
                                          defaultIcon: Icons.add,
                                          size: 16,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                        label: const Text('Hausnummer hinzufügen  (optional)'),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                    ),

                                  ],

                                  const SizedBox(height: 16),

// NEU: Zusätzliche Adresszeilen
                                  buildAddressLinesSection(
                                    context,
                                    additionalAddressLines,
                                    setState,
                                    'Adresszeile',
                                  ),
                                  const SizedBox(height: 16),

                                  // PLZ und Ort
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: TextFormField(
                                          controller: zipCodeController,
                                          decoration: InputDecoration(
                                            labelText: 'PLZ *',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            filled: true,
                                            fillColor: Colors.grey.shade50,
                                            prefixIcon: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 12),
                                              child: getAdaptiveIcon(
                                                iconName: 'pin',
                                                defaultIcon: Icons.pin,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(color: Colors.grey.shade300),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                                            ),
                                          ),
                                          validator: (value) => value?.isEmpty == true ? 'Bitte PLZ eingeben' : null,

                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 3,
                                        child: TextFormField(
                                          controller: cityController,
                                          decoration: InputDecoration(
                                            labelText: 'Ort *',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            filled: true,
                                            fillColor: Colors.grey.shade50,
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(color: Colors.grey.shade300),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                                            ),
                                          ),
                                          validator: (value) => value?.isEmpty == true ? 'Bitte Ort eingeben' : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // NEU: Provinz/Bundesland/Kanton
                                  TextFormField(
                                    controller: provinceController,
                                    decoration: InputDecoration(
                                      labelText: 'Provinz/Bundesland/Kanton',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      prefixIcon: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        child: getAdaptiveIcon(
                                          iconName: 'map',
                                          defaultIcon: Icons.map,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  // Land mit CountryDropdown
                                  CountryDropdown(
                                    countryController: countryController,
                                    countryCodeController: countryCodeController,
                                    label: 'Land',
                                    isRequired: true,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  const SizedBox(height: 16),
// Zusatz
                                  TextFormField(
                                    controller: addressSupplementController,
                                    decoration: InputDecoration(
                                      labelText: 'Zusatz',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
// Bezirk/Postfach
                                  TextFormField(
                                    controller: districtPOBoxController,
                                    decoration: InputDecoration(
                                      labelText: 'Bezirk/Postfach etc.',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Lieferadresse
                            buildSectionCard(
                              context,
                              title: 'Abweichende Lieferadresse',
                              icon: 'local_shipping',
                              defaultIcon: Icons.local_shipping,
                              iconColor: Colors.orange,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  SwitchListTile(
                                    title: const Text('Abweichende Lieferadresse'),
                                    value: _useShippingAddress,
                                    onChanged: (value) {
                                      setState(() {
                                        _useShippingAddress = value;
                                      });
                                    },
                                    activeColor: Theme.of(context).primaryColor,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  if (_useShippingAddress) ...[
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: shippingCompanyController,
                                      decoration: InputDecoration(
                                        labelText: 'Firma',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                        prefixIcon: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          child: getAdaptiveIcon(
                                            iconName: 'domain',
                                            defaultIcon: Icons.domain,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    // Lieferadresse Kontaktperson
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                                          child: Row(
                                            children: [
                                              Text(
                                                'Kontaktperson',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                                                ),
                                              ),
                                              const Spacer(),
                                              TextButton.icon(
                                                onPressed: () {
                                                  setState(() {
                                                    shippingLastNameController.text = lastNameController.text;
                                                    shippingFirstNameController.text = firstNameController.text;
                                                    shippingEmailController.text=emailController.text;
                                                    shippingPhoneController.text=phone1Controller.text;

                                                    if (firstNameController.text.isNotEmpty) {
                                                      _showShippingFirstName = true;
                                                    }
                                                  });
                                                },
                                                icon: getAdaptiveIcon(
                                                  iconName: 'content_copy',
                                                  defaultIcon: Icons.content_copy,
                                                  size: 16,
                                                  color: Theme.of(context).colorScheme.primary,
                                                ),
                                                label: const Text('Von Hauptkontakt'),
                                                style: TextButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  visualDensity: VisualDensity.compact,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Name (ehemals Nachname)
                                        TextFormField(
                                          controller: shippingLastNameController,
                                          decoration: InputDecoration(
                                            labelText: 'Name',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            filled: true,
                                            fillColor: Colors.grey.shade50,
                                            prefixIcon: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 12),
                                              child: getAdaptiveIcon(
                                                iconName: 'person',
                                                defaultIcon: Icons.person,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(color: Colors.grey.shade300),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        // Vorname optional
                                        if (_showShippingFirstName) ...[
                                          TextFormField(
                                            controller: shippingFirstNameController,
                                            decoration: InputDecoration(
                                              labelText: 'Vorname',
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              filled: true,
                                              fillColor: Colors.grey.shade50,
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: BorderSide(color: Colors.grey.shade300),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                                              ),
                                              suffixIcon: IconButton(
                                                icon: getAdaptiveIcon(
                                                  iconName: 'close',
                                                  defaultIcon: Icons.close,
                                                  size: 18,
                                                  color: Colors.grey,
                                                ),
                                                onPressed: () {
                                                  setState(() {
                                                    _showShippingFirstName = false;
                                                    shippingFirstNameController.clear();
                                                  });
                                                },
                                                tooltip: 'Vorname entfernen',
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                        ] else ...[
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: TextButton.icon(
                                              onPressed: () {
                                                setState(() {
                                                  _showShippingFirstName = true;
                                                });
                                              },
                                              icon: getAdaptiveIcon(
                                                iconName: 'add',
                                                defaultIcon: Icons.add,
                                                size: 16,
                                                color: Theme.of(context).primaryColor,
                                              ),
                                              label: const Text('Vorname hinzufügen (optional)'),
                                              style: TextButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                visualDensity: VisualDensity.compact,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: TextFormField(
                                            controller: shippingStreetController,
                                            decoration: InputDecoration(
                                              labelText: 'Straße und Hausnummer *',
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              filled: true,
                                              fillColor: Colors.grey.shade50,
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: BorderSide(color: Colors.grey.shade300),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                                              ),
                                            ),
                                            validator: (value) => _useShippingAddress && value?.isEmpty == true
                                                ? 'Bitte Straße und Hausnummer eingeben'
                                                : null,
                                          ),
                                        ),
                                        // const SizedBox(width: 16),
                                        // Expanded(
                                        //   flex:1,
                                        //   child: TextFormField(
                                        //     controller: shippingHouseNumberController,
                                        //     decoration: InputDecoration(
                                        //       labelText: 'Nr.',
                                        //       border: OutlineInputBorder(
                                        //         borderRadius: BorderRadius.circular(12),
                                        //       ),
                                        //       filled: true,
                                        //       fillColor: Colors.grey.shade50,
                                        //       enabledBorder: OutlineInputBorder(
                                        //         borderRadius: BorderRadius.circular(12),
                                        //         borderSide: BorderSide(color: Colors.grey.shade300),
                                        //       ),
                                        //       focusedBorder: OutlineInputBorder(
                                        //         borderRadius: BorderRadius.circular(12),
                                        //         borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                                        //       ),
                                        //     ),
                                        //
                                        //   ),
                                        // ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),

// NEU: Zusätzliche Adresszeilen für Lieferadresse
                                    buildAddressLinesSection(
                                        context,
                                      shippingAdditionalAddressLines,
                                      setState,
                                      'Adresszeile',
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: TextFormField(
                                            controller: shippingZipCodeController,
                                            decoration: InputDecoration(
                                              labelText: 'PLZ *',
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              filled: true,
                                              fillColor: Colors.grey.shade50,
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: BorderSide(color: Colors.grey.shade300),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                                              ),
                                            ),
                                            validator: (value) => _useShippingAddress && value?.isEmpty == true
                                                ? 'Bitte PLZ eingeben'
                                                : null,

                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          flex: 3,
                                          child: TextFormField(
                                            controller: shippingCityController,
                                            decoration: InputDecoration(
                                              labelText: 'Ort *',
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              filled: true,
                                              fillColor: Colors.grey.shade50,
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: BorderSide(color: Colors.grey.shade300),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                                              ),
                                            ),
                                            validator: (value) => _useShippingAddress && value?.isEmpty == true
                                                ? 'Bitte Ort eingeben'
                                                : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    // NEU: Provinz für Lieferadresse
                                    TextFormField(
                                      controller: shippingProvinceController,
                                      decoration: InputDecoration(
                                        labelText: 'Provinz/Bundesland/Kanton',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                        prefixIcon: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          child: getAdaptiveIcon(
                                            iconName: 'map',
                                            defaultIcon: Icons.map,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                                        ),
                                      ),
                                      // validator: (value) => _useShippingAddress && value?.isEmpty == true
                                      //     ? 'Bitte Provinz eingeben'
                                      //     : null,
                                    ),
                                    const SizedBox(height: 16),

                                    CountryDropdown(
                                      countryController: shippingCountryController,
                                      countryCodeController: shippingCountryCodeController,
                                      label: 'Land',
                                      isRequired: _useShippingAddress,
                                      validator: (country) => _useShippingAddress && country == null
                                          ? 'Bitte Land auswählen'
                                          : null,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller: shippingEmailController,
                                            decoration: InputDecoration(
                                              labelText: 'E-Mail',
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              filled: true,
                                              fillColor: Colors.grey.shade50,
                                              prefixIcon: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                                child: getAdaptiveIcon(
                                                  iconName: 'email',
                                                  defaultIcon: Icons.email,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: BorderSide(color: Colors.grey.shade300),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                                              ),
                                            ),
                                          ),
                                        ),


                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [

                                        Expanded(
                                          child: TextFormField(
                                            controller: shippingPhoneController,
                                            decoration: InputDecoration(
                                              labelText: 'Telefon 1',
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              filled: true,
                                              fillColor: Colors.grey.shade50,
                                              prefixIcon: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                                child: getAdaptiveIcon(
                                                  iconName: 'phone',
                                                  defaultIcon: Icons.phone,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: BorderSide(color: Colors.grey.shade300),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Weitere Informationen
                            buildSectionCard(
                              context,
                              title: 'Weitere Informationen',
                              icon: 'info',
                              defaultIcon: Icons.info,
                              iconColor: Colors.purple,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          decoration: InputDecoration(
                                            labelText: 'Kundensprache *',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            filled: true,
                                            fillColor: Colors.grey.shade50,
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(color: Colors.grey.shade300),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                                            ),
                                          ),
                                          value: languageController.text,
                                          items: const [
                                            DropdownMenuItem(value: 'DE', child: Text('Deutsch')),
                                            DropdownMenuItem(value: 'EN', child: Text('Englisch')),
                                          ],
                                          onChanged: (value) {
                                            if (value != null) {
                                              languageController.text = value;
                                            }
                                          },
                                          validator: (value) => value == null ? 'Bitte Sprache auswählen' : null,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          decoration: InputDecoration(
                                            labelText: 'Weihnachtsbrief',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            filled: true,
                                            fillColor: Colors.grey.shade50,
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(color: Colors.grey.shade300),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                                            ),
                                          ),
                                          value: christmasLetterController.text,
                                          items: const [
                                            DropdownMenuItem(value: 'JA', child: Text('JA')),
                                            DropdownMenuItem(value: 'NEIN', child: Text('NEIN')),
                                          ],
                                          onChanged: (value) {
                                            if (value != null) {
                                              christmasLetterController.text = value;
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: notesController,
                                    decoration: InputDecoration(
                                      labelText: 'Notizen',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      prefixIcon: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        child: getAdaptiveIcon(
                                          iconName: 'note',
                                          defaultIcon: Icons.note,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                                      ),
                                    ),
                                    maxLines: 3,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

// Kundengruppen
                            // Kundengruppen
                            buildSectionCard(
                              context,
                              title: 'Kundengruppen *',  // Stern hinzufügen
                              icon: 'group',
                              defaultIcon: Icons.group,
                              iconColor: Colors.teal,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 16),
                                  CustomerGroupSelectionWidget(
                                    selectedGroupIds: _selectedGroupIds,
                                    onChanged: (ids) {
                                      setState(() {
                                        _selectedGroupIds = ids;
                                        if (ids.isNotEmpty) _showGroupError = false;
                                      });
                                    },
                                    showLabel: false,
                                  ),
                                  if (_selectedGroupIds.isEmpty && _showGroupError)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        'Bitte mindestens eine Kundengruppe auswählen',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.error,  // Rot statt neutral
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Footer mit Buttons
                            Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '* Pflichtfelder!',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.outline,
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 16.0,bottom: 16),
                                  child: Row(
                                    children: [

                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 2,
                                        child: ElevatedButton.icon(
                                          onPressed: () async {
                                            // Kundengruppen-Validierung
                                            if (_selectedGroupIds.isEmpty) {
                                              setState(() {
                                                _showGroupError = true;
                                              });
                                              return; // Abbrechen
                                            }

                                            if (formKey.currentState?.validate() == true) {
                                              try {
                                                final updatedCustomer = Customer(
                                                  isFavorite: _isFavorite, // NEU
                                                  id: customer.id,
                                                  name: companyController.text.trim(),
                                                  company: companyController.text.trim(),
                                                  firstName: firstNameController.text.trim(),
                                                  lastName: lastNameController.text.trim(),
                                                  street: streetController.text.trim(),
                                                  houseNumber: houseNumberController.text.trim(),
                                                  zipCode: zipCodeController.text.trim(),
                                                  city: cityController.text.trim(),
                                                  province: provinceController.text.trim(),
                                                  country: countryController.text.trim(),
                                                  countryCode: countryCodeController.text.trim(),
                                                  email: emailController.text.trim(),
                                                  customerGroupIds: _selectedGroupIds,
                                                  phone1: phone1Controller.text.trim(),
                                                  phone2: phone2Controller.text.trim(),
                                                  vatNumber: vatNumberController.text.trim(),
                                                  eoriNumber: eoriNumberController.text.trim(),
                                                  language: languageController.text.trim(),
                                                  wantsChristmasCard: christmasLetterController.text == 'JA',
                                                  notes: notesController.text.trim(),
                                                  addressSupplement: addressSupplementController.text.trim(),
                                                  districtPOBox: districtPOBoxController.text.trim(),
                                                  hasDifferentShippingAddress: _useShippingAddress,
                                                  shippingCompany: _useShippingAddress ? shippingCompanyController.text.trim() : '',
                                                  shippingFirstName: _useShippingAddress ? shippingFirstNameController.text.trim() : '',
                                                  shippingLastName: _useShippingAddress ? shippingLastNameController.text.trim() : '',
                                                  shippingStreet: _useShippingAddress ? shippingStreetController.text.trim() : '',
                                                  shippingHouseNumber: _useShippingAddress ? shippingHouseNumberController.text.trim() : '',
                                                  shippingZipCode: _useShippingAddress ? shippingZipCodeController.text.trim() : '',
                                                  shippingProvince: _useShippingAddress ? shippingProvinceController.text.trim() : '',
                                                  shippingCity: _useShippingAddress ? shippingCityController.text.trim() : '',
                                                  shippingCountry: _useShippingAddress ? shippingCountryController.text.trim() : '',
                                                  shippingCountryCode: _useShippingAddress ? shippingCountryCodeController.text.trim() : '',
                                                  shippingPhone: _useShippingAddress ? shippingPhoneController.text.trim() : '',
                                                  shippingEmail: _useShippingAddress ? shippingEmailController.text.trim() : '',
                                                  showVatOnDocuments: showVatOnDocuments,
                                                  showEoriOnDocuments: showEoriOnDocuments,
                                                  showCustomFieldOnDocuments: showCustomFieldOnDocuments,
                                                  customFieldTitle: customFieldTitleController.text.trim().isEmpty
                                                      ? null : customFieldTitleController.text.trim(),
                                                  customFieldValue: customFieldValueController.text.trim().isEmpty
                                                      ? null : customFieldValueController.text.trim(),
                                                  additionalAddressLines: additionalAddressLines
                                                      .map((c) => c.text.trim())
                                                      .where((text) => text.isNotEmpty)
                                                      .toList(),
                                                  shippingAdditionalAddressLines: _useShippingAddress
                                                      ? shippingAdditionalAddressLines
                                                      .map((c) => c.text.trim())
                                                      .where((text) => text.isNotEmpty)
                                                      .toList()
                                                      : [],
                                                );

                                                await FirebaseFirestore.instance
                                                    .collection('customers')
                                                    .doc(customer.id)
                                                    .update(updatedCustomer.toMap());

                                                if (context.mounted) {
                                                  wasUpdated = true; // ← NEU! Setze Flag auf true
                                                  Navigator.pop(context);
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Kunde wurde aktualisiert'),
                                                      backgroundColor: Colors.green,
                                                    ),
                                                  );
                                                }
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Fehler beim Aktualisieren: $e'),
                                                      backgroundColor: Colors.red,
                                                    ),
                                                  );
                                                }
                                              }
                                            }
                                          },
                                          icon: getAdaptiveIcon(
                                            iconName: 'save',
                                            defaultIcon: Icons.save,
                                            color: Colors.white,
                                          ),
                                          label: const Text('Speichern'),
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            backgroundColor: Theme.of(context).primaryColor,
                                            foregroundColor: Colors.white,
                                            elevation: 2,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Platz für Tastatur
                                SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 20 : 0),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
    // Controller aufräumen
    for (var controller in additionalAddressLines) {
      controller.dispose();
    }
    for (var controller in shippingAdditionalAddressLines) {
      controller.dispose();
    }
    return wasUpdated;
  }

  /// Zeigt einen Dialog zum Erstellen eines neuen Kunden an
  /// Zeigt einen Dialog zum Erstellen eines neuen Kunden an
  static Future<Customer?> showNewCustomerDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();

    final companyController = TextEditingController();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final streetController = TextEditingController();
    final houseNumberController = TextEditingController();
    final zipCodeController = TextEditingController();
    final cityController = TextEditingController();
    final provinceController = TextEditingController(); // NEU
    final countryController = TextEditingController(text: 'Schweiz'); // Default
    final countryCodeController = TextEditingController(text: 'CH'); // Default für Schweiz
    final emailController = TextEditingController();
    final phone1Controller = TextEditingController();
    final phone2Controller = TextEditingController();
    final vatNumberController = TextEditingController();
    final eoriNumberController = TextEditingController();
    final languageController = TextEditingController(text: 'DE'); // Default
    final christmasLetterController = TextEditingController(text: 'JA'); // Default
    final notesController = TextEditingController();

    // Lieferadresse
    final shippingCompanyController = TextEditingController();
    final shippingFirstNameController = TextEditingController();
    final shippingLastNameController = TextEditingController();

    final shippingStreetController = TextEditingController();
    final shippingHouseNumberController = TextEditingController();
    final shippingZipCodeController = TextEditingController();
    final shippingProvinceController = TextEditingController(); // NEU
    final shippingCityController = TextEditingController();
    final shippingCountryController = TextEditingController();
    final shippingCountryCodeController = TextEditingController();
    final shippingEmailController = TextEditingController();
    final shippingPhoneController = TextEditingController();

    bool _useShippingAddress = false;
    bool showVatOnDocuments =  false;
    bool showEoriOnDocuments =  false;
    bool showCustomFieldOnDocuments =false;

    bool _showFirstName = false;
    bool _showHouseNumber = false; // NEU
    bool _showShippingFirstName = false;
    bool _showGroupError = false;

    final customFieldTitleController = TextEditingController();
    final customFieldValueController = TextEditingController();

    List<String> _selectedGroupIds = [];




    // Nach den bestehenden Controllern:
    final List<TextEditingController> additionalAddressLines = [];
    final List<TextEditingController> shippingAdditionalAddressLines = [];
    Customer? newCustomer;

    Widget buildAddressLinesSection(
        BuildContext context, // NEU: Context als Parameter

        List<TextEditingController> controllers,
        StateSetter setState,
        String labelPrefix,
        ) {
      return Column(
        children: [
          ...controllers.asMap().entries.map((entry) {
            final index = entry.key;
            final controller = entry.value;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: '$labelPrefix ${index + 1}',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        prefixIcon: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: getAdaptiveIcon(
                            iconName: 'notes',
                            defaultIcon: Icons.notes,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Theme.of(context).primaryColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        controller.dispose();
                        controllers.removeAt(index);
                      });
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: getAdaptiveIcon(
                        iconName: 'delete',
                        defaultIcon: Icons.delete,
                        color: Colors.red.shade700,
                        size: 20,
                      ),
                    ),
                    tooltip: 'Zeile entfernen',
                  ),
                ],
              ),
            );
          }).toList(),

          // Button zum Hinzufügen weiterer Zeilen
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                controllers.add(TextEditingController());
              });
            },
            icon: getAdaptiveIcon(
              iconName: 'add',
              defaultIcon: Icons.add,
              size: 20,
              color: Theme.of(context).primaryColor,
            ),
            label: const Text('Weitere Zeile hinzufügen'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              side: BorderSide(
                color: Theme.of(context).primaryColor.withOpacity(0.5),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      );
    }



    await showModalBottomSheet(
        context: context,
        isScrollControlled: true, // Wichtig für mehr Platz
        backgroundColor: Colors.transparent, // Für abgerundete Ecken
        builder: (context) => StatefulBuilder(
        builder: (context, setState) {
      return DraggableScrollableSheet(
          initialChildSize: 0.85, // Etwas größer für mehr Inhalt
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), // Stärkere Abrundung
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                spreadRadius: 0.5,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Column(
              children: [
          // Ansprechenderer Drag-Indikator
          Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),

    // Stylischer Header mit Farbabstufung
    Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
    child: Row(
    children: [
    // Icon vor dem Titel
    Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
    color: Theme.of(context).primaryColor.withOpacity(0.1),
    borderRadius: BorderRadius.circular(12),
    ),
    child: getAdaptiveIcon(
    iconName: 'person_add',
    defaultIcon: Icons.person_add,
    color: Theme.of(context).primaryColor,
    ),
    ),
    const SizedBox(width: 12),
    Text(
    'Neuer Kunde',
    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
    fontWeight: FontWeight.bold,
    color: Theme.of(context).primaryColor,
    ),
    ),
    const Spacer(),
    // Eleganter Schließen-Button
    IconButton(
    onPressed: () => Navigator.pop(context),
    icon: Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
    color: Colors.grey.shade200,
    shape: BoxShape.circle,
    ),
    child: getAdaptiveIcon(
    iconName: 'close',
    defaultIcon: Icons.close,
    size: 18,
    ),
    ),
    ),
    ],
    ),
    ),

    // Hauptinhalt
    Expanded(
    child: Form(
    key: formKey,
    child: ListView(
    controller: scrollController,
    padding: const EdgeInsets.fromLTRB(20, 5, 20, 20),
    children: [
    // Unternehmensdaten
    buildSectionCard(
    context,
    title: 'Unternehmensdaten',
    icon: 'business',
    defaultIcon: Icons.business,
    iconColor: Colors.blue,
    child: Column(
    children: [
    const SizedBox(height: 16),
    TextFormField(
    controller: companyController,
    decoration: InputDecoration(
    labelText: 'Firma',
    border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    filled: true,
    fillColor: Colors.grey.shade50,
    prefixIcon: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: getAdaptiveIcon(
    iconName: 'domain',
    defaultIcon: Icons.domain,
    color: Colors.grey.shade600,
    ),
    ),
    enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
    ),
    ),
   // validator: (value) => value?.isEmpty == true ? 'Bitte Firma eingeben' : null,
    ),
      const SizedBox(height: 24),

      // Info-Box
      Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            getAdaptiveIcon(
              iconName: 'info',
              defaultIcon: Icons.info,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Aktiviere die Checkboxen, um die jeweiligen Felder im Dokumentenkopf anzuzeigen',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),

      // MwSt-Nummer mit Checkbox
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: vatNumberController,
              decoration: InputDecoration(
                labelText: 'MwSt-Nummer / UID',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              Checkbox(
                value: showVatOnDocuments,
                onChanged: (value) {
                  setState(() {
                    showVatOnDocuments = value ?? false;
                  });
                },
              ),
              Text(
                'Anzeigen',
                style: TextStyle(fontSize: 10),
              ),
            ],
          ),
        ],
      ),

      const SizedBox(height: 16),

      // EORI-Nummer mit Checkbox
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: eoriNumberController,
              decoration: InputDecoration(
                labelText: 'EORI-Nummer',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              Checkbox(
                value: showEoriOnDocuments,
                onChanged: (value) {
                  setState(() {
                    showEoriOnDocuments = value ?? false;
                  });
                },
              ),
              Text(
                'Anzeigen',
                style: TextStyle(fontSize: 10),
              ),
            ],
          ),
        ],
      ),

      const SizedBox(height: 24),

      // Zusatzfeld mit Checkbox
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                getAdaptiveIcon(
                  iconName: 'add_box',
                  defaultIcon: Icons.add_box,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Zusätzliches Feld (z.B. für Lieferschein)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                Checkbox(
                  value: showCustomFieldOnDocuments,
                  onChanged: (value) {
                    setState(() {
                      showCustomFieldOnDocuments = value ?? false;
                    });
                  },
                ),
                Text(
                  'Anzeigen',
                  style: TextStyle(fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: customFieldTitleController,
              decoration: InputDecoration(
                labelText: 'Feldbezeichnung',
                hintText: 'z.B. Sendungsnummer, CPF/CNPJ, Tracking-ID',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: customFieldValueController,
              decoration: InputDecoration(
                labelText: 'Wert',
                hintText: 'z.B. 94838101, ABC-123456',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    ],
    ),
    ),

    const SizedBox(height: 16),

    // Kontaktperson-Karte
      // Kontaktperson-Karte
      buildSectionCard(
        context,
        title: 'Kontaktperson',
        icon: 'contacts',
        defaultIcon: Icons.contacts,
        iconColor: Colors.green,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            // Name (ehemals Nachname)
            TextFormField(
              controller: lastNameController,
              decoration: InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                prefixIcon: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: getAdaptiveIcon(
                    iconName: 'person',
                    defaultIcon: Icons.person,
                    color: Colors.grey.shade600,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Vorname optional
            if (_showFirstName) ...[
              TextFormField(
                controller: firstNameController,
                decoration: InputDecoration(
                  labelText: 'Vorname',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                  ),
                  suffixIcon: IconButton(
                    icon: getAdaptiveIcon(
                      iconName: 'close',
                      defaultIcon: Icons.close,
                      size: 18,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _showFirstName = false;
                        firstNameController.clear();
                      });
                    },
                    tooltip: 'Vorname entfernen',
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showFirstName = true;
                    });
                  },
                  icon: getAdaptiveIcon(
                    iconName: 'add',
                    defaultIcon: Icons.add,
                    size: 16,
                    color: Theme.of(context).primaryColor,
                  ),
                  label: const Text('Vorname hinzufügen (optional)'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            // E-Mail
            TextFormField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'E-Mail *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                prefixIcon: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: getAdaptiveIcon(
                    iconName: 'email',
                    defaultIcon: Icons.email,
                    color: Colors.grey.shade600,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                ),
              ),
              validator: (value) {
                if (value?.isEmpty == true) {
                  return 'Bitte E-Mail eingeben';
                }
                if (!value!.contains('@')) {
                  return 'Bitte gültige E-Mail eingeben';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Telefon 1
            TextFormField(
              controller: phone1Controller,
              decoration: InputDecoration(
                labelText: 'Telefon 1',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                prefixIcon: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: getAdaptiveIcon(
                    iconName: 'phone',
                    defaultIcon: Icons.phone,
                    color: Colors.grey.shade600,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Telefon 2
            TextFormField(
              controller: phone2Controller,
              decoration: InputDecoration(
                labelText: 'Telefon 2',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                prefixIcon: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: getAdaptiveIcon(
                    iconName: 'phone',
                    defaultIcon: Icons.phone,
                    color: Colors.grey.shade600,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                ),
              ),
            ),
          ],
        ),
      ),

    const SizedBox(height: 16),

    // Adress-Karte
    buildSectionCard(
    context,
    title: 'Rechnungsadresse',
    icon: 'location_on',
    defaultIcon: Icons.location_on,
    iconColor: Colors.red,
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    const SizedBox(height: 16),
    // Straße und Hausnummer
    Row(
    children: [
    Expanded(
    flex: 3,
    child: TextFormField(
    controller: streetController,
    decoration: InputDecoration(
    labelText: 'Straße',
    border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    ),
    filled: true,
    fillColor: Colors.grey.shade50,
    prefixIcon: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: getAdaptiveIcon(
    iconName: 'add_road',
    defaultIcon: Icons.add_road,
    color: Colors.grey.shade600,
    ),
    ),
    enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
    ),
    ),
    ),
    ),
    // const SizedBox(width: 16),
    // Expanded(
    // child: TextFormField(
    // controller: houseNumberController,
    // decoration: InputDecoration(
    // labelText: 'Nr. *',
    // border: OutlineInputBorder(
    // borderRadius: BorderRadius.circular(12),
    // ),
    // filled: true,
    // fillColor: Colors.grey.shade50,
    // enabledBorder: OutlineInputBorder(
    // borderRadius: BorderRadius.circular(12),
    // borderSide: BorderSide(color: Colors.grey.shade300),
    // ),
    // focusedBorder: OutlineInputBorder(
    // borderRadius: BorderRadius.circular(12),
    // borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
    // ),
    // ),
    // validator: (value) => value?.isEmpty == true ? 'Bitte Nr. eingeben' : null,
    // ),
    // ),
    ],
    ),
    const SizedBox(height: 8),
      // Hausnummer optional
      if (_showHouseNumber) ...[
        TextFormField(
          controller: houseNumberController,
          decoration: InputDecoration(
            labelText: 'Hausnummer',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            prefixIcon: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: getAdaptiveIcon(
                iconName: 'tag',
                defaultIcon: Icons.tag,
                color: Colors.grey.shade600,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
            ),
            suffixIcon: IconButton(
              icon: getAdaptiveIcon(
                iconName: 'close',
                defaultIcon: Icons.close,
                size: 18,
                color: Colors.grey,
              ),
              onPressed: () {
                setState(() {
                  _showHouseNumber = false;
                  houseNumberController.clear();
                });
              },
              tooltip: 'Hausnummer entfernen',
            ),
          ),
        ),
        const SizedBox(height: 16),
      ] else ...[
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _showHouseNumber = true;
              });
            },
            icon: getAdaptiveIcon(
              iconName: 'add',
              defaultIcon: Icons.add,
              size: 16,
              color: Theme.of(context).primaryColor,
            ),
            label: const Text('Hausnummer hinzufügen (optional)'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),

      ],
      const SizedBox(height: 16),
    // PLZ und Ort

      // Zusätzliche Adresszeilen
      buildAddressLinesSection(
          context,
        additionalAddressLines,
        setState,
        'Adresszeile',
      ),

      const SizedBox(height: 16),



    Row(
    children: [
    Expanded(
      flex: 2,
    child: TextFormField(
    controller: zipCodeController,
    decoration: InputDecoration(
    labelText: 'PLZ',
    border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    ),
    filled: true,
    fillColor: Colors.grey.shade50,
    prefixIcon: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: getAdaptiveIcon(
    iconName: 'pin',
    defaultIcon: Icons.pin,
    color: Colors.grey.shade600,
    ),
    ),
    enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
    ),
    ),

    ),
    ),
    const SizedBox(width: 16),
    Expanded(
    flex: 3,
    child: TextFormField(
    controller: cityController,
    decoration: InputDecoration(
    labelText: 'Ort',
    border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    ),
    filled: true,
    fillColor: Colors.grey.shade50,
    enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
    ),
    ),

    ),
    ),
    ],
    ),
    const SizedBox(height: 16),

// NEU: Provinz/Bundesland/Kanton
      TextFormField(
        controller: provinceController,
        decoration: InputDecoration(
          labelText: 'Provinz/Bundesland/Kanton',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: getAdaptiveIcon(
              iconName: 'map',
              defaultIcon: Icons.map,
              color: Colors.grey.shade600,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
          ),
        ),
      ),
      const SizedBox(height: 16),
    // Land mit Flag-Icon
      CountryDropdown(
        countryController: countryController,
        countryCodeController: countryCodeController,
        label: 'Land',
        isRequired: false,
        borderRadius: BorderRadius.circular(12), // Behalte den gleichen Radius wie andere Felder
      )
    ],
    ),
    ),

    const SizedBox(height: 16),

    // Lieferadresse
    buildSectionCard(
    context,
    title: 'Abweichende Lieferadresse',
    icon: 'local_shipping',
    defaultIcon: Icons.local_shipping,
    iconColor: Colors.orange,
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    const SizedBox(height: 8),
    SwitchListTile(
    title: const Text('Abweichende Lieferadresse'),
    value: _useShippingAddress,
    onChanged: (value) {
    setState(() {
    _useShippingAddress = value;
    });
    },
    activeColor: Theme.of(context).primaryColor,
    contentPadding: EdgeInsets.zero,
    ),
    if (_useShippingAddress) ...[
    const SizedBox(height: 16),
    TextFormField(
    controller: shippingCompanyController,
    decoration: InputDecoration(
    labelText: 'Firma',
    border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    ),
    filled: true,
    fillColor: Colors.grey.shade50,
    prefixIcon: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: getAdaptiveIcon(
    iconName: 'domain',
    defaultIcon: Icons.domain,
    color: Colors.grey.shade600,
    ),
    ),
    enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
    ),
    ),
    ),
    const SizedBox(height: 16),

      // Lieferadresse Kontaktperson
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Text(
                  'Kontaktperson',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      shippingLastNameController.text = lastNameController.text;
                      shippingFirstNameController.text = firstNameController.text;
                      if (firstNameController.text.isNotEmpty) {
                        _showShippingFirstName = true;
                      }
                    });
                  },
                  icon: getAdaptiveIcon(
                    iconName: 'content_copy',
                    defaultIcon: Icons.content_copy,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  label: const Text('Von Hauptkontakt'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
          // Name (ehemals Nachname)
          TextFormField(
            controller: shippingLastNameController,
            decoration: InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: getAdaptiveIcon(
                  iconName: 'person',
                  defaultIcon: Icons.person,
                  color: Colors.grey.shade600,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Vorname optional
          if (_showShippingFirstName) ...[
            TextFormField(
              controller: shippingFirstNameController,
              decoration: InputDecoration(
                labelText: 'Vorname',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                ),
                suffixIcon: IconButton(
                  icon: getAdaptiveIcon(
                    iconName: 'close',
                    defaultIcon: Icons.close,
                    size: 18,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _showShippingFirstName = false;
                      shippingFirstNameController.clear();
                    });
                  },
                  tooltip: 'Vorname entfernen',
                ),
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showShippingFirstName = true;
                  });
                },
                icon: getAdaptiveIcon(
                  iconName: 'add',
                  defaultIcon: Icons.add,
                  size: 16,
                  color: Theme.of(context).primaryColor,
                ),
                label: const Text('Vorname separat hinzufügen (optional)'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    const SizedBox(height: 16),
    Row(
    children: [
    Expanded(
    flex: 3,
    child: TextFormField(
    controller: shippingStreetController,
    decoration: InputDecoration(
    labelText: 'Straße und Hausnummer*',
    border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    ),
    filled: true,
    fillColor: Colors.grey.shade50,
    enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
    ),
    ),
    validator: (value) => _useShippingAddress && value?.isEmpty == true
    ? 'Bitte Straße und Nr. eingeben'
        : null,
    ),
    ),

    ],
    ),
    const SizedBox(height: 16),

// Zusätzliche Adresszeilen für Lieferadresse
      buildAddressLinesSection(
        context,
        shippingAdditionalAddressLines,
        setState,
        'Adresszeile',
      ),

      const SizedBox(height: 16),

    Row(
    children: [
    Expanded(
    child: TextFormField(
    controller: shippingZipCodeController,
      decoration: InputDecoration(
        labelText: 'PLZ *',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
      ),
      validator: (value) => _useShippingAddress && value?.isEmpty == true
          ? 'Bitte PLZ eingeben'
          : null,

    ),
    ),
      const SizedBox(width: 16),
      Expanded(
        flex: 3,
        child: TextFormField(
          controller: shippingCityController,
          decoration: InputDecoration(
            labelText: 'Ort *',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
            ),
          ),
          validator: (value) => _useShippingAddress && value?.isEmpty == true
              ? 'Bitte Ort eingeben'
              : null,
        ),
      ),
    ],
    ),
      const SizedBox(height: 16),
      // NEU: Provinz für Lieferadresse
      TextFormField(
        controller: shippingProvinceController,
        decoration: InputDecoration(
          labelText: 'Provinz/Bundesland/Kanton',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: getAdaptiveIcon(
              iconName: 'map',
              defaultIcon: Icons.map,
              color: Colors.grey.shade600,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
          ),
        ),
      ),
      const SizedBox(height: 16),
      CountryDropdown(
        countryController: shippingCountryController,
        countryCodeController: shippingCountryCodeController,
        label: 'Land',
        isRequired: _useShippingAddress,
        validator: (country) => _useShippingAddress && (country == null || country.toString().isEmpty)
            ? 'Bitte Land eingeben'
            : null,
        borderRadius: BorderRadius.circular(12),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: shippingEmailController,
              decoration: InputDecoration(
                labelText: 'E-Mail',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                prefixIcon: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: getAdaptiveIcon(
                    iconName: 'email',
                    defaultIcon: Icons.email,
                    color: Colors.grey.shade600,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextFormField(
              controller: shippingPhoneController,
              decoration: InputDecoration(
                labelText: 'Telefon',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                prefixIcon: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: getAdaptiveIcon(
                    iconName: 'phone',
                    defaultIcon: Icons.phone,
                    color: Colors.grey.shade600,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                ),
              ),
            ),
          ),
        ],
      ),
    ],
    ],
    ),
    ),

      const SizedBox(height: 16),

      // Weitere Informationen
      buildSectionCard(
        context,
        title: 'Weitere Informationen',
        icon: 'info',
        defaultIcon: Icons.info,
        iconColor: Colors.purple,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Kundensprache *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                      ),
                    ),
                    value: languageController.text,
                    items: const [
                      DropdownMenuItem(value: 'DE', child: Text('Deutsch')),
                      DropdownMenuItem(value: 'EN', child: Text('Englisch')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        languageController.text = value;
                      }
                    },
                    validator: (value) => value == null ? 'Bitte Sprache auswählen' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Weihnachtsbrief',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                      ),
                    ),
                    value: christmasLetterController.text,
                    items: const [
                      DropdownMenuItem(value: 'JA', child: Text('JA')),
                      DropdownMenuItem(value: 'NEIN', child: Text('NEIN')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        christmasLetterController.text = value;
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: notesController,
              decoration: InputDecoration(
                labelText: 'Notizen',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                prefixIcon: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: getAdaptiveIcon(
                    iconName: 'note',
                    defaultIcon: Icons.note,
                    color: Colors.grey.shade600,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                ),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),

// Kundengruppen
      // Kundengruppen
      buildSectionCard(
        context,
        title: 'Kundengruppen *',  // Stern hinzufügen
        icon: 'group',
        defaultIcon: Icons.group,
        iconColor: Colors.teal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            CustomerGroupSelectionWidget(
              selectedGroupIds: _selectedGroupIds,
              onChanged: (ids) {
                setState(() {
                  _selectedGroupIds = ids;
                  if (ids.isNotEmpty) _showGroupError = false;
                });
              },
              showLabel: false,
            ),
            if (_selectedGroupIds.isEmpty && _showGroupError)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Bitte mindestens eine Kundengruppe auswählen',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error,  // Rot statt neutral
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 24),

      // Footer mit schicken Buttons
      Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '* Pflichtfelder',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16.0,bottom: 16),
            child: Row(
              children: [

                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      // Kundengruppen-Validierung
                      if (_selectedGroupIds.isEmpty) {
                        setState(() {
                          _showGroupError = true;
                        });
                        return;  // Abbrechen
                      }






                      if (formKey.currentState?.validate() == true) {
                        try {
                          print("streetcontr:${streetController.text.trim()},");
                          final customerData = Customer(
                            id: '',
                            name: companyController.text.trim(),
                            company: companyController.text.trim(),
                            firstName: firstNameController.text.trim(),
                            lastName: lastNameController.text.trim(),
                            street: streetController.text.trim(),
                            houseNumber: houseNumberController.text.trim(),
                            zipCode: zipCodeController.text.trim(),
                            city: cityController.text.trim(),
                            province: provinceController.text.trim(), // NEU
                            country: countryController.text.trim(),
                            countryCode: countryCodeController.text.trim(),
                            email: emailController.text.trim(),
                            customerGroupIds: _selectedGroupIds,
                            // Neue Felder mit korrekten Typen
                            phone1: phone1Controller.text.trim(),
                            phone2: phone2Controller.text.trim(),
                            vatNumber: vatNumberController.text.trim(),
                            eoriNumber: eoriNumberController.text.trim(),
                            language: languageController.text.trim(),
                            wantsChristmasCard: christmasLetterController.text == 'JA',
                            notes: notesController.text.trim(),

                            // Abweichende Lieferadresse
                            hasDifferentShippingAddress: _useShippingAddress,
                            shippingCompany: _useShippingAddress ? shippingCompanyController.text.trim() : '',
                            shippingFirstName: _useShippingAddress ? firstNameController.text.trim() : '', // Wir können hier die Standard-Werte verwenden, wenn keine abweichenden vorhanden
                            shippingLastName: _useShippingAddress ? lastNameController.text.trim() : '',
                            shippingStreet: _useShippingAddress ? shippingStreetController.text.trim() : '',
                            shippingHouseNumber: _useShippingAddress ? shippingHouseNumberController.text.trim() : '',
                            shippingZipCode: _useShippingAddress ? shippingZipCodeController.text.trim() : '',
                            shippingProvince: _useShippingAddress ? shippingProvinceController.text.trim() : '', // NEU

                            shippingCity: _useShippingAddress ? shippingCityController.text.trim() : '',
                            shippingCountry: _useShippingAddress ? shippingCountryController.text.trim() : '',
                            shippingCountryCode: _useShippingAddress ? shippingCountryCodeController.text.trim() : '',
                            shippingPhone: _useShippingAddress ? shippingPhoneController.text.trim() : '',
                            shippingEmail: _useShippingAddress ? shippingEmailController.text.trim() : '',
                            showVatOnDocuments: showVatOnDocuments,
                            showEoriOnDocuments: showEoriOnDocuments,
                            showCustomFieldOnDocuments: showCustomFieldOnDocuments,
                            customFieldTitle: customFieldTitleController.text.trim().isEmpty
                                ? null : customFieldTitleController.text.trim(),
                            customFieldValue: customFieldValueController.text.trim().isEmpty
                                ? null : customFieldValueController.text.trim(),

                            additionalAddressLines: additionalAddressLines
                                .map((c) => c.text.trim())
                                .where((text) => text.isNotEmpty)
                                .toList(),
                            shippingAdditionalAddressLines: _useShippingAddress
                                ? shippingAdditionalAddressLines
                                .map((c) => c.text.trim())
                                .where((text) => text.isNotEmpty)
                                .toList()
                                : [],




                          );

                          final docRef = await FirebaseFirestore.instance
                              .collection('customers')
                              .add(customerData.toMap());

                          newCustomer = Customer.fromMap(
                            customerData.toMap(),
                            docRef.id,
                          );

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Kunde wurde erfolgreich angelegt'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Fehler beim Anlegen: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    },
                    icon: getAdaptiveIcon(
                      iconName: 'save',
                      defaultIcon: Icons.save,
                      color: Colors.white,
                    ),
                    label: const Text('Kunde anlegen'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Platz für Tastatur
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 20 : 0),
        ],
      ),
    ],
    ),
    ),
    ),
              ],
          ),
        );
          },
      );
        },
        ),
    );
// Controller aufräumen
    for (var controller in additionalAddressLines) {
      controller.dispose();
    }
    for (var controller in shippingAdditionalAddressLines) {
      controller.dispose();
    }
    return newCustomer;
  }

  /// Lösche einen Kunden
  static Future<bool> deleteCustomer(BuildContext context, String customerId) async {
    try {
      await FirebaseFirestore.instance
          .collection('customers')
          .doc(customerId)
          .delete();

      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Löschen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  static  buildSectionCard(
    BuildContext context, {
      required String title,
      required String icon,
      required IconData defaultIcon,
      required Color iconColor,
      required Widget child,
    }) {
  return Card(
    elevation: 0.5,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: Colors.grey.shade200),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: getAdaptiveIcon(
                  iconName: icon,
                  defaultIcon: defaultIcon,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
            ],
          ),
          child,
        ],
      ),
    ),
  );
}


}

class _CustomerSelectionBottomSheet extends StatefulWidget {
  final Customer? initialCustomer;  // NEU

  const _CustomerSelectionBottomSheet({this.initialCustomer});  // NEU

  @override
  _CustomerSelectionBottomSheetState createState() => _CustomerSelectionBottomSheetState();
}

class _CustomerSelectionBottomSheetState extends State<_CustomerSelectionBottomSheet> {
  final TextEditingController customerSearchController = TextEditingController();
  Customer? selectedCustomer;

  // Speichern aller geladenen Kunden für Client-seitiges Filtern

  bool _isLoading = false;


  bool _showOnlyFavorites = false;


  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  String _lastSearchTerm = '';

  final CustomerCacheService _cacheService = CustomerCacheService();
  List<Customer> _displayedCustomers = [];



  @override
  void initState() {
    super.initState();
    selectedCustomer = widget.initialCustomer;
    _initializeCache();

    customerSearchController.addListener(_onSearchChanged);
  }

  Future<void> _initializeCache() async {
    setState(() {
      _isLoading = true;
    });

    await _cacheService.initialize();

    setState(() {
      _displayedCustomers = _cacheService.getSorted(onlyFavorites: _showOnlyFavorites);
      _isLoading = false;
    });
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (customerSearchController.text != _lastSearchTerm) {
        _lastSearchTerm = customerSearchController.text;
        _applySearchAndFilters();
      }
    });
  }

  void _applySearchAndFilters() {
    setState(() {
      _displayedCustomers = _cacheService.search(
        _lastSearchTerm,
        onlyFavorites: _showOnlyFavorites,
      );

      // Nach Firma/Name sortieren
      _displayedCustomers.sort((a, b) {
        final aName = a.company.isNotEmpty ? a.company : a.name;
        final bName = b.company.isNotEmpty ? b.company : b.name;
        return aName.toLowerCase().compareTo(bName.toLowerCase());
      });
    });
  }

  void _toggleFavoritesFilter() {
    setState(() {
      _showOnlyFavorites = !_showOnlyFavorites;
    });
    _applySearchAndFilters();
  }

  @override
  void dispose() {
    customerSearchController.removeListener(_onSearchChanged);
    customerSearchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                getAdaptiveIcon(iconName: 'person', defaultIcon: Icons.person),
                const SizedBox(width: 12),
                Text(
                  'Kunde',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Spacer(),
                // NEU: Refresh-Button
                IconButton(
                  onPressed: _isLoading ? null : () async {
                    setState(() {
                      _isLoading = true;
                    });

                    try {
                      await _cacheService.forceRefresh();
                      _applySearchAndFilters();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Fehler beim Aktualisieren: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } finally {
                      setState(() {
                        _isLoading = false;
                      });
                    }
                  },
                  icon: _isLoading
                      ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  )
                      : getAdaptiveIcon(
                    iconName: 'refresh',
                    defaultIcon: Icons.refresh,
                  ),
                  tooltip: 'Kundenliste aktualisieren',
                ),
                // Favoriten-Filter-Button
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showOnlyFavorites = !_showOnlyFavorites;
                    });
                    _applySearchAndFilters();
                  },
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _showOnlyFavorites
                          ? Colors.amber.shade100
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _showOnlyFavorites
                            ? Colors.amber.shade700
                            : Colors.grey.shade400,
                        width: 1.5,
                      ),
                    ),
                    child: getAdaptiveIcon(
                      iconName: _showOnlyFavorites ? 'star' : 'star_border',
                      defaultIcon: _showOnlyFavorites ? Icons.star : Icons.star_border,
                      size: 20,
                      color: _showOnlyFavorites ? Colors.amber.shade700 : Colors.grey,
                    ),
                  ),
                  tooltip: _showOnlyFavorites ? 'Alle Kunden anzeigen' : 'Nur Favoriten anzeigen',
                ),
                // Neuer Kunde Button
                IconButton(
                  onPressed: () async {
                    final newCustomer = await CustomerSelectionSheet.showNewCustomerDialog(context);
                    if (newCustomer != null) {
                      _cacheService.addCustomer(newCustomer);
                      setState(() {
                        selectedCustomer = newCustomer;
                      });
                      _applySearchAndFilters();
                    }
                  },
                  icon: getAdaptiveIcon(iconName: 'add', defaultIcon: Icons.add),
                  tooltip: 'Neuer Kunde',
                ),
                // Schließen Button
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                  tooltip: 'Schließen',
                ),
              ],
            ),
          ),
          // Suchfeld
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextFormField(
              controller: customerSearchController,
              decoration: InputDecoration(
                labelText: 'Suchen',
                prefixIcon: getAdaptiveIcon(iconName: 'search', defaultIcon: Icons.search),
                suffixIcon: customerSearchController.text.isNotEmpty
                    ? IconButton(
                  icon: getAdaptiveIcon(iconName: 'clear', defaultIcon: Icons.clear),
                  onPressed: () {
                    customerSearchController.clear();
                  },
                )
                    : null,
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
            ),
          ),
          // NEU: Favoriten-Filter-Hinweis
          if (_showOnlyFavorites)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.star, size: 16, color: Colors.amber.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Nur Favoriten werden angezeigt',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _toggleFavoritesFilter,
                      child: Text(
                        'Filter aufheben',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Suchstatus anzeigen (optional)
          if (_lastSearchTerm.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Text(
        'Suchergebnisse für "$_lastSearchTerm" (${_displayedCustomers.length})',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ),
          if (selectedCustomer != null && _lastSearchTerm.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aktuell ausgewählt',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildCustomerListTile(selectedCustomer!, true),
                  const Divider(),
                ],
              ),
            ),

          // Kundenliste
          Expanded(
            child: _isLoading &&_displayedCustomers.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _displayedCustomers.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  getAdaptiveIcon(
                    iconName: 'search_off',
                    defaultIcon: Icons.search_off,
                    size: 48,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _lastSearchTerm.isEmpty
                        ? 'Keine Kunden gefunden'
                        : 'Keine Ergebnisse für "${_lastSearchTerm}"',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _displayedCustomers.length,
              itemBuilder: (context, index) {
                final customer = _displayedCustomers[index];

                // Bereits ausgewählten Kunden überspringen
                if (selectedCustomer != null && customer.id == selectedCustomer!.id && _lastSearchTerm.isEmpty) {
                  return const SizedBox.shrink();
                }

                final isSelected = selectedCustomer?.id == customer.id;
                return _buildCustomerListTile(customer, isSelected);
              },
            )
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerListTile(Customer customer, bool isSelected) {
    // Robuste Avatar-Buchstaben-Extraktion
    String getAvatarLetter() {
      // Zuerst versuchen: Firma (da das der Haupttitel ist)
      if (customer.company?.isNotEmpty == true) {
        return customer.company!.substring(0, 1).toUpperCase();
      }

      // Dann versuchen: Name-Feld
      if (customer.name.isNotEmpty) {
        return customer.name.substring(0, 1).toUpperCase();
      }

      // Dann versuchen: Vorname
      if (customer.firstName?.isNotEmpty == true) {
        return customer.firstName!.substring(0, 1).toUpperCase();
      }

      // Dann versuchen: Nachname
      if (customer.lastName?.isNotEmpty == true) {
        return customer.lastName!.substring(0, 1).toUpperCase();
      }

      // Fallback: Fragezeichen
      return '?';
    }

    // Haupttitel = Firmenname
    String getDisplayName() {
      // Priorität 1: Firma
      if (customer.company?.isNotEmpty == true) {
        return customer.company!;
      }

      // Fallback: Name-Feld
      if (customer.name.isNotEmpty) {
        return customer.name;
      }

      // Fallback: Vor- und Nachname kombinieren
      final firstName = customer.firstName ?? '';
      final lastName = customer.lastName ?? '';

      if (firstName.isNotEmpty || lastName.isNotEmpty) {
        return '$firstName $lastName'.trim();
      }

      // Letzter Fallback
      return 'Unbenannter Kunde';
    }

    // Untertitel = Ansprechpartner / Ort
    String getSubtitle() {
      List<String> subtitleParts = [];

      // Ansprechpartner hinzufügen
      String contactPerson = '';

      // Zuerst versuchen: Vor- und Nachname
      final firstName = customer.firstName ?? '';
      final lastName = customer.lastName ?? '';

      if (firstName.isNotEmpty || lastName.isNotEmpty) {
        contactPerson = '$firstName $lastName'.trim();
      } else if (customer.name.isNotEmpty && customer.company?.isNotEmpty == true) {
        // Falls Name-Feld als Ansprechpartner genutzt wird (wenn Firma separat vorhanden)
        contactPerson = customer.name;
      }

      if (contactPerson.isNotEmpty) {
        subtitleParts.add(contactPerson);
      }

      // Stadt hinzufügen
      if (customer.city?.isNotEmpty == true) {
        subtitleParts.add(customer.city!);
      }

      // Falls gar nichts vorhanden, E-Mail als Fallback
      if (subtitleParts.isEmpty && customer.email?.isNotEmpty == true) {
        subtitleParts.add(customer.email!);
      }

      return subtitleParts.join(' / ');
    }

    return Card(
      elevation: isSelected ? 2 : 0,
      color: isSelected
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Text(
                getAvatarLetter(),
                style: TextStyle(
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // NEU: Stern-Badge für Favoriten
            if (customer.isFavorite)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.star,
                    size: 14,
                    color: Colors.amber.shade700,
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          getDisplayName(),
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        subtitle: getSubtitle().isNotEmpty
            ? Text(
          getSubtitle(),
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        )
            : null,
        trailing: IconButton(
          icon: getAdaptiveIcon(iconName: 'edit', defaultIcon: Icons.edit),
          onPressed: () async {
            final wasUpdated = await CustomerSelectionSheet.showEditCustomerDialog(context, customer);
            if (wasUpdated) {
              // NEU: Kunde aus Firestore neu laden und Cache aktualisieren
              final updatedDoc = await FirebaseFirestore.instance
                  .collection('customers')
                  .doc(customer.id)
                  .get();
              if (updatedDoc.exists) {
                final updatedCustomer = Customer.fromMap(updatedDoc.data()!, updatedDoc.id);
                _cacheService.updateCustomer(updatedCustomer);
                _applySearchAndFilters();
              }
            }
          },
          tooltip: 'Kunde bearbeiten',
        ),
        isThreeLine: false,
        onTap: () {
          setState(() => selectedCustomer = customer);
          Navigator.pop(context, customer);
        },
      ),
    );
  }

}



