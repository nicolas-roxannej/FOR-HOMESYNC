import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:homesync/databaseservice.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore

class EditDeviceScreen extends StatefulWidget {
  final String applianceId;
  const EditDeviceScreen({super.key, required this.applianceId});

  @override
  _EditDeviceScreenState createState() => _EditDeviceScreenState();
}

class _EditDeviceScreenState extends State<EditDeviceScreen> {
  // Add a list of available relays
  // Add a list of all possible relays
  final List<String> _allRelays = List.generate(9, (index) => 'relay${index + 1}');
  // List to hold available relays after filtering
  List<String> _availableRelays = [];

  bool isEditing = false;
  bool _isLoading = true;

  final TextEditingController applianceNameController = TextEditingController();
  final TextEditingController wattageController = TextEditingController();
  final TextEditingController roomController = TextEditingController();
  final TextEditingController relayController = TextEditingController(); // For relay name

  String? selectedRelay;
  final _formKey = GlobalKey<FormState>();

  String deviceType = 'Light';
  String? selectedRoom;
  List<String> rooms = [];
  Map<String, IconData> roomIcons = {};

  // State variable for room names
  List<String> _roomNames = [];

  TimeOfDay? startTime;
  TimeOfDay? endTime;
  
  // Preset time periods
  final Map<String, Map<String, TimeOfDay>> presetTimes = {
    'Morning': {
      'start': TimeOfDay(hour: 6, minute: 0),
      'end': TimeOfDay(hour: 12, minute: 0),
    },
    'Afternoon': {
      'start': TimeOfDay(hour: 12, minute: 0),
      'end': TimeOfDay(hour: 18, minute: 0),
    },
    'Evening': {
      'start': TimeOfDay(hour: 18, minute: 0),
      'end': TimeOfDay(hour: 23, minute: 0),
    },
  };
  
  // Repeating days
  final List<String> weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  Map<String, bool> selectedDays = {
    'Mon': false,
    'Tue': false,
    'Wed': false,
    'Thu': false,
    'Fri': false,
    'Sat': false,
    'Sun': false,
  };

  IconData selectedIcon = Icons.device_hub;

  // validation errors
  String? applianceNameError;
  String? wattageError;
  String? roomError;
  String? socketError;
  String? daysError;

  @override
  void initState() {
    super.initState();
    // Initialize error states
    wattageError = null;
    roomError = null;
    socketError = null;
    daysError = null;
    
    _fetchDeviceData();
    _fetchRooms(); // Fetch rooms when the state is initialized
  }

