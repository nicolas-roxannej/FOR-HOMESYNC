import 'package:flutter/material.dart';
import 'package:homesync/adddevices.dart';
import 'package:homesync/notification_screen.dart';
import 'package:weather/weather.dart'; // Added weather import
import 'package:homesync/welcome_screen.dart';
import 'package:homesync/relay_state.dart'; // Re-adding for relay state management
import 'package:homesync/databaseservice.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:homesync/usage.dart'; // Import UsageTracker
import 'dart:async';
import 'dart:math'; // For min function
import 'package:firebase_auth/firebase_auth.dart'; // Added import for FirebaseAuth
import 'package:cloud_firestore/cloud_firestore.dart'; // For QueryDocumentSnapshot
import 'package:homesync/scheduling_service.dart'; // Import scheduling service
import 'package:intl/intl.dart'; // For date formatting

// TODO: Replace 'YOUR_API_KEY' with your actual OpenWeatherMap API key
const String _apiKey = 'YOUR_API_KEY'; // Placeholder for Weather API Key
const String _cityName = 'Manila'; // Default city for weather

class DevicesScreen extends StatefulWidget {
  final ApplianceSchedulingService schedulingService;

  const DevicesScreen({super.key, required this.schedulingService});

  @override
  State<DevicesScreen> createState() => DevicesScreenState();
}

