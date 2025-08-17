import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:homesync/adddevices.dart';
// Import EditDeviceScreen
import 'package:homesync/relay_state.dart'; // Re-adding for relay state management
import 'package:homesync/databaseservice.dart';
import 'package:homesync/room_data_manager.dart'; // Re-adding for room data management
import 'package:homesync/devices_screen.dart'; // Import DeviceCard from devices_screen.dart
import 'package:homesync/usage.dart'; // Import UsageTracker
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart'; // For QueryDocumentSnapshot
import 'package:firebase_auth/firebase_auth.dart'; // For user authentication
import 'package:homesync/scheduling_service.dart'; // Import scheduling service
import 'package:intl/intl.dart'; // For date formatting

class Roomsinfo extends StatefulWidget {
  final String roomItem; 
  final ApplianceSchedulingService schedulingService;

  const Roomsinfo({super.key, required this.roomItem, required this.schedulingService});

  @override
  State<Roomsinfo> createState() => RoomsinfoState();
}

class RoomsinfoState extends State<Roomsinfo> {
  final RoomDataManager _roomDataManager = RoomDataManager(); 
  StreamSubscription? _relayStateSubscription; 
  final DatabaseService _dbService = DatabaseService();
  late ApplianceSchedulingService _schedulingService; // Instance from widget
  StreamSubscription? _appliancesSubscription;
  List<Map<String, dynamic>> _roomDevices = []; // Changed to List<Map<String, dynamic>>
  String _roomType = 'Unknown Type'; // State variable for room type
  UsageService? _usageService;

  @override
  void initState() {
    super.initState();
    _schedulingService = widget.schedulingService; // Initialize from widget
    _usageService = UsageService(); // Initialize UsageService
    _listenForRelayStateChanges(); // Start listening for relay changes
    _listenToRoomAppliances();
    _fetchRoomType(); // Fetch room type
  }

  @override
  void dispose() {
    _relayStateSubscription?.cancel(); // Cancel the relay subscription
    _appliancesSubscription?.cancel();
    super.dispose();
  }

  void _fetchRoomType() async {
    final roomDetails = await _roomDataManager.fetchRoomDetails(widget.roomItem);
    if (mounted && roomDetails != null) {
      setState(() {
        _roomType = roomDetails['roomType'] as String? ?? 'Unknown Type';
      });
    }
  }

  void _listenToRoomAppliances() {
    _appliancesSubscription?.cancel();
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("User not authenticated. Cannot fetch appliances.");
      if (mounted) {
        setState(() {
          _roomDevices = [];
        });
      }
      return;
    }
    
    print("Authenticated user: ${user.email}");
    print("Fetching devices for room: ${widget.roomItem}");
    
    _appliancesSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('appliances')
        .where('roomName', isEqualTo: widget.roomItem)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _roomDevices = snapshot.docs.map((doc) {
            return {
              'id': doc.id, // Store document ID
              ...doc.data(),
            };
          }).toList();
          
