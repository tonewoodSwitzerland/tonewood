import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/country_dropdown_widget.dart';
import '../services/customer.dart';
import '../services/customer_export_service.dart';
import '../services/icon_helper.dart';

import 'package:intl/intl.dart';

import 'customer_filter_dialog.dart';
import 'customer_filter_favorite_sheet.dart';
import 'customer_filter_service.dart';
import 'customer_label_print_screen.dart';


/// Zentrale Klasse für alle Kundenfunktionen
class CustomerSelectionSheet {
  /// Zeigt die Kundenauswahl als ModalBottomSheet an
  static Future<Customer?> show(BuildContext context) async {
    final Customer? selectedCustomer = await showModalBottomSheet<Customer?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return const _CustomerSelectionBottomSheet();
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
  static Future<void> showEditCustomerDialog(BuildContext context, Customer customer) async {
    final formKey = GlobalKey<FormState>();
    final companyController = TextEditingController(text: customer.company);
    final firstNameController = TextEditingController(text: customer.firstName);
    final lastNameController = TextEditingController(text: customer.lastName);
    final streetController = TextEditingController(text: customer.street);
    final houseNumberController = TextEditingController(text: customer.houseNumber);
    final zipCodeController = TextEditingController(text: customer.zipCode);
    final cityController = TextEditingController(text: customer.city);
    final countryController = TextEditingController(text: customer.country);
    final countryCodeController = TextEditingController(text: customer.countryCode);
    final emailController = TextEditingController(text: customer.email);
    final phone1Controller = TextEditingController(text: customer.phone1);
    final phone2Controller = TextEditingController(text: customer.phone2);
    final vatNumberController = TextEditingController(text: customer.vatNumber);
    final eoriNumberController = TextEditingController(text: customer.eoriNumber);
    final languageController = TextEditingController(text: customer.language);
    final christmasLetterController = TextEditingController(text: customer.wantsChristmasCard ? 'JA' : 'NEIN');
    final notesController = TextEditingController(text: customer.notes);
    final addressSupplementController = TextEditingController(text: customer?.addressSupplement ?? '');
    final districtPOBoxController = TextEditingController(text: customer?.districtPOBox ?? '');



    // Lieferadresse
    final shippingCompanyController = TextEditingController(text: customer.shippingCompany);
    final shippingFirstNameController = TextEditingController(text: customer.shippingFirstName);
    final shippingLastNameController = TextEditingController(text: customer.shippingLastName);
    final shippingStreetController = TextEditingController(text: customer.shippingStreet);
    final shippingHouseNumberController = TextEditingController(text: customer.shippingHouseNumber);
    final shippingZipCodeController = TextEditingController(text: customer.shippingZipCode);
    final shippingCityController = TextEditingController(text: customer.shippingCity);
    final shippingCountryController = TextEditingController(text: customer.shippingCountry);
    final shippingCountryCodeController = TextEditingController(text: customer.shippingCountryCode);
    final shippingEmailController = TextEditingController(text: customer.shippingEmail);
    final shippingPhoneController = TextEditingController(text: customer.shippingPhone);

    bool _useShippingAddress = customer.hasDifferentShippingAddress;

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
                                      labelText: 'Firma *',
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
                                    validator: (value) => value?.isEmpty == true ? 'Bitte Firma eingeben' : null,
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: vatNumberController,
                                          decoration: InputDecoration(
                                            labelText: 'MwSt-Nummer',
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
                                      const SizedBox(width: 16),
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
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

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
                                  // Vorname und Nachname
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: firstNameController,
                                          decoration: InputDecoration(
                                            labelText: 'Vorname',
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
                                       //   validator: (value) => value?.isEmpty == true ? 'Bitte Vorname eingeben' : null,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: TextFormField(
                                          controller: lastNameController,
                                          decoration: InputDecoration(
                                            labelText: 'Nachname',
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
                                      //    validator: (value) => value?.isEmpty == true ? 'Bitte Nachname eingeben' : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
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
                                      // const SizedBox(width: 16),
                                      // Expanded(
                                      //   child: TextFormField(
                                      //     controller: houseNumberController,
                                      //     decoration: InputDecoration(
                                      //       labelText: 'Nr. *',
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
                                      //     validator: (value) => value?.isEmpty == true ? 'Bitte Nr. eingeben' : null,
                                      //   ),
                                      // ),
                                    ],
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
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.digitsOnly,
                                            LengthLimitingTextInputFormatter(5),
                                          ],
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
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller: shippingFirstNameController,
                                            decoration: InputDecoration(
                                              labelText: 'Vorname',
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
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: TextFormField(
                                            controller: shippingLastNameController,
                                            decoration: InputDecoration(
                                              labelText: 'Nachname',
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
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: TextFormField(
                                            controller: shippingStreetController,
                                            decoration: InputDecoration(
                                              labelText: 'Straße *',
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
                                                ? 'Bitte Straße eingeben'
                                                : null,
                                          ),
                                        ),
                                        // const SizedBox(width: 16),
                                        // Expanded(
                                        //   child: TextFormField(
                                        //     controller: shippingHouseNumberController,
                                        //     decoration: InputDecoration(
                                        //       labelText: 'Nr. *',
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
                                        //     validator: (value) => _useShippingAddress && value?.isEmpty == true
                                        //         ? 'Bitte Nr. eingeben'
                                        //         : null,
                                        //   ),
                                        // ),
                                      ],
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
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter.digitsOnly,
                                              LengthLimitingTextInputFormatter(5),
                                            ],
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

                            const SizedBox(height: 24),

                            // Footer mit Buttons
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
                                            if (formKey.currentState?.validate() == true) {
                                              try {
                                                final updatedCustomer = Customer(
                                                  id: customer.id,
                                                  name: companyController.text.trim(),
                                                  company: companyController.text.trim(),
                                                  firstName: firstNameController.text.trim(),
                                                  lastName: lastNameController.text.trim(),
                                                  street: streetController.text.trim(),
                                                  houseNumber: houseNumberController.text.trim(),
                                                  zipCode: zipCodeController.text.trim(),
                                                  city: cityController.text.trim(),
                                                  country: countryController.text.trim(),
                                                  countryCode: countryCodeController.text.trim(),
                                                  email: emailController.text.trim(),

                                                  // Neue Felder
                                                  phone1: phone1Controller.text.trim(),
                                                  phone2: phone2Controller.text.trim(),
                                                  vatNumber: vatNumberController.text.trim(),
                                                  eoriNumber: eoriNumberController.text.trim(),
                                                  language: languageController.text.trim(),
                                                  wantsChristmasCard: christmasLetterController.text == 'JA',
                                                  notes: notesController.text.trim(),

                                                  addressSupplement: addressSupplementController.text.trim(),
                                                  districtPOBox: districtPOBoxController.text.trim(),

                                                  // Abweichende Lieferadresse
                                                  hasDifferentShippingAddress: _useShippingAddress,
                                                  shippingCompany: _useShippingAddress ? shippingCompanyController.text.trim() : '',
                                                  shippingFirstName: _useShippingAddress ? shippingFirstNameController.text.trim() : '',
                                                  shippingLastName: _useShippingAddress ? shippingLastNameController.text.trim() : '',
                                                  shippingStreet: _useShippingAddress ? shippingStreetController.text.trim() : '',
                                                  shippingHouseNumber: _useShippingAddress ? shippingHouseNumberController.text.trim() : '',
                                                  shippingZipCode: _useShippingAddress ? shippingZipCodeController.text.trim() : '',
                                                  shippingCity: _useShippingAddress ? shippingCityController.text.trim() : '',
                                                  shippingCountry: _useShippingAddress ? shippingCountryController.text.trim() : '',
                                                  shippingCountryCode: _useShippingAddress ? shippingCountryCodeController.text.trim() : '',
                                                  shippingPhone: _useShippingAddress ? shippingPhoneController.text.trim() : '',
                                                  shippingEmail: _useShippingAddress ? shippingEmailController.text.trim() : '',
                                                );


                                                print("test111");

                                                await FirebaseFirestore.instance
                                                    .collection('customers')
                                                    .doc(customer.id)
                                                    .update(updatedCustomer.toMap());

                                                if (context.mounted) {
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
    final shippingCityController = TextEditingController();
    final shippingCountryController = TextEditingController();
    final shippingCountryCodeController = TextEditingController();
    final shippingEmailController = TextEditingController();
    final shippingPhoneController = TextEditingController();

    bool _useShippingAddress = false;

    Customer? newCustomer;





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
    const SizedBox(height: 16),
    Row(
    children: [
    Expanded(
    child: TextFormField(
    controller: vatNumberController,
    decoration: InputDecoration(
    labelText: 'MwSt-Nummer',
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
    const SizedBox(width: 16),
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
    ],
    ),
    ],
    ),
    ),

    const SizedBox(height: 16),

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
    // Vorname und Nachname in einer Reihe
    Row(
    children: [
    Expanded(
    child: TextFormField(
    controller: firstNameController,
    decoration: InputDecoration(
    labelText: 'Vorname',
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
   // validator: (value) => value?.isEmpty == true ? 'Bitte Vorname eingeben' : null,
    ),
    ),
    const SizedBox(width: 16),
    Expanded(
    child: TextFormField(
    controller: lastNameController,
    decoration: InputDecoration(
    labelText: 'Nachname',
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
  //  validator: (value) => value?.isEmpty == true ? 'Bitte Nachname eingeben' : null,
    ),
    ),
    ],
    ),
    const SizedBox(height: 16),
    // E-Mail mit Icon
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
    // Telefonnummern
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
    keyboardType: TextInputType.number,
    inputFormatters: [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(5),
    ],
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
    // Land mit Flag-Icon
      CountryDropdown(
        countryController: countryController,
        countryCodeController: countryCodeController,
        label: 'Land',
        isRequired: true,
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
      // Im showEditCustomerDialog und showNewCustomerDialog,
// ersetze den bestehenden Code für Vor- und Nachname in der Lieferadresse:


// NEUE VERSION:
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
                // Option zum Kopieren der Hauptkontaktperson
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      shippingFirstNameController.text = firstNameController.text;
                      shippingLastNameController.text = lastNameController.text;
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
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: shippingFirstNameController,
                  decoration: InputDecoration(
                    labelText: 'Vorname',
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
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: shippingLastNameController,
                  decoration: InputDecoration(
                    labelText: 'Nachname',
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
    labelText: 'Straße *',
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
    ? 'Bitte Straße eingeben'
        : null,
    ),
    ),
    // const SizedBox(width: 16),
    // Expanded(
    // child: TextFormField(
    // controller: shippingHouseNumberController,
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
    // validator: (value) => _useShippingAddress && value?.isEmpty == true
    // ? 'Bitte Nr. eingeben'
    //     : null,
    // ),
    // ),
    ],
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
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(5),
      ],
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
                      if (formKey.currentState?.validate() == true) {
                        try {
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
                            country: countryController.text.trim(),
                            countryCode: countryCodeController.text.trim(),
                            email: emailController.text.trim(),

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
                            shippingCity: _useShippingAddress ? shippingCityController.text.trim() : '',
                            shippingCountry: _useShippingAddress ? shippingCountryController.text.trim() : '',
                            shippingCountryCode: _useShippingAddress ? shippingCountryCodeController.text.trim() : '',
                            shippingPhone: _useShippingAddress ? shippingPhoneController.text.trim() : '',
                            shippingEmail: _useShippingAddress ? shippingEmailController.text.trim() : '',
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
  const _CustomerSelectionBottomSheet();

  @override
  _CustomerSelectionBottomSheetState createState() => _CustomerSelectionBottomSheetState();
}

class _CustomerSelectionBottomSheetState extends State<_CustomerSelectionBottomSheet> {
  final TextEditingController customerSearchController = TextEditingController();
  Customer? selectedCustomer;

  // Speichern aller geladenen Kunden für Client-seitiges Filtern
  List<Customer> _allLoadedCustomers = [];
  List<DocumentSnapshot> _customerDocs = [];
  bool _isLoading = false;
  bool _hasMore = true;
  final int _limit = 10;
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  String _lastSearchTerm = '';





  @override
  void initState() {
    super.initState();
    _loadInitialCustomers();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
          !_isLoading &&
          _hasMore) {
        _loadMoreCustomers();
      }
    });

    // Hinzufügen des Listeners für die Suche mit Debounce
    customerSearchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (customerSearchController.text != _lastSearchTerm) {
        _lastSearchTerm = customerSearchController.text;

        if (_lastSearchTerm.isEmpty) {
          // Wenn Suche gelöscht wird, ursprüngliche Daten neu laden
          setState(() {
            _customerDocs = [];
            _hasMore = true;
            _allLoadedCustomers = [];
          });
          _loadInitialCustomers();
        } else {
          // Mit Suchtext führen wir eine Client-seitige Suche durch
          _performSearch();
        }
      }
    });
  }

  void _performSearch() {
    setState(() {
      _isLoading = true;
    });

    // Wenn wir bereits genügend Kunden geladen haben, filtern wir sie Client-seitig
    if (_allLoadedCustomers.length > 20) {
      _filterExistingResults();
    } else {
      // Wenn wir nicht viele Kunden geladen haben, holen wir mehr von Firestore
      _loadAllCustomersForSearch();
    }
  }

  void _filterExistingResults() {
    // Filtern der bereits geladenen Kunden
    final filteredDocs = _customerDocs.where((doc) {
      final customer = Customer.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      final searchTerm = _lastSearchTerm.toLowerCase();

      return customer.company.toLowerCase().contains(searchTerm) ||
          customer.firstName.toLowerCase().contains(searchTerm) ||
          customer.lastName.toLowerCase().contains(searchTerm) ||
          customer.city.toLowerCase().contains(searchTerm) ||
          customer.email.toLowerCase().contains(searchTerm);
    }).toList();

    setState(() {
      _customerDocs = filteredDocs;
      _hasMore = false; // Keine weiteren Daten mehr zu laden beim Filtern
      _isLoading = false;
    });
  }

  Future<void> _loadAllCustomersForSearch() async {
    // Für eine umfassende Suche laden wir mehr Kunden
    // Dies könnte in einer Produktionsapp mit serverseitiger Suche optimiert werden
    final searchSnapshot = await FirebaseFirestore.instance
        .collection('customers')
        .orderBy('company')
        .get();

    // Ergebnisse verarbeiten
    List<DocumentSnapshot> matchingDocs = [];

    for (var doc in searchSnapshot.docs) {
      final customer = Customer.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      final searchTerm = _lastSearchTerm.toLowerCase();

      if (customer.company.toLowerCase().contains(searchTerm) ||
          customer.firstName.toLowerCase().contains(searchTerm) ||
          customer.lastName.toLowerCase().contains(searchTerm) ||
          customer.city.toLowerCase().contains(searchTerm) ||
          customer.email.toLowerCase().contains(searchTerm)) {
        matchingDocs.add(doc);
      }
    }

    setState(() {
      _customerDocs = matchingDocs;
      _allLoadedCustomers = matchingDocs.map((doc) =>
          Customer.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
      _hasMore = false; // Alle Ergebnisse geladen
      _isLoading = false;
    });
  }

  Future<void> _loadInitialCustomers() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final query = await FirebaseFirestore.instance
          .collection('customers')
          .orderBy('company')
          .limit(_limit)
          .get();

      setState(() {
        _customerDocs = query.docs;
        // Alle geladenen Kunden für Client-seitiges Filtern speichern
        _allLoadedCustomers = query.docs.map((doc) =>
            Customer.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
        _hasMore = query.docs.length == _limit;
        _isLoading = false;
      });
    } catch (error) {
      print('Fehler beim Laden der Kunden: $error');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreCustomers() async {
    if (_isLoading || !_hasMore || _customerDocs.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final lastDoc = _customerDocs.last;

      final query = await FirebaseFirestore.instance
          .collection('customers')
          .orderBy('company')
          .startAfterDocument(lastDoc)
          .limit(_limit)
          .get();

      if (mounted) {
        setState(() {
          _customerDocs.addAll(query.docs);
          // Zu unserem Client-seitigen Speicher für Filterung hinzufügen
          _allLoadedCustomers.addAll(query.docs.map((doc) =>
              Customer.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList());
          _hasMore = query.docs.length == _limit;
          _isLoading = false;
        });
      }
    } catch (error) {
      print('Fehler beim Laden weiterer Kunden: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
                IconButton(
                  onPressed: () async {
                    final newCustomer = await CustomerSelectionSheet.showNewCustomerDialog(context);
                    if (newCustomer != null) {
                      setState(() {
                        selectedCustomer = newCustomer;
                      });
                    }
                  },
                  icon: getAdaptiveIcon(iconName: 'add', defaultIcon: Icons.add),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
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

          // Suchstatus anzeigen (optional)
          if (_lastSearchTerm.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Text(
                'Suchergebnisse für "${_lastSearchTerm}" (${_customerDocs.length})',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ),

          // Kundenliste
          Expanded(
            child: _isLoading && _customerDocs.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _customerDocs.isEmpty
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
              itemCount: _customerDocs.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _customerDocs.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final doc = _customerDocs[index];
                final customer = Customer.fromMap(doc.data() as Map<String, dynamic>, doc.id);
                final isSelected = selectedCustomer?.id == customer.id;

                return _buildCustomerListTile(customer, isSelected);
              },
            ),
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
        leading: CircleAvatar(
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
          onPressed: () => CustomerSelectionSheet.showEditCustomerDialog(context, customer),
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

/// Vollbild-Screen zur Kundenverwaltung
class CustomerManagementScreen extends StatefulWidget {
  const CustomerManagementScreen({Key? key}) : super(key: key);

  @override
  CustomerManagementScreenState createState() => CustomerManagementScreenState();
}

class CustomerManagementScreenState extends State<CustomerManagementScreen> {
  final TextEditingController searchController = TextEditingController();
  List<DocumentSnapshot> _customerDocs = [];
  bool _isLoading = false;
  bool _hasMore = true;
  final int _limit = 10;
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  String _lastSearchTerm = '';
  List<Customer> _allLoadedCustomers = [];
// Filter-bezogene Variablen
  Map<String, dynamic> _activeFilters = CustomerFilterService.createEmptyFilter();
  StreamSubscription<Map<String, dynamic>>? _filterSubscription;
  bool _isFilteredDataLoading = false;
  @override
  void initState() {
    super.initState();
    _loadFilters(); // NEU
    _loadInitialCustomers();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
          !_isLoading &&
          _hasMore &&
          !CustomerFilterService.hasActiveFilters(_activeFilters)) { // NEU: Check für aktive Filter
        _loadMoreCustomers();
      }
    });

    searchController.addListener(_onSearchChanged);
  }
  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (searchController.text != _lastSearchTerm) {
        _lastSearchTerm = searchController.text;

        if (_lastSearchTerm.isEmpty) {
          // If search is cleared, reload initial data
          setState(() {
            _customerDocs = [];
            _hasMore = true;
            _allLoadedCustomers = [];
          });
          _loadInitialCustomers();
        } else {
          // With search text, we'll do a client-side search with improved loading
          _performSearch();
        }
      }
    });
  }
  void _loadFilters() {
    _filterSubscription = CustomerFilterService.loadSavedFilters().listen((filters) {
      if (mounted) {
        setState(() {
          _activeFilters = filters;
          searchController.text = filters['searchText'] ?? '';
        });
        _applyFilters();
      }
    });
  }

  Future<void> _applyFilters() async {
    if (!CustomerFilterService.hasActiveFilters(_activeFilters)) {
      // Wenn keine Filter aktiv sind, lade normale Daten
      _loadInitialCustomers();
      return;
    }

    setState(() {
      _isFilteredDataLoading = true;
    });

    try {
      // Lade alle Kunden für die Filterung
      final allCustomersSnapshot = await FirebaseFirestore.instance
          .collection('customers')
          .get();

      final allCustomers = allCustomersSnapshot.docs
          .map((doc) => {
        ...doc.data() as Map<String, dynamic>,
        'id': doc.id,
      })
          .toList();

      // Wende Filter an
      final filteredCustomers = await CustomerFilterService.applyClientSideFilters(
        allCustomers,
        _activeFilters,
      );

      // Konvertiere zurück zu DocumentSnapshots für die Anzeige
      setState(() {
        _customerDocs = filteredCustomers.map((customerData) {
          // Erstelle ein Mock-DocumentSnapshot
          return _MockDocumentSnapshot(customerData);
        }).toList();
        _hasMore = false; // Bei gefilterten Daten kein weiteres Laden
        _isFilteredDataLoading = false;
      });
    } catch (e) {
      print('Fehler beim Anwenden der Filter: $e');
      setState(() {
        _isFilteredDataLoading = false;
      });
    }
  }

  void _showFilterDialog() {
    CustomerFilterDialog.show(
      context,
      currentFilters: _activeFilters,
      onApply: (filters) {
        setState(() {
          _activeFilters = filters;
        });
        CustomerFilterService.saveFilters(filters);
      },
    );
  }

  void _showFilterFavorites() {
    CustomerFilterFavoritesSheet.show(
      context,
      onFavoriteSelected: (favoriteData) {
        setState(() {
          _activeFilters = Map<String, dynamic>.from(favoriteData['filters']);
          searchController.text = _activeFilters['searchText'] ?? '';
        });
        CustomerFilterService.saveFilters(_activeFilters);
      },
      onCreateNew: () => _saveCurrentFilterAsFavorite(),
    );
  }

  Future<void> _saveCurrentFilterAsFavorite() async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter-Favorit speichern'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Name für diesen Filter',
            border: OutlineInputBorder(),
            hintText: 'z.B. Premium-Kunden',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      try {
        await CustomerFilterService.saveFavorite(name, _activeFilters);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Filter-Favorit "$name" gespeichert'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fehler beim Speichern: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  void _performSearch() {
    setState(() {
      _isLoading = true;
    });

    // If we have enough customers loaded already, filter them client-side
    if (_allLoadedCustomers.length > 20) {
      _filterExistingResults();
    } else {
      // If we don't have many customers loaded, get more from Firestore
      _loadAllCustomersForSearch();
    }
  }

  void _filterExistingResults() {
    // Filter the already loaded customers
    final filteredDocs = _customerDocs.where((doc) {
      final customer = Customer.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      final searchTerm = _lastSearchTerm.toLowerCase();

      return customer.company.toLowerCase().contains(searchTerm) ||
          customer.firstName.toLowerCase().contains(searchTerm) ||
          customer.lastName.toLowerCase().contains(searchTerm) ||
          customer.city.toLowerCase().contains(searchTerm) ||
          customer.email.toLowerCase().contains(searchTerm);
    }).toList();

    setState(() {
      _customerDocs = filteredDocs;
      _hasMore = false; // No more to load when filtering
      _isLoading = false;
    });
  }

  Future<void> _loadAllCustomersForSearch() async {
    // For a comprehensive search, we'll load more customers
    // This could be optimized with server-side search in a production app
    final searchSnapshot = await FirebaseFirestore.instance
        .collection('customers')
        .orderBy('company')
        .get();

    // Process the results
    List<DocumentSnapshot> matchingDocs = [];

    for (var doc in searchSnapshot.docs) {
      final customer = Customer.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      final searchTerm = _lastSearchTerm.toLowerCase();

      if (customer.company.toLowerCase().contains(searchTerm) ||
          customer.firstName.toLowerCase().contains(searchTerm) ||
          customer.lastName.toLowerCase().contains(searchTerm) ||
          customer.city.toLowerCase().contains(searchTerm) ||
          customer.email.toLowerCase().contains(searchTerm)) {
        matchingDocs.add(doc);
      }
    }

    setState(() {
      _customerDocs = matchingDocs;
      _allLoadedCustomers = matchingDocs.map((doc) =>
          Customer.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
      _hasMore = false; // All results loaded
      _isLoading = false;
    });
  }

  Future<void> _loadInitialCustomers() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('customers')
          .orderBy('company')
          .limit(_limit)
          .get();

      setState(() {
        _customerDocs = querySnapshot.docs;
        // Store all loaded customers for client-side filtering
        _allLoadedCustomers = querySnapshot.docs.map((doc) =>
            Customer.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
        _hasMore = querySnapshot.docs.length == _limit;
        _isLoading = false;
      });
    } catch (error) {
      print('Error loading customers: $error');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreCustomers() async {
    if (_isLoading || !_hasMore || _customerDocs.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final lastDoc = _customerDocs.last;

      final querySnapshot = await FirebaseFirestore.instance
          .collection('customers')
          .orderBy('company')
          .startAfterDocument(lastDoc)
          .limit(_limit)
          .get();

      if (mounted) {
        setState(() {
          _customerDocs.addAll(querySnapshot.docs);
          // Add to our client-side store for filtering
          _allLoadedCustomers.addAll(querySnapshot.docs.map((doc) =>
              Customer.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList());
          _hasMore = querySnapshot.docs.length == _limit;
          _isLoading = false;
        });
      }
    } catch (error) {
      print('Error loading more customers: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Kunden'),
            // Nach dem Suchfeld
            if (CustomerFilterService.hasActiveFilters(_activeFilters))
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Icon(Icons.filter_list, size: 16, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              CustomerFilterService.getFilterSummary(_activeFilters),
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await CustomerFilterService.resetFilters();
                      },
                      child: const Text('Zurücksetzen', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: getAdaptiveIcon(iconName: 'print', defaultIcon: Icons.print),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CustomerLabelPrintScreen(),
                ),
              );
            },
            tooltip: 'Adressetiketten drucken',
          ),
          IconButton(
            icon: getAdaptiveIcon(iconName: 'download', defaultIcon: Icons.download),
            onPressed: () => CustomerExportService.exportCustomersCsv(context),
          ),
          // NEU: Filter-Button
          IconButton(
            icon: Badge(
              isLabelVisible: CustomerFilterService.hasActiveFilters(_activeFilters),
              label: const Text('!'),
              child: getAdaptiveIcon(
                iconName: 'filter_list',
                defaultIcon: Icons.filter_list,
              ),
            ),
            onPressed: _showFilterDialog,
          ),
          // NEU: Favoriten-Button
          IconButton(
            icon: getAdaptiveIcon(
              iconName: 'star',
              defaultIcon: Icons.star,
              color: CustomerFilterService.hasActiveFilters(_activeFilters)
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            onPressed: _showFilterFavorites,
            tooltip: 'Filter-Favoriten',
          ),
        ],
      ),

      body: Column(
        children: [
          // Suchfeld
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: searchController,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Suchen',
                hintStyle: const TextStyle(fontSize: 14),
                prefixIcon: getAdaptiveIcon(
                  iconName: 'search',
                  defaultIcon: Icons.search,
                ),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                  icon: getAdaptiveIcon(
                    iconName: 'clear',
                    defaultIcon: Icons.clear,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      searchController.clear();
                    });
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context)
                    .colorScheme
                    .surfaceVariant
                    .withOpacity(0.5),
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
SizedBox(height:8),
// Filter-Chips anzeigen
          if (CustomerFilterService.hasActiveFilters(_activeFilters))
            Container(
              height: 40,
              margin: const EdgeInsets.only(top: 0,),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // Umsatz-Chip
                  if (_activeFilters['minRevenue'] != null || _activeFilters['maxRevenue'] != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(
                          'Umsatz: ${_activeFilters['minRevenue'] != null ? 'ab CHF ${_activeFilters['minRevenue']}' : ''}${_activeFilters['minRevenue'] != null && _activeFilters['maxRevenue'] != null ? ' - ' : ''}${_activeFilters['maxRevenue'] != null ? 'bis CHF ${_activeFilters['maxRevenue']}' : ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            _activeFilters['minRevenue'] = null;
                            _activeFilters['maxRevenue'] = null;
                          });
                          CustomerFilterService.saveFilters(_activeFilters);
                        },
                      ),
                    ),

                  // Zeitraum-Chip
                  if (_activeFilters['revenueStartDate'] != null || _activeFilters['revenueEndDate'] != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(
                          'Zeitraum: ${_activeFilters['revenueStartDate'] != null ? DateFormat('dd.MM.yy').format(_activeFilters['revenueStartDate']) : ''}${_activeFilters['revenueStartDate'] != null && _activeFilters['revenueEndDate'] != null ? ' - ' : ''}${_activeFilters['revenueEndDate'] != null ? DateFormat('dd.MM.yy').format(_activeFilters['revenueEndDate']) : ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            _activeFilters['revenueStartDate'] = null;
                            _activeFilters['revenueEndDate'] = null;
                          });
                          CustomerFilterService.saveFilters(_activeFilters);
                        },
                      ),
                    ),

                  // Aufträge-Chip
                  if (_activeFilters['minOrderCount'] != null || _activeFilters['maxOrderCount'] != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(
                          'Aufträge: ${_activeFilters['minOrderCount'] ?? ''}${_activeFilters['minOrderCount'] != null && _activeFilters['maxOrderCount'] != null ? '-' : ''}${_activeFilters['maxOrderCount'] ?? ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            _activeFilters['minOrderCount'] = null;
                            _activeFilters['maxOrderCount'] = null;
                          });
                          CustomerFilterService.saveFilters(_activeFilters);
                        },
                      ),
                    ),

                  // Weihnachtskarte-Chip
                  if (_activeFilters['wantsChristmasCard'] != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(
                          'Weihnachtskarte: ${_activeFilters['wantsChristmasCard'] ? 'JA' : 'NEIN'}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            _activeFilters['wantsChristmasCard'] = null;
                          });
                          CustomerFilterService.saveFilters(_activeFilters);
                        },
                      ),
                    ),

                  // MwSt-Nummer-Chip
                  if (_activeFilters['hasVatNumber'] != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(
                          'MwSt-Nr: ${_activeFilters['hasVatNumber'] ? 'Vorhanden' : 'Fehlt'}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            _activeFilters['hasVatNumber'] = null;
                          });
                          CustomerFilterService.saveFilters(_activeFilters);
                        },
                      ),
                    ),

                  // EORI-Nummer-Chip
                  if (_activeFilters['hasEoriNumber'] != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(
                          'EORI-Nr: ${_activeFilters['hasEoriNumber'] ? 'Vorhanden' : 'Fehlt'}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            _activeFilters['hasEoriNumber'] = null;
                          });
                          CustomerFilterService.saveFilters(_activeFilters);
                        },
                      ),
                    ),

                  // Länder-Chip
                  if ((_activeFilters['countries'] as List?)?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(
                          '${(_activeFilters['countries'] as List).length} Länder',
                          style: const TextStyle(fontSize: 12),
                        ),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            _activeFilters['countries'] = [];
                          });
                          CustomerFilterService.saveFilters(_activeFilters);
                        },
                      ),
                    ),

                  // Sprachen-Chip
                  if ((_activeFilters['languages'] as List?)?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(
                          '${(_activeFilters['languages'] as List).length} Sprachen',
                          style: const TextStyle(fontSize: 12),
                        ),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            _activeFilters['languages'] = [];
                          });
                          CustomerFilterService.saveFilters(_activeFilters);
                        },
                      ),
                    ),
                ],
              ),
            ),
          // Search status
          if (_lastSearchTerm.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Text(
                    'Suchergebnisse für "${_lastSearchTerm}"',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_customerDocs.length} Ergebnisse',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ),
SizedBox(height: 8,),
          // Kundenliste mit Lazy Loading
          Expanded(
            child: _isLoading && _customerDocs.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _customerDocs.isEmpty
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
              itemCount: _customerDocs.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _customerDocs.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final doc = _customerDocs[index];
                final customer = Customer.fromMap(doc.data() as Map<String, dynamic>, doc.id);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor,
                      child: Text(
                        customer.company.isNotEmpty ? customer.company.substring(0, 1).toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      customer.company,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(customer.fullName),
                        Text('${customer.zipCode} ${customer.city}'),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: getAdaptiveIcon(iconName: 'edit', defaultIcon: Icons.edit),
                          onPressed: () async {
                            await CustomerSelectionSheet.showEditCustomerDialog(context, customer);
                            // Refresh list after edit
                            if (_lastSearchTerm.isEmpty) {
                              _loadInitialCustomers();
                            } else {
                              _performSearch();
                            }
                          },
                        ),
                        IconButton(
                          icon: getAdaptiveIcon(iconName: 'delete', defaultIcon: Icons.delete),
                          onPressed: () {
                            _showDeleteConfirmation(context, customer);
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      _showCustomerDetails(context, customer);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(

        onPressed: () async {
          final newCustomer = await CustomerSelectionSheet.showNewCustomerDialog(context);
          if (newCustomer != null) {
            // Reload customers to include the new one
            setState(() {
              _customerDocs = [];
              _hasMore = true;
              _allLoadedCustomers = [];
              _lastSearchTerm = '';
              searchController.clear();
            });
            _loadInitialCustomers();
          }
        },
        child: getAdaptiveIcon(iconName: 'add', defaultIcon: Icons.add),
        tooltip: 'Neuer Kunde',
      ),
    );
  }

  // Löschbestätigung anzeigen
  void _showDeleteConfirmation(BuildContext context, Customer customer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kunde löschen'),
        content: Text(
          'Möchtest du den Kunden "${customer.company}" wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await CustomerSelectionSheet.deleteCustomer(context, customer.id);
              if (success && context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Kunde wurde gelöscht'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }

  void _showCustomerDetails(BuildContext context, Customer customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
        child: DefaultTabController(
          length: 2,
          child: Column(
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
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor,
                      child: Text(
                        customer.name.isNotEmpty
                            ? customer.name.substring(0, 1).toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.name.isNotEmpty ? customer.name : 'Unbenannter Kunde',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (customer.countryCode?.isNotEmpty == true)
                            Text(
                              'Länderkürzel: ${customer.countryCode}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                    ),
                  ],
                ),
              ),

              // Tab-Bar
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                ),
                child: TabBar(
                  tabs: [
                    Tab(
                      icon: getAdaptiveIcon(iconName: 'person', defaultIcon: Icons.person),
                      text: 'Details',
                    ),
                    Tab(
                      icon: getAdaptiveIcon(iconName: 'shopping_bag', defaultIcon: Icons.shopping_bag),
                      text: 'Kaufhistorie',
                    ),
                  ],
                ),
              ),

              // Tab-Views
              Expanded(
                child: TabBarView(
                  children: [
                    // Tab 1: Kundendetails
                    _buildCustomerDetailsTab(context, customer),

                    // Tab 2: Kaufhistorie
                    _buildPurchaseHistoryTab(context, customer),
                  ],
                ),
              ),

              // Aktionsbuttons
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            CustomerSelectionSheet.showEditCustomerDialog(context, customer);
                          },
                          icon: getAdaptiveIcon(iconName: 'edit', defaultIcon: Icons.edit),
                          label: const Text('Bearbeiten'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showDeleteConfirmation(context, customer);
                          },
                          icon: getAdaptiveIcon(iconName: 'delete', defaultIcon: Icons.delete),
                          label: const Text('Löschen'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// Tab 1: Kundendetails (dein bestehender Code)
  Widget _buildCustomerDetailsTab(BuildContext context, Customer customer) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grunddaten
          _buildDetailSection(
            context,
            'Grunddaten',
            [
              _buildDetailRow('Kunden-ID', customer.id.isNotEmpty ? customer.id : 'Noch nicht vergeben'),
              _buildDetailRow('Name/Firma', customer.name),
              if (customer.company?.isNotEmpty == true)
                _buildDetailRow('Firma', customer.company!),
              if (customer.firstName?.isNotEmpty == true)
                _buildDetailRow('Vorname', customer.firstName!),
              if (customer.lastName?.isNotEmpty == true)
                _buildDetailRow('Nachname', customer.lastName!),
            ],
          ),

          const SizedBox(height: 16),

          // Kontaktdaten
          _buildDetailSection(
            context,
            'Kontaktdaten',
            [
              if (customer.email?.isNotEmpty == true)
                _buildDetailRow('E-Mail', customer.email!),
              if (customer.phone1?.isNotEmpty == true)
                _buildDetailRow('Telefon 1', customer.phone1!),
              if (customer.phone2?.isNotEmpty == true)
                _buildDetailRow('Telefon 2', customer.phone2!),
            ],
          ),

          const SizedBox(height: 16),

          // Rechnungsadresse
          _buildDetailSection(
            context,
            'Rechnungsadresse',
            [
              if (customer.street?.isNotEmpty == true)
                _buildDetailRow('Straße', '${customer.street}${customer.houseNumber?.isNotEmpty == true ? ' ${customer.houseNumber}' : ''}'),
              if (customer.addressSupplement?.isNotEmpty == true)
                _buildDetailRow('Adresszusatz', customer.addressSupplement!),
              if (customer.districtPOBox?.isNotEmpty == true)
                _buildDetailRow('Bezirk/Postfach', customer.districtPOBox!),
              if (customer.zipCode?.isNotEmpty == true || customer.city?.isNotEmpty == true)
                _buildDetailRow('Ort', '${customer.zipCode ?? ''} ${customer.city ?? ''}'),
              if (customer.country?.isNotEmpty == true)
                _buildDetailRow('Land', '${customer.country}${customer.countryCode?.isNotEmpty == true ? ' (${customer.countryCode})' : ''}'),
            ],
          ),

          const SizedBox(height: 16),

          // Steuerliche Angaben
          if (customer.vatNumber?.isNotEmpty == true || customer.eoriNumber?.isNotEmpty == true)
            _buildDetailSection(
              context,
              'Steuerliche Angaben',
              [
                if (customer.vatNumber?.isNotEmpty == true)
                  _buildDetailRow('MwSt-Nummer / UID', customer.vatNumber!),
                if (customer.eoriNumber?.isNotEmpty == true)
                  _buildDetailRow('EORI-Nummer', customer.eoriNumber!),
              ],
            ),

          if (customer.vatNumber?.isNotEmpty == true || customer.eoriNumber?.isNotEmpty == true)
            const SizedBox(height: 16),

          // Lieferadresse (falls abweichend)
          if (customer.hasDifferentShippingAddress) ...[
            _buildDetailSection(
              context,
              'Lieferadresse',
              [
                if (customer.shippingCompany?.isNotEmpty == true)
                  _buildDetailRow('Firma', customer.shippingCompany!),
                if (customer.shippingFirstName?.isNotEmpty == true || customer.shippingLastName?.isNotEmpty == true)
                  _buildDetailRow('Name', '${customer.shippingFirstName ?? ''} ${customer.shippingLastName ?? ''}'),
                if (customer.shippingStreet?.isNotEmpty == true)
                  _buildDetailRow('Straße', '${customer.shippingStreet}${customer.shippingHouseNumber?.isNotEmpty == true ? ' ${customer.shippingHouseNumber}' : ''}'),
                if (customer.shippingZipCode?.isNotEmpty == true || customer.shippingCity?.isNotEmpty == true)
                  _buildDetailRow('Ort', '${customer.shippingZipCode ?? ''} ${customer.shippingCity ?? ''}'),
                if (customer.shippingCountry?.isNotEmpty == true)
                  _buildDetailRow('Land', '${customer.shippingCountry}${customer.shippingCountryCode?.isNotEmpty == true ? ' (${customer.shippingCountryCode})' : ''}'),
                if (customer.shippingEmail?.isNotEmpty == true)
                  _buildDetailRow('E-Mail', customer.shippingEmail!),
                if (customer.shippingPhone?.isNotEmpty == true)
                  _buildDetailRow('Telefon', customer.shippingPhone!),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Weitere Informationen
          _buildDetailSection(
            context,
            'Weitere Informationen',
            [
              _buildDetailRow('Sprache', customer.language == 'DE' ? 'Deutsch' :
              customer.language == 'EN' ? 'Englisch' :
              customer.language ?? 'Nicht angegeben'),
              _buildDetailRow('Weihnachtskarte', customer.wantsChristmasCard ? 'JA' : 'NEIN'),
              _buildDetailRow('Abweichende Lieferadresse', customer.hasDifferentShippingAddress ? 'JA' : 'NEIN'),
              if (customer.notes?.isNotEmpty == true)
                _buildDetailRow('Notizen', customer.notes!),
            ],
          ),
        ],
      ),
    );
  }

// In der _buildPurchaseHistoryTab Methode, ersetze den StreamBuilder mit:

  Widget _buildPurchaseHistoryTab(BuildContext context, Customer customer) {
    return Column(
      children: [
        // Statistiken-Header bleibt gleich
        FutureBuilder<Map<String, dynamic>>(
          future: _getCustomerStats(customer.id),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final stats = snapshot.data!;
              return Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                '${stats['totalQuotes']}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text('Angebote'),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                '${stats['totalOrders']}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text('Aufträge'),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                'CHF ${stats['totalSpent'].toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text('Gesamt'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Info-Text
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Alle Beträge in CHF (Basis-Währung)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }
            return const SizedBox(height: 80);
          },
        ),

        // Tab-Ansicht für Angebote und Aufträge
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                TabBar(
                  tabs: [
                    Tab(text: 'Aufträge'),
                    Tab(text: 'Angebote'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Aufträge Tab
                      _buildOrdersList(customer),
                      // Angebote Tab
                      _buildQuotesList(customer),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

// Neue Methode für Aufträge
  Widget _buildOrdersList(Customer customer) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('customer.id', isEqualTo: customer.id)
          .orderBy('orderDate', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                getAdaptiveIcon(iconName: 'error', defaultIcon: Icons.error, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Fehler beim Laden der Aufträge',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data?.docs ?? [];

        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                getAdaptiveIcon(iconName: 'shopping_bag_outlined', defaultIcon: Icons.shopping_bag_outlined, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Noch keine Aufträge',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Dieser Kunde hat noch keine Aufträge',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final orderDoc = orders[index];
            final order = orderDoc.data() as Map<String, dynamic>;
            return _buildOrderListTile(context, orderDoc.id, order);
          },
        );
      },
    );
  }

// Neue Methode für Angebote
  Widget _buildQuotesList(Customer customer) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('quotes')
          .where('customer.id', isEqualTo: customer.id)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                getAdaptiveIcon(iconName: 'error', defaultIcon: Icons.error, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Fehler beim Laden der Angebote',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final quotes = snapshot.data?.docs ?? [];

        if (quotes.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                getAdaptiveIcon(iconName: 'description_outlined', defaultIcon: Icons.description_outlined, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Noch keine Angebote',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Dieser Kunde hat noch keine Angebote erhalten',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: quotes.length,
          itemBuilder: (context, index) {
            final quoteDoc = quotes[index];
            final quote = quoteDoc.data() as Map<String, dynamic>;
            return _buildQuoteListTile(context, quoteDoc.id, quote);
          },
        );
      },
    );
  }

// Für Orders
  Widget _buildOrderListTile(BuildContext context, String orderId, Map<String, dynamic> order) {
    final calculations = order['calculations'] as Map<String, dynamic>? ?? {};
    final items = order['items'] as List<dynamic>? ?? [];
    final orderDate = (order['orderDate'] as Timestamp?)?.toDate() ?? DateTime.now();

    // Der total ist in CHF gespeichert
    final totalInCHF = (calculations['total'] as num?)?.toDouble() ?? 0;

    // Hole Währung und Exchange Rates
    final currency = order['metadata']?['currency'] ?? 'CHF';
    final exchangeRates = order['metadata']?['exchangeRates'] as Map<String, dynamic>? ?? {};
    final rate = (exchangeRates[currency] as num?)?.toDouble() ?? 1.0;

    // Rechne um falls nicht CHF
    final displayTotal = currency == 'CHF' ? totalInCHF : totalInCHF * rate;

    final orderNumber = order['orderNumber'] as String? ?? orderId;
    final status = order['status'] as String? ?? 'pending';
    final paymentStatus = order['paymentStatus'] as String? ?? 'pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: getAdaptiveIcon(iconName: 'shopping_bag', defaultIcon: Icons.shopping_bag),
        ),
        title: Text(
          'Auftrag $orderNumber',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('dd.MM.yyyy HH:mm').format(orderDate)),
            Text('${items.length} Artikel'),
            Row(
              children: [
                _buildStatusChip(status),
                const SizedBox(width: 8),
                _buildPaymentStatusChip(paymentStatus),
              ],
            ),
          ],
        ),
        trailing: Text(
          '$currency ${displayTotal.toStringAsFixed(2)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        onTap: () => _showOrderDetails(context, orderId, order),
      ),
    );
  }

// Für Quotes
  Widget _buildQuoteListTile(BuildContext context, String quoteId, Map<String, dynamic> quote) {
    final calculations = quote['calculations'] as Map<String, dynamic>? ?? {};
    final items = quote['items'] as List<dynamic>? ?? [];
    final createdAt = (quote['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final validUntil = (quote['validUntil'] as Timestamp?)?.toDate() ?? DateTime.now();

    // Der total ist in CHF gespeichert
    final totalInCHF = (calculations['total'] as num?)?.toDouble() ?? 0;

    // Hole Währung und Exchange Rates
    final currency = quote['metadata']?['currency'] ?? 'CHF';
    final exchangeRates = quote['metadata']?['exchangeRates'] as Map<String, dynamic>? ?? {};
    final rate = (exchangeRates[currency] as num?)?.toDouble() ?? 1.0;

    // Rechne um falls nicht CHF
    final displayTotal = currency == 'CHF' ? totalInCHF : totalInCHF * rate;

    final quoteNumber = quote['quoteNumber'] as String? ?? quoteId;
    final status = quote['status'] as String? ?? 'open';

    // Prüfe ob Angebot abgelaufen ist
    final isExpired = validUntil.isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          child: getAdaptiveIcon(iconName: 'description', defaultIcon: Icons.description),
        ),
        title: Text(
          'Angebot $quoteNumber',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('dd.MM.yyyy').format(createdAt)),
            Text('${items.length} Artikel'),
            Row(
              children: [
                _buildQuoteStatusChip(status, isExpired),
                const SizedBox(width: 8),
                if (!isExpired && status == 'open')
                  Text(
                    'Gültig bis ${DateFormat('dd.MM.yyyy').format(validUntil)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: Text(
          '$currency ${displayTotal.toStringAsFixed(2)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        onTap: () => _showQuoteDetails(context, quoteId, quote),
      ),
    );
  }
  void _showOrderDetails(BuildContext context, String orderId, Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  getAdaptiveIcon(iconName: 'shopping_bag', defaultIcon: Icons.shopping_bag),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Auftrag ${order['orderNumber']}',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          DateFormat('dd.MM.yyyy').format(
                              (order['orderDate'] as Timestamp).toDate()
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(bottomSheetContext),
                    icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                  ),
                ],
              ),
            ),

            const Divider(),

            // Dokumente Liste
            Expanded(
              child: (order['documents'] as Map<String, dynamic>?)?.isNotEmpty ?? false
                  ? ListView(
                padding: const EdgeInsets.all(16),
                children: (order['documents'] as Map<String, dynamic>).entries.map((entry) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.red.withOpacity(0.1),
                        child: const Icon(
                          Icons.picture_as_pdf,
                          color: Colors.red,
                        ),
                      ),
                      title: Text(_getDocumentTypeName(entry.key)),
                      trailing: IconButton(
                        icon: getAdaptiveIcon(
                          iconName: 'open_in_new',
                          defaultIcon: Icons.open_in_new,
                        ),
                        onPressed: () => _openDocument(entry.value),
                      ),
                    ),
                  );
                }).toList(),
              )
                  : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    getAdaptiveIcon(
                      iconName: 'description',
                      defaultIcon: Icons.description,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Keine Dokumente verfügbar',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDocumentTypeName(String key) {
    switch (key) {
      case 'quote_pdf':
        return 'Angebot';
      case 'invoice_pdf':
        return 'Rechnung';
      case 'delivery_note_pdf':
        return 'Lieferschein';
      case 'commercial_invoice_pdf':
        return 'Handelsrechnung';
      case 'packing_list_pdf':
        return 'Packliste';
      case 'veranlagungsverfuegung_pdf':
        return 'Veranlagungsverfügung';
      default:
        return key.replaceAll('_', ' ').replaceAll('-', ' ').toUpperCase();
    }
  }
