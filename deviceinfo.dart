import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:homesync/device_usage.dart';
import 'package:homesync/usage.dart'; // Now imports UsageService
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:homesync/databaseservice.dart'; // Import DatabaseService
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'package:intl/intl.dart'; // Import for date formatting
import 'package:homesync/scheduling_service.dart'; // Import the scheduling service

class DeviceInfoScreen extends StatefulWidget {
  final String applianceId;
  final String initialDeviceName;
  final ApplianceSchedulingService schedulingService;

  const DeviceInfoScreen({
    super.key,
    required this.applianceId,
    required this.initialDeviceName,
    required this.schedulingService,
  });

  @override
  DeviceInfoScreenState createState() => DeviceInfoScreenState();
}

class DeviceInfoScreenState extends State<DeviceInfoScreen> {
  final DatabaseService _dbService = DatabaseService();
  StreamSubscription? _applianceSubscription;
  StreamSubscription? _specificRelayStateSubscription; // For this device's relay
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late UsageService _usageService;
  late ApplianceSchedulingService _schedulingService;

  // Schedule details state
  String? _startTimeStr;
  String? _endTimeStr;
  List<String> _scheduledDays = [];

  bool _isDeviceOn = false;
  bool _isLoadingUsage = false;
  String _currentDeviceName = "";
  String _currentDeviceUsage = "0 kWh";
  final String _latestDailyUsage = "0 kWh"; 
  final bool _showAverageUsages = false; 
  Map<String, double> _averageUsages = {}; 
  bool _isRefreshing = false;

  late TextEditingController _nameController;
  late TextEditingController _roomController;
  late TextEditingController _typeController;
  final TextEditingController _kWhRateController = TextEditingController(text: "0.0");
  IconData _selectedIcon = Icons.devices;
  String _deviceType = 'Light';
  List<String> _roomNames = [];
  String? _selectedRoom;