          print("Found ${_roomDevices.length} devices for room ${widget.roomItem}");
          // Log devices for debugging
          for (var deviceDataMap in _roomDevices) {
            print("Fetched Device: ${deviceDataMap['applianceName']} - Room: ${deviceDataMap['roomName']} - Status: ${deviceDataMap['applianceStatus']}");
          }
        });
      }
    }, onError: (error) {
      print("Error listening to room appliances for ${widget.roomItem}: $error");
      if (mounted) {
        setState(() {
          _roomDevices = [];
        });
      }
    });
  }

  void _listenForRelayStateChanges() {
    // Cancel existing subscriptions if any to prevent multiple listeners on hot reload or re-init.
    // This simple cancellation works if _relayStateSubscription is for a single combined stream or the last one in a loop.
    // For multiple individual subscriptions, a List<StreamSubscription> and proper cancellation loop in dispose is better.
    _relayStateSubscription?.cancel(); 
    // It's safer to manage multiple subscriptions in a list and cancel them all in dispose.
    // For this fix, we'll focus on correcting the paths and logic for relay10.

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("RoomsinfoScreen: User not authenticated. Cannot listen to relay state changes.");
      return;
    }
    final userId = user.uid;

    // Listener for master relay (relay10) directly on the user document
    // Note: _relayStateSubscription will be overwritten by the loop below.
    // This needs a more robust subscription management strategy for multiple listeners.
    // For now, this demonstrates the separate logic for relay10.
    var masterRelaySubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((userDocSnapshot) {
      if (mounted) {
        if (userDocSnapshot.exists && userDocSnapshot.data() != null) {
          final userData = userDocSnapshot.data()!;
          final String? relay10StatusString = userData['relay10'] as String?;
          int newMasterState = 0; // Default to OFF
          if (relay10StatusString == 'ON') {
            newMasterState = 1;
          }
          if (RelayState.relayStates['relay10'] != newMasterState) {
            setState(() {
              RelayState.relayStates['relay10'] = newMasterState;
              print("RoomsinfoScreen: Updated master relay (relay10) state from Firestore: $newMasterState (${relay10StatusString ?? 'N/A'})");
            });
          }
        } else {
          print("RoomsinfoScreen: User document for $userId does not exist. Assuming master relay (relay10) OFF.");
          if (RelayState.relayStates['relay10'] != 0) {
            setState(() {
              RelayState.relayStates['relay10'] = 0;
            });
          }
        }
      }
    }, onError: (error) {
      print("RoomsinfoScreen: Error listening to user document for relay10 state for user $userId: $error");
    });
    // TODO: Add masterRelaySubscription to a list of subscriptions to be cancelled in dispose().
    // For now, _relayStateSubscription will only hold the last subscription from the loop below.

    // Listeners for individual device relays (relay1 through relay9)
    for (int i = 1; i <= 9; i++) {
      String relayKey = "relay$i";
      // Each of these creates a new subscription. The _relayStateSubscription variable will only hold the last one.
      FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('relay_states')
          .doc(relayKey)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          if (snapshot.exists && snapshot.data() != null) {
            final data = snapshot.data()!;
            final newState = data['state'] as int?;
            if (newState != null && RelayState.relayStates[relayKey] != newState) {
              setState(() {
                RelayState.relayStates[relayKey] = newState;
                print("RoomsinfoScreen: Updated device relay state from Firestore: $relayKey = $newState");
              });
            }
          } else {
            print("RoomsinfoScreen: Device relay document for $relayKey does not exist for user $userId. Assuming OFF.");
            if (RelayState.relayStates[relayKey] != 0) {
               setState(() {
                 RelayState.relayStates[relayKey] = 0;
               });
            }
          }
        }
      }, onError: (error) {
        print("RoomsinfoScreen: Error listening to device relay state for $relayKey under user $userId: $error");
      });
    }
    // Note: The _relayStateSubscription should ideally be a List<StreamSubscription>
    // and each subscription added to it, then all cancelled in dispose.
    // The current code only allows cancelling the last subscription from the loop.
  }

  // Helper methods for schedule logic (similar to DeviceInfoScreen & DevicesScreen)
  TimeOfDay? _parseTime(String? timeStr, {bool isStartTime = false}) {
    if (timeStr == null || timeStr.isEmpty) return null;
    if (isStartTime && timeStr == "0") { 
        return null; 
    }
    try {
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (e) {
      print("RoomsinfoScreen: Error parsing time string '$timeStr': $e");
    }
    return null;
  }

  String _getCurrentDayName(DateTime now) {
    return DateFormat('E').format(now); // E.g., "Mon", "Tue"
  }

  Future<bool> _showScheduleConfirmationDialog({required String title, required String content}) async {
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(title),
              content: Text(content),
              actions: <Widget>[
                TextButton(
                  child: const Text('No'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                TextButton(
                  child: const Text('Yes'),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            );
          },
        ) ?? false;
  }

  Future<void> _toggleDeviceStatus(String applianceId, String currentStatus) async {
    // Check if master switch is ON
    if (RelayState.relayStates['relay10'] == 0) {
      // If master switch is OFF, do nothing and show a message
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Cannot toggle device when master power is OFF")),
        );
      }
      return;
    }

    final newStatus = currentStatus == 'ON' ? 'OFF' : 'ON';
    int deviceIndex = -1; // Declare outside try
    String previousStatus = currentStatus; // Declare outside try, initialize with currentStatus

    try {
      print("Toggling device $applianceId from $currentStatus to $newStatus in room ${widget.roomItem}");
      
      deviceIndex = _roomDevices.indexWhere((d) => d['id'] == applianceId); // Assign here
      if (deviceIndex == -1) {
        print("Error: Device $applianceId not found in local list for room ${widget.roomItem}.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Device not found. Please refresh.")),
          );
        }
        return;
      }
      final Map<String, dynamic> deviceDataMap = _roomDevices[deviceIndex];
      final String applianceName = deviceDataMap['applianceName'] as String? ?? 'Unknown Device';
      final double wattage = (deviceDataMap['wattage'] as num?)?.toDouble() ?? 0.0;
      final String? startTimeStr = deviceDataMap['startTime'] as String?;
      final String? endTimeStr = deviceDataMap['endTime'] as String?;
      final List<String> scheduledDays = List<String>.from(deviceDataMap['days'] as List<dynamic>? ?? []);

      final bool intendedNewStatusFlag = currentStatus == 'OFF'; 
      bool proceedWithToggle = true;

      DateTime now = DateTime.now();
      TimeOfDay currentTime = TimeOfDay.fromDateTime(now);
      String currentDayName = _getCurrentDayName(now);

      TimeOfDay? scheduledStartTime = _parseTime(startTimeStr, isStartTime: true);
      TimeOfDay? scheduledEndTime = _parseTime(endTimeStr);
      bool isScheduledToday = scheduledDays.contains(currentDayName);

      if (intendedNewStatusFlag == true) { // User wants to turn ON
        if (isScheduledToday && scheduledEndTime != null && scheduledStartTime != null) {
          double currentMinutes = currentTime.hour * 60.0 + currentTime.minute;
          double endMinutes = scheduledEndTime.hour * 60.0 + scheduledEndTime.minute;
          double startMinutes = scheduledStartTime.hour * 60.0 + scheduledStartTime.minute;
          bool isAfterScheduledEnd = (startMinutes <= endMinutes) ? (currentMinutes > endMinutes) : (currentMinutes > endMinutes && currentMinutes < startMinutes);
          if (isAfterScheduledEnd) {
               proceedWithToggle = await _showScheduleConfirmationDialog(
                  title: 'Confirm Action',
                  content: 'The scheduled ON time for $applianceName has ended for today. Are you sure you want to turn it ON?',
               );
          }
        }
      } else { // User wants to turn OFF
        if (isScheduledToday && scheduledStartTime != null && scheduledEndTime != null) {
          double currentMinutes = currentTime.hour * 60.0 + currentTime.minute;
          double startMinutes = scheduledStartTime.hour * 60.0 + scheduledStartTime.minute;
          double endMinutes = scheduledEndTime.hour * 60.0 + scheduledEndTime.minute;
          bool withinScheduledOnPeriod = (startMinutes <= endMinutes) ? (currentMinutes >= startMinutes && currentMinutes < endMinutes) : (currentMinutes >= startMinutes || currentMinutes < endMinutes);
          if (withinScheduledOnPeriod) {
            proceedWithToggle = await _showScheduleConfirmationDialog(
              title: 'Confirm Action',
              content: '$applianceName is currently within its scheduled ON time. Are you sure you want to turn it OFF?',
            );
            if (proceedWithToggle && mounted) {
              _schedulingService.recordManualOffOverride(applianceId, scheduledEndTime);
            }
          }
        }
      }

      if (!proceedWithToggle) {
        print("Toggle for $applianceName in room ${widget.roomItem} cancelled by user or schedule conflict.");
        if (mounted) {
          setState(() {}); // Rebuild to ensure UI reflects original state if user cancelled
        }
        return;
      }

      // Optimistic UI Update
      // previousStatus is already initialized. Now get the specific one if device found.
      previousStatus = deviceDataMap['applianceStatus']; 
      deviceDataMap['applianceStatus'] = intendedNewStatusFlag ? 'ON' : 'OFF';
      if (mounted) {
        setState(() {
          _roomDevices[deviceIndex] = deviceDataMap; // Update the list
        });
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      DocumentSnapshot userSnap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      double kwhrRate = DEFAULT_KWHR_RATE;
      if (userSnap.exists && userSnap.data() != null) {
          kwhrRate = ((userSnap.data() as Map<String,dynamic>)['kwhr'] as num?)?.toDouble() ?? DEFAULT_KWHR_RATE;
      }

      // === Prioritized Relay State Update ===
      final String? relayKey = deviceDataMap['relay'] as String?;
      if (relayKey != null && relayKey.isNotEmpty) {
        final int newRelayState = intendedNewStatusFlag ? 1 : 0;
        print("RoomsinfoScreen: PRIORITY: Attempting to update relay state for $relayKey to $newRelayState for user ${user.uid}.");
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('relay_states')
              .doc(relayKey)
              .set({'state': newRelayState}, SetOptions(merge: true));
          print("RoomsinfoScreen: PRIORITY: Relay state update for $relayKey to $newRelayState successful.");
        } catch (relayError) {
          print("RoomsinfoScreen: PRIORITY: ERROR updating relay state for $relayKey: $relayError");
        }
      } else {
        print("RoomsinfoScreen: PRIORITY: No relayKey found for appliance $applianceId. Skipping relay state update.");
      }
      // ====================================

      await _usageService?.handleApplianceToggle(
        userId: user.uid,
        applianceId: applianceId,
        isOn: intendedNewStatusFlag,
        wattage: wattage,
        kwhrRate: kwhrRate,
      );
      print("RoomsinfoScreen: applianceStatus update via UsageService for $applianceId initiated after relay update attempt.");

    } catch (e) {
      print("Error during toggle operations (relay or UsageService) for $applianceId in room ${widget.roomItem}: $e");
      // Revert optimistic update on error
      if (mounted && deviceIndex != -1) {
        _roomDevices[deviceIndex]['applianceStatus'] = previousStatus;
        setState(() {});
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update $applianceId: ${e.toString()}")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9E7E6),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // When adding a device from a room screen, you might pre-fill the roomName
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddDeviceScreen(initialRoomName: widget.roomItem)),
          );
        },
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.only(top: 30),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 50, color: Colors.black),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      widget.roomItem,
                      style: GoogleFonts.jaldi(
                        textStyle: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _roomDevices.isEmpty
                    ? Center(child: Text("No devices found in ${widget.roomItem}.",
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: Colors.grey[700],
                        ),
                      ))
                    : GridView.builder(
                        padding: const EdgeInsets.only(top: 20, bottom: 70),
                        itemCount: _roomDevices.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemBuilder: (context, index) {
                          final deviceDataMap = _roomDevices[index]; 
                          final String applianceId = deviceDataMap['id'] as String;
                          final String applianceName = deviceDataMap['applianceName'] as String? ?? 'Unknown Device';
                          final String roomName = deviceDataMap['roomName'] as String? ?? 'Unknown Room'; // This should be widget.roomItem
                          final String deviceType = deviceDataMap['deviceType'] as String? ?? 'Unknown Type';
                          final int iconCodePoint = (deviceDataMap['icon'] is int) ? deviceDataMap['icon'] as int : Icons.devices.codePoint;
                          final String relayKey = deviceDataMap['relay'] as String? ?? '';
                          
                          final bool masterSwitchIsOn = RelayState.relayStates['relay10'] == 1;
                          // Determine current state FROM RELAY_STATE
                          final bool currentRelayIsOn = (RelayState.relayStates[relayKey] == 1);
                          final String currentRelayStatusString = currentRelayIsOn ? 'ON' : 'OFF';
                          
                          // Effective visual state for the card
                          final bool displayIsOn = masterSwitchIsOn && currentRelayIsOn;

                          return GestureDetector(
                            onTap: () {
                              if (masterSwitchIsOn) { // Only allow toggle if master is ON
                                _toggleDeviceStatus(applianceId, currentRelayStatusString);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Turn on master power first")),
                                );
                              }
                            },
                            onLongPress: () {
                              Navigator.pushNamed(
                                context,
                                '/deviceinfo',
                                arguments: {
                                  'applianceId': applianceId,
                                  'deviceName': applianceName,
                                },
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: displayIsOn ? Colors.black : Colors.white, // Color based on effective display state
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.3),
                                    spreadRadius: 1,
                                    blurRadius: 3,
                                    offset: Offset(0, 2),
                                  )
                                ]
                              ),
                              child: DeviceCard( 
                                applianceId: applianceId,
                                applianceName: applianceName,
                                roomName: roomName, // Use roomName from device data for consistency if DeviceCard expects it
                                deviceType: deviceType,
 main
                                isOn: isOn, // Pass individual device state
                                icon: _getIconFromCodePoint(iconCodePoint),
                                applianceStatus: applianceStatus, // Pass applianceStatus
                                masterSwitchIsOn: masterSwitchIsOn, // Pass master switch state
                                isOn: currentRelayIsOn, // Pass the raw relay state
                                icon: IconData(iconCodePoint, fontFamily: 'MaterialIcons'),
                                applianceStatus: currentRelayStatusString, // Pass status string from relay
                                masterSwitchIsOn: masterSwitchIsOn, 
 wout_notif
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _getIconFromCodePoint(int codePoint) {
  final Map<int, IconData> iconMap = {
    Icons.light.codePoint: Icons.light,
    Icons.tv.codePoint: Icons.tv,
    Icons.power.codePoint: Icons.power,
    Icons.kitchen.codePoint: Icons.kitchen,
    Icons.speaker.codePoint: Icons.speaker,
    Icons.laptop.codePoint: Icons.laptop,
    Icons.ac_unit.codePoint: Icons.ac_unit,
    Icons.microwave.codePoint: Icons.microwave,
    Icons.coffee_maker.codePoint: Icons.coffee_maker,
    Icons.radio_button_checked.codePoint: Icons.radio_button_checked,
    Icons.thermostat.codePoint: Icons.thermostat,
    Icons.doorbell.codePoint: Icons.doorbell,
    Icons.camera.codePoint: Icons.camera,
    Icons.sensor_door.codePoint: Icons.sensor_door,
    Icons.lock.codePoint: Icons.lock,
    Icons.door_sliding.codePoint: Icons.door_sliding,
    Icons.local_laundry_service.codePoint: Icons.local_laundry_service,
    Icons.dining.codePoint: Icons.dining,
    Icons.rice_bowl.codePoint: Icons.rice_bowl,
    Icons.wind_power.codePoint: Icons.wind_power,
    Icons.router.codePoint: Icons.router,
    Icons.outdoor_grill.codePoint: Icons.outdoor_grill,
    Icons.air.codePoint: Icons.air,
    Icons.alarm.codePoint: Icons.alarm,
    Icons.living.codePoint: Icons.living,
    Icons.bed.codePoint: Icons.bed,
    Icons.bathroom.codePoint: Icons.bathroom,
    Icons.meeting_room.codePoint: Icons.meeting_room,
    Icons.garage.codePoint: Icons.garage,
    Icons.local_library.codePoint: Icons.local_library,
    Icons.stairs.codePoint: Icons.stairs,
    Icons.devices.codePoint: Icons.devices,
    Icons.home.codePoint: Icons.home,
  };
  return iconMap[codePoint] ?? Icons.devices;
}
