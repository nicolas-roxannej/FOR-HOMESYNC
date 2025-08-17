# HomeSync Notification System

This document describes the comprehensive notification system implemented for the HomeSync home automation app. The system provides Android push notifications for various home automation events.

## Overview

The notification system consists of several components that work together to provide real-time notifications for:
- Device status changes (on/off, connected/disconnected)
- Energy usage alerts and reports
- System updates and maintenance
- Safety alerts (overload, temperature warnings)
- Weather updates and energy-saving recommendations

## Architecture

### Core Components

1. **NotificationService** (`lib/notification_service.dart`)
   - Handles Firebase Cloud Messaging (FCM) and local notifications
   - Manages notification channels and permissions
   - Provides low-level notification functionality

2. **NotificationManager** (`lib/notification_manager.dart`)
   - High-level interface for triggering notifications
   - Integrates with user preferences and settings
   - Provides specific methods for different notification types

3. **NotificationTestScreen** (`lib/notification_test_screen.dart`)
   - Testing interface for all notification types
   - Helps verify that Android pop-ups are working correctly

4. **Integration Examples** (`lib/notification_integration_example.dart`)
   - Comprehensive examples showing how to integrate notifications with existing code
   - Ready-to-use code snippets for common scenarios

## Features

### Notification Types

#### Device Notifications
- Device status changes (on/off)
- Device connection status (connected/disconnected)
- New device discovery
- Automation triggers

#### Energy Notifications
- Daily energy reports
- High energy usage alerts
- Energy spikes from individual devices
- Monthly energy comparisons
- Energy-saving tips

#### System Notifications
- Firmware updates available
- System maintenance schedules
- Data sync status
- App updates
- Weather updates

#### Alert Notifications
- Electrical overload warnings
- Temperature alerts
- Connectivity issues
- Safety-related alerts

### Android Integration

#### Permissions
The system automatically requests the following Android permissions:
- `POST_NOTIFICATIONS` - For showing notifications
- `INTERNET` - For Firebase messaging
- `WAKE_LOCK` - For background notifications
- `VIBRATE` - For notification vibration
- `RECEIVE_BOOT_COMPLETED` - For persistent notifications

#### Notification Channels
Four notification channels are created with different priorities:
- **Device Notifications** - High importance
- **Energy Notifications** - High importance  
- **System Notifications** - Default importance
- **Alert Notifications** - Maximum importance

## Setup and Installation

### 1. Dependencies Added
The following packages were added to `pubspec.yaml`:
```yaml
firebase_messaging: ^15.1.6
flutter_local_notifications: ^18.0.1
```

### 2. Android Configuration
Updated `android/app/src/main/AndroidManifest.xml` with:
- Required permissions
- Firebase messaging service configuration
- Notification click handling

### 3. App Initialization
The notification system is initialized in `main.dart` during app startup:
```dart
final notificationManager = NotificationManager();
await notificationManager.initialize();
```

## Usage

### Basic Usage

```dart
import 'package:homesync/notification_manager.dart';

final notificationManager = NotificationManager();

// Device status change
await notificationManager.notifyDeviceStatusChange(
  deviceName: 'Living Room Light',
  room: 'Living Room',
  isOn: true,
);

// Energy alert
await notificationManager.notifyHighEnergyUsage(
  currentUsage: 15.2,
  threshold: 12.0,
  period: 'today',
);

// System notification
await notificationManager.notifySystemMaintenance(
  scheduledTime: 'Saturday, 2:00 AM',
  description: 'System optimization and updates',
);
```

### Integration with Existing Code

See `lib/notification_integration_example.dart` for comprehensive examples of how to integrate notifications with:
- Device control systems
- Energy monitoring
- Safety checks
- Scheduling systems
- Data synchronization

## Testing

### Notification Test Screen

Access the test screen through:
1. Navigate to Notification Settings
2. Tap "Test Notifications" under "Testing & Debug"
3. Test different notification types to verify Android pop-ups

### Manual Testing

```dart
// Test a device notification
await notificationManager.sendTestNotification(
  type: NotificationType.device,
  customTitle: 'Test Device Alert',
  customMessage: 'This is a test device notification',
);
```

## Configuration

### User Preferences

The system respects user notification preferences stored in SharedPreferences:
- `system_notifications_enabled` - Global system notifications
- `device_notifications_enabled` - Global device notifications  
- `energy_notifications_enabled` - Energy-related notifications
- `device_[devicename]_notifications` - Per-device notifications
- `firmware_update_enabled` - Firmware update notifications
- `new_device_found_enabled` - New device discovery notifications

### Notification Settings UI

Users can control notifications through:
- **Notification Settings** → **System** → Toggle system notification types
- **Notification Settings** → **Device** → Toggle per-device notifications
- **Notification Settings** → **Test Notifications** → Test the system

## Firebase Cloud Messaging (FCM)

### Setup Requirements

1. Ensure `google-services.json` is properly configured
2. Firebase project has Cloud Messaging enabled
3. FCM tokens are generated and can be used for remote notifications

### Remote Notifications

The system supports both local and remote notifications:
- **Local notifications** - Triggered by app logic
- **Remote notifications** - Sent via Firebase Console or server

### Background Handling

Notifications work in all app states:
- **Foreground** - Shows local notification overlay
- **Background** - Shows system notification
- **Terminated** - Handled by Firebase messaging service

## Troubleshooting

### Common Issues

1. **Notifications not appearing**
   - Check Android notification permissions
   - Verify notification channels are created
   - Test with the notification test screen

2. **Firebase messaging not working**
   - Verify `google-services.json` configuration
   - Check Firebase project settings
   - Ensure internet connectivity

3. **Permissions denied**
   - Request permissions manually in Android settings
   - Check if "Do Not Disturb" mode is enabled
   - Verify app notification settings in Android

### Debug Information

The system logs important information:
- FCM token generation
- Notification channel creation
- Permission request results
- Background message handling

## File Structure

```
lib/
├── notification_service.dart           # Core notification service
├── notification_manager.dart           # High-level notification manager
├── notification_test_screen.dart       # Testing interface
├── notification_integration_example.dart # Integration examples
├── notification_screen.dart            # Existing notification list UI
├── notification_settings.dart          # Notification settings UI
├── System_notif.dart                   # System notification settings
└── device_notif.dart                   # Device notification settings

android/app/src/main/
└── AndroidManifest.xml                 # Android permissions and services
```

## Integration Checklist

To fully integrate the notification system with your existing HomeSync functionality:

- [ ] Add notification calls to device control functions
- [ ] Integrate with energy monitoring systems
- [ ] Add safety monitoring notifications
- [ ] Connect to scheduling/automation systems
- [ ] Implement weather-based notifications
- [ ] Add data sync status notifications
- [ ] Test all notification types on Android device
- [ ] Configure user preference settings
- [ ] Set up Firebase Cloud Messaging for remote notifications

## Future Enhancements

Potential improvements to consider:
- iOS notification support
- Rich notifications with images and actions
- Notification scheduling and batching
- Machine learning for smart notification timing
- Integration with wearable devices
- Voice notifications via smart speakers

## Support

For issues or questions about the notification system:
1. Check the troubleshooting section above
2. Test with the notification test screen
3. Review the integration examples
4. Check Android system notification settings
5. Verify Firebase configuration

The notification system is designed to be robust and user-friendly, providing timely alerts for all important home automation events while respecting user preferences and system limitations.
