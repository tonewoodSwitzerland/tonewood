// lib/analytics/sales/widgets/sales_world_map.dart

import 'dart:math' as math; // Für Quadratwurzel-Berechnung
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../models/sales_analytics_models.dart';

class SalesWorldMap extends StatefulWidget {
  final List<CountryStats> countries;
  final double totalRevenue;

  const SalesWorldMap({
    Key? key,
    required this.countries,
    required this.totalRevenue,
  }) : super(key: key);

  @override
  State<SalesWorldMap> createState() => _SalesWorldMapState();
}

class _SalesWorldMapState extends State<SalesWorldMap> {
  CountryStats? _selectedCountry;

  // Wichtig: Diese Map muss alle deine Verkaufsländer abdecken
  final Map<String, LatLng> _coords = {
    'DE': const LatLng(51.16, 10.45), 'CH': const LatLng(46.81, 8.22),
    'AT': const LatLng(47.51, 14.55), 'FR': const LatLng(46.22, 2.21),
    'IT': const LatLng(41.87, 12.56), 'ES': const LatLng(40.46, -3.74),
    'GB': const LatLng(55.37, -3.43), 'US': const LatLng(37.09, -95.71),
    'EE': const LatLng(58.59, 25.01), 'LI': const LatLng(47.14, 9.52),
    // Ergänze hier weitere Länder nach Bedarf
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Wir sortieren, damit kleine Bubbles über großen liegen (besser klickbar)
    final sorted = List<CountryStats>.from(widget.countries)
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    final maxRev = sorted.isNotEmpty ? sorted.first.revenue : 0.0;

    return Container(
      height: 500, // Feste Höhe für die "Riesige Karte"
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            // Key sorgt dafür, dass die Karte bei neuen Daten (z.B. Adress-Toggle)
            // den Cache verwirft und Marker neu zeichnet.
            key: ValueKey('map_${widget.countries.length}_${widget.totalRevenue}'),
            options: const MapOptions(
              initialCenter: LatLng(30.0, 10.0), // Etwas südlicher für Weltfokus
              initialZoom: 2.2,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
              ),
              MarkerLayer(
                markers: sorted.map((c) {
                  final pos = _coords[c.countryCode.toUpperCase()] ?? const LatLng(0,0);
                  if (pos.latitude == 0) return Marker(point: pos, child: const SizedBox());

                  // PROFESSIONELLE SKALIERUNG:
                  // Wir nutzen die Quadratwurzel des Verhältnisses zum Max-Umsatz.
                  // Das entspricht der optischen Wahrnehmung der Kreisfläche.
                  final double ratio = maxRev > 0 ? (c.revenue / maxRev) : 0;
                  final double bubbleSize = 12 + (math.sqrt(ratio) * 38);

                  return Marker(
                    point: pos,
                    width: 80, height: 80, // Klickbereich groß halten
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedCountry = c),
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: bubbleSize,
                          height: bubbleSize,
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.7),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                            boxShadow: [
                              BoxShadow(color: Colors.black12, blurRadius: 4)
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // Tooltip-Overlay
          if (_selectedCountry != null)
            _buildOverlay(theme, _selectedCountry!),
        ],
      ),
    );
  }

  Widget _buildOverlay(ThemeData theme, CountryStats c) {
    final fmt = NumberFormat.currency(locale: 'de_CH', symbol: 'CHF', decimalDigits: 0);
    return Positioned(
      bottom: 20, left: 20,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(c.countryName, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Umsatz: ${fmt.format(c.revenue)}'),
              TextButton(onPressed: () => setState(() => _selectedCountry = null), child: const Text('Schließen'))
            ],
          ),
        ),
      ),
    );
  }
}