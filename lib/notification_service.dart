import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:homesync/notification_screen.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  // Notification channels
  static const String _deviceChannelId = 'device_notifications';
  static const String _systemChannelId = 'system_notifications';
  static const String _energyChannelId = 'energy_notifications';
  static const String _alertChannelId = 'alert_notifications';

  // Initialize the notification service
  Future<void> initialize() async {
    await _initializeLocalNotifications();
    await _initializeFirebaseMessaging();
  }

  // Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    // Skip local notifications initialization on web
    if (kIsWeb) {
      print('Local notifications not supported on web, using Firebase messaging only');
      return;
    }

    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels
    await _createNotificationChannels();
  }

  // Create notification channels for different types
  Future<void> _createNotificationChannels() async {
    // Skip channel creation on web
    if (kIsWeb) return;

    const List<AndroidNotificationChannel> channels = [
      AndroidNotificationChannel(
        _deviceChannelId,
        'Device Notifications',
        description: 'Notifications about device status changes',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      ),
      AndroidNotificationChannel(
        _systemChannelId,
        'System Notifications',
        description: 'System updates and maintenance notifications',
        importance: Importance.defaultImportance,
        enableVibration: true,
        playSound: true,
      ),
      AndroidNotificationChannel(
        _energyChannelId,
        'Energy Notifications',
        description: 'Energy usage reports and alerts',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      ),
      AndroidNotificationChannel(
        _alertChannelId,
        'Alert Notifications',
        description: 'Critical alerts and warnings',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
      ),
    ];

    for (final channel in channels) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  // Initialize Firebase Messaging
  Future<void> _initializeFirebaseMessaging() async {
    // Request permission for notifications
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    } else {
      print('User declined or has not accepted permission');
    }

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Get FCM token
    String? token = await _firebaseMessaging.getToken();
    print('FCM Token: $token');
  }

  // Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    print('Received foreground message: ${message.messageId}');
    
    // Show local notification when app is in foreground
    _showLocalNotificationFromRemote(message);
    
    // Add to notification list
    _addNotificationToList(message);
  }

  // Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    print('Notification tapped: ${message.messageId}');
    // Navigate to notification screen or specific page based on message data
  }

  // Show local notification from remote message
  Future<void> _showLocalNotificationFromRemote(RemoteMessage message) async {
    final notification = message.notification;
    if (notification != null) {
      await showNotification(
        title: notification.title ?? 'HomeSync',
        body: notification.body ?? '',
        type: _getNotificationTypeFromData(message.data),
        payload: jsonEncode(message.data),
      );
    }
  }

  // Get notification type from message data
  NotificationType _getNotificationTypeFromData(Map<String, dynamic> data) {
    String type = data['type'] ?? 'system';
    switch (type.toLowerCase()) {
      case 'device':
        return NotificationType.device;
      case 'energy':
        return NotificationType.energy;
      case 'alert':
        return NotificationType.alert;
      default:
        return NotificationType.system;
    }
  }

  // Show local notification
  Future<void> showNotification({
    required String title,
    required String body,
    NotificationType type = NotificationType.system,
    String? payload,
  }) async {
    // On web, just add to notification list (web notifications handled by service worker)
    if (kIsWeb) {
      await _addLocalNotificationToList(title, body, type);
      print('Web notification: $title - $body');
      return;
    }

    final channelId = _getChannelId(type);
    final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'default_channel',
      'Default Channel',
      channelDescription: 'Default notification channel',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(
      notificationId,
      title,
      body,
      notificationDetails,
      payload: payload,
    );

    // Add to local notification list
    await _addLocalNotificationToList(title, body, type);
  }

  // Get channel ID based on notification type
  String _getChannelId(NotificationType type) {
    switch (type) {
      case NotificationType.device:
        return _deviceChannelId;
      case NotificationType.energy:
        return _energyChannelId;
      case NotificationType.alert:
        return _alertChannelId;
      default:
        return _systemChannelId;
    }
  }

  // Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped with payload: ${response.payload}');
    // Handle navigation based on payload
  }

  // Add notification to local list (integrate with existing notification screen)
  Future<void> _addLocalNotificationToList(
    String title, 
    String body, 
    NotificationType type
  ) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> notifications = prefs.getStringList('local_notifications') ?? [];
    
    final notificationData = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': title,
      'description': body,
      'time': _formatTime(DateTime.now()),
      'type': type.toString(),
      'isSelected': false,
    };

    notifications.insert(0, jsonEncode(notificationData));
    
    // Keep only last 50 notifications
    if (notifications.length > 50) {
      notifications = notifications.take(50).toList();
    }

    await prefs.setStringList('local_notifications', notifications);
  }

  // Add remote notification to list
  void _addNotificationToList(RemoteMessage message) async {
    final notification = message.notification;
    if (notification != null) {
      await _addLocalNotificationToList(
        notification.title ?? 'HomeSync',
        notification.body ?? '',
        _getNotificationTypeFromData(message.data),
      );
    }
  }

  // Format time for display
  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Today, ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} ${dateTime.hour >= 12 ? 'PM' : 'AM'}';
    } else if (difference.inDays == 1) {
      return 'Yesterday, ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} ${dateTime.hour >= 12 ? 'PM' : 'AM'}';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  // Get stored notifications
  Future<List<NotificationItem>> getStoredNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> notifications = prefs.getStringList('local_notifications') ?? [];
    
    return notifications.map((notificationString) {
      final data = jsonDecode(notificationString);
      return NotificationItem(
        id: data['id'],
        title: data['title'],
        description: data['description'],
        time: data['time'],
        isSelected: data['isSelected'] ?? false,
      );
    }).toList();
  }

  // Device-specific notification methods
  Future<void> showDeviceNotification({
    required String deviceName,
    required String status,
    required String room,
  }) async {
    await showNotification(
      title: 'Device Update',
      body: '$deviceName in $room is now $status',
      type: NotificationType.device,
    );
  }

  Future<void> showEnergyNotification({
    required String message,
    required double usage,
  }) async {
    await showNotification(
      title: 'Energy Alert',
      body: '$message (${usage.toStringAsFixed(1)} kWh)',
      type: NotificationType.energy,
    );
  }

  Future<void> showSystemNotification({
    required String title,
    required String message,
  }) async {
    await showNotification(
      title: title,
      body: message,
      type: NotificationType.system,
    );
  }

  Future<void> showAlertNotification({
    required String title,
    required String message,
  }) async {
    await showNotification(
      title: title,
      body: message,
      type: NotificationType.alert,
    );
  }

  // Check notification settings before showing
  Future<bool> _shouldShowNotification(NotificationType type, String? deviceName) async {
    final prefs = await SharedPreferences.getInstance();
    
    switch (type) {
      case NotificationType.system:
        return prefs.getBool('system_notifications_enabled') ?? true;
      case NotificationType.device:
        if (deviceName != null) {
          return prefs.getBool('device_${deviceName}_notifications') ?? true;
        }
        return prefs.getBool('device_notifications_enabled') ?? true;
      case NotificationType.energy:
        return prefs.getBool('energy_notifications_enabled') ?? true;
      case NotificationType.alert:
        return prefs.getBool('alert_notifications_enabled') ?? true;
    }
  }
}

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling background message: ${message.messageId}');
}

// Notification types enum
enum NotificationType {
  device,
  system,
  energy,
  alert,
}
