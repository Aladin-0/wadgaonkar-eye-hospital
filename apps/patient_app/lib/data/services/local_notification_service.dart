import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'package:weh_shared/weh_shared.dart';

class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  LocalNotificationService._internal();

  Future<void> init() async {
    // Initialize timezone for scheduled notifications
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    // Using default iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open notification',
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      linux: linuxSettings,
    );

    await _notificationsPlugin.initialize(initSettings);
    
    // Request exact alarm permission (Android 12+)
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();
        
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Cancels all previously scheduled local notifications
  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }

  final Set<String> _immediateAlarmsFired = {};

  /// Schedules a 15-minute reverse countdown notification
  Future<void> scheduleAppointmentCountdown(Appointment appt) async {
    // Calculate exactly 15 minutes before the appointment start time
    final reminderTime = appt.slotStartTime.subtract(const Duration(minutes: 15));

    // If the reminder time has already passed, check if the appointment hasn't started yet
    tz.TZDateTime scheduledTzTime;
    if (reminderTime.isBefore(DateTime.now())) {
      if (appt.slotStartTime.isAfter(DateTime.now())) {
        if (_immediateAlarmsFired.contains(appt.id)) {
          return; // Already fired immediate alarm for this appointment in this session
        }
        _immediateAlarmsFired.add(appt.id);
        
        // Appt is less than 15 mins away! Trigger almost immediately
        debugPrint('Scheduling IMMEDIATE alarm for appt ${appt.id}, within 15 min window.');
        scheduledTzTime = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 2));
      } else {
        debugPrint('Skipping alarm for appt ${appt.id}, it has already started.');
        return;
      }
    } else {
      debugPrint('Scheduling alarm for appt ${appt.id} at reminderTime $reminderTime');
      scheduledTzTime = tz.TZDateTime.from(reminderTime, tz.local);
    }

    final int notificationId = appt.id.hashCode;

    // Use Android's Chronometer feature for a live countdown timer in the notification
    final androidDetails = AndroidNotificationDetails(
      'appointment_reminders_v2',
      'Appointment Reminders',
      channelDescription: 'Notifications for upcoming appointments',
      importance: Importance.max,
      priority: Priority.high,
      when: appt.slotStartTime.millisecondsSinceEpoch,
      usesChronometer: true,
      chronometerCountDown: true,
      showWhen: true,
      ticker: 'Upcoming Appointment',
      color: const Color(0xFF007BFF), // Example blue
      styleInformation: const BigTextStyleInformation(
        'Your appointment with the doctor is starting very soon. Please ensure you are at the clinic or ready for your consultation.',
        htmlFormatBigText: true,
        contentTitle: '<b>Upcoming Appointment</b>',
        htmlFormatContentTitle: true,
        summaryText: 'Action Required',
        htmlFormatSummaryText: true,
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.zonedSchedule(
      notificationId,
      'Upcoming Appointment',
      'Your appointment with ${appt.doctorName} is starting soon!',
      scheduledTzTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
