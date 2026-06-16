import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/report_model.dart';
import 'base_repository.dart';

class ReportRepository extends BaseRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference? get _reportsCollection {
    final uid = currentUid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('reports');
  }

  /// Firestore에서 유저의 리포트 목록을 가져옵니다. 없으면 빈 리스트를 반환합니다.
  Future<List<ReportLetter>> getReports() async {
    if (!isEnabled) return [];
    try {
      final snapshot = await _reportsCollection?.get();
      if (snapshot != null && snapshot.docs.isNotEmpty) {
        final list = snapshot.docs.map((doc) {
          return ReportLetter.fromJson(doc.data() as Map<String, dynamic>);
        }).toList();
        // ID 순서대로 정렬
        list.sort((a, b) => a.id.compareTo(b.id));
        return list;
      }
    } catch (e) {
      debugPrint('ReportRepository: getReports error: $e');
    }
    return [];
  }

  /// 리포트를 Firestore에 저장합니다.
  Future<void> saveReport(ReportLetter report) async {
    if (!isEnabled) return;
    try {
      await _reportsCollection?.doc(report.id).set(report.toJson());
    } catch (e) {
      debugPrint('ReportRepository: saveReport error: $e');
    }
  }

  /// 특정 리포트를 읽음 처리합니다.
  Future<void> updateReportReadStatus(String id, {required bool isRead, required bool isNew}) async {
    if (!isEnabled) return;
    try {
      await _reportsCollection?.doc(id).update({
        'isRead': isRead,
        'isNew': isNew,
      });
    } catch (e) {
      debugPrint('ReportRepository: updateReportReadStatus error: $e');
    }
  }
}