  void _fetchDeviceData() async {
    try {
      final deviceData = await DatabaseService().getApplianceData(widget.applianceId);
      if (deviceData != null) {
        setState(() {
          isEditing = true;
          applianceNameController.text = deviceData['applianceName'] as String;
          wattageController.text = (deviceData['wattage'] ?? 0.0).toString();
          
          // Store room in controller and selectedRoom
          selectedRoom = deviceData['roomName'] as String?;
          if (selectedRoom != null) {
            roomController.text = selectedRoom!;
          }
          
          deviceType = deviceData['deviceType'] as String? ?? 'Light';
          
          // Set relay
          selectedRelay = deviceData['relay'] as String?;
          if (selectedRelay != null) {
            relayController.text = selectedRelay!;
          }
          
          selectedIcon = IconData(deviceData['icon'] as int? ?? Icons.device_hub.codePoint, fontFamily: 'MaterialIcons');

          // Parse start and end times
          final startTimeString = deviceData['startTime'] as String?;
          final endTimeString = deviceData['endTime'] as String?;
          if (startTimeString != null) {
            try {
              final startTimeParts = startTimeString.split(':');
              startTime = TimeOfDay(hour: int.parse(startTimeParts[0]), minute: int.parse(startTimeParts[1]));
            } catch (e) {
              print("Error parsing start time: $e");
            }
          }
          if (endTimeString != null) {
            try {
              final endTimeParts = endTimeString.split(':');
              endTime = TimeOfDay(hour: int.parse(endTimeParts[0]), minute: int.parse(endTimeParts[1]));
            } catch (e) {
              print("Error parsing end time: $e");
            }
          }

          // Populate selected days
          final daysList = List<String>.from(deviceData['days'] as List? ?? []);
          for (var day in selectedDays.keys) {
            selectedDays[day] = daysList.contains(day);
          }
          
          _isLoading = false;
        });
        await _fetchAndFilterRelays(); // Call after fetching device data
      } else {
        // Handle case where device data is not found
        print("Device with ID ${widget.applianceId} not found.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Device not found."))
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      print("Error fetching device data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading device data: ${e.toString()}"))
        );
        Navigator.of(context).pop();
      }
    }
  }

  // Method to fetch room names from the database
  Future<void> _fetchRooms() async {
    print("Fetching rooms for EditDeviceScreen..."); // Debug print
    final userId = DatabaseService().getCurrentUserId(); // Use DatabaseService to get user ID
    if (userId == null) {
      print("User not logged in, cannot fetch rooms for EditDeviceScreen.");
      return;
    }
    print("Fetching rooms for user ID: $userId"); // Added debug print
    try {
      final roomDocs = await DatabaseService().getCollection(collectionPath: 'users/$userId/Rooms');
      print("Fetched ${roomDocs.docs.length} room documents."); // Added debug print
      final roomNames = roomDocs.docs.map((doc) => doc['roomName'] as String).toList();
      if (mounted) {
        setState(() {
          _roomNames = roomNames;
        });
      }
       print("Fetched rooms for EditDeviceScreen: $_roomNames"); // Debug print
    } catch (e) {
      print("Error fetching rooms for EditDeviceScreen: $e");
      // Handle error, maybe show a message
    }
  }

  Future<void> _fetchAndFilterRelays() async {
    final userId = DatabaseService().getCurrentUserId();
    if (userId == null) {
      print("User not authenticated. Cannot fetch relay states.");
      setState(() {
        _availableRelays = [];
      });
      return;
    }

    try {
      final relayStatesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('relay_states')
          .get();

      final occupiedRelays = <String>{};
      for (final doc in relayStatesSnapshot.docs) {
        final data = doc.data();
        // A relay is considered "occupied" if it exists in the relay_states collection
        // and is not the relay of the device being edited (if in edit mode).
        // Since we are removing the 'assigned' field, we will consider a relay occupied
        // if a document for it exists in relay_states.
        // We also need to ensure that if we are editing a device, its currently assigned
        // relay is still considered available for selection.
        if (isEditing && selectedRelay != null && doc.id == selectedRelay) {
            // If we are editing and this is the current device's relay, it's available
            continue;
        }
        occupiedRelays.add(doc.id);
      }

      setState(() {
        _availableRelays = _allRelays.where((relay) => !occupiedRelays.contains(relay)).toList();
        // If in edit mode and the current relay is not in the available list (meaning it was occupied by another device), add it back.
        // This case should ideally not happen with the updated logic above, but as a safeguard:
        if (isEditing && selectedRelay != null && !_availableRelays.contains(selectedRelay)) {
           _availableRelays.add(selectedRelay!);
           _availableRelays.sort(); // Keep the list sorted
        }
      });

      print("Fetched and filtered relays. Available: ${_availableRelays.length}");

    } catch (e) {
      print("Error fetching and filtering relay states: $e");
      setState(() {
        _availableRelays = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while data is loading
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFE9E7E6),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFFE9E7E6),
      appBar: null,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: Transform.translate(
                      offset: Offset(0.0, 20),
                      child: IconButton(
                        icon: Icon(Icons.arrow_back, size: 50, color: Colors.black),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),

                  Transform.translate(
                    offset: Offset(-50, -30),
                    child: Text(
                      isEditing ? ' Edit device' : ' Add device',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.jaldi(
                        textStyle: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                        color: Colors.black,
                      ),
                    ),
                  ),
      
                  SizedBox(height: 5),
                  Transform.translate(
                    offset: Offset(0,-15),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[400],
                      ),
                      child: IconButton(
                        color: Colors.black,
                        iconSize: 60,
                        icon: Icon(selectedIcon),
                        onPressed: () => _pickIcon(),
                      ),
                    ),
                  ),
                  
                  // Required text fields
                  _buildRequiredTextField(
                    applianceNameController, 
                    "Appliance Name", 
                    Icons.device_hub,
                    errorText: applianceNameError
                  ),
                  _buildRequiredTextField(
                    wattageController,
                    "Wattage",
                    Icons.energy_savings_leaf,
                    keyboardType: TextInputType.number,
                    errorText: wattageError
                  ),
                  SizedBox(height: 10),
                  
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: Icon(Icons.home, size: 30, color: Colors.black),
                            labelText: 'Room',
                            labelStyle: GoogleFonts.jaldi(
                              textStyle: TextStyle(fontSize: 20),
                              color: Colors.grey, // Use grey for label like other text fields
                            ),
                            border: OutlineInputBorder(),
                            errorText: roomError,
                            contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 17),
                          ),
                          dropdownColor: Colors.grey[200],
                          style: GoogleFonts.jaldi(
                            textStyle: TextStyle(fontSize: 18, color: Colors.black87),
                          ),
                          value: selectedRoom,
                          items: _roomNames.map((roomName) {
                            return DropdownMenuItem(
                              value: roomName,
                              child: Text(roomName),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedRoom = value;
                              roomController.text = value ?? ''; // Update controller as well
                              roomError = null;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Room is required";
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: 8), // Add some spacing
                      IconButton(
                        icon: Icon(Icons.add, size: 30, color: Colors.black),
                        onPressed: _addRoom,
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 15),
                  
                  // Device type dropdown 
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: 'Device Type',
                      labelStyle: GoogleFonts.jaldi(
                        textStyle: TextStyle(fontSize: 20),
                        color: Colors.black,
                      ),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 17),
                    ),
                    dropdownColor: Colors.grey[200], 
                    style: GoogleFonts.jaldi(
                      textStyle: TextStyle(fontSize: 18, color: Colors.black87),
                    ),
                    value: deviceType,
                    items: ['Light', 'Socket'].map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        deviceType = value!;
                      });
                    },
                  ),
                  
                  
                  SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: Icon(Icons.electrical_services, size: 30, color: Colors.black),
                      labelText: "Relay",
                      errorText: socketError,
                      border: OutlineInputBorder(),
                    ),
                    value: selectedRelay,
                    items: _availableRelays.map((relay) {
                      return DropdownMenuItem(
                        value: relay,
                        child: Text(relay),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedRelay = value;
                        socketError = null;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Relay is required";
                      }
                      return null;
                    },
                  ),

                  SizedBox(height: 10),
                  
                
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white, 
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: socketError != null ? Colors.red : Colors.black // Using socketError here as usagetimeError is removed
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ListTile(
                                leading: Icon(Icons.access_time, color: Colors.black),
                                contentPadding: EdgeInsets.symmetric(horizontal: 25, vertical: 5),
                                title: Text(
                                  startTime != null
                                      ? 'Start: \n${startTime!.format(context)}'
                                      : 'Set Start Time',
                                ),
                                onTap: () => _pickStartTime(),
                              ),
                            ),
                            Expanded(
                              child: ListTile(
                                leading: Icon(Icons.access_time, color: Colors.black),
                                contentPadding: EdgeInsets.symmetric(horizontal: 25, vertical: 5),
                                title: Text(
                                  endTime != null
                                      ? 'End: \n${endTime!.format(context)}'
                                      : 'Set End Time',
                                ),
                                onTap: () => _pickEndTime(),
                              ),
                            ),
                          ],
                        ),
                        // Removed usagetimeError check here
                      ],
                    ),
                  ),

                  Transform.translate( 
                    offset: Offset(-90, 13),
                    child: Text(
                      ' Automatic alarm set',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        textStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        color: Colors.black,
                      ),
                    ),
                  ),
                  
                  // automatic time buttons
                  Transform.translate( 
                    offset: Offset(-0, 10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (final preset in presetTimes.keys)
                            ElevatedButton(
                              onPressed: () => _applyPresetTime(preset),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                side: BorderSide(color: Colors.grey, width: 1),
                              ),
                              child: Text(preset),
                            ),
                        ],
                      ),
                    ),
                  ),
                  
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Repeating Days',
                              style: TextStyle(
                                fontSize: 16, 
                                fontWeight: FontWeight.bold
                              ),
                            ),
                            if (daysError != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                              ),
                          ],
                        ),
                        SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: weekdays.map((day) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                child: FilterChip(
                                  label: Text(day),
                                  labelStyle: TextStyle(
                                    color: selectedDays[day] ?? false ? Colors.white : Colors.white,
                                  ),
                                  selected: selectedDays[day] ?? false,
                                  onSelected: (selected) {
                                    setState(() {
                                      selectedDays[day] = selected;
                                      if (selected) {
                                        daysError = null;
                                      }
                                    });
                                  },
                                  backgroundColor: Colors.black,
                                  side: BorderSide(
                                    color: daysError != null ? Colors.red : Colors.grey, 
                                    width: 1
                                  ),
                                  selectedColor: Theme.of(context).colorScheme.secondary,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 10),
                  
                  // Submit and Delete buttons
                  Row(
                    children: [
                      if (isEditing) // Show delete button only in edit mode
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _deleteDevice,
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size(double.infinity, 60),
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(0),
                                side: BorderSide(color: Colors.black, width: 1),
                              ),
                              elevation: 5,
                              shadowColor: Colors.black.withOpacity(0.5),
                            ),
                            child: Text(
                              'Delete Device',
                              style: GoogleFonts.judson(
                                fontSize: 19,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      SizedBox(width: isEditing ? 10 : 0),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _validateAndSubmitDevice,
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size(double.infinity, 60),
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(0),
                              side: BorderSide(color: Colors.black, width: 1),
                            ),
                            elevation: 5,
                            shadowColor: Colors.black.withOpacity(0.5),
                          ),
                          child: Text(
                            isEditing ? 'Save Changes' : 'Add Device',
                            style: GoogleFonts.judson(
                              fontSize: isEditing ? 19 : 19,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Required text field 
  Widget _buildRequiredTextField(
    TextEditingController controller, 
    String label, 
    IconData icon, 
    {TextInputType keyboardType = TextInputType.text, 
    String? hint,
    String? errorText}
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5, top: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          prefixIcon: Icon(icon, size: 30, color: Colors.black), 
          labelText: label,  
          labelStyle: GoogleFonts.jaldi(
            textStyle: TextStyle(fontSize: 20),
            color: Colors.grey,
          ),
          hintText: hint,
          border: OutlineInputBorder(),
          errorText: errorText,
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return "$label is required";
          }
          return null;
        },
      ),
    );
  }
 
  static IconData roomIconSelected = Icons.home;

  void _pickIcon() { // icon picker
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFE9E7E6),
      builder: (_) => GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        children: [
          Icons.light, Icons.tv, Icons.power, Icons.kitchen,
          Icons.speaker, Icons.laptop, Icons.ac_unit, Icons.microwave,
        ].map((icon) {
          return IconButton(
            icon: Icon(icon, color: Colors.black),
            onPressed: () {
              setState(() {
                selectedIcon = icon;
              });
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  void _applyPresetTime(String preset) {
    if (presetTimes.containsKey(preset)) {
      setState(() {
        startTime = presetTimes[preset]!['start'];
        endTime = presetTimes[preset]!['end'];
      });
    }
  }
  
  void _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: startTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        startTime = picked;
      });
    }
  }

  void _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: endTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        endTime = picked;
      });
    }
  }
  
  void _addRoom() async {
    String? newRoomName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        TextEditingController newRoomController = TextEditingController();
        return AlertDialog(
          title: Text('Add New Room'),
          content: TextField(
            controller: newRoomController,
            decoration: InputDecoration(hintText: "Enter Room Name"),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Add'),
              onPressed: () {
                Navigator.of(context).pop(newRoomController.text.trim());
              },
            ),
          ],
        );
      },
    );

    if (newRoomName != null && newRoomName.isNotEmpty) {
      final userId = DatabaseService().getCurrentUserId();
      if (userId != null) {
        try {
          // Add the new room to the database
          await DatabaseService().addDocumentToCollection(
            collectionPath: 'users/$userId/Rooms',
            data: {'roomName': newRoomName},
          );
          // Refresh the room list
          await _fetchRooms();
          // Optionally select the newly added room
          if (_roomNames.contains(newRoomName)) {
            setState(() {
              selectedRoom = newRoomName;
              roomController.text = newRoomName;
            });
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Room '$newRoomName' added successfully!"))
          );
        } catch (e) {
          print("Error adding room: $e");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error adding room: ${e.toString()}"))
          );
        }
      }
    }
  }

  void _validateAndSubmitDevice() {
    // Checking req field
    bool isValid = true;

    if (applianceNameController.text.isEmpty) {
      setState(() {
        applianceNameError = "Appliance name is required";
      });
      isValid = false;
    } else {
      setState(() {
        applianceNameError = null;
      });
    }

    if (wattageController.text.isEmpty) {
      setState(() {
        wattageError = "Wattage is required";
      });
      isValid = false;
    } else {
      setState(() {
        wattageError = null;
      });
    }

    if (roomController.text.isEmpty) {
      setState(() {
        roomError = "Room is required";
      });
      isValid = false;
    } else {
      setState(() {
        roomError = null;
        // Make sure selectedRoom is set from controller
        // selectedRoom is removed
      });
    }

    if (selectedRelay == null || selectedRelay!.isEmpty) {
      setState(() {
        socketError = "Relay is required";
      });
      isValid = false;
    } else {
      setState(() {
        socketError = null;
      });
    }

    // Time and days are optional
    // setState(() { // Removed clearing timeError and daysError here as they are handled above
    //   timeError = null;
    //   daysError = null;
    // });

    if (isValid) {
      if (isEditing) {
        _updateDevice();
      } else {
        _submitDevice();
      }
    }
  }

  void _submitDevice() async {
    final DatabaseService dbService = DatabaseService();
    
    // Get room name from controller to be safe
    final roomName = roomController.text.trim();
    
    final Map<String, dynamic> deviceData = {
      "applianceName": applianceNameController.text.trim(),
      "deviceType": deviceType,
      "wattage": double.tryParse(wattageController.text) ?? 0.0,
      "roomName": roomName,
      "icon": selectedIcon.codePoint,
      "startTime": startTime != null ? "${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}" : null,
      "endTime": endTime != null ? "${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}" : null,
      "days": selectedDays.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList(),
      "relay": selectedRelay,
      "applianceStatus": 'OFF',
    };

    try {
      await dbService.addAppliance(applianceData: deviceData);
      print("Device successfully added to Firestore.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${deviceData['applianceName']} added successfully!"))
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      print("Error adding device: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error adding device: ${e.toString()}"))
        );
      }
    }
  }

  void _updateDevice() async {
    final DatabaseService dbService = DatabaseService();
    final String applianceId = widget.applianceId;

    // Get room name from controller to be safe
    final roomName = roomController.text.trim();
    
    final Map<String, dynamic> updatedData = {
      "applianceName": applianceNameController.text.trim(),
      "deviceType": deviceType,
      "wattage": double.tryParse(wattageController.text) ?? 0.0,
      "roomName": roomName,
      "icon": selectedIcon.codePoint,
      "startTime": startTime != null ? "${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}" : null,
      "endTime": endTime != null ? "${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}" : null,
      "days": selectedDays.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList(),
      "relay": selectedRelay,
    };

    try {
      await dbService.updateApplianceData(applianceId: applianceId, dataToUpdate: updatedData);
      print("Device $applianceId successfully updated.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${updatedData['applianceName']} updated successfully!"))
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      print("Error updating device: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating device: ${e.toString()}"))
        );
      }
    }
  }

  void _deleteDevice() async {
    final DatabaseService dbService = DatabaseService();
    final String applianceId = widget.applianceId;
    
    // Use the current controller value for the name
    final String applianceNameToDelete = applianceNameController.text.trim();

    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Delete'),
          content: Text('Are you sure you want to delete "$applianceNameToDelete"?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        await dbService.deleteAppliance(applianceId: applianceId);
        print("Device $applianceId successfully deleted.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("$applianceNameToDelete deleted successfully!"))
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        print("Error deleting device: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error deleting device: ${e.toString()}"))
          );
        }
      }
    }
  }
}
