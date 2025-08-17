import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart'; // For TimeOfDay
import 'package:homesync/usage.dart'; // Assuming UsageService is here
import 'package:intl/intl.dart'; // For date formatting (day of week)

class ApplianceSchedulingService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final UsageService _usageService;

  Timer? _periodicTimer;
  List<Map<String, dynamic>> _activeSchedules = [];
  final Map<String, DateTime> _manualOffOverrides = {}; // applianceId -> overrideExpiryTime

  // To store appliance data including wattage and relay for handleApplianceToggle
  final Map<String, Map<String, dynamic>> _applianceDetailsCache = {};

  static ApplianceSchedulingService? _instance;

  // Private constructor
  ApplianceSchedulingService._({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required UsageService usageService,
  })  : _auth = auth,
        _firestore = firestore,
        _usageService = usageService;

  // Static getter for the instance
  static ApplianceSchedulingService get instance {
    if (_instance == null) {
      throw Exception("ApplianceSchedulingService not initialized. Call initService() first.");
    }
    return _instance!;
  }

  // Static method to initialize the service
  static Future<void> initService({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required UsageService usageService,
  }) async {
    if (_instance == null) {
      _instance = ApplianceSchedulingService._(
        auth: auth,
        firestore: firestore,
        usageService: usageService,
      );
      await _instance!.initialize();
    } else {
      // Optionally, re-initialize or just ensure it's running if already created
      // For now, we assume it's initialized once.
      print("SchedulingService: Already initialized.");
    }
  }

  Future<void> initialize() async {
    // This is now an instance method called by initService
    final user = _auth.currentUser;
    if (user == null) {
      print("SchedulingService: No authenticated user. Instance cannot complete initialization.");
      return;
    }
    print("SchedulingService: Initializing for user ${user.uid}...");
    await _loadSchedules(user.uid);

    // Listen for changes to appliances to reload schedules if they are modified
    _firestore
        .collection('users')
        .doc(user.uid)
        .collection('appliances')
        .snapshots()
        .listen((snapshot) {
      print("SchedulingService: Appliance data changed, reloading schedules.");
      _loadSchedules(user.uid);
    });

    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(seconds: 1), _checkSchedules);
    print("SchedulingService: Periodic schedule check started.");
  }

  Future<void> _loadSchedules(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('appliances')
          .get();

      _activeSchedules = snapshot.docs.map((doc) {
        final data = doc.data();
        _applianceDetailsCache[doc.id] = {
          'wattage': (data['wattage'] as num?)?.toDouble() ?? 0.0,
          'relay': data['relay'] as String?, // Needed by some interpretations of handleApplianceToggle
          'applianceName': data['applianceName'] as String? ?? 'Unknown Device',
          // Store current status to avoid redundant Firestore reads in _checkSchedules,
          // but be aware this might get stale if status changes outside this service.
          // For robust status, _checkSchedules might need to fetch fresh status or listen to it.
          'applianceStatus': data['applianceStatus'] as String? ?? 'OFF',
        };
        return {
          'id': doc.id,
          ...data,
        };
      }).where((schedule) {
        // Filter for schedules that are potentially active (have days and times)
        final days = schedule['days'] as List?;
        final startTime = schedule['startTime'] as String?;
        final endTime = schedule['endTime'] as String?;
        return days != null && days.isNotEmpty && startTime != null && endTime != null;
      }).toList();
      print("SchedulingService: Loaded ${_activeSchedules.length} active schedules.");
    } catch (e) {
      print("SchedulingService: Error loading schedules: $e");
      _activeSchedules = [];
    }
  }

  String _getCurrentDayName(DateTime now) {
    return DateFormat('E').format(now); // E.g., "Mon", "Tue"
  }

  TimeOfDay? _parseTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty || timeStr == "0") {
      return null;
    }
    try {
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (e) {
      print("SchedulingService: Error parsing time string '$timeStr': $e");
    }
    return null;
  }

  void _checkSchedules(Timer timer) async {
    final user = _auth.currentUser;
    if (user == null) return;

    DateTime now = DateTime.now();
    String currentDayName = _getCurrentDayName(now);
    TimeOfDay currentTime = TimeOfDay.fromDateTime(now);

    // Clean up expired overrides
    _manualOffOverrides.removeWhere((applianceId, expiryTime) => now.isAfter(expiryTime));

    print("SchedulingService: Checking schedules at $now ($currentDayName $currentTime)");

    // Fetch user's kWh rate once for this check cycle
    double kwhrRate = DEFAULT_KWHR_RATE; // Default if not found
    DocumentSnapshot userDocSnap = await _firestore.collection('users').doc(user.uid).get();
    if (userDocSnap.exists && userDocSnap.data() != null) {
      kwhrRate = ((userDocSnap.data() as Map<String,dynamic>)['kwhr'] as num?)?.toDouble() ?? DEFAULT_KWHR_RATE;
    }

    for (var scheduleData in List.from(_activeSchedules)) { // Iterate on a copy
      String applianceId = scheduleData['id'];
      List<dynamic> scheduledDaysRaw = scheduleData['days'] as List<dynamic>? ?? [];
      List<String> scheduledDays = scheduledDaysRaw.map((day) => day.toString()).toList();
      String? startTimeStr = scheduleData['startTime'] as String?;
      String? endTimeStr = scheduleData['endTime'] as String?;
      
      // Fetch fresh appliance status for accurate check
      DocumentSnapshot applianceSnap;
      try {
        applianceSnap = await _firestore.collection('users').doc(user.uid).collection('appliances').doc(applianceId).get();
      } catch (e) {
        print("SchedulingService: Error fetching appliance $applianceId status: $e");
        continue; // Skip this appliance if status fetch fails
      }

      if (!applianceSnap.exists || applianceSnap.data() == null) {
        print("SchedulingService: Appliance $applianceId not found. Skipping.");
        continue;
      }
      String currentApplianceStatus = (applianceSnap.data() as Map<String,dynamic>)['applianceStatus'] as String? ?? 'OFF';
      Map<String, dynamic>? applianceDetails = _applianceDetailsCache[applianceId];
      if (applianceDetails == null) {
          print("SchedulingService: Missing details for $applianceId in cache. Skipping.");
          continue;
      }


      TimeOfDay? scheduledStartTime = _parseTime(startTimeStr);
      TimeOfDay? scheduledEndTime = _parseTime(endTimeStr);

      bool isScheduledDay = scheduledDays.contains(currentDayName);

      if (!isScheduledDay) {
        continue; // Not scheduled for today
      }

      // --- Auto-ON Logic ---
      if (scheduledStartTime != null && currentApplianceStatus == 'OFF') {
        if (currentTime.hour == scheduledStartTime.hour && currentTime.minute == scheduledStartTime.minute) {
          if (_manualOffOverrides.containsKey(applianceId)) {
            // Active manual OFF override for this appliance's current scheduled period
            print("SchedulingService: Auto-ON for $applianceId skipped due to active manual OFF override.");
          } else {
            print("SchedulingService: Auto-ON triggered for $applianceId");
            String? relayKey = applianceDetails['relay'] as String?;
            if (relayKey != null && relayKey.isNotEmpty) {
              print("SchedulingService: Updating relay $relayKey state to 1 (ON) for $applianceId");
              await _firestore.collection('users').doc(user.uid).collection('relay_states').doc(relayKey).set({'state': 1}, SetOptions(merge: true));
            } else {
              print("SchedulingService: No relayKey for $applianceId, cannot update relay state directly for Auto-ON.");
            }
            // It's important that handleApplianceToggle is called AFTER the relay state might have changed,
            // or that handleApplianceToggle itself also ensures the main applianceStatus field is updated.
            // The current handleApplianceToggle in usage.dart does not directly update the main applianceStatus.
            // This needs to be coordinated. For now, we assume UI listens to relay_state.
            // The toggle function will handle usage recording.
            await _usageService.handleApplianceToggle(
              userId: user.uid,
              applianceId: applianceId,
              isOn: true,
              wattage: applianceDetails['wattage'],
              kwhrRate: kwhrRate, 
            );
             // Ensure main appliance document reflects the ON status
            await _firestore.collection('users').doc(user.uid).collection('appliances').doc(applianceId).update({'applianceStatus': 'ON'});
            print("SchedulingService: Updated applianceStatus to ON for $applianceId in main doc.");
          }
        }
      }

      // --- Auto-OFF Logic ---
      if (scheduledEndTime != null && currentApplianceStatus == 'ON') {
        if (currentTime.hour == scheduledEndTime.hour && currentTime.minute == scheduledEndTime.minute) {
          print("SchedulingService: Auto-OFF triggered for $applianceId");
          String? relayKey = applianceDetails['relay'] as String?;
          if (relayKey != null && relayKey.isNotEmpty) {
            print("SchedulingService: Updating relay $relayKey state to 0 (OFF) for $applianceId");
            await _firestore.collection('users').doc(user.uid).collection('relay_states').doc(relayKey).set({'state': 0}, SetOptions(merge: true));
          } else {
            print("SchedulingService: No relayKey for $applianceId, cannot update relay state directly for Auto-OFF.");
          }
          await _usageService.handleApplianceToggle(
            userId: user.uid,
            applianceId: applianceId,
            isOn: false,
            wattage: applianceDetails['wattage'],
            kwhrRate: kwhrRate,
          );
          // Ensure main appliance document reflects the OFF status
          await _firestore.collection('users').doc(user.uid).collection('appliances').doc(applianceId).update({'applianceStatus': 'OFF'});
          print("SchedulingService: Updated applianceStatus to OFF for $applianceId in main doc.");
          _manualOffOverrides.remove(applianceId); 
        }
      }
    }
  }

  // Called from UI when user confirms manual OFF during a scheduled ON period
  void recordManualOffOverride(String applianceId, TimeOfDay scheduleEndTimeForToday) {
    final now = DateTime.now();
    // Override lasts until the end of the current day's scheduled ON period
    DateTime overrideExpiryTime = DateTime(
        now.year, now.month, now.day, 
        scheduleEndTimeForToday.hour, scheduleEndTimeForToday.minute
    );
    // If scheduleEndTime is next day (e.g. 23:00 to 02:00), adjust expiry.
    // For simplicity, current logic assumes endTime is on the same day as startTime.
    // Complex overnight schedules would need more sophisticated expiry calculation.

    if (overrideExpiryTime.isAfter(now)) {
        _manualOffOverrides[applianceId] = overrideExpiryTime;
        print("SchedulingService: Manual OFF override recorded for $applianceId until $overrideExpiryTime");
    } else {
        print("SchedulingService: Manual OFF override for $applianceId not recorded as schedule end time is in the past.");
    }
  }
  
  void dispose() {
    _periodicTimer?.cancel();
    // Cancel any Firestore listeners if they were set up directly here
    print("SchedulingService: Disposed.");
  }
}
