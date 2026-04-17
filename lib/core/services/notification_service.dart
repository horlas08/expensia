import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false, 
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    const androidChannel = AndroidNotificationChannel(
      'expensia_channel',
      'Expensia Notifications',
      description: 'Channel for scheduled transaction and daily reminders',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
  }

  static void _onNotificationResponse(NotificationResponse details) {
    debugPrint("Notification clicked: ${details.payload}");
  }

  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'expensia_channel',
        'Expensia Notifications',
        channelDescription: 'Channel for scheduled transaction and daily reminders',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  Future<bool> requestPermissions() async {
    bool granted = false;
    
    // Android 13+ Notification Permission
    final status = await Permission.notification.request();
    if (status.isGranted) granted = true;
    
    // iOS Permission
    final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      final iosGranted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      if (iosGranted == true) granted = true;
    }

    // Exact Alarm for Android (For ZonedSchedule exactAllowWhileIdle)
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
    
    return granted;
  }

  Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required TimeOfDay time,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> scheduleEntityReminder({
    required int id,
    required String title,
    required String body,
    required DateTime date,
  }) async {
    final tzDate = tz.TZDateTime.from(date, tz.local);
    if (tzDate.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tzDate,
      notificationDetails: _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String repeatType = 'once',
  }) async {
    final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);
    if (tzDate.isBefore(tz.TZDateTime.now(tz.local))) return;

    DateTimeComponents? matchComponents;
    switch (repeatType) {
      case 'daily':
        matchComponents = DateTimeComponents.time;
        break;
      case 'weekly':
        matchComponents = DateTimeComponents.dayOfWeekAndTime;
        break;
      case 'monthly':
        matchComponents = DateTimeComponents.dayOfMonthAndTime;
        break;
      default: // once
        matchComponents = null;
    }

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tzDate,
      notificationDetails: _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: matchComponents,
    );
  }

  Future<void> cancel(int id) async {
    await _plugin.cancel(id: id);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
