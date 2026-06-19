import 'package:flutter/foundation.dart';
import 'package:device_calendar/device_calendar.dart';

class CalendarService {
  static final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();

  /// 오늘 하루 동안 등록되어 있는 사용자의 일정 제목(title) 목록을 조회합니다.
  static Future<List<String>> getTodayEvents({bool requestPermission = false}) async {
    final List<String> eventTitles = [];
    try {
      // 1. 권한 보유 여부 확인
      var permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
      debugPrint('CalendarService: hasPermissions() success = ${permissionsGranted.isSuccess}, data = ${permissionsGranted.data}');
      
      if (!permissionsGranted.isSuccess || permissionsGranted.data == false) {
        if (!requestPermission) {
          debugPrint('CalendarService: Calendar permissions not granted, requestPermission is false. Returning empty.');
          return [];
        }
        // 플러그인 레벨에서 권한이 감지되지 않으면, 플러그인 자체 권한 요청을 시도합니다.
        final requestResult = await _deviceCalendarPlugin.requestPermissions();
        debugPrint('CalendarService: requestPermissions() success = ${requestResult.isSuccess}, data = ${requestResult.data}');
        if (!requestResult.isSuccess || requestResult.data == false) {
          debugPrint('CalendarService: Calendar permissions not fully granted by device_calendar.');
          return [];
        }
      }

      // 2. 기기에 연결된 모든 캘린더 조회
      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      if (!calendarsResult.isSuccess || calendarsResult.data == null) {
        debugPrint('CalendarService: Failed to retrieve calendars: ${calendarsResult.errors}');
        return [];
      }

      final calendars = calendarsResult.data!;
      debugPrint('CalendarService: Found ${calendars.length} calendars in device.');
      
      // 3. 오늘 하루의 시작(00:00:00)과 끝(23:59:59) 정의
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
      debugPrint('CalendarService: Querying range from $startOfDay to $endOfDay');

      // 4. 각 캘린더에 등재된 오늘 일정 조회
      for (final calendar in calendars) {
        if (calendar.id == null) continue;
        
        debugPrint('CalendarService: Checking calendar [${calendar.name}] (id: ${calendar.id}, isReadOnly: ${calendar.isReadOnly})');

        final eventsResult = await _deviceCalendarPlugin.retrieveEvents(
          calendar.id,
          RetrieveEventsParams(
            startDate: startOfDay,
            endDate: endOfDay,
          ),
        );

        if (eventsResult.isSuccess && eventsResult.data != null) {
          final events = eventsResult.data!;
          debugPrint('CalendarService: Found ${events.length} events in [${calendar.name}]');
          for (final event in events) {
            debugPrint('CalendarService: -> Event Title: ${event.title}');
            if (event.title != null && event.title!.trim().isNotEmpty) {
              eventTitles.add(event.title!.trim());
            }
          }
        } else {
          debugPrint('CalendarService: Failed to fetch events for [${calendar.name}]: ${eventsResult.errors}');
        }
      }
    } catch (e) {
      // 디버깅 편의성을 위해 에러 출력
      debugPrint('CalendarService Error: $e');
    }
    
    // 중복 일정 제거 후 반환
    return eventTitles.toSet().toList();
  }

  /// 오늘 중 현재 시각 이전에 끝난 일정 제목 목록을 반환합니다.
  /// 종료 시각이 없는 하루종일 일정은 현재 시각이 오전 6시 이후이면 포함합니다.
  static Future<List<String>> getPastTodayEvents({bool requestPermission = false}) async {
    final List<String> eventTitles = [];
    try {
      var permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
      if (!permissionsGranted.isSuccess || permissionsGranted.data == false) {
        if (!requestPermission) {
          debugPrint('CalendarService: Calendar permissions not granted, requestPermission is false. Returning empty.');
          return [];
        }
        final requestResult = await _deviceCalendarPlugin.requestPermissions();
        if (!requestResult.isSuccess || requestResult.data == false) return [];
      }

      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      if (!calendarsResult.isSuccess || calendarsResult.data == null) return [];

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      for (final calendar in calendarsResult.data!) {
        if (calendar.id == null) continue;
        final eventsResult = await _deviceCalendarPlugin.retrieveEvents(
          calendar.id,
          RetrieveEventsParams(startDate: startOfDay, endDate: endOfDay),
        );
        if (!eventsResult.isSuccess || eventsResult.data == null) continue;
        for (final event in eventsResult.data!) {
          if (event.title == null || event.title!.trim().isEmpty) continue;
          final end = event.end;
          // 종료 시각이 현재보다 이전이거나, 하루종일 일정이고 오전 6시 이후
          final isPast = end != null
              ? end.isBefore(now)
              : now.hour >= 6;
          if (isPast) eventTitles.add(event.title!.trim());
        }
      }
    } catch (e) {
      debugPrint('CalendarService.getPastTodayEvents Error: $e');
    }
    return eventTitles.toSet().toList();
  }
}