  String _selectedPeriod = 'Daily'; 
  double _totalUsageKwh = 0.0;
  double _totalElectricityCost = 0.0;
  StreamSubscription? _periodicUsageSubscription;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialDeviceName);
    _roomController = TextEditingController();
    _typeController = TextEditingController();
    _usageService = UsageService();
    _schedulingService = widget.schedulingService;
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      _listenToPeriodicUsageData();
    } else {
       print("User not logged in in initState");
    }
    _listenToApplianceData();
    _fetchRooms();
  }

  @override
  void dispose() {
    _applianceSubscription?.cancel();
    _specificRelayStateSubscription?.cancel(); // Cancel new subscription
    _periodicUsageSubscription?.cancel();
    _nameController.dispose();
    _roomController.dispose();
    _typeController.dispose();
    _kWhRateController.dispose();
    super.dispose();
  }

  void _listenToApplianceData() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      if (mounted) setState(() => _currentDeviceName = "Error: Not logged in");
      return;
    }
    _applianceSubscription = _dbService.streamDocument(
      collectionPath: 'users/$userId/appliances',
      docId: widget.applianceId,
    ).listen((DocumentSnapshot<Map<String, dynamic>> snapshot) async {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        if (mounted) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
          final userData = userDoc.data(); // Explicit cast
          double userKwhrValue = (userDoc.exists && userData != null && userData['kwhr'] is num) ? (userData['kwhr'] as num).toDouble() : DEFAULT_KWHR_RATE;

          setState(() {
            _isDeviceOn = (data['applianceStatus'] == 'ON');
            _currentDeviceName = data['applianceName'] ?? widget.initialDeviceName;
            _startTimeStr = data['startTime'] as String?;
            _endTimeStr = data['endTime'] as String?;
            final daysData = data['days'];
            if (daysData is List) {
              _scheduledDays = List<String>.from(daysData.map((day) => day.toString()));
            } else {
              _scheduledDays = [];
            }
            _nameController.text = _currentDeviceName;
            _roomController.text = data['roomName'] ?? "";
            _deviceType = data['deviceType'] ?? "Light";
            _typeController.text = _deviceType;
            _selectedIcon = IconData(data['icon'] ?? Icons.devices.codePoint, fontFamily: 'MaterialIcons');
            _kWhRateController.text = userKwhrValue.toString();
            double accumulatedKwh = (data['kwh'] is num) ? (data['kwh'] as num).toDouble() : 0.0;
            _currentDeviceUsage = "${accumulatedKwh.toStringAsFixed(2)} kWh";
            _selectedRoom = data['roomName'] as String?;

            // After getting appliance data, listen to its specific relay state
            final String? relayKey = data['relay'] as String?;
            _listenToSpecificRelayState(relayKey);
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _currentDeviceName = "Appliance not found";
            _isDeviceOn = false; // Default if appliance not found
            _isLoadingUsage = false; 
          });
        }
      }
    }, onError: (error) {
      if (mounted) setState(() => _currentDeviceName = "Error loading data");
    });
  }

  void _listenToSpecificRelayState(String? relayKey) {
    _specificRelayStateSubscription?.cancel();
    final userId = _auth.currentUser?.uid;
    if (userId == null || relayKey == null || relayKey.isEmpty) {
      print("DeviceInfoScreen: Cannot listen to specific relay state - userId or relayKey missing.");
      // Ensure _isDeviceOn reflects a default or error state if needed
      if (mounted && (relayKey == null || relayKey.isEmpty)) {
          setState(() {
              _isDeviceOn = false; // Default to OFF if no relay key
          });
      }
      return;
    }

    print("DeviceInfoScreen: Listening to relay state for $relayKey for user $userId");
    _specificRelayStateSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('relay_states')
        .doc(relayKey)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        if (snapshot.exists && snapshot.data() != null) {
          final relayData = snapshot.data()!;
          final bool currentRelayIsOn = (relayData['state'] == 1);
          print("DeviceInfoScreen: Relay $relayKey state received: ${relayData['state']}. UI should be ${currentRelayIsOn ? 'ON' : 'OFF'}");
          if (_isDeviceOn != currentRelayIsOn) { // Only update if different to avoid unnecessary rebuilds
            setState(() {
              _isDeviceOn = currentRelayIsOn;
            });
          }
        } else {
          print("DeviceInfoScreen: Relay document for $relayKey does not exist. Defaulting UI to OFF.");
          // If relay doc doesn't exist, assume OFF
          if (_isDeviceOn != false) {
            setState(() {
              _isDeviceOn = false;
            });
          }
        }
      }
    }, onError: (error) {
      print("DeviceInfoScreen: Error listening to relay state for $relayKey: $error");
      if (mounted && _isDeviceOn != false) { // Default to OFF on error
          setState(() {
              _isDeviceOn = false;
          });
      }
    });
  }

  Future<void> _fetchRooms() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    try {
      final roomDocs = await _dbService.getCollection(collectionPath: 'users/$userId/Rooms');
      final roomNames = roomDocs.docs.map((doc) => doc['roomName'] as String).toList();
      if (mounted) {
        setState(() {
          _roomNames = roomNames;
          if (_roomController.text.isNotEmpty && _roomNames.contains(_roomController.text)) {
            _selectedRoom = _roomController.text;
          } else if (_roomNames.isNotEmpty) {
            _selectedRoom = _roomNames.first;
            _roomController.text = _selectedRoom!;
          } else {
            _selectedRoom = null;
            _roomController.text = '';
          }
        });
      }
    } catch (e) {
      print("Error fetching rooms: $e");
    }
  }

  void _addRoom() async {
    TextEditingController newRoomController = TextEditingController();
    IconData roomIconSelected = Icons.home;

    String? newRoomName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFE9E7E6),
          titleTextStyle: GoogleFonts.jaldi(fontSize: 25, fontWeight: FontWeight.bold, color: Colors.black),
          title: Text('Add New Room'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: newRoomController,
                      style: GoogleFonts.inter(textStyle: TextStyle(fontSize: 17), color: Colors.black),
                      decoration: InputDecoration(
                        filled: true, fillColor: Colors.white, border: OutlineInputBorder(),
                        hintText: "Enter Room Name", hintStyle: GoogleFonts.inter(color: Colors.grey, fontSize: 15),
                        prefixIcon: Icon(roomIconSelected, color: Colors.black, size: 24),
                      ),
                    ),
                    SizedBox(height: 15),
                    Text('Select Icon', style: GoogleFonts.jaldi(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                    SizedBox(height: 5),
                    Container(
                      height: 200, width: double.maxFinite,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                      child: GridView.count(
                        crossAxisCount: 4, shrinkWrap: true,
                        children: [
                          Icons.living, Icons.bed, Icons.kitchen, Icons.dining,
                          Icons.bathroom, Icons.meeting_room, Icons.workspace_premium, Icons.chair,
                          Icons.stairs, Icons.garage, Icons.yard, Icons.balcony,
                        ].map((icon) {
                          return IconButton(
                            icon: Icon(icon, color: roomIconSelected == icon ? Theme.of(context).colorScheme.secondary : Colors.black),
                            onPressed: () => setDialogState(() => roomIconSelected = icon),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            }
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel', style: GoogleFonts.jaldi(textStyle: TextStyle(fontSize: 18, color: Colors.black87))),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              onPressed: () { if (newRoomController.text.trim().isNotEmpty) Navigator.of(context).pop(newRoomController.text.trim()); },
              style: ButtonStyle(backgroundColor: WidgetStateProperty.all(Colors.black), foregroundColor: WidgetStateProperty.all(Colors.white)),
              child: Text('Add', style: GoogleFonts.jaldi(textStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.bold), color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (newRoomName != null && newRoomName.isNotEmpty) {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        try {
          await _dbService.addDocumentToCollection(
            collectionPath: 'users/$userId/Rooms',
            data: {'roomName': newRoomName, 'icon': roomIconSelected.codePoint, 'createdAt': FieldValue.serverTimestamp()},
          );
          await _fetchRooms();
          if (mounted && _roomNames.contains(newRoomName)) {
            setState(() { _selectedRoom = newRoomName; _roomController.text = newRoomName; });
          }
          if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Room '$newRoomName' added successfully!")));
        } catch (e) {
          if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error adding room: ${e.toString()}")));
        }
      }
    }
  }

  Future<void> _fetchUsageForPeriod(String period) async {
    print("INFO: _fetchUsageForPeriod for '$period' needs rewrite for UsageService data structure.");
  }

  String _getMonthNameHelper(int month) {
    const monthNames = ['', 'january', 'february', 'march', 'april', 'may', 'jun', 'july', 'august', 'september', 'october', 'november', 'december'];
    return monthNames[month].toLowerCase();
  }

  int _getWeekOfMonthHelper(DateTime date) {
    if (date.day <= 7) return 1;
    if (date.day <= 14) return 2;
    if (date.day <= 21) return 3;
    if (date.day <= 28) return 4;
    return 5;
  }

  Future<void> _fetchAverageUsages() async {
     print("INFO: _fetchAverageUsages needs rewrite for UsageService data structure.");
  }

  void _listenToPeriodicUsageData() {
     _periodicUsageSubscription?.cancel();
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) setState(() { _totalUsageKwh = 0.0; _totalElectricityCost = 0.0; _isLoadingUsage = false; });
      return;
    }
    if (mounted) setState(() => _isLoadingUsage = true);
    final userId = user.uid;
    final applianceId = widget.applianceId;
    final now = DateTime.now();
    String firestorePath;
    String yearStr = now.year.toString();
    String monthName = _getMonthNameHelper(now.month);
    int weekOfMonth = _getWeekOfMonthHelper(now);
    String dayStr = DateFormat('yyyy-MM-dd').format(now);

    switch (_selectedPeriod.toLowerCase()) {
      case 'daily':
        firestorePath = 'users/$userId/appliances/$applianceId/yearly_usage/$yearStr/monthly_usage/${monthName}_usage/week_usage/week${weekOfMonth}_usage/day_usage/$dayStr';
        break;
      case 'weekly':
        firestorePath = 'users/$userId/appliances/$applianceId/yearly_usage/$yearStr/monthly_usage/${monthName}_usage/week_usage/week${weekOfMonth}_usage';
        break;
      case 'monthly':
        firestorePath = 'users/$userId/appliances/$applianceId/yearly_usage/$yearStr/monthly_usage/${monthName}_usage';
        break;
      case 'yearly':
        firestorePath = 'users/$userId/appliances/$applianceId/yearly_usage/$yearStr';
        break;
      default:
        if (mounted) setState(() { _totalUsageKwh = 0.0; _totalElectricityCost = 0.0; _isLoadingUsage = false;});
        return;
    }
    _periodicUsageSubscription = FirebaseFirestore.instance.doc(firestorePath).snapshots().listen(
      (snapshot) {
        if (mounted) {
          if (snapshot.exists && snapshot.data() != null) {
            final data = snapshot.data()!;
            setState(() {
              _totalUsageKwh = (data['kwh'] as num?)?.toDouble() ?? 0.0;
              _totalElectricityCost = (data['kwhrcost'] as num?)?.toDouble() ?? 0.0;
              _isLoadingUsage = false;
            });
          } else {
            setState(() { _totalUsageKwh = 0.0; _totalElectricityCost = 0.0; _isLoadingUsage = false;});
          }
        }
      },
      onError: (error) {
        if (mounted) setState(() { _totalUsageKwh = 0.0; _totalElectricityCost = 0.0; _isLoadingUsage = false; });
      }
    );
  }

  // Helper methods for schedule logic
  TimeOfDay? _parseTime(String? timeStr, {bool isStartTime = false}) {
    if (timeStr == null || timeStr.isEmpty) return null;
    if (isStartTime && timeStr == "0") { // "0" for startTime means DO NOT auto-ON
        return null; 
    }
    try {
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (e) {
      print("DeviceInfoScreen: Error parsing time string '$timeStr': $e");
    }
    return null;
  }

  String _getCurrentDayName(DateTime now) {
    return DateFormat('E').format(now); // E.g., "Mon", "Tue"
  }

  Future<bool> _showConfirmationDialog({required String title, required String content}) async {
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

  Future<void> _toggleDeviceStatus(bool newStatus) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print("User not logged in, cannot update appliance status.");
      return;
    }

    DocumentSnapshot applianceSnap = await FirebaseFirestore.instance
        .collection('users').doc(userId)
        .collection('appliances').doc(widget.applianceId)
        .get();

    if (!applianceSnap.exists || applianceSnap.data() == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Appliance data not found. Cannot toggle.")),
        );
      }
      return;
    }
    Map<String, dynamic> applianceData = applianceSnap.data() as Map<String, dynamic>;
    double wattage = (applianceData['wattage'] as num?)?.toDouble() ?? 0.0;
    
    DocumentSnapshot userSnap = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    double kwhrRate = DEFAULT_KWHR_RATE; 
    if (userSnap.exists && userSnap.data() != null) {
        kwhrRate = ((userSnap.data() as Map<String,dynamic>)['kwhr'] as num?)?.toDouble() ?? DEFAULT_KWHR_RATE;
    }

    DateTime now = DateTime.now();
    TimeOfDay currentTime = TimeOfDay.fromDateTime(now);
    String currentDayName = _getCurrentDayName(now);

    // Use schedule details from state, which are updated by _listenToApplianceData
    TimeOfDay? scheduledStartTime = _parseTime(_startTimeStr, isStartTime: true);
    TimeOfDay? scheduledEndTime = _parseTime(_endTimeStr); 
    bool isScheduledToday = _scheduledDays.contains(currentDayName);

    bool proceedWithToggle = true;

    if (newStatus == true) { // Turning ON
      if (isScheduledToday && scheduledEndTime != null && scheduledStartTime != null) {
        double currentMinutes = currentTime.hour * 60.0 + currentTime.minute;
        double endMinutes = scheduledEndTime.hour * 60.0 + scheduledEndTime.minute;
        double startMinutes = scheduledStartTime.hour * 60.0 + scheduledStartTime.minute;
        
        bool isAfterScheduledEnd = false;
        if (startMinutes <= endMinutes) { // Same day schedule
            isAfterScheduledEnd = currentMinutes > endMinutes;
        } else { // Overnight schedule
             if (currentMinutes > endMinutes && currentMinutes < startMinutes) { 
                isAfterScheduledEnd = true;
             }
        }

        if (isAfterScheduledEnd) {
             proceedWithToggle = await _showConfirmationDialog(
                title: 'Confirm Action',
                content: 'The scheduled ON time for $_currentDeviceName has ended for today. Are you sure you want to turn it ON?',
             );
        }
      }
    } else { // Turning OFF
      if (isScheduledToday && scheduledStartTime != null && scheduledEndTime != null) {
        double currentMinutes = currentTime.hour * 60.0 + currentTime.minute;
        double startMinutes = scheduledStartTime.hour * 60.0 + scheduledStartTime.minute;
        double endMinutes = scheduledEndTime.hour * 60.0 + scheduledEndTime.minute;

        bool withinScheduledOnPeriod = false;
        if (startMinutes <= endMinutes) { // Same day schedule
            withinScheduledOnPeriod = currentMinutes >= startMinutes && currentMinutes < endMinutes;
        } else { // Overnight schedule
            withinScheduledOnPeriod = currentMinutes >= startMinutes || currentMinutes < endMinutes;
        }

        if (withinScheduledOnPeriod) {
          proceedWithToggle = await _showConfirmationDialog(
            title: 'Confirm Action',
            content: '$_currentDeviceName is currently within its scheduled ON time. Are you sure you want to turn it OFF?',
          );
          if (proceedWithToggle && mounted) {
            _schedulingService.recordManualOffOverride(widget.applianceId, scheduledEndTime);
          }
        }
      }
    }

    if (!proceedWithToggle) {
      print("Toggle cancelled by user or schedule conflict.");
      // Ensure the UI rebuilds with the current _isDeviceOn state,
      // reverting any visual change if the user cancelled.
      if (mounted) {
        setState(() {});
      }
      return;
    }

    // Optimistic UI update
    bool previousDeviceOnState = _isDeviceOn; // Store previous state for potential revert
    if (mounted) {
      setState(() {
        _isDeviceOn = newStatus; 
      });
    }

    try {
      // === Prioritized Relay State Update ===
      final String? relayKey = applianceData['relay'] as String?;
      if (relayKey != null && relayKey.isNotEmpty) {
        final int newRelayState = newStatus ? 1 : 0;
        print("DeviceInfoScreen: PRIORITY: Attempting to update relay state for $relayKey to $newRelayState for user $userId.");
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('relay_states')
              .doc(relayKey)
              .set({'state': newRelayState}, SetOptions(merge: true)); 
          print("DeviceInfoScreen: PRIORITY: Relay state update for $relayKey to $newRelayState successful.");
        } catch (relayError) {
          print("DeviceInfoScreen: PRIORITY: ERROR updating relay state for $relayKey: $relayError");
          // Optionally, if relay update fails, we might not want to proceed or revert optimistic UI.
          // For now, we'll let UsageService try, but this error is logged.
        }
      } else {
        print("DeviceInfoScreen: PRIORITY: No relayKey found for appliance ${widget.applianceId}. Skipping relay state update.");
      }
      // ====================================

      await _usageService.handleApplianceToggle(
        userId: userId,
        applianceId: widget.applianceId,
        isOn: newStatus,
        wattage: wattage,
        kwhrRate: kwhrRate,
      );
      print("DeviceInfoScreen: UsageService.handleApplianceToggle called for ${widget.applianceId}.");

      // Explicitly update the applianceStatus in the main appliance document
      print("[DEVICE_INFO_TOGGLE] Attempting to update main appliance document for ${widget.applianceId} to status: ${newStatus ? 'ON' : 'OFF'}.");
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('appliances')
          .doc(widget.applianceId)
          .update({'applianceStatus': newStatus ? 'ON' : 'OFF'});
      print("[DEVICE_INFO_TOGGLE] SUCCESSFULLY updated main appliance document for ${widget.applianceId} with status: ${newStatus ? 'ON' : 'OFF'}.");

      // Verification Read
      print("[DEVICE_INFO_TOGGLE] Attempting verification read for ${widget.applianceId} immediately after update.");
      try {
        DocumentSnapshot updatedApplianceSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('appliances')
            .doc(widget.applianceId)
            .get();
        if (updatedApplianceSnap.exists) {
          final data = updatedApplianceSnap.data() as Map<String, dynamic>?;
          final statusAfterUpdate = data?['applianceStatus'];
          print("[DEVICE_INFO_TOGGLE] VERIFICATION SUCCESS for ${widget.applianceId}: applianceStatus is now '$statusAfterUpdate' in Firestore.");
        } else {
          print("[DEVICE_INFO_TOGGLE] VERIFICATION WARNING for ${widget.applianceId}: Document no longer exists after update attempt.");
        }
      } catch (verifyError) {
        print("[DEVICE_INFO_TOGGLE] VERIFICATION ERROR for ${widget.applianceId}: Error during verification read: $verifyError");
      }

    } catch (e) {
      print("Error during toggle operations (relay or UsageService) for ${widget.applianceId}: $e");
      // Revert optimistic UI update on error
      if (mounted) {
        setState(() {
          _isDeviceOn = previousDeviceOnState; 
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update status: ${e.toString()}")),
        );
      }
    }
  }

  Future<void> _updateDeviceDetails() async {
    final userId = _auth.currentUser?.uid; 
    if (userId == null) {
      print("User not logged in, cannot update appliance details.");
      return;
    }
   
    double kWhRate = double.tryParse(_kWhRateController.text) ?? 0.0;
    final applianceUpdateData = {
      'applianceName': _nameController.text,
      'roomName': _roomController.text,
      'deviceType': _deviceType,
      'icon': _selectedIcon.codePoint,
    };
    final userUpdateData = {'kwhr': kWhRate,};

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).collection('appliances').doc(widget.applianceId).update(applianceUpdateData);
      await FirebaseFirestore.instance.collection('users').doc(userId).update(userUpdateData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Device details and kWh rate updated successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update details: ${e.toString()}"))
        );
      }
    }
  }

  void _showIconPickerDialog() {
     showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFE9E7E6),
          title: Text('Select an Icon', style: GoogleFonts.jaldi(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _getCommonIcons().map((IconData icon) {
                  return InkWell(
                    onTap: () {
                      if (mounted) setState(() => _selectedIcon = icon);
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _selectedIcon.codePoint == icon.codePoint ? Colors.grey[300] : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 32, color: Colors.black),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: GoogleFonts.jaldi(textStyle: TextStyle(fontSize: 18, color: Colors.black87))),
            ),
          ],
        );
      },
    );
  }

  List<IconData> _getCommonIcons() {
    return [
      Icons.lightbulb_outline, Icons.power_outlined, Icons.power_settings_new, Icons.ac_unit_outlined,
      Icons.tv_outlined, Icons.air_outlined, Icons.device_thermostat, Icons.kitchen,
      Icons.water_drop_outlined, Icons.microwave_outlined, Icons.coffee_maker_outlined, Icons.speaker_outlined,
      Icons.computer_outlined, Icons.router_outlined, Icons.videogame_asset_outlined, Icons.camera_outlined,
      Icons.shower_outlined, Icons.local_laundry_service_outlined, Icons.devices_other_outlined,
    ];
  }

  @override
  Widget build(BuildContext context) {
    print("Building DeviceInfoScreen - RoomController text: ${_roomController.text}, RoomNames: $_roomNames"); 
    return Scaffold(
      backgroundColor: const Color(0xFFE9E7E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE9E7E6), 
        elevation: 0, 
        leading: IconButton(
          icon: Transform.translate(offset: Offset(5, 0), child: Icon(Icons.arrow_back, size: 50, color: Colors.black)),
          onPressed: () => Navigator.of(context).pop(),
        ),
         title: Transform.translate(
            offset: Offset(2, 5),
            child: Text(_currentDeviceName, style: GoogleFonts.jaldi(textStyle: TextStyle(fontSize: 23, fontWeight: FontWeight.bold, color: Colors.black)), overflow: TextOverflow.ellipsis),
         ),
        actions: [
          _isRefreshing
              ? Padding(padding: const EdgeInsets.all(12.0), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)))
              : IconButton(icon: Transform.translate(offset: Offset(-20, 5), child: Icon(Icons.refresh, color: Colors.black, size: 30,)), onPressed: _handleRefresh),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.grey[350], borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Row(
                                children: [
                                  Icon(_getIconForDevice(_currentDeviceName), size: 30, color: _isDeviceOn ? Colors.black : Colors.grey),
                                  SizedBox(width: 12),
                                  Flexible(child: Text(_currentDeviceName, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            ),
                            Switch(
                              value: _isDeviceOn,
                              onChanged: (value) { _toggleDeviceStatus(value); },
                              activeColor: Colors.white, activeTrackColor: Colors.black,
                              inactiveThumbColor: Colors.white, inactiveTrackColor: Colors.black,
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        Text("Current Status", style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[700])),
                        SizedBox(height: 8),
                        Text(_isDeviceOn ? "ON" : "OFF", style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: _isDeviceOn ? Colors.black : Colors.grey)),
                      ],
                    ),
                  ),
                Transform.translate(
                  offset: Offset(0, 5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Energy Usage", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Row(children: [ Text(_selectedPeriod), IconButton(icon: Icon(Icons.calendar_month), onPressed: () => _showPeriodPicker())]),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                Transform.translate(
                  offset: Offset(0, -15),
                  child: _isLoadingUsage
                      ? Center(child: CircularProgressIndicator())
                      : Column(children: [
                            _buildEnergyStatCard(title: "Total Usage", value: "${_totalUsageKwh.toStringAsFixed(2)} kWh", period: _selectedPeriod, icon: Icons.flash_on),
                          ]),
                ),
                 Transform.translate(
                  offset: Offset(0, -9),
                  child: _buildEnergyStatCard(title: "Estimated Cost", value: "₱${(_totalElectricityCost).toStringAsFixed(2)}", period: _selectedPeriod, icon: Icons.attach_money),
                ),
                Container( 
                    margin: const EdgeInsets.only(bottom: 0, top: 0), 
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 4))]),
                    child: Row(
                      children: [
                        Container(padding: EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.attach_money, color: Colors.blue)),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("kWh Rate", style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600])),
                              SizedBox(height: 4),
                              TextField(controller: _kWhRateController, keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8), hintText: "Enter KWH rate", suffixText: "₱/kWh")),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(height: 24), 
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0), side: BorderSide(color: Colors.black, width: 1)), minimumSize: Size(double.infinity, 50)),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) {
                      final userId = _auth.currentUser?.uid;
                      if (userId == null) return Scaffold(appBar: AppBar(title: Text("Error")), body: Center(child: Text("User not logged in.")));
                      return DeviceUsage(userId: userId, applianceId: widget.applianceId);
                    }));
                  },
                  child: Text('View Detailed Usage', style: GoogleFonts.judson(fontSize: 20, color: Colors.black)),
                ),
                SizedBox(height: 24), 
                Text("Appliance Details", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                TextField(controller: _nameController, decoration: InputDecoration(filled: true, fillColor: Colors.white, labelText: 'Appliance Name', labelStyle: GoogleFonts.jaldi(fontSize: 20), border: OutlineInputBorder())),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(filled: true, fillColor: Colors.white, labelText: 'Room Name', labelStyle: GoogleFonts.jaldi(textStyle: TextStyle(fontSize: 20)), border: OutlineInputBorder()),
                        dropdownColor: Colors.grey[200], style: GoogleFonts.jaldi(textStyle: TextStyle(fontSize: 18, color: Colors.black87)),
                        value: _selectedRoom, 
                        items: _roomNames.map<DropdownMenuItem<String>>((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(),
                        onChanged: (String? newValue) { if (mounted) setState(() { _selectedRoom = newValue; _roomController.text = newValue ?? ''; }); }
                      ),
                    ),
                    SizedBox(width: 8), 
                    IconButton(icon: Icon(Icons.add, size: 30, color: Colors.black), onPressed: _addRoom),
                  ],
                ),
                SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(filled: true, fillColor: Colors.white, labelText: 'Device Type', labelStyle: GoogleFonts.jaldi(textStyle: TextStyle(fontSize: 20)), border: OutlineInputBorder()),
                  dropdownColor: Colors.grey[200], style: GoogleFonts.jaldi(textStyle: TextStyle(fontSize: 18, color: Colors.black87)),
                  value: _deviceType,
                  items: ['Light', 'Socket'].map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                  onChanged: (value) { if (mounted) setState(() { _deviceType = value!; _typeController.text = value; }); },
                ),
                SizedBox(height: 8),
                Transform.translate(
                    offset: Offset(-0, -0),
                    child: Row(
                      children: [
                        SizedBox(width: 16), Icon(_selectedIcon),
                        TextButton(onPressed: _showIconPickerDialog, child: Text('Change Icon', style: GoogleFonts.jaldi(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.black))),
                      ],
                    ),
                ),
                SizedBox(height: 5),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0), side: BorderSide(color: Colors.black, width: 1))),
                  onPressed: _updateDeviceDetails,
                  child: Text('Save Changes', style: GoogleFonts.judson(fontSize: 20, color: Colors.black)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnergyStatCard({required String title, required String value, required String period, required IconData icon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10), 
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 4))]),
      child: Row(
        children: [
          Container(padding: EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: Colors.blue)),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600])),
                SizedBox(height: 4),
                Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 2),
                Text(period, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForUsagePeriod(String period) {
     switch (period) {
      case 'daily': return Icons.query_stats;
      case 'weekly': return Icons.calendar_view_week;
      case 'monthly': return Icons.calendar_view_month;
      case 'yearly': return Icons.calendar_today;
      default: return Icons.query_stats;
    }
  }

  IconData _getIconForDevice(String deviceName) {
    final name = deviceName.toLowerCase();
    if (name.contains("light")) return Icons.lightbulb_outline;
    if (name.contains("socket") || name.contains("plug")) return Icons.power_outlined;
    if (name.contains("ac") || name.contains("air conditioner") || name.contains("aircon")) return Icons.ac_unit_outlined;
    if (name.contains("tv") || name.contains("television")) return Icons.tv_outlined;
    if (name.contains("fan")) return Icons.air_outlined;
    return Icons.devices_other_outlined;
  }

  void _showPeriodPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Select Period', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text('Daily'), onTap: () { if (mounted) setState(() => _selectedPeriod = 'Daily'); _listenToPeriodicUsageData(); Navigator.pop(context); }),
            ListTile(title: Text('Weekly'), onTap: () { if (mounted) setState(() => _selectedPeriod = 'Weekly'); _listenToPeriodicUsageData(); Navigator.pop(context); }),
            ListTile(title: Text('Monthly'), onTap: () { if (mounted) setState(() => _selectedPeriod = 'Monthly'); _listenToPeriodicUsageData(); Navigator.pop(context); }),
            ListTile(title: Text('Yearly'), onTap: () { if (mounted) setState(() => _selectedPeriod = 'Yearly'); _listenToPeriodicUsageData(); Navigator.pop(context); }),
          ],
        ),
      ),
    );
  }

  Future<Map<String, double>> getAverageUsages() async {
    try {
      final now = DateTime.now();
      final userId = _auth.currentUser!.uid;
      final today = DateTime(now.year, now.month, now.day);
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final endOfWeek = startOfWeek.add(Duration(days: 6));
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);
      final startOfYear = DateTime(now.year, 1, 1);
      final endOfYear = DateTime(now.year, 12, 31);
      final averageDaily = await _getAverageDailyUsageForPeriod(today, today);
      final averageWeekly = await _getAverageDailyUsageForPeriod(startOfWeek, endOfWeek);
      final averageMonthly = await _getAverageDailyUsageForPeriod(startOfMonth, endOfMonth);
      final averageYearly = await _getAverageDailyUsageForPeriod(startOfYear, endOfYear);
      return {'daily': averageDaily, 'weekly': averageWeekly, 'monthly': averageMonthly, 'yearly': averageYearly};
    } catch (e) {
      if (mounted) setState(() => _averageUsages = {'daily': 0.0, 'weekly': 0.0, 'monthly': 0.0, 'yearly': 0.0});
      return {'daily': 0.0, 'weekly': 0.0, 'monthly': 0.0, 'yearly': 0.0};
    }
  }

  Future<double> _getAverageDailyUsageForPeriod(DateTime startDate, DateTime endDate) async {
     try {
      double totalKwhr = 0.0;
      int numberOfDaysWithUsage = 0;
      final userId = _auth.currentUser!.uid; 
      final dayUsageCollectionRef = FirebaseFirestore.instance.collection('users').doc(userId).collection('appliances').doc(widget.applianceId).collection('yearly_usage');
      for (int year = startDate.year; year <= endDate.year; year++) {
        final yearlyDocRef = dayUsageCollectionRef.doc(year.toString());
        final monthlySnapshots = await yearlyDocRef.collection('monthly_usage').get();
        for (final monthlyDoc in monthlySnapshots.docs) {
          final weekSnapshots = await monthlyDoc.reference.collection('week_usage').get();
          for (final weekDoc in weekSnapshots.docs) {
            final daySnapshots = await weekDoc.reference.collection('day_usage').get();
            for (final dayDoc in daySnapshots.docs) {
              final dateString = dayDoc.id; 
              try {
                final dateParts = dateString.split('-');
                final dayDate = DateTime(int.parse(dateParts[0]), int.parse(dateParts[1]), int.parse(dateParts[2]));
                if (dayDate.isAfter(startDate.subtract(Duration(days: 1))) && dayDate.isBefore(endDate.add(Duration(days: 1)))) {
                  final Object rawDayData = dayDoc.data();
                  if (rawDayData is Map<String, dynamic>) {
                    final Map<String, dynamic> dayData = rawDayData;
                    dynamic kwhValue = dayData['kwh']; // Get the value first
                    double dailyKwhr = 0.0;
                    if (kwhValue is num) {
                      dailyKwhr = kwhValue.toDouble();
                    }
                    totalKwhr += dailyKwhr;
                    if (dailyKwhr > 0) numberOfDaysWithUsage++;
                  } else {
                    // Handle case where data is null or not a map, though 'exists' should cover null.
                    print("Warning: dayData for $dateString is null or not a Map, though document exists.");
                  }
                }
              } catch (e) { print('Error parsing date from document ID $dateString or processing dayData: $e'); }
            }
          }
        }
      }
      return numberOfDaysWithUsage > 0 ? totalKwhr / numberOfDaysWithUsage : 0.0;
    } catch (e) { 
      print("Error in _getAverageDailyUsageForPeriod: $e");
      return 0.0; 
    }
  }

  Future<void> _handleRefresh() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('User not authenticated. Cannot refresh.')));
      return;
    }
    if (_isRefreshing) return;
    if (mounted) setState(() => _isRefreshing = true);
    try {
      // We need the kwhrRate. The wattage is fetched inside handleManualRefreshForAppliance.
      double kwhrRate = double.tryParse(_kWhRateController.text) ?? DEFAULT_KWHR_RATE; 
      // If _kWhRateController is not populated reliably, fetch from user doc or use a state variable like in homepage.
      // For now, assuming _kWhRateController.text is the source of truth for the current rate on this screen.
      // Alternatively, ensure _kwhrRate is a state variable updated from userDoc like in homepage.
      // Let's assume _fetchUserKwhrRate (similar to homepage) should be called if _kWhRateController is not reliable.
      // For this change, we'll proceed with _kWhRateController.text as the source.

      print("DeviceInfoScreen: Manual refresh for ${widget.applianceId} initiated by user ${user.uid}.");
      await _usageService.handleManualRefreshForAppliance(
        userId: user.uid,
        applianceId: widget.applianceId,
        kwhrRate: kwhrRate,
        refreshTime: DateTime.now(),
      );
      
      // _listenToPeriodicUsageData() is still relevant as it fetches the specific period's data for this appliance.
      _listenToPeriodicUsageData(); 
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$_currentDeviceName usage data refreshed!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error refreshing data: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
