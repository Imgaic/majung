import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/diary_data.dart';
import 'base_repository.dart';

class DiaryRepository extends BaseRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference? get _diariesCollection {
    final uid = currentUid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('diaries');
  }

  /// 사용자의 모든 일기 목록을 실시간 스트림으로 가져옵니다.
  Stream<List<DiaryData>> watchDiaries() {
    final col = _diariesCollection;
    if (col == null) return const Stream.empty();

    return col.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return DiaryData.fromJson(doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  /// 사용자의 모든 일기 목록을 1회성 Future로 가져옵니다.
  Future<List<DiaryData>> getDiaries() async {
    if (!isEnabled) return [];
    try {
      final snapshot = await _diariesCollection?.get();
      if (snapshot != null) {
        return snapshot.docs.map((doc) {
          return DiaryData.fromJson(doc.data() as Map<String, dynamic>);
        }).toList();
      }
    } catch (e) {
      debugPrint('DiaryRepository: getDiaries error: $e');
    }
    return [];
  }

  /// 특정 날짜 범위의 일기를 가져옵니다. (date 필드 형식: "YYYY.MM.DD")
  Future<List<DiaryData>> getDiariesInRange(String from, String to) async {
    if (!isEnabled) return [];
    try {
      final snapshot = await _diariesCollection
          ?.where('date', isGreaterThanOrEqualTo: from)
          .where('date', isLessThanOrEqualTo: to)
          .get();
      if (snapshot != null) {
        return snapshot.docs
            .map((doc) => DiaryData.fromJson(doc.data() as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('DiaryRepository: getDiariesInRange error: $e');
    }
    return [];
  }

  /// 일기를 추가하거나 수정합니다.
  Future<void> saveDiary(DiaryData diary) async {
    if (!isEnabled) return;
    try {
      // 날짜 스트링(예: 2026.06.06)을 문서 ID로 활용하여 날짜별 1개 제약 보장
      await _diariesCollection?.doc(diary.date).set(diary.toJson());
    } catch (e) {
      debugPrint('DiaryRepository: saveDiary error: $e');
    }
  }

  /// 일기를 삭제합니다.
  Future<void> deleteDiary(String date) async {
    if (!isEnabled) return;
    try {
      await _diariesCollection?.doc(date).delete();
    } catch (e) {
      debugPrint('DiaryRepository: deleteDiary error: $e');
    }
  }
}
