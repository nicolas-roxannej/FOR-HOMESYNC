import 'package:homesync/notification_manager.dart';

/// This file demonstrates how to integrate the notification system
/// with your existing home automation functionality.
/// 
/// Copy these examples into your existing device control, energy monitoring,
/// and system management code to trigger notifications when events occur.

class NotificationIntegrationExample {
  final NotificationManager _notificationManager = NotificationManager();

  /// Example: Device Control Integration
  /// Call this when a device status changes
  Future<void> onDeviceStatusChanged({
    required String deviceName,
    required String room,
    required bool isOn,
    bool wasTriggeredByUser = true,
  }) async {
    // Your existing device control logic here...
    
    // Trigger notification
    await _notificationManager.notifyDeviceStatusChange(
      deviceName: deviceName,
      room: room,
      isOn: isOn,
    );

    // If it was an automation trigger, also notify about that
    if (!wasTriggeredByUser) {
      await _notificationManager.notifyAutomationTriggered(
        automationName: "Smart Schedule",
        action: isOn ? "turned on" : "turned off",
        deviceName: deviceName,
      );
    }
  }

  /// Example: Device Connection Monitoring
  /// Call this when monitoring device connectivity
  Future<void> onDeviceConnectionChanged({
    required String deviceName,
    required String room,
    required bool isConnected,
  }) async {
    // Your existing connectivity monitoring logic here...
    
    if (isConnected) {
      await _notificationManager.notifyDeviceReconnected(
        deviceName: deviceName,
        room: room,
      );
    } else {
      await _notificationManager.notifyDeviceDisconnected(
        deviceName: deviceName,
        room: room,
      );
    }
  }

  /// Example: Energy Monitoring Integration
  /// Call this when checking daily energy usage
  Future<void> onDailyEnergyCheck({
    required double todayUsage,
    required double yesterdayUsage,
    required double threshold,
  }) async {
    // Your existing energy calculation logic here...
    
    // Send daily report
    await _notificationManager.notifyDailyEnergyReport(
      totalUsage: todayUsage,
      previousDayUsage: yesterdayUsage,
    );

    // Check for high usage
    if (todayUsage > threshold) {
      await _notificationManager.notifyHighEnergyUsage(
        currentUsage: todayUsage,
        threshold: threshold,
        period: "today",
      );
    }
  }

  /// Example: Device Power Monitoring
  /// Call this when monitoring individual device power consumption
  Future<void> onDevicePowerSpike({
    required String deviceName,
    required String room,
    required double currentPower,
    required double normalPower,
  }) async {
    // Your existing power monitoring logic here...
    
    // Check if power consumption is significantly higher than normal
    if (currentPower > normalPower * 1.5) { // 50% higher than normal
      await _notificationManager.notifyEnergySpike(
        deviceName: deviceName,
        room: room,
        currentPower: currentPower,
      );
    }
  }

  /// Example: Safety Monitoring Integration
  /// Call this when monitoring electrical safety parameters
  Future<void> onSafetyCheck({
    required String deviceName,
    required String room,
    required double currentAmperage,
    required double maxAmperage,
    required double temperature,
  }) async {
    // Your existing safety monitoring logic here...
    
    // Check for overload
    if (currentAmperage > maxAmperage * 0.9) { // 90% of max capacity
      await _notificationManager.notifyOverloadWarning(
        deviceName: deviceName,
        room: room,
        currentAmperage: currentAmperage,
        maxAmperage: maxAmperage,
      );
    }

    // Check for high temperature
    if (temperature > 60.0) { // Above 60°C
      String severity = temperature > 80.0 ? "Critical" : "High";
      await _notificationManager.notifyTemperatureAlert(
        deviceName: deviceName,
        room: room,
        temperature: temperature,
        severity: severity,
      );
    }
  }

  /// Example: Schedule/Automation Integration
  /// Call this when a scheduled action is about to execute
  Future<void> onScheduledActionPending({
    required String deviceName,
    required String action,
    required int minutesRemaining,
  }) async {
    // Your existing scheduling logic here...
    
    if (minutesRemaining <= 15) { // Notify 15 minutes before
      await _notificationManager.notifyScheduledAction(
        deviceName: deviceName,
        action: action,
        timeRemaining: "$minutesRemaining minutes",
      );
    }
  }

  /// Example: System Update Integration
  /// Call this when checking for firmware updates
  Future<void> onFirmwareUpdateAvailable({
    required String deviceName,
    required String currentVersion,
    required String newVersion,
  }) async {
    // Your existing update checking logic here...
    
    await _notificationManager.notifyFirmwareUpdate(
      deviceName: deviceName,
      version: newVersion,
    );
  }