// Helper Widget für Order Status
  Widget _buildOrderStatusCard(BuildContext context, String label, String status, IconData icon) {
    Color color;
    String text;

    switch (status) {
      case 'pending':
        color = Colors.orange;
        text = 'Ausstehend';
        break;
      case 'processing':
        color = Colors.blue;
        text = 'In Bearbeitung';
        break;
      case 'shipped':
        color = Colors.purple;
        text = 'Versendet';
        break;
      case 'delivered':
        color = Colors.green;
        text = 'Geliefert';
        break;
      case 'cancelled':
        color = Colors.red;
        text = 'Storniert';
        break;
      default:
        color = Colors.grey;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

// Helper Widget für Payment Status
  Widget _buildOrderPaymentStatusCard(BuildContext context, String label, String status, IconData icon) {
    Color color;
    String text;

    switch (status) {
      case 'pending':
        color = Colors.orange;
        text = 'Offen';
        break;
      case 'partial':
        color = Colors.blue;
        text = 'Teilzahlung';
        break;
      case 'paid':
        color = Colors.green;
        text = 'Bezahlt';
        break;
      default:
        color = Colors.grey;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  void _showQuoteDetails(BuildContext context, String quoteId, Map<String, dynamic> quote) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  getAdaptiveIcon(iconName: 'description', defaultIcon: Icons.description),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Angebot ${quote['quoteNumber']}',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          DateFormat('dd.MM.yyyy').format(
                              (quote['createdAt'] as Timestamp).toDate()
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(bottomSheetContext),
                    icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                  ),
                ],
              ),
            ),

            const Divider(),

            // Dokumente Liste
            Expanded(
              child: (quote['documents'] as Map<String, dynamic>?)?.isNotEmpty ?? false
                  ? ListView(
                padding: const EdgeInsets.all(16),
                children: (quote['documents'] as Map<String, dynamic>).entries.map((entry) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.red.withOpacity(0.1),
                        child: const Icon(
                          Icons.picture_as_pdf,
                          color: Colors.red,
                        ),
                      ),
                      title: Text(_getDocumentTypeName(entry.key)),
                      trailing: IconButton(
                        icon: getAdaptiveIcon(
                          iconName: 'open_in_new',
                          defaultIcon: Icons.open_in_new,
                        ),
                        onPressed: () => _openDocument(entry.value),
                      ),
                    ),
                  );
                }).toList(),
              )
                  : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    getAdaptiveIcon(
                      iconName: 'picture_as_pdf',
                      defaultIcon: Icons.picture_as_pdf,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Kein PDF verfügbar',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

// Hilfsmethode zum Öffnen von Dokumenten (aus deinem orders_overview_screen)
  Future<void> _openDocument(String url) async {
    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (!await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication)) {
          await launchUrl(uri, mode: LaunchMode.inAppWebView);
        }
      }
    } catch (e) {
      if (mounted) {
        await Clipboard.setData(ClipboardData(text: url));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link wurde in die Zwischenablage kopiert'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
// Helper für Quote Status
  Widget _buildQuoteStatusWidget(BuildContext context, Map<String, dynamic> quote) {
    final status = quote['status'] as String? ?? 'open';
    final validUntil = (quote['validUntil'] as Timestamp).toDate();
    final isExpired = validUntil.isBefore(DateTime.now());

    Color color;
    IconData icon;
    String text;

    if (isExpired && status == 'open') {
      color = Colors.grey;
      icon = Icons.timer_off;
      text = 'Angebot ist abgelaufen';
    } else {
      switch (status) {
        case 'accepted':
          color = Colors.green;
          icon = Icons.check_circle;
          text = 'Angebot wurde angenommen';
          break;
        case 'rejected':
          color = Colors.red;
          icon = Icons.cancel;
          text = 'Angebot wurde abgelehnt';
          break;
        default:
          color = Colors.blue;
          icon = Icons.schedule;
          text = 'Angebot ist offen';
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

// Helper für Status-Chips
  Widget _buildStatusChip(String status) {
    Color color;
    String displayText;

    switch (status) {
      case 'pending':
        color = Colors.orange;
        displayText = 'Ausstehend';
        break;
      case 'processing':
        color = Colors.blue;
        displayText = 'In Bearbeitung';
        break;
      case 'shipped':
        color = Colors.purple;
        displayText = 'Versendet';
        break;
      case 'delivered':
        color = Colors.green;
        displayText = 'Geliefert';
        break;
      case 'cancelled':
        color = Colors.red;
        displayText = 'Storniert';
        break;
      default:
        color = Colors.grey;
        displayText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPaymentStatusChip(String status) {
    Color color;
    String displayText;

    switch (status) {
      case 'pending':
        color = Colors.orange;
        displayText = 'Offen';
        break;
      case 'partial':
        color = Colors.blue;
        displayText = 'Teilweise';
        break;
      case 'paid':
        color = Colors.green;
        displayText = 'Bezahlt';
        break;
      default:
        color = Colors.grey;
        displayText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          getAdaptiveIcon(iconName: 'euro', defaultIcon: Icons.euro, size: 10, color: color),
          const SizedBox(width: 2),
          Text(
            displayText,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteStatusChip(String status, bool isExpired) {
    Color color;
    String displayText;

    if (isExpired && status == 'open') {
      color = Colors.grey;
      displayText = 'Abgelaufen';
    } else {
      switch (status) {
        case 'open':
          color = Colors.blue;
          displayText = 'Offen';
          break;
        case 'accepted':
          color = Colors.green;
          displayText = 'Angenommen';
          break;
        case 'rejected':
          color = Colors.red;
          displayText = 'Abgelehnt';
          break;
        default:
          color = Colors.grey;
          displayText = status;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

// Aktualisierte Statistiken-Methode
  Future<Map<String, dynamic>> _getCustomerStats(String customerId) async {
    try {
      // Hole Aufträge
      final orders = await FirebaseFirestore.instance
          .collection('orders')
          .where('customer.id', isEqualTo: customerId)
          .get();

      // Hole Angebote
      final quotes = await FirebaseFirestore.instance
          .collection('quotes')
          .where('customer.id', isEqualTo: customerId)
          .get();

      // Gruppiere Beträge nach Währung
      Map<String, double> totalsByurrency = {
        'CHF': 0.0,
        'EUR': 0.0,
        'USD': 0.0,
      };

      DateTime? lastActivity;

      // Verarbeite Aufträge
      for (var doc in orders.docs) {
        final data = doc.data();
        final calculations = data['calculations'] as Map<String, dynamic>?;
        final currency = data['metadata']?['currency'] ?? 'CHF';

        if (calculations != null) {
          final total = (calculations['total'] as num?)?.toDouble() ?? 0;
          totalsByurrency[currency] = (totalsByurrency[currency] ?? 0) + total;
        }

        final orderDate = (data['orderDate'] as Timestamp?)?.toDate();
        if (orderDate != null) {
          if (lastActivity == null || orderDate.isAfter(lastActivity)) {
            lastActivity = orderDate;
          }
        }
      }

      // Bestimme Hauptwährung (die am häufigsten verwendet wird)
      String primaryCurrency = 'CHF';
      double maxAmount = 0;

      totalsByurrency.forEach((currency, amount) {
        if (amount > maxAmount) {
          maxAmount = amount;
          primaryCurrency = currency;
        }
      });

      return {
        'totalOrders': orders.docs.length,
        'totalQuotes': quotes.docs.length,
        'totalSpent': totalsByurrency[primaryCurrency] ?? 0.0,
        'currency': primaryCurrency,
        'totalsByCurrency': totalsByurrency, // Falls du alle Währungen anzeigen möchtest
        'lastActivity': lastActivity,
      };
    } catch (e) {
      print('Fehler beim Berechnen der Kundenstatistiken: $e');
      return {
        'totalOrders': 0,
        'totalQuotes': 0,
        'totalSpent': 0.0,
        'currency': 'CHF',
        'totalsByCurrency': {'CHF': 0.0},
        'lastActivity': null,
      };
    }
  }
// Einzelner Kauf in der Liste
  Widget _buildPurchaseListTile(BuildContext context, String receiptId, Map<String, dynamic> purchase) {
    final calculations = purchase['calculations'] as Map<String, dynamic>;
    final items = purchase['items'] as List<dynamic>;
    final metadata = purchase['metadata'] as Map<String, dynamic>;

    final timestamp = metadata['timestamp'] as Timestamp?;
    final date = timestamp?.toDate() ?? DateTime.now();

    final total = calculations['total'] as num? ?? 0;
    final receiptNumber = purchase['receiptNumber'] as String? ?? receiptId;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: getAdaptiveIcon(iconName: 'receipt', defaultIcon: Icons.receipt),
        ),
        title: Text(
          'LS-$receiptNumber',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${DateFormat('dd.MM.yyyy HH:mm').format(date)}'),
            Text('${items.length} Artikel'),
            if (metadata['fairName'] != null)
              Text(
                'Messe: ${metadata['fairName']}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: Text(
          '${total.toStringAsFixed(2)} CHF',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        onTap: () => _showPurchaseDetails(context, receiptId, purchase),
      ),
    );
  }

// Details eines einzelnen Kaufs anzeigen
  void _showPurchaseDetails(BuildContext context, String receiptId, Map<String, dynamic> purchase) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  getAdaptiveIcon(iconName: 'receipt_long', defaultIcon: Icons.receipt_long),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Lieferschein LS-${purchase['receiptNumber']}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: getAdaptiveIcon(iconName: 'close', defaultIcon: Icons.close),
                  ),
                ],
              ),
            ),

            // Artikel-Liste
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: (purchase['items'] as List).length,
                itemBuilder: (context, index) {
                  final item = (purchase['items'] as List)[index];
                  return Card(
                    child: ListTile(
                      title: Text(item['product_name'] ?? 'Unbekanntes Produkt'),
                      subtitle: Text(
                        '${item['quantity']} ${item['unit']} × ${(item['price_per_unit'] as num).toStringAsFixed(2)} CHF',
                      ),
                      trailing: Text(
                        '${(item['total'] as num).toStringAsFixed(2)} CHF',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Gesamtsumme
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Gesamtbetrag:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${(purchase['calculations']['total'] as num).toStringAsFixed(2)} CHF',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Hilfsmethode für Abschnittsdarstellung
  Widget _buildDetailSection(
      BuildContext context,
      String title,
      List<Widget> children,
      ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  // Hilfsmethode für Detailzeile
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Hilfsklasse für gefilterte Daten
class _MockDocumentSnapshot implements DocumentSnapshot {
  final Map<String, dynamic> _data;
  final String _id;

  _MockDocumentSnapshot(Map<String, dynamic> data)
      : _data = Map<String, dynamic>.from(data),
        _id = data['id'] ?? '';

  @override
  Map<String, dynamic> data() => _data;

  @override
  String get id => _id;

  @override
  bool get exists => true;

  @override
  dynamic get(Object field) => _data[field];

  @override
  dynamic operator [](Object field) => _data[field];

  @override
  SnapshotMetadata get metadata => throw UnimplementedError();

  @override
  DocumentReference get reference => throw UnimplementedError();
}