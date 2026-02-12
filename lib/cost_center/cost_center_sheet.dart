import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../services/icon_helper.dart';
import 'cost_center.dart';


// ═══════════════════════════════════════════════════════════════
//  FORMULAR: Neue Kostenstelle / Kostenstelle bearbeiten
// ═══════════════════════════════════════════════════════════════

class CostCenterFormContent extends StatefulWidget {
  final CostCenter? costCenter;
  final bool isDialog;

  const CostCenterFormContent({
    Key? key,
    this.costCenter,
    required this.isDialog,
  }) : super(key: key);

  @override
  State<CostCenterFormContent> createState() => _CostCenterFormContentState();
}

class _CostCenterFormContentState extends State<CostCenterFormContent> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController codeController;
  late final TextEditingController nameController;
  late final TextEditingController descriptionController;
  late bool isActive;
  bool _isSaving = false;

  bool get _isEdit => widget.costCenter != null;

  @override
  void initState() {
    super.initState();
    codeController =
        TextEditingController(text: widget.costCenter?.code ?? '');
    nameController =
        TextEditingController(text: widget.costCenter?.name ?? '');
    descriptionController =
        TextEditingController(text: widget.costCenter?.description ?? '');
    isActive = widget.costCenter?.isActive ?? true;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isDialog) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Column(
            children: [
              _buildHeader(context),
              const Divider(height: 1),
              Expanded(child: _buildFormBody(context)),
              _buildFooter(context),
            ],
          ),
        ),
      );
    }

    // Bottom-Sheet-Variante (Mobile)
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
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
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          _buildHeader(context),
          const Divider(height: 1),
          Expanded(child: _buildFormBody(context)),
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: getAdaptiveIcon(
              iconName: _isEdit ? 'edit' : 'add_circle',
              defaultIcon: _isEdit ? Icons.edit : Icons.add_circle,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isEdit ? 'Kostenstelle bearbeiten' : 'Neue Kostenstelle',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: getAdaptiveIcon(
                iconName: 'close', defaultIcon: Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFormBody(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Basisdaten ──
            _buildSectionTitle(context, 'Basisdaten', Icons.badge),
            const SizedBox(height: 12),

            TextFormField(
              controller: codeController,
              decoration: InputDecoration(
                labelText: 'Code *',
                hintText: 'z.B. KST-001',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                prefixIcon: getAdaptiveIcon(
                    iconName: 'tag', defaultIcon: Icons.tag),
              ),
              textCapitalization: TextCapitalization.characters,
              enabled: !_isEdit,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Bitte Code eingeben';
                }
                return null;
              },
            ),

            if (_isEdit) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  'Der Code kann nach der Erstellung nicht geändert werden.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.outline,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            TextFormField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Bezeichnung *',
                hintText: 'z.B. Marketing, Vertrieb, Produktion',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                prefixIcon: getAdaptiveIcon(
                    iconName: 'label', defaultIcon: Icons.label_outline),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Bitte Bezeichnung eingeben';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),

            // ── Beschreibung ──
            _buildSectionTitle(context, 'Beschreibung', Icons.notes),
            const SizedBox(height: 12),

            TextFormField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: 'Beschreibung (optional)',
                hintText: 'Wofür wird diese Kostenstelle verwendet?',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: getAdaptiveIcon(
                      iconName: 'description',
                      defaultIcon: Icons.description),
                ),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),

            // ── Status (nur bei Bearbeitung) ──
            if (_isEdit) ...[
              const SizedBox(height: 24),
              _buildSectionTitle(context, 'Status', Icons.toggle_on),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.green.withOpacity(0.05)
                      : Colors.orange.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isActive
                        ? Colors.green.withOpacity(0.3)
                        : Colors.orange.withOpacity(0.3),
                  ),
                ),
                child: SwitchListTile(
                  title: Text(
                    isActive ? 'Aktiv' : 'Inaktiv',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color:
                      isActive ? Colors.green[700] : Colors.orange[700],
                    ),
                  ),
                  subtitle: Text(
                    isActive
                        ? 'Kostenstelle ist verfügbar und kann verwendet werden.'
                        : 'Kostenstelle ist deaktiviert und wird bei Auswahlen ausgeblendet.',
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: isActive,
                  onChanged: (value) => setState(() => isActive = value),
                  secondary: getAdaptiveIcon(
                    iconName: isActive ? 'check_circle' : 'pause_circle',
                    defaultIcon: isActive
                        ? Icons.check_circle
                        : Icons.pause_circle,
                    color: isActive ? Colors.green : Colors.orange,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ── Metadaten (nur bei Bearbeitung) ──
            if (_isEdit) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    getAdaptiveIcon(
                      iconName: 'info',
                      defaultIcon: Icons.info_outline,
                      size: 16,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Erstellt am: ${DateFormat('dd.MM.yyyy HH:mm').format(widget.costCenter!.createdAt)} Uhr',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            Text(
              '* Pflichtfelder',
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Abbrechen'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
                    : getAdaptiveIcon(
                  iconName: 'save',
                  defaultIcon: Icons.save,
                  color: Colors.white,
                ),
                label: Text(_isSaving ? 'Speichern...' : 'Speichern'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(
      BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        getAdaptiveIcon(
          iconName: icon.toString().split('.').last,
          defaultIcon: icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() => _isSaving = true);

    final costCenter = CostCenter(
      id: widget.costCenter?.id ?? '',
      code: codeController.text.trim(),
      name: nameController.text.trim(),
      description: descriptionController.text.trim(),
      createdAt: widget.costCenter?.createdAt ?? DateTime.now(),
      isActive: isActive,
    );

    try {
      if (_isEdit) {
        await FirebaseFirestore.instance
            .collection('cost_centers')
            .doc(costCenter.id)
            .update(costCenter.toMap());
      } else {
        // Duplikat-Prüfung
        final existing = await FirebaseFirestore.instance
            .collection('cost_centers')
            .where('code', isEqualTo: costCenter.code)
            .get();

        if (existing.docs.isNotEmpty) {
          if (mounted) {
            setState(() => _isSaving = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Eine Kostenstelle mit Code "${costCenter.code}" existiert bereits.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        await FirebaseFirestore.instance
            .collection('cost_centers')
            .add(costCenter.toMap());
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit
                ? 'Kostenstelle erfolgreich aktualisiert'
                : 'Kostenstelle erfolgreich angelegt'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    codeController.dispose();
    nameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════
//  DETAILS: Kostenstelle anzeigen
// ═══════════════════════════════════════════════════════════════

class CostCenterDetailsContent extends StatelessWidget {
  final CostCenter costCenter;
  final bool isDialog;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const CostCenterDetailsContent({
    Key? key,
    required this.costCenter,
    required this.isDialog,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isDialog) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Column(
            children: [
              _buildHeader(context),
              const Divider(height: 1),
              Expanded(child: _buildDetailsBody(context)),
              _buildFooter(context),
            ],
          ),
        ),
      );
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
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
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          _buildHeader(context),
          const Divider(height: 1),
          Expanded(child: _buildDetailsBody(context)),
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: getAdaptiveIcon(
              iconName: 'account_balance_wallet',
              defaultIcon: Icons.account_balance_wallet,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  costCenter.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  costCenter.code,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: getAdaptiveIcon(
                iconName: 'close', defaultIcon: Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsBody(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status
          _buildDetailCard(
            context,
            icon: costCenter.isActive
                ? Icons.check_circle
                : Icons.pause_circle,
            iconColor: costCenter.isActive ? Colors.green : Colors.orange,
            title: 'Status',
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: costCenter.isActive
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: costCenter.isActive
                          ? Colors.green.withOpacity(0.4)
                          : Colors.orange.withOpacity(0.4),
                    ),
                  ),
                  child: Text(
                    costCenter.isActive ? 'Aktiv' : 'Inaktiv',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: costCenter.isActive
                          ? Colors.green[700]
                          : Colors.orange[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Basisdaten
          _buildDetailCard(
            context,
            icon: Icons.badge,
            title: 'Basisdaten',
            child: Column(
              children: [
                _buildDetailRow(context, 'Code', costCenter.code),
                const SizedBox(height: 8),
                _buildDetailRow(context, 'Bezeichnung', costCenter.name),
              ],
            ),
          ),

          if (costCenter.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildDetailCard(
              context,
              icon: Icons.description,
              title: 'Beschreibung',
              child: Text(costCenter.description,
                  style: const TextStyle(fontSize: 15)),
            ),
          ],

          const SizedBox(height: 12),

          // Metadaten
          _buildDetailCard(
            context,
            icon: Icons.info_outline,
            title: 'Informationen',
            child: _buildDetailRow(
              context,
              'Erstellt am',
              DateFormat('dd.MM.yyyy HH:mm').format(costCenter.createdAt),
            ),
          ),

          // Platzhalter für Analyse
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                getAdaptiveIcon(
                  iconName: 'analytics',
                  defaultIcon: Icons.analytics,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Analyse & Auswertung für diese Kostenstelle wird in Kürze verfügbar sein.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.primary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(
      BuildContext context, {
        required IconData icon,
        required String title,
        required Widget child,
        Color? iconColor,
      }) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                getAdaptiveIcon(
                  iconName: icon.toString().split('.').last,
                  defaultIcon: icon,
                  color:
                  iconColor ?? Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: iconColor ??
                        Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
      BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
            child: Text(value, style: const TextStyle(fontSize: 15))),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              onPressed: onDelete,
              icon: getAdaptiveIcon(
                iconName: 'delete',
                defaultIcon: Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              tooltip: 'Löschen',
              style: IconButton.styleFrom(
                backgroundColor:
                Theme.of(context).colorScheme.error.withOpacity(0.1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Schließen'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onEdit,
                icon: getAdaptiveIcon(
                  iconName: 'edit',
                  defaultIcon: Icons.edit,
                  color: Colors.white,
                ),
                label: const Text('Bearbeiten'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}