  /// Example: New Device Discovery
  /// Call this when a new device is discovered on the network
  Future<void> onNewDeviceDiscovered({
    required String deviceName,
    required String deviceType,
    required String macAddress,
  }) async {
    // Your existing device discovery logic here...
    
    await _notificationManager.notifyNewDeviceFound(
      deviceName: deviceName,
      deviceType: deviceType,
    );
  }

  /// Example: Data Sync Integration
  /// Call this after syncing data with Firebase/cloud
  Future<void> onDataSyncCompleted({
    required bool success,
    String? errorMessage,
  }) async {
    // Your existing data sync logic here...
    
    if (success) {
      await _notificationManager.notifyDataSyncCompleted();
    } else {
      await _notificationManager.notifyDataSyncFailed(
        reason: errorMessage ?? "Unknown error occurred",
      );
    }
  }

  /// Example: Weather Integration
  /// Call this when weather data is updated
  Future<void> onWeatherUpdate({
    required String condition,
    required double temperature,
    required bool shouldRecommendEnergyActions,
  }) async {
    // Your existing weather integration logic here...
    
    if (shouldRecommendEnergyActions) {
      String recommendation = "";
      
      if (condition.toLowerCase().contains("sunny") && temperature > 25) {
        recommendation = "Consider using natural lighting to save energy";
      } else if (temperature < 18) {
        recommendation = "Consider adjusting thermostat settings";
      } else if (condition.toLowerCase().contains("rain")) {
        recommendation = "Good time to run energy-intensive appliances";
      }

      if (recommendation.isNotEmpty) {
        await _notificationManager.notifyWeatherUpdate(
          condition: condition,
          temperature: temperature,
          recommendation: recommendation,
        );
      }
    }
  }

  /// Example: Monthly Energy Comparison
  /// Call this at the end of each month
  Future<void> onMonthlyEnergyComparison({
    required double currentMonthUsage,
    required double previousMonthUsage,
  }) async {
    // Your existing monthly calculation logic here...
    
    final difference = currentMonthUsage - previousMonthUsage;
    final percentageChange = ((difference / previousMonthUsage) * 100).round();

    await _notificationManager.notifyMonthlyComparison(
      currentMonthUsage: currentMonthUsage,
      previousMonthUsage: previousMonthUsage,
      percentageChange: percentageChange,
    );

    // If usage increased significantly, provide energy saving tips
    if (percentageChange > 15) {
      await _notificationManager.notifyEnergySavingTip(
        tip: "Consider setting up automated schedules for high-consumption devices",
        potentialSavings: "10-15% energy",
      );
    }
  }

  /// Example: Connectivity Issue Detection
  /// Call this when network or device connectivity issues are detected
  Future<void> onConnectivityIssue({
    required String deviceName,
    required String issueType,
    required String details,
  }) async {
    // Your existing connectivity monitoring logic here...
    
    String issue = "";
    switch (issueType.toLowerCase()) {
      case "wifi":
        issue = "Wi-Fi connection unstable";
        break;
      case "timeout":
        issue = "Device not responding";
        break;
      case "offline":
        issue = "Device appears to be offline";
        break;
      default:
        issue = details;
    }

    await _notificationManager.notifyConnectivityIssue(
      deviceName: deviceName,
      issue: issue,
    );
  }

  /// Example: System Maintenance Notification
  /// Call this when scheduling system maintenance
  Future<void> onSystemMaintenanceScheduled({
    required DateTime scheduledTime,
    required String description,
  }) async {
    // Your existing maintenance scheduling logic here...
    
    final timeString = "${_getDayName(scheduledTime.weekday)}, ${scheduledTime.hour}:${scheduledTime.minute.toString().padLeft(2, '0')} ${scheduledTime.hour >= 12 ? 'PM' : 'AM'}";
    
    await _notificationManager.notifySystemMaintenance(
      scheduledTime: timeString,
      description: description,
    );
  }

  String _getDayName(int weekday) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday - 1];
  }
}

/// Usage Examples:
/// 
/// 1. In your device control code:
/// ```dart
/// final notificationExample = NotificationIntegrationExample();
/// await notificationExample.onDeviceStatusChanged(
///   deviceName: "Living Room Light",
///   room: "Living Room", 
///   isOn: true,
/// );
/// ```
/// 
/// 2. In your energy monitoring code:
/// ```dart
/// await notificationExample.onDailyEnergyCheck(
///   todayUsage: 15.2,
///   yesterdayUsage: 12.8,
///   threshold: 20.0,
/// );
/// ```
/// 
/// 3. In your device discovery code:
/// ```dart
/// await notificationExample.onNewDeviceDiscovered(
///   deviceName: "Smart Thermostat",
///   deviceType: "Climate Control",
///   macAddress: "AA:BB:CC:DD:EE:FF",
/// );