class DevicesScreenState extends State<DevicesScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance; // Moved here
  Weather? _currentWeather; // Added weather state variable
  int _selectedIndex = 1;
  final DatabaseService _dbService = DatabaseService();
  late ApplianceSchedulingService _schedulingService; // Instance from widget
  StreamSubscription? _appliancesSubscription;
  final List<StreamSubscription> _relaySubscriptions = []; // For managing relay state listeners

  List<Map<String, dynamic>> _devices = []; // Changed to List<Map<String, dynamic>>

  // Local state for master power button visual, true if it's in "ON" commanding mode
  bool _masterPowerButtonState = false;

  // UsageService instance
  UsageService? _usageService;
  double _kwhrRate = DEFAULT_KWHR_RATE; // Cache for user's kWh rate

  // Method to get username from Firestore
  Future<String> getCurrentUsername() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          return userData['username'] ?? ' ';
        }
      }
      return ' ';
    } catch (e) {
      print('Error fetching username: $e');
      return ' ';
    }
  }

  // Added weather fetching method
  Future<void> _fetchWeather() async {
    if (_apiKey == 'YOUR_API_KEY') {
      print("Weather API key is a placeholder. Please replace it.");
      if (mounted) {
        setState(() {
          // Keep _currentWeather as null to show placeholder
        });
      }
      return;
    }
    WeatherFactory wf = WeatherFactory(_apiKey);
    try {
      Weather w = await wf.currentWeatherByCityName(_cityName);
      if (mounted) {
        setState(() {
          _currentWeather = w;
        });
      }
    } catch (e) {
      print("Failed to fetch weather: $e");
      if (mounted) {
        // Handle weather fetch error, e.g., show a default or error message
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _schedulingService = widget.schedulingService; // Initialize from widget
    _usageService = UsageService(); // Initialize UsageService
    _fetchUserKwhrRate(); // Fetch kwhrRate
    _fetchWeather(); // Fetch weather data
    _listenToAppliances();
    _listenForRelayStateChanges();
    _updateMasterPowerButtonVisualState();

    // User authentication check is handled within methods that need userId.
  }

  Future<void> _fetchUserKwhrRate() async {
    final user = _auth.currentUser;
    if (user == null) {
      print("DevicesScreen: User not authenticated. Using default kWh rate.");
      _kwhrRate = DEFAULT_KWHR_RATE; // Fallback to default
      return;
    }
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _kwhrRate = (data['kwhr'] as num?)?.toDouble() ?? DEFAULT_KWHR_RATE;
          });
        }
      } else {
         if (mounted) setState(() => _kwhrRate = DEFAULT_KWHR_RATE);
      }
    } catch (e) {
      print("DevicesScreen: Error fetching user kWh rate: $e. Using default.");
      if (mounted) setState(() => _kwhrRate = DEFAULT_KWHR_RATE);
    }
  }

  void _listenForRelayStateChanges() {
    // Clear existing subscriptions before starting new ones
    for (var sub in _relaySubscriptions) {
      sub.cancel();
    }
    _relaySubscriptions.clear();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("DevicesScreen: User not authenticated. Cannot listen to relay state changes.");
      return;
    }
    final userId = user.uid;

    // Listener for master relay (relay10) directly on the user document
    var masterRelaySub = FirebaseFirestore.instance
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
              _masterPowerButtonState = newMasterState == 1; // Update visual state for master button
              print("DevicesScreen: Updated master relay (relay10) state from Firestore: $newMasterState (${relay10StatusString ?? 'N/A'})");
            });
          }
        } else {
          print("DevicesScreen: User document for $userId does not exist. Assuming master relay (relay10) OFF.");
          if (RelayState.relayStates['relay10'] != 0) {
            setState(() {
              RelayState.relayStates['relay10'] = 0;
              _masterPowerButtonState = false;
            });
          }
        }
      }
    }, onError: (error) {
      print("DevicesScreen: Error listening to user document for relay10 state for user $userId: $error");
    });
    _relaySubscriptions.add(masterRelaySub);

    // Listeners for individual device relays (relay1 through relay9)
    for (int i = 1; i <= 9; i++) {
      String relayKey = "relay$i";
      var deviceRelaySub = FirebaseFirestore.instance
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
            final bool newIrControlledState = data['irControlled'] as bool? ?? false;

            bool changed = false;
            if (newState != null && RelayState.relayStates[relayKey] != newState) {
              RelayState.relayStates[relayKey] = newState;
              changed = true;
            }
            if (RelayState.irControlledStates[relayKey] != newIrControlledState) {
              RelayState.irControlledStates[relayKey] = newIrControlledState;
              changed = true;
            }

            if (changed) {
              setState(() {
                print("DevicesScreen: Updated device relay data from Firestore: $relayKey = State: ${RelayState.relayStates[relayKey]}, IR: ${RelayState.irControlledStates[relayKey]}");
              });
            }
          } else {
            print("DevicesScreen: Device relay document for $relayKey does not exist for user $userId. Assuming OFF and not IR controlled.");
            bool changed = false;
            if (RelayState.relayStates[relayKey] != 0) {
               RelayState.relayStates[relayKey] = 0;
               changed = true;
            }
            if (RelayState.irControlledStates[relayKey] != false) {
               RelayState.irControlledStates[relayKey] = false;
               changed = true;
            }
            if (changed && mounted) {
              setState(() {});
            }
          }
        }
      }, onError: (error) {
        print("DevicesScreen: Error listening to device relay state for $relayKey under user $userId: $error");
      });
      _relaySubscriptions.add(deviceRelaySub);
    }
  }

  void _listenToAppliances() {
    _appliancesSubscription?.cancel(); 

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("User not authenticated. Cannot fetch appliances.");
      if (mounted) {
        setState(() {
          _devices = [];
        });
      }
      return;
    }

    print("Authenticated user: ${user.email}");

    _appliancesSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('appliances')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _devices = snapshot.docs.map((doc) {
            return {
              'id': doc.id, // Store document ID
              ...doc.data(),
            };
          }).toList();

          print("Found ${_devices.length} devices from Firestore");
          // Log the first few devices for debugging
          for (int i = 0; i < min(_devices.length, 3); i++) {
            final data = _devices[i];
            print("Device ${i+1}: ${data['applianceName']} (${data['roomName']}) - Status: ${data['applianceStatus']}");
          }
        });
        _updateMasterPowerButtonVisualState();
      }
    }, onError: (error) {
      print("Error listening to appliances: $e");
      if (mounted) {
        setState(() {
          _devices = [];
        });
      }
    });
  }

  void _updateMasterPowerButtonVisualState() {
    // Check if relay10 state is available
    int masterState = RelayState.relayStates['relay10'] ?? 0;

    // Master power button shows "ON" if relay10 is ON
    if (mounted) {
      setState(() {
        _masterPowerButtonState = masterState == 1;
      });
    }

    print("Master power button state: ${_masterPowerButtonState ? 'ON' : 'OFF'}");
  }


  @override
  void dispose() {
    _appliancesSubscription?.cancel();
    for (var sub in _relaySubscriptions) {
      sub.cancel();
    }
    _relaySubscriptions.clear();
    super.dispose();
  }

  void _toggleMasterPower() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("Error: User not authenticated for master power toggle.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("User not authenticated.")),
        );
      }
      return;
    }
    final userUid = user.uid;

    int currentMasterState = RelayState.relayStates['relay10'] ?? 0;
    int newMasterState = 1 - currentMasterState; // Toggle between 0 and 1

    // Update local state immediately for responsiveness
    setState(() {
      RelayState.relayStates['relay10'] = newMasterState;
      _masterPowerButtonState = newMasterState == 1;
    });

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(userUid);
      final newMasterStateString = newMasterState == 1 ? 'ON' : 'OFF';

      batch.update(userDocRef, {'relay10': newMasterStateString});

      // If turning OFF master switch, turn off all devices
      if (newMasterState == 0) { // Master is turning OFF
        // Update all individual relays (1-9)
        for (int i = 1; i <= 9; i++) {
          String relayKey = 'relay$i';
          RelayState.relayStates[relayKey] = 0; // Update local state
          final relayDocRef = userDocRef.collection('relay_states').doc(relayKey);
          // Check if document exists before trying to update, or use set with merge if appropriate
          // For simplicity, assuming update is fine, but robust code might check existence or use set with merge.
          batch.update(relayDocRef, {'state': 0});
        }

        // Update all appliance documents' status to 'OFF'
        for (var deviceData in _devices) {
          final applianceId = deviceData['id'] as String?;
          if (applianceId != null) {
            final applianceDocRef = userDocRef.collection('appliances').doc(applianceId);
            batch.update(applianceDocRef, {'applianceStatus': 'OFF'});
          }
        }
      }
      // If turning ON master switch (newMasterState == 1), no individual devices are turned on automatically by this action.
      // They retain their previous states or are controlled individually.

      await batch.commit(); // Commit all batched writes
      print("Master power toggled to ${newMasterState == 1 ? 'ON' : 'OFF'} successfully using WriteBatch.");

    } catch (e) {
      print("Error during master power toggle with WriteBatch: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error toggling master power: ${e.toString()}")),
        );
        // Revert visual state if error by re-fetching current states
        // This might involve re-calling parts of _listenForRelayStateChanges or _listenToAppliances
        // For simplicity, we'll rely on the listeners to eventually correct the state.
        // A more robust solution might force a refresh of the specific states involved.
         _listenForRelayStateChanges(); // Re-attach listeners to get latest state
         _listenToAppliances();
      }
    }
  }

  // Helper methods for schedule logic (similar to DeviceInfoScreen)
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
      print("DevicesScreen: Error parsing time string '$timeStr': $e");
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

  Future<void> _toggleIndividualDevice(Map<String, dynamic> deviceDataWithId, String currentStatus) async {
    final String applianceName = deviceDataWithId['applianceName'] as String? ?? 'Unknown Device';
    final String applianceId = deviceDataWithId['id'] as String;

    // Check if master switch is OFF
    if (RelayState.relayStates['relay10'] == 0) {
      // If master switch is OFF, do nothing
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Cannot toggle device when master power is OFF")),
      );
      return;
    }

    // deviceData is now deviceDataWithId
    final String relayKey = deviceDataWithId['relay'] as String? ?? '';
    final double wattage = (deviceDataWithId['wattage'] as num?)?.toDouble() ?? 0.0;
    final String? startTimeStr = deviceDataWithId['startTime'] as String?;
    final String? endTimeStr = deviceDataWithId['endTime'] as String?;
    final List<String> scheduledDays = List<String>.from(deviceDataWithId['days'] as List<dynamic>? ?? []);

    // IR Control Check (existing logic)
    if (RelayState.irControlledStates[relayKey] == true && currentStatus == 'ON') {
       bool confirmTurnOff = await _showScheduleConfirmationDialog( // Using renamed dialog
         title: "Confirm Turn Off",
         content: "This device is currently controlled by IR. Do you want to force it OFF?",
       );
       if (!confirmTurnOff) return;
    }

    final bool intendedNewStatusFlag = currentStatus == 'OFF'; // If current is OFF, user wants to turn ON
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
      print("Toggle for $applianceName cancelled by user or schedule conflict.");
      // To revert visual state of switch in DeviceCard, we'd need to call setState here.
      if(mounted) {
        setState(() {}); // Force rebuild to ensure DeviceCard reflects the original _devices state.
      }
      return;
    }
    
    // Optimistic UI Update
    final int deviceIndex = _devices.indexWhere((d) => d['id'] == applianceId);
    if (deviceIndex == -1) {
      print("Error: Device not found in local list for optimistic update.");
      return;
    }
    final String previousStatus = _devices[deviceIndex]['applianceStatus'];
    _devices[deviceIndex]['applianceStatus'] = intendedNewStatusFlag ? 'ON' : 'OFF';
    if (mounted) {
      setState(() {}); // Update UI immediately
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // Revert optimistic update if user is somehow null
        if (mounted && deviceIndex != -1) {
          _devices[deviceIndex]['applianceStatus'] = previousStatus;
          setState(() {});
        }
        return;
      }

      // === Prioritized Relay State Update ===
      if (relayKey.isNotEmpty) {
        final int newRelayState = intendedNewStatusFlag ? 1 : 0;
        print("DevicesScreen: PRIORITY: Attempting to update relay state for $relayKey to $newRelayState for user ${user.uid}.");
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('relay_states')
              .doc(relayKey)
              .set({'state': newRelayState}, SetOptions(merge: true));
          print("DevicesScreen: PRIORITY: Relay state update for $relayKey to $newRelayState successful.");
        } catch (relayError) {
          print("DevicesScreen: PRIORITY: ERROR updating relay state for $relayKey: $relayError");
          // If relay update fails, we might revert optimistic UI and not proceed.
          // For now, logging the error. Consider if _usageService.handleApplianceToggle should still be called.
        }
      } else {
        print("DevicesScreen: PRIORITY: No relayKey found for appliance $applianceId. Skipping relay state update.");
      }
      // ====================================

      // Fetch user's kWh rate (needed for UsageService) - NOW USING CACHED _kwhrRate
      // DocumentSnapshot userSnap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      // double kwhrRate = DEFAULT_KWHR_RATE;
      // if (userSnap.exists && userSnap.data() != null) {
      //     kwhrRate = ((userSnap.data() as Map<String,dynamic>)['kwhr'] as num?)?.toDouble() ?? DEFAULT_KWHR_RATE;
      // }

      await _usageService?.handleApplianceToggle(
        userId: user.uid,
        applianceId: applianceId,
        isOn: intendedNewStatusFlag,
        wattage: wattage,
        kwhrRate: _kwhrRate, // Use cached kwhrRate
      );
      print("DevicesScreen: applianceStatus update via UsageService for $applianceId initiated after relay update attempt.");

    } catch (e) {
      print("Error during toggle operations (relay or UsageService) for $applianceName: $e");
      // Revert optimistic update on error
      if (mounted && deviceIndex != -1) {
        _devices[deviceIndex]['applianceStatus'] = previousStatus;
        setState(() {});
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update $applianceName: ${e.toString()}")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // final screenSize = MediaQuery.of(context).size; // Not used currently
    return Scaffold(
      backgroundColor: const Color(0xFFE9E7E6),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddDeviceScreen()),
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
              // Updated header section to match homepage design
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => _showFlyout(context),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Transform.translate(
                          offset: Offset(0, 20),
                          child: CircleAvatar(
                            backgroundColor: Colors.grey,
                            radius: 25,
                            child: Icon(Icons.home, color: Colors.black, size: 35),
                          ),
                        ),
                        SizedBox(width: 10),
                        Transform.translate(
                          offset: Offset(0, 20),
                          child: SizedBox(
                            width: 110,
                            child: FutureBuilder<String>(
                              future: getCurrentUsername(),
                              builder: (context, snapshot) {
                                return Text(
                                  snapshot.data ?? " ",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Updated weather section to match homepage
                  Transform.translate(
                    offset: Offset(0, 20),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.cloud_circle_sharp, size: 35, color: Colors.lightBlue),
                              SizedBox(width: 4),
                              Transform.translate(
                                offset: Offset(0, -5),
                                child: _currentWeather == null
                                    ? (_apiKey == 'YOUR_API_KEY'
                                        ? Text('Set API Key', style: GoogleFonts.inter(fontSize: 12))
                                        : Text('Loading...', style: GoogleFonts.inter(fontSize: 12)))
                                    : Text(
                                        '${_currentWeather?.temperature?.celsius?.toStringAsFixed(0) ?? '--'}°C',
                                        style: GoogleFonts.inter(fontSize: 16),
                                      ),
                              ),
                            ],
                          ),
                          Transform.translate(
                            offset: Offset(40, -15),
                            child: Text(
                              _currentWeather?.weatherDescription ?? (_apiKey == 'YOUR_API_KEY' ? 'Weather' : 'Fetching weather...'),
                              style: GoogleFonts.inter(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20),

              // Navigation Tabs
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavButton('Electricity', _selectedIndex == 0, 0),
                  _buildNavButton('Appliance', _selectedIndex == 1, 1),
                  _buildNavButton('Rooms', _selectedIndex == 2, 2),
                ],
              ),

              SizedBox(
                width: double.infinity,
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.black38,
                ),
              ),

              // UPDATED: Made the entire content area scrollable
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      
                      // UPDATED: Search section moved into scrollable area
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 47,
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'Search',
                                  prefixIcon: const Icon(Icons.search),
                                  filled: true,
                                  fillColor: Color(0xFFD9D9D9),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(30),
                                    borderSide: BorderSide(
                                      color: Colors.grey,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: RelayState.relayStates['relay10'] == 1 ? Colors.black : Colors.grey, // Use relay10 state
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.power_settings_new,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                onPressed: _toggleMasterPower,
                                tooltip: 'Master Power',
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 25),
                      
                      // UPDATED: Device grid now uses shrinkWrap and physics: NeverScrollableScrollPhysics
                      _devices.isEmpty
                          ? SizedBox(
                              height: 200, // Give it some height when empty
                              child: Center(child: Text("No devices found.", style: GoogleFonts.inter())),
                            )
                          : GridView.builder(
                              shrinkWrap: true, // UPDATED: Allow grid to size itself
                              physics: NeverScrollableScrollPhysics(), // UPDATED: Disable grid's own scrolling
                              padding: const EdgeInsets.only(bottom: 70),
                              itemCount: _devices.length,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                              itemBuilder: (context, index) {
                                final deviceDataWithId = _devices[index]; 
                                final String applianceId = deviceDataWithId['id'] as String;
                                final String applianceName = deviceDataWithId['applianceName'] as String? ?? 'Unknown Device';
                                final String roomName = deviceDataWithId['roomName'] as String? ?? 'Unknown Room';
                                final String deviceType = deviceDataWithId['deviceType'] as String? ?? 'Unknown Type';
                                final int iconCodePoint = (deviceDataWithId['icon'] is int) ? deviceDataWithId['icon'] as int : Icons.devices.codePoint;
                                final String relayKey = deviceDataWithId['relay'] as String? ?? '';

                                // Determine current state FROM RELAY_STATE
                                final bool currentRelayIsOn = (RelayState.relayStates[relayKey] == 1);
                                final String currentRelayStatusString = currentRelayIsOn ? 'ON' : 'OFF';
                                
                                // For DeviceCard display, it might still use applianceStatus from deviceDataWithId if needed for other logic,
                                // but the primary visual ON/OFF should be currentRelayIsOn.
                                // Let's ensure DeviceCard's `isOn` prop reflects the relay state.
                                final bool displayIsOn = RelayState.relayStates['relay10'] == 1 && currentRelayIsOn;

                                return GestureDetector(
                                  onTap: () {
                                    if (RelayState.relayStates['relay10'] == 1) {
                                      // Pass the status derived from the relay state
                                      _toggleIndividualDevice(deviceDataWithId, currentRelayStatusString);
                                    } else {
                                       ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Turn on master power first")),
                                      );
                                    }
                                  },
                                  onLongPress: () { // Navigate to device info on long press
                                  Navigator.pushNamed(
                                    context,
                                    '/editdevice',
                                    arguments: {
                                      'applianceId': applianceId,
                                    },
                                  );
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      // Change color based on individual state AND master switch state
                                      color: displayIsOn ? Colors.black : Colors.white, // Use displayIsOn
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
                                      applianceName: applianceName,
                                      roomName: roomName,
                                      deviceType: deviceType,
                                      // Pass individual state, now derived from relay state
                                      isOn: currentRelayIsOn, // This is the raw device state from relay
                                      icon: IconData(iconCodePoint, fontFamily: 'MaterialIcons'),
                                      applianceStatus: currentRelayStatusString, // Status string from relay
                                      masterSwitchIsOn: RelayState.relayStates['relay10'] == 1, 
                                      applianceId: applianceId,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFlyout(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Align(
          alignment: Alignment.centerRight,
          child: Transform.translate(
            offset: const Offset(-90, 0), // Adjust if necessary for your layout
            child: Container(
              width: screenSize.width * 0.75,
              height: screenSize.height,
              decoration: const BoxDecoration(
                color: Color(0xFF3D3D3D),
                // borderRadius: BorderRadius.only( // Full height, no specific radius needed
                //   topLeft: Radius.circular(0),
                //   bottomLeft: Radius.circular(0),
                // ),
              ),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 60),
                  Row(
                    children: [
                      const Icon(Icons.home, size: 50, color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded( 
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Updated to use FutureBuilder for username
                            FutureBuilder<String>(
                              future: getCurrentUsername(),
                              builder: (context, snapshot) {
                                return Text(
                                  snapshot.data ?? "User", // Display username or "User" as fallback
                                  style: TextStyle(
                                    color: Colors.white, 
                                    fontSize: 20, 
                                    fontWeight: FontWeight.bold
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                );
                              },
                            ),
                            Text(
                              _auth.currentUser?.email ?? "email@example.com", // Display user email
                              style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                              overflow: TextOverflow.ellipsis, 
                              maxLines: 1, 
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  ListTile(
                    leading: const Icon(Icons.person, color: Colors.white, size: 35),
                    title: Text('Profile', style: GoogleFonts.inter(color: Colors.white)),
                    onTap: () {
                    
                       Navigator.pushNamed(context, '/profile'); // Navigate to profile
                    }
                  ),
                  const SizedBox(height: 15),
                  ListTile(
                    leading: const Icon(Icons.notifications, color: Colors.white, size: 35),
                    title: Text('Notification', style: GoogleFonts.inter(color: Colors.white)),
                    onTap: () {
                      
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => NotificationScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 15),
                  ListTile(
                    leading: const Padding(
                      padding: EdgeInsets.only(left: 5), // Align icon
                      child: Icon(Icons.logout, color: Colors.white, size: 35),
                    ),
                    title: Text('Logout', style: GoogleFonts.inter(color: Colors.white)),
                    onTap: () async {
                      await _auth.signOut();
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => WelcomeScreen()),
                        (Route<dynamic> route) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavButton(String title, bool isSelected, int index) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: () {
            setState(() => _selectedIndex = index);
            switch (index) {
              case 0:
                Navigator.pushNamed(context, '/homepage'); // Assuming '/homepage' is your electricity screen route
                break;
              case 1:
                // Already on Devices screen, do nothing or refresh
                break;
              case 2:
                Navigator.pushNamed(context, '/rooms');
                break;
            }
          },
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal:12, vertical: 8),
            minimumSize: Size(80, 36) // Ensure buttons have a decent tap area
          ),
          child: Text(
            title,
            style: GoogleFonts.inter(
              color: isSelected ? Colors.black : Colors.grey[600],
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 16, // Slightly adjusted size
            ),
          ),
        ),
        if (isSelected)
        Transform.translate(
            offset: const Offset(0, -10),
          child:Container(
            height: 2, // Slightly thicker underline
            width: 70, // Width of underline
            color: Colors.brown[600], // Darker brown
            margin: const EdgeInsets.only(top: 1), // Closer to text
          ),
        ),
      ],
    );
  }
}

// DeviceCard widget with updated UI architecture
class DeviceCard extends StatelessWidget {
  final String applianceName;
  final String roomName;
  final String deviceType;
  final bool isOn;
  final IconData icon;
  final String applianceStatus; // Added applianceStatus
  final bool masterSwitchIsOn; // Added master switch state
  final String applianceId; // Added applianceId

  const DeviceCard({
    super.key,
    required this.applianceName,
    required this.roomName,
    required this.deviceType,
    required this.isOn,
    required this.icon,
    required this.applianceStatus, // Added applianceStatus
    required this.masterSwitchIsOn, // Added master switch state
    required this.applianceId, // Added applianceId
  });

  @override
  Widget build(BuildContext context) {
    // Determine the effective state for visual representation
    final bool effectiveIsOn = masterSwitchIsOn && isOn;

    return Stack(
      children: [     // box switch container
        Container(
          width: double.infinity, // Take full width of Grid cell
          height: double.infinity, // Take full height of Grid cell
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: effectiveIsOn ? Colors.white : Colors.black,
              width: 4,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center, // Align text to center
            children: [
              Icon(icon, color: effectiveIsOn ? Colors.white : Colors.black, size: 35,), // Adjusted size
              const SizedBox(height: 1),

              // Appliance Name
              Text(
                applianceName,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14, // Consistent font size
                  fontWeight: FontWeight.bold,
                  color: effectiveIsOn ? Colors.white : Colors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              // Room Name
              Text(
                roomName,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: effectiveIsOn ? Colors.white : Colors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              // Device Type
              Text(
                deviceType,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: effectiveIsOn ? Colors.white : Colors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 1),
              Text(  // status
                effectiveIsOn ? 'ON' : 'OFF',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: effectiveIsOn ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),

        // Edit btn in corner
        Positioned(
          top: 10,
          right: 9,
          child: InkWell(
            onTap: () {
              if (applianceStatus == 'ON') {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Turn off the appliance before editing.")),
                );
              } else {
                // Navigate to schedule or edit screen
                Navigator.pushNamed(
                  context,
                  '/editdevice',
                  arguments: {
                    'applianceId': applianceId,
                  },
                );
              }
            },
            child: Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: effectiveIsOn ? Colors.white30 : Colors.grey.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.edit,
                size: 16,
                color: effectiveIsOn ? Colors.white : Colors.black,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Helper for FirebaseAuth instance is now a member of DevicesScreenState
