import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Initialize for Android using the app's default launcher icon
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('ic_launcher');
    
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Here we can handle what happens when the user taps the notification (e.g. redirect to Alerts Tab)
      },
    );
  }

  Future<void> requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
    }
  }

  Future<void> cancelAllAlarms() async {
    await _plugin.cancelAll();
  }

  Future<void> cancelAlarm(int id) async {
    await _plugin.cancel(id: id);
  }

  Future<void> scheduleMedicationAlarm(Map<String, dynamic> medication) async {
    final pmIdRaw = medication['patient_medication_id'];
    final pmId = pmIdRaw is int ? pmIdRaw : int.parse(pmIdRaw.toString());
    
    final name = medication['medication_name']?.toString() ?? 'دواء';
    final dosage = medication['dosage']?.toString() ?? medication['dosage_amount']?.toString() ?? 'الجرعة المقررة';
    final intakeTime = medication['intake_time']?.toString() ?? '10:00:00';
    final sDays = medication['schedule_days']?.toString() ?? '';
    final endDateStr = medication['end_date']?.toString();

    // 1. Clean up old alarms (max 8 per medication)
    for (int i = 0; i < 8; i++) {
      await cancelAlarm((pmId * 10) + i);
    }

    // 2. Stop if end_date has passed
    if (endDateStr != null && endDateStr.isNotEmpty) {
      final endDate = DateTime.tryParse(endDateStr);
      if (endDate != null && DateTime.now().isAfter(endDate.add(const Duration(days: 1)))) {
        return; // Don't schedule if treatment is over
      }
    }

    // 3. Parse Time
    final parts = intakeTime.split(':');
    if (parts.length < 2) return;
    final hour = int.tryParse(parts[0]) ?? 10;
    final minute = int.tryParse(parts[1]) ?? 0;

    // 4. Notification Settings
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'medication_channel',
      'تذكير بمواعيد الأدوية',
      channelDescription: 'تنبيهات بمواعيد أخذ الجرعات',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_launcher',
      playSound: true,
      enableVibration: true,
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    // 5. Parse Days Array
    List<String> selectedDays = [];
    if (sDays.isNotEmpty) {
      selectedDays = sDays.replaceAll('[', '').replaceAll(']', '').split(',').map((e) => e.trim().replaceAll('"', '')).where((e) => e.isNotEmpty).toList();
    }

    // 6. Schedule
    if (selectedDays.isEmpty) {
      // Daily Alarm
      final tz.TZDateTime nextTime = _nextInstanceOfTime(hour, minute);
      await _plugin.zonedSchedule(
        id: pmId * 10,
        title: 'حان موعد الدواء!',
        body: 'تذكير بأخذ $dosage من $name',
        scheduledDate: nextTime,
        notificationDetails: platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } else {
      // Weekly Alarms for specific days
      final dayMap = {'Mon': DateTime.monday, 'Tue': DateTime.tuesday, 'Wed': DateTime.wednesday, 'Thu': DateTime.thursday, 'Fri': DateTime.friday, 'Sat': DateTime.saturday, 'Sun': DateTime.sunday};
      
      for (int i = 0; i < selectedDays.length; i++) {
        final dayNum = dayMap[selectedDays[i]];
        if (dayNum == null) continue;
        
        final tz.TZDateTime nextTime = _nextInstanceOfWeekdayAndTime(dayNum, hour, minute);
        await _plugin.zonedSchedule(
          id: (pmId * 10) + i + 1,
          title: 'حان موعد الدواء!',
          body: 'تذكير بأخذ $dosage من $name',
          scheduledDate: nextTime,
          notificationDetails: platformDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  tz.TZDateTime _nextInstanceOfWeekdayAndTime(int weekday, int hour, int minute) {
    tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, minute);
    while (scheduledDate.weekday != weekday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
