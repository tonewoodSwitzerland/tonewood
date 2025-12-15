import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../customer.dart';
import 'customer_group.dart';


class CustomerGroupService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'customer_groups';

  // Stream aller Kundengruppen (sortiert)
  static Stream<List<CustomerGroup>> getGroupsStream() {
    return _firestore
        .collection(_collection)
        .orderBy('sortOrder')
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => CustomerGroup.fromMap(doc.data(), doc.id))
        .toList());
  }

  // Alle Gruppen einmalig laden
  static Future<List<CustomerGroup>> getAllGroups() async {
    final snapshot = await _firestore
        .collection(_collection)
        .orderBy('sortOrder')
        .get();

    return snapshot.docs
        .map((doc) => CustomerGroup.fromMap(doc.data(), doc.id))
        .toList();
  }

  // Einzelne Gruppe laden
  static Future<CustomerGroup?> getGroup(String groupId) async {
    final doc = await _firestore.collection(_collection).doc(groupId).get();
    if (doc.exists) {
      return CustomerGroup.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  // Gruppe erstellen
  static Future<String> createGroup(CustomerGroup group) async {
    final docRef = await _firestore.collection(_collection).add(group.toMap());
    return docRef.id;
  }

  // Gruppe aktualisieren
  static Future<void> updateGroup(CustomerGroup group) async {
    await _firestore
        .collection(_collection)
        .doc(group.id)
        .update(group.toMap());
  }

  // Gruppe löschen
  static Future<void> deleteGroup(String groupId) async {
    // Erst alle Kunden aktualisieren, die diese Gruppe haben
    final customersWithGroup = await _firestore
        .collection('customers')
        .where('customerGroupIds', arrayContains: groupId)
        .get();

    final batch = _firestore.batch();

    for (var doc in customersWithGroup.docs) {
      final currentGroups = List<String>.from(doc.data()['customerGroupIds'] ?? []);
      currentGroups.remove(groupId);
      batch.update(doc.reference, {'customerGroupIds': currentGroups});
    }

    // Gruppe löschen
    batch.delete(_firestore.collection(_collection).doc(groupId));

    await batch.commit();
  }

  // Standardgruppen initialisieren (falls noch keine vorhanden)
  static Future<void> initializeDefaultGroups() async {
    final existing = await _firestore.collection(_collection).limit(1).get();

    if (existing.docs.isEmpty) {
      final batch = _firestore.batch();

      for (var group in CustomerGroup.defaultGroups) {
        final docRef = _firestore.collection(_collection).doc();
        batch.set(docRef, group.toMap());
      }

      await batch.commit();
    }
  }

  // Anzahl Kunden pro Gruppe
  static Future<Map<String, int>> getCustomerCountPerGroup() async {
    final groups = await getAllGroups();
    final counts = <String, int>{};

    for (var group in groups) {
      final snapshot = await _firestore
          .collection('customers')
          .where('customerGroupIds', arrayContains: group.id)
          .count()
          .get();

      counts[group.id] = snapshot.count ?? 0;
    }

    return counts;
  }

  // Alle Kunden einer Gruppe laden
  static Future<List<Customer>> getCustomersInGroup(String groupId) async {
    final snapshot = await _firestore
        .collection('customers')
        .where('customerGroupIds', arrayContains: groupId)
        .orderBy('company')
        .get();

    return snapshot.docs
        .map((doc) => Customer.fromMap(doc.data(), doc.id))
        .toList();
  }

  // Stream der Kunden einer Gruppe
  static Stream<List<Customer>> getCustomersInGroupStream(String groupId) {
    return _firestore
        .collection('customers')
        .where('customerGroupIds', arrayContains: groupId)
        .orderBy('company')
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => Customer.fromMap(doc.data(), doc.id))
        .toList());
  }

  // E-Mail-Liste einer Gruppe exportieren
  static Future<List<String>> getEmailsForGroup(String groupId) async {
    final customers = await getCustomersInGroup(groupId);
    return customers
        .where((c) => c.email.isNotEmpty)
        .map((c) => c.email)
        .toSet() // Duplikate entfernen
        .toList();
  }

  // E-Mails in Zwischenablage kopieren
  static Future<int> copyEmailsToClipboard(String groupId) async {
    final emails = await getEmailsForGroup(groupId);
    if (emails.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: emails.join('; ')));
    }
    return emails.length;
  }

  // Mehrere Kunden einer Gruppe zuweisen
  static Future<void> addCustomersToGroup(
      List<String> customerIds,
      String groupId,
      ) async {
    final batch = _firestore.batch();

    for (var customerId in customerIds) {
      final docRef = _firestore.collection('customers').doc(customerId);
      batch.update(docRef, {
        'customerGroupIds': FieldValue.arrayUnion([groupId]),
      });
    }

    await batch.commit();
  }

  // Mehrere Kunden aus einer Gruppe entfernen
  static Future<void> removeCustomersFromGroup(
      List<String> customerIds,
      String groupId,
      ) async {
    final batch = _firestore.batch();

    for (var customerId in customerIds) {
      final docRef = _firestore.collection('customers').doc(customerId);
      batch.update(docRef, {
        'customerGroupIds': FieldValue.arrayRemove([groupId]),
      });
    }

    await batch.commit();
  }

  // Kundengruppen für einen Kunden setzen
  static Future<void> setCustomerGroups(
      String customerId,
      List<String> groupIds,
      ) async {
    await _firestore.collection('customers').doc(customerId).update({
      'customerGroupIds': groupIds,
    });
  }

  // Gruppennamen für IDs laden (für Anzeige)
  static Future<Map<String, String>> getGroupNames(List<String> groupIds) async {
    if (groupIds.isEmpty) return {};

    final names = <String, String>{};

    for (var id in groupIds) {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        names[id] = doc.data()?['name'] ?? 'Unbekannt';
      }
    }

    return names;
  }

  // Statistiken für eine Gruppe
  static Future<Map<String, dynamic>> getGroupStatistics(String groupId) async {
    final customers = await getCustomersInGroup(groupId);

    double totalRevenue = 0;
    int totalOrders = 0;

    for (var customer in customers) {
      final ordersSnapshot = await _firestore
          .collection('orders')
          .where('customer.id', isEqualTo: customer.id)
          .get();

      for (var orderDoc in ordersSnapshot.docs) {
        final calculations = orderDoc.data()['calculations'] as Map<String, dynamic>?;
        if (calculations != null) {
          totalRevenue += (calculations['total'] as num?)?.toDouble() ?? 0;
        }
        totalOrders++;
      }
    }

    return {
      'customerCount': customers.length,
      'totalRevenue': totalRevenue,
      'totalOrders': totalOrders,
      'emailCount': customers.where((c) => c.email.isNotEmpty).length,
    };
  }
}