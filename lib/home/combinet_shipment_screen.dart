import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/combined_shipment_manager.dart';
import '../services/icon_helper.dart';
import '../orders/order_model.dart';
import 'combined_shipment_create_screen.dart';

class CombinedShipmentScreen extends StatefulWidget {
  const CombinedShipmentScreen({Key? key}) : super(key: key);

  @override
  State<CombinedShipmentScreen> createState() => _CombinedShipmentScreenState();
}

class _CombinedShipmentScreenState extends State<CombinedShipmentScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sammellieferungen'),
        actions: [
          IconButton(
            icon: getAdaptiveIcon(
              iconName: 'info',
              defaultIcon: Icons.info,
            ),
            onPressed: _showInfoDialog,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('combined_shipments')
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Fehler: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final shipments = snapshot.data?.docs ?? [];

          if (shipments.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: shipments.length,
            itemBuilder: (context, index) {
              return _buildShipmentCard(shipments[index]);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CombinedShipmentCreateScreen(),
            ),
          );
        },
        icon: getAdaptiveIcon(
          iconName: 'add',
          defaultIcon: Icons.add,
        ),
        label: const Text('Neue Sammellieferung'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: getAdaptiveIcon(
              iconName: 'local_shipping',
              defaultIcon: Icons.local_shipping,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Keine Sammellieferungen vorhanden',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Erstell eine neue Sammellieferung\nfür mehrere Aufträge',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShipmentCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final orderIds = List<String>.from(data['order_ids'] ?? []);
    final createdAt = (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showShipmentDetails(doc.id, data),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['shipment_number'] ?? 'SL-${doc.id.substring(0, 8)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Erstellt am ${_formatDate(createdAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(data['status'] ?? 'draft'),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  getAdaptiveIcon(
                    iconName: 'shopping_bag',
                    defaultIcon: Icons.shopping_bag,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${orderIds.length} Aufträge',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const Spacer(),
                  // Dokument-Status Icons
                  if (data['documents']?['delivery_note_pdf'] != null)
                    _buildDocIcon('description', 'Lieferschein'),
                  if (data['documents']?['commercial_invoice_pdf'] != null)
                    _buildDocIcon('receipt', 'Handelsrechnung'),
                  if (data['documents']?['packing_list_pdf'] != null)
                    _buildDocIcon('list_alt', 'Packliste'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case 'draft':
        color = Colors.grey;
        label = 'Entwurf';
        break;
      case 'confirmed':
        color = Colors.blue;
        label = 'Bestätigt';
        break;
      case 'shipped':
        color = Colors.green;
        label = 'Versendet';
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildDocIcon(String iconName, String tooltip) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Tooltip(
        message: tooltip,
        child: getAdaptiveIcon(
          iconName: iconName,
          defaultIcon: Icons.description,
          size: 20,
          color: Colors.green,
        ),
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            getAdaptiveIcon(
              iconName: 'info',
              defaultIcon: Icons.info,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            const Text('Sammellieferungen'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mit Sammellieferungen kannst du mehrere Aufträge zusammenfassen und gemeinsam versenden.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),

              SizedBox(height: 16),
              Text('Ablauf:'),
              SizedBox(height: 8),
              Text('1. Wähle die Aufträge aus'),
              Text('2. Gib die gemeinsame Lieferadresse ein'),
              Text('3. Erstell Lieferschein, Handelsrechnung und Packliste'),
              Text('4. Die einzelnen Rechnungsnummern werden auf den Dokumenten referenziert'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Verstanden'),
          ),
        ],
      ),
    );
  }

  void _showShipmentDetails(String shipmentId, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('combined_shipments')
              .doc(shipmentId)
              .snapshots(),
          builder: (context, shipmentSnapshot) {
            if (!shipmentSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final shipmentData = shipmentSnapshot.data!.data() as Map<String, dynamic>;
            final orderIds = List<String>.from(shipmentData['order_ids'] ?? []);

            return Column(
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
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: getAdaptiveIcon(
                          iconName: 'local_shipping',
                          defaultIcon: Icons.local_shipping,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shipmentData['shipment_number'] ?? 'Sammellieferung',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Status: ${_getStatusLabel(shipmentData['status'] ?? 'draft')}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: getAdaptiveIcon(
                          iconName: 'close',
                          defaultIcon: Icons.close,
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(),

                // Content
                Expanded(
                  child: DefaultTabController(
                    length: 3,
                    child: Column(
                      children: [
                        // Tab Bar
                        TabBar(
                          labelColor: Theme.of(context).colorScheme.primary,
                          tabs: const [
                            Tab(text: 'Übersicht'),
                            Tab(text: 'Aufträge'),
                            Tab(text: 'Dokumente'),
                          ],
                        ),

                        // Tab Views
                        Expanded(
                          child: TabBarView(
                            children: [
                              // Tab 1: Übersicht
                              _buildOverviewTab(shipmentData, orderIds),

                              // Tab 2: Aufträge
                              _buildOrdersTab(orderIds),

                              // Tab 3: Dokumente
                              _buildDocumentsTab(shipmentId, shipmentData),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Action Bar
                _buildBottomActionBar(shipmentId, shipmentData),
              ],
            );
          },
        ),
      ),
    );
  }

// Übersicht Tab
  Widget _buildOverviewTab(Map<String, dynamic> shipmentData, List<String> orderIds) {
    final shippingAddress = shipmentData['shipping_address'] as Map<String, dynamic>? ?? {};
    final createdAt = (shipmentData['created_at'] as Timestamp?)?.toDate() ?? DateTime.now();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lieferadresse
          _buildSectionHeader('Lieferadresse'),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (shippingAddress['contactPerson']?.isNotEmpty ?? false) ...[
                  Text(
                    shippingAddress['contactPerson'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                ],
                Text('${shippingAddress['street']} ${shippingAddress['houseNumber']}'),
                Text('${shippingAddress['zipCode']} ${shippingAddress['city']}'),
                Text(shippingAddress['country'] ?? ''),
                if (shippingAddress['phone']?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      getAdaptiveIcon(
                        iconName: 'phone',
                        defaultIcon: Icons.phone,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(shippingAddress['phone']),
                    ],
                  ),
                ],
                if (shippingAddress['email']?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      getAdaptiveIcon(
                        iconName: 'email',
                        defaultIcon: Icons.email,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(shippingAddress['email']),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Statistiken
          _buildSectionHeader('Zusammenfassung'),
          const SizedBox(height: 12),

          // Lade Aufträge für Statistiken
          StreamBuilder<List<OrderX>>(
            stream: _loadOrdersStream(orderIds),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final orders = snapshot.data!;
              double totalAmount = 0;
              int totalItems = 0;

              for (final order in orders) {
                totalAmount += (order.calculations['total'] as num? ?? 0).toDouble();
                totalItems += order.items.length;
              }

              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  _buildStatCard(
                    'Aufträge',
                    '${orders.length}',
                    Icons.shopping_bag,
                    Colors.blue,
                  ),
                  _buildStatCard(
                    'Positionen',
                    '$totalItems',
                    Icons.inventory,
                    Colors.orange,
                  ),
                  _buildStatCard(
                    'Gesamtwert',
                    'CHF ${totalAmount.toStringAsFixed(2)}',
                    Icons.savings,
                    Colors.green,
                  ),
                  _buildStatCard(
                    'Erstellt',
                    _formatDate(createdAt),
                    Icons.calendar_today,
                    Colors.purple,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

// Aufträge Tab
  Widget _buildOrdersTab(List<String> orderIds) {
    return StreamBuilder<List<OrderX>>(
      stream: _loadOrdersStream(orderIds),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  'Rechnung ${order.orderNumber}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.customer['company'] ?? order.customer['fullName'] ?? ''),
                    Text(
                      '${order.items.length} Artikel • CHF ${(order.calculations['total'] as num).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                // In _buildOrdersTab - korrigiert:
                trailing: IconButton(
                  icon: getAdaptiveIcon(
                    iconName: 'open_in_new',
                    defaultIcon: Icons.open_in_new,
                  ),
                  onPressed: () {
                    // Zeige Order-Details in einem Modal
                    Navigator.pop(context); // Schließe aktuelle Details
                    // Nutze die existierende _showOrderDetails Methode aus orders_overview_screen
                    // Da wir aber in einem anderen Screen sind, zeigen wir erstmal nur eine Info
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) => Container(
                        height: MediaQuery.of(context).size.height * 0.6,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Auftrag ${order.orderNumber}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 16),
                            Text('Kunde: ${order.customer['company'] ?? order.customer['fullName']}'),
                            Text('Datum: ${_formatDate(order.orderDate)}'),
                            Text('Status: ${order.status.displayName}'),
                            const SizedBox(height: 16),
                            Text('Positionen:', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Expanded(
                              child: ListView.builder(
                                itemCount: order.items.length,
                                itemBuilder: (context, index) {
                                  final item = order.items[index];
                                  return ListTile(
                                    title: Text(item['product_name'] ?? 'Produkt'),
                                    subtitle: Text('${item['quantity']} ${item['unit'] ?? 'Stk'}'),
                                    trailing: Text('CHF ${(item['total'] as num).toStringAsFixed(2)}'),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

// Dokumente Tab
  Widget _buildDocumentsTab(String shipmentId, Map<String, dynamic> shipmentData) {
    final documents = shipmentData['documents'] as Map<String, dynamic>? ?? {};

    if (documents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            getAdaptiveIcon(
              iconName: 'description',
              defaultIcon: Icons.description,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'Noch keine Dokumente erstellt',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await CombinedShipmentManager.showCreateDocumentsDialog(
                  context,
                  shipmentId,
                );
              },
              icon: getAdaptiveIcon(
                iconName: 'add',
                defaultIcon: Icons.add,
              ),
              label: const Text('Dokumente erstellen'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (documents['delivery_note_pdf'] != null)
          _buildDocumentTile(
            'Lieferschein',
            'delivery_note_pdf',
            documents['delivery_note_pdf'],
            Colors.purple,
          ),
        if (documents['commercial_invoice_pdf'] != null)
          _buildDocumentTile(
            'Handelsrechnung',
            'commercial_invoice_pdf',
            documents['commercial_invoice_pdf'],
            Colors.green,
          ),
        if (documents['packing_list_pdf'] != null)
          _buildDocumentTile(
            'Packliste',
            'packing_list_pdf',
            documents['packing_list_pdf'],
            Colors.orange,
          ),
      ],
    );
  }

// Bottom Action Bar
  Widget _buildBottomActionBar(String shipmentId, Map<String, dynamic> shipmentData) {
    final status = shipmentData['status'] ?? 'draft';
    final hasDocuments = (shipmentData['documents'] as Map<String, dynamic>?)?.isNotEmpty ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (status == 'draft') ...[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _deleteShipment(shipmentId),
                icon: getAdaptiveIcon(
                  iconName: 'delete',
                  defaultIcon: Icons.delete,
                  color: Colors.red,
                ),
                label: const Text('Löschen'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          if (!hasDocuments) ...[
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await CombinedShipmentManager.showCreateDocumentsDialog(
                    context,
                    shipmentId,
                  );
                },
                icon: getAdaptiveIcon(
                  iconName: 'description',
                  defaultIcon: Icons.description,
                ),
                label: const Text('Dokumente erstellen'),
              ),
            ),
          ] else ...[
            if (status == 'draft')
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _confirmShipment(shipmentId),
                  icon: getAdaptiveIcon(
                    iconName: 'check',
                    defaultIcon: Icons.check,
                  ),
                  label: const Text('Lieferung bestätigen'),
                ),
              ),

            if (status == 'confirmed')
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _markAsShipped(shipmentId),
                  icon: getAdaptiveIcon(
                    iconName: 'local_shipping',
                    defaultIcon: Icons.local_shipping,
                  ),
                  label: const Text('Als versendet markieren'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

// Hilfsfunktionen
  Stream<List<OrderX>> _loadOrdersStream(List<String> orderIds) {
    if (orderIds.isEmpty) {
      return Stream.value([]);
    }

    return FirebaseFirestore.instance
        .collection('orders')
        .where(FieldPath.documentId, whereIn: orderIds)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => OrderX.fromFirestore(doc)).toList());
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentTile(String title, String docType, String url, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.picture_as_pdf,
            color: color,
          ),
        ),
        title: Text(title),
        subtitle: Text('PDF-Dokument'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: getAdaptiveIcon(
                iconName: 'visibility',
                defaultIcon: Icons.visibility,
              ),
              onPressed: () => _openDocument(url),
            ),
            IconButton(
              icon: getAdaptiveIcon(
                iconName: 'share',
                defaultIcon: Icons.share,
              ),
              onPressed: () => _shareDocument(url, title),
            ),
          ],
        ),
      ),
    );
  }

// Aktionen
  Future<void> _deleteShipment(String shipmentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sammellieferung löschen'),
        content: const Text('Möchtest du diese Sammellieferung wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Lösche Sammellieferung und entferne Referenzen aus Orders
      await FirebaseFirestore.instance
          .collection('combined_shipments')
          .doc(shipmentId)
          .delete();

      Navigator.pop(context);
    }
  }

  Future<void> _confirmShipment(String shipmentId) async {
    await FirebaseFirestore.instance
        .collection('combined_shipments')
        .doc(shipmentId)
        .update({
      'status': 'confirmed',
      'confirmed_at': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Lieferung wurde bestätigt'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _markAsShipped(String shipmentId) async {
    await FirebaseFirestore.instance
        .collection('combined_shipments')
        .doc(shipmentId)
        .update({
      'status': 'shipped',
      'shipped_at': FieldValue.serverTimestamp(),
    });

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Lieferung wurde als versendet markiert'),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'draft':
        return 'Entwurf';
      case 'confirmed':
        return 'Bestätigt';
      case 'shipped':
        return 'Versendet';
      default:
        return status;
    }
  }

// Document-Methoden (aus orders_overview_screen.dart kopiert)
  Future<void> _openDocument(String url) async {
    // Implementation analog zu orders_overview_screen
  }

  Future<void> _shareDocument(String url, String title) async {
    // Implementation analog zu orders_overview_screen
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}