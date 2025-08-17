import 'package:homesync/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  final NotificationService _notificationService = NotificationService();

  // Initialize the notification manager
  Future<void> initialize() async {
    await _notificationService.initialize();
  }

  // Device-related notifications
  Future<void> notifyDeviceStatusChange({
    required String deviceName,
    required String room,
    required bool isOn,
  }) async {
    if (await _isDeviceNotificationEnabled(deviceName)) {
      final status = isOn ? 'turned on' : 'turned off';
      await _notificationService.showDeviceNotification(
        deviceName: deviceName,
        status: status,
        room: room,
      );
    }
  }

  Future<void> notifyDeviceDisconnected({
    required String deviceName,
    required String room,
  }) async {
    if (await _isDeviceNotificationEnabled(deviceName)) {
      await _notificationService.showAlertNotification(
        title: 'Device Disconnected',
        message: '$deviceName in $room has disconnected from the network',
      );
    }
  }

  Future<void> notifyDeviceReconnected({
    required String deviceName,
    required String room,
  }) async {
    if (await _isDeviceNotificationEnabled(deviceName)) {
      await _notificationService.showDeviceNotification(
        deviceName: deviceName,
        status: 'reconnected',
        room: room,
      );
    }
  }

  Future<void> notifyNewDeviceFound({
    required String deviceName,
    required String deviceType,
  }) async {
    if (await _isSystemNotificationEnabled('newDeviceFound')) {
      await _notificationService.showSystemNotification(
        title: 'New Device Found',
        message: '$deviceType "$deviceName" has been discovered on your network',
      );
    }
  }

  // Energy-related notifications
  Future<void> notifyHighEnergyUsage({
    required double currentUsage,
    required double threshold,
    required String period,
  }) async {
    if (await _isEnergyNotificationEnabled()) {
      final percentage = ((currentUsage - threshold) / threshold * 100).round();
      await _notificationService.showEnergyNotification(
        message: 'Energy usage is $percentage% higher than usual $period',
        usage: currentUsage,
      );
    }
  }

  Future<void> notifyDailyEnergyReport({
    required double totalUsage,
    required double previousDayUsage,
  }) async {
    if (await _isEnergyNotificationEnabled()) {
      final difference = totalUsage - previousDayUsage;
      final changeText = difference > 0 
          ? '${difference.toStringAsFixed(1)} kWh more than yesterday'
          : '${difference.abs().toStringAsFixed(1)} kWh less than yesterday';
      
      await _notificationService.showEnergyNotification(
        message: 'Daily energy report: $changeText',
        usage: totalUsage,
      );
    }
  }

  Future<void> notifyEnergySpike({
    required String deviceName,
    required String room,
    required double currentPower,
  }) async {
    if (await _isDeviceNotificationEnabled(deviceName)) {
      await _notificationService.showAlertNotification(
        title: 'Unusual Energy Spike',
        message: '$deviceName in $room is consuming ${currentPower.toStringAsFixed(1)}W - higher than usual',
      );
    }
  }

  // System notifications
  Future<void> notifyFirmwareUpdate({
    required String deviceName,
    required String version,
  }) async {
    if (await _isSystemNotificationEnabled('firmwareUpdate')) {
      await _notificationService.showSystemNotification(
        title: 'Firmware Update Available',
        message: '$deviceName can be updated to version $version',
      );
    }
  }

  Future<void> notifySystemMaintenance({
    required String scheduledTime,
    required String description,
  }) async {
    if (await _isSystemNotificationEnabled('maintenance')) {
      await _notificationService.showSystemNotification(
        title: 'System Maintenance Scheduled',
        message: '$description scheduled for $scheduledTime',
      );
    }
  }

  Future<void> notifyConnectivityIssue({
    required String deviceName,
    required String issue,
  }) async {
    await _notificationService.showAlertNotification(
      title: 'Connectivity Issue',
      message: '$deviceName: $issue',
    );
  }

  // Automation notifications
  Future<void> notifyAutomationTriggered({
    required String automationName,
    required String action,
    required String deviceName,
  }) async {
    if (await _isDeviceNotificationEnabled(deviceName)) {
      await _notificationService.showDeviceNotification(
        deviceName: deviceName,
        status: action,
        room: 'via automation "$automationName"',
      );
    }
  }

  Future<void> notifyScheduledAction({
    required String deviceName,
    required String action,
    required String timeRemaining,
  }) async {
    if (await _isDeviceNotificationEnabled(deviceName)) {
      await _notificationService.showSystemNotification(
        title: 'Scheduled Action',
        message: '$deviceName will be $action in $timeRemaining',
      );
    }
  }

  // Safety and alert notifications
  Future<void> notifyOverloadWarning({
    required String deviceName,
    required String room,
    required double currentAmperage,
    required double maxAmperage,
  }) async {
    await _notificationService.showAlertNotification(
      title: 'Overload Warning',
      message: '$deviceName in $room is drawing ${currentAmperage.toStringAsFixed(1)}A (max: ${maxAmperage.toStringAsFixed(1)}A)',
    );
  }

  Future<void> notifyTemperatureAlert({
    required String deviceName,
    required String room,
    required double temperature,
    required String severity,
  }) async {
    await _notificationService.showAlertNotification(
      title: 'Temperature Alert',
      message: '$deviceName in $room temperature: ${temperature.toStringAsFixed(1)}°C ($severity)',
    );
  }

  // Weather-related notifications
  Future<void> notifyWeatherUpdate({
    required String condition,
    required double temperature,
    required String recommendation,
  }) async {
    if (await _isSystemNotificationEnabled('weather')) {
      await _notificationService.showSystemNotification(
        title: 'Weather Update',
        message: '$condition, ${temperature.toStringAsFixed(0)}°C. $recommendation',
      );
    }
  }

  // Data sync notifications
  Future<void> notifyDataSyncCompleted() async {
    if (await _isSystemNotificationEnabled('dataSync')) {
      await _notificationService.showSystemNotification(
        title: 'Data Sync Completed',
        message: 'Your data has been successfully synced with the cloud',
      );
    }
  }

  Future<void> notifyDataSyncFailed({
    required String reason,
  }) async {
    await _notificationService.showAlertNotification(
      title: 'Data Sync Failed',
      message: 'Unable to sync data: $reason',
    );
  }

  // App update notifications
  Future<void> notifyAppUpdateAvailable({
    required String version,
    required String features,
  }) async {
    if (await _isSystemNotificationEnabled('appUpdate')) {
      await _notificationService.showSystemNotification(
        title: 'App Update Available',
        message: 'Version $version is now available. $features',
      );
    }
  }

  // Energy saving tips
  Future<void> notifyEnergySavingTip({
    required String tip,
    required String potentialSavings,
  }) async {
    if (await _isEnergyNotificationEnabled()) {
      await _notificationService.showSystemNotification(
        title: 'Energy Saving Tip',
        message: '$tip Save up to $potentialSavings',
      );
    }
  }

  // Monthly comparison notifications
  Future<void> notifyMonthlyComparison({
    required double currentMonthUsage,
    required double previousMonthUsage,
    required int percentageChange,
  }) async {
    if (await _isEnergyNotificationEnabled()) {
      final changeText = percentageChange > 0 
          ? '$percentageChange% more than last month'
          : '${percentageChange.abs()}% less than last month';
      
      await _notificationService.showEnergyNotification(
        message: 'Monthly comparison: $changeText',
        usage: currentMonthUsage,
      );
    }
  }

  // Test notification (for debugging)
  Future<void> sendTestNotification({
    required NotificationType type,
    String? customTitle,
    String? customMessage,
  }) async {
    String title = customTitle ?? 'Test Notification';
    String message = customMessage ?? 'This is a test notification from HomeSync';

    switch (type) {
      case NotificationType.device:
        await _notificationService.showDeviceNotification(
          deviceName: 'Test Device',
          status: 'tested',
          room: 'Test Room',
        );
        break;
      case NotificationType.energy:
        await _notificationService.showEnergyNotification(
          message: message,
          usage: 12.5,
        );
        break;
      case NotificationType.alert:
        await _notificationService.showAlertNotification(
          title: title,
          message: message,
        );
        break;
      default:
        await _notificationService.showSystemNotification(
          title: title,
          message: message,
        );
    }
  }

  // Helper methods to check notification settings
  Future<bool> _isDeviceNotificationEnabled(String deviceName) async {
    final prefs = await SharedPreferences.getInstance();
    // Check global device notifications setting
    bool globalEnabled = prefs.getBool('device_notifications_enabled') ?? true;
    if (!globalEnabled) return false;
    
    // Check specific device setting
    return prefs.getBool('device_${deviceName.toLowerCase().replaceAll(' ', '_')}_notifications') ?? true;
  }

  Future<bool> _isSystemNotificationEnabled(String type) async {
    final prefs = await SharedPreferences.getInstance();
    switch (type) {
      case 'firmwareUpdate':
        return prefs.getBool('firmware_update_enabled') ?? true;
      case 'newDeviceFound':
        return prefs.getBool('new_device_found_enabled') ?? true;
      case 'maintenance':
        return prefs.getBool('maintenance_notifications_enabled') ?? true;
      case 'weather':
        return prefs.getBool('weather_notifications_enabled') ?? true;
      case 'dataSync':
        return prefs.getBool('data_sync_notifications_enabled') ?? true;
      case 'appUpdate':
        return prefs.getBool('app_update_notifications_enabled') ?? true;
      default:
        return prefs.getBool('system_notifications_enabled') ?? true;
    }
  }

  Future<bool> _isEnergyNotificationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('energy_notifications_enabled') ?? true;
  }

  // Save notification settings
  Future<void> saveNotificationSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  // Get notification settings
  Future<bool> getNotificationSetting(String key, {bool defaultValue = true}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? defaultValue;
  }
}
