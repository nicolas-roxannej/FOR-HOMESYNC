import 'package:flutter/material.dart';
import 'package:homesync/welcome_screen.dart';
import 'package:homesync/signup_screen.dart';
import 'package:homesync/login_screen.dart';
import 'package:homesync/devices_screen.dart';
import 'package:homesync/forgot_password_screen.dart';
import 'package:homesync/homepage_screen.dart';
import 'package:homesync/rooms.dart';
import 'package:homesync/adddevices.dart';
import 'package:homesync/notification_screen.dart';
import 'package:homesync/notification_settings.dart';
import 'package:homesync/System_notif.dart';
import 'package:homesync/device_notif.dart';
import 'package:homesync/roomsinfo.dart';
import 'package:homesync/schedule.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Import firebase_options.dart
import 'package:homesync/deviceinfo.dart'; // Import deviceinfo.dart
import 'package:homesync/editdevice.dart'; // Import editdevice.dart
import 'package:homesync/profile_screen.dart';
import 'package:homesync/scheduling_service.dart'; // Import the scheduling service
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:homesync/usage.dart';
// Import DatabaseService
// Import usage.dart for sumAllAppliancesKwh and sumAllAppliancesKwhr
// Import FirebaseAuth
import 'package:homesync/device_usage.dart';
import 'package:homesync/notification_manager.dart';
import 'package:homesync/notification_test_screen.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
 main

  // Initialize notification system
  final notificationManager = NotificationManager();
  await notificationManager.initialize();

  // Trigger the appliance update chain on app startup
  await Permission.notification.isDenied.then((value) {
    if (value) {
      Permission.notification.request();
    }
  });
  await initializeService();
 wout_notif
  runApp(MyApp());
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
  service.startService();
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  // DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // DartPluginRegistrant.ensureInitialized();
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }
  service.on('stopService').listen((event) {
    service.stopSelf();
  });
  // bring to foreground
  Timer.periodic(const Duration(seconds: 1), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        // if you don't using custom notification, uncomment this
        service.setForegroundNotificationInfo(
          title: "HomeSync",
          content: "Scheduler is running",
        );
      }
    }
    print('FLUTTER BACKGROUND SERVICE: ${DateTime.now()}');
    final FirebaseAuth _auth = FirebaseAuth.instance;
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    final UsageService _usageService = UsageService();
    if (_auth.currentUser != null) {
      await ApplianceSchedulingService.initService(
        auth: _auth,
        firestore: _firestore,
        usageService: _usageService,
      );
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HomeSync',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => WelcomeScreen(),
        '/signup': (context) => SignUpScreen(),
        '/login': (context) => LoginScreen(),
        '/forgot-password': (context) => ForgotPasswordScreen(),
        '/homepage': (context) => HomepageScreen(),
        '/devices': (context) => DevicesScreen(schedulingService: ApplianceSchedulingService.instance),
        '/rooms':(context) => Rooms(),
        '/adddevice':(context) => AddDeviceScreen(),
        '/notification':(context) => NotificationScreen(),
        '/notificationsettings':(context) => NotificationSettings(),
        '/systemnotif':(context) => SystemNotif(),
        '/devicenotif':(context) => DeviceNotif(),
 main
        '/notificationtest':(context) => NotificationTestScreen(),
        '/roominfo': (context) => Roomsinfo(roomItem: ModalRoute.of(context)!.settings.arguments as String),
        '/roominfo': (context) => Roomsinfo(
          roomItem: ModalRoute.of(context)!.settings.arguments as String,
          schedulingService: ApplianceSchedulingService.instance,
        ),
 wout_notif
        '/schedule': (context)=> Schedule(),
        '/deviceinfo': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return DeviceInfoScreen( 
            applianceId: args['applianceId'] as String, 
            initialDeviceName: args['deviceName'] as String,
            schedulingService: ApplianceSchedulingService.instance, // Pass the singleton instance
        // initialDeviceUsage: args['deviceUsage'] as String, // Usage will be fetched by DeviceInfoScreen
          );
        },
        '/editdevice': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return EditDeviceScreen(
            applianceId: args['applianceId'] as String, // Expect applianceId in args
          );
        },
       '/profile':(context) => ProfileScreen(),
       '/deviceusage':(context) {
          // Attempt to get arguments. If DeviceUsage is navigated to without arguments,
          // this will cause an error or require default/null handling.
          // For now, let's assume arguments are passed similar to DeviceInfoScreen.
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final String userId = args?['userId'] as String? ?? "DEFAULT_USER_ID"; // Provide a fallback or handle null
          final String applianceId = args?['applianceId'] as String? ?? "DEFAULT_APPLIANCE_ID"; // Provide a fallback or handle null

          // It's crucial that DeviceUsage is prepared to handle these potentially default/invalid IDs,
          // for example, by showing an error message or an empty state.
          if (userId == "DEFAULT_USER_ID" || applianceId == "DEFAULT_APPLIANCE_ID") {
            // Optionally, return a screen indicating that parameters are missing
            // For now, we'll proceed, and DeviceUsage should handle it.
            print("Warning: Navigating to /deviceusage without proper userId or applianceId arguments.");
          }
          
          return DeviceUsage(
            userId: userId,
            applianceId: applianceId,
          );
        },



      },

    );
  }
}
