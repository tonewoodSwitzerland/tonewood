// lib/screens/analytics/roundwood/services/roundwood_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/roundwood_models.dart';

class RoundwoodService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot> getRoundwoodStream(RoundwoodFilter filter) {
    Query query = _firestore.collection('roundwood');

    // Zeitraum Filter
    if (filter.timeRange != null) {
      DateTime startDate;
      switch (filter.timeRange) {
        case 'week':
          startDate = DateTime.now().subtract(const Duration(days: 7));
          break;
        case 'month':
          startDate = DateTime.now().subtract(const Duration(days: 30));
          break;
        case 'quarter':
          startDate = DateTime.now().subtract(const Duration(days: 90));
          break;
        case 'year':
          startDate = DateTime.now().subtract(const Duration(days: 365));
          break;
        default:
          startDate = DateTime.now().subtract(const Duration(days: 30));
      }
      query = query.where('timestamp', isGreaterThan: startDate);
    } else if (filter.startDate != null && filter.endDate != null) {
      query = query.where('timestamp',
          isGreaterThanOrEqualTo: filter.startDate,
          isLessThanOrEqualTo: filter.endDate);
    }

    // Weitere Filter anwenden
    if (filter.woodTypes?.isNotEmpty == true) {
      query = query.where('wood_type', whereIn: filter.woodTypes);
    }

    if (filter.qualities?.isNotEmpty == true) {
      query = query.where('quality', whereIn: filter.qualities);
    }

    if (filter.purposeCodes?.isNotEmpty == true) {
      query = query.where('purpose_codes', arrayContainsAny: filter.purposeCodes);
    }

    if (filter.origin != null) {
      query = query.where('origin', isEqualTo: filter.origin);
    }

    if (filter.isMoonwood == true) {
      query = query.where('is_moonwood', isEqualTo: true);
    }

    if (filter.volumeMin != null) {
      query = query.where('volume', isGreaterThanOrEqualTo: filter.volumeMin);
    }
    if (filter.volumeMax != null) {
      query = query.where('volume', isLessThanOrEqualTo: filter.volumeMax);
    }

    return query.orderBy('timestamp', descending: true).snapshots();
  }

  Future<void> updateRoundwood(String id, Map<String, dynamic> data) {
    return _firestore.collection('roundwood').doc(id).update(data);
  }

  Future<void> deleteRoundwood(String id) {
    return _firestore.collection('roundwood').doc(id).delete();
  }
}