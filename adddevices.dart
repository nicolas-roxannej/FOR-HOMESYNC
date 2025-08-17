import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:homesync/databaseservice.dart';
// Import RoomDataManager
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:intl/intl.dart'; // Import the intl package for date formatting
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth

// Function to check if a year is a leap year
bool isLeapYear(int year) {
  return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
}

class AddDeviceScreen extends StatefulWidget {
  final Map<String, dynamic>? deviceData; // Optional device data for editing
  final String? initialRoomName; // New optional parameter
  const AddDeviceScreen({super.key, this.deviceData, this.initialRoomName});

  @override
  _AddDeviceScreenState createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  // Add a list of all possible relays
  final List<String> _allRelays = List.generate(9, (index) => 'relay${index + 1}');
  // List to hold available relays after filtering
  List<String> _availableRelays = [];

  bool isEditing = false; // Flag to indicate if in edit mode
  bool _isLoading = true; // Combined loading state for rooms and relays

  final TextEditingController applianceNameController = TextEditingController();
  final TextEditingController wattageController = TextEditingController();
  final TextEditingController roomController = TextEditingController();
  final TextEditingController socketController = TextEditingController();

  String? selectedRelay;

  final _formKey = GlobalKey<FormState>();

  String deviceType = 'Light';
  String? selectedRoom;
  List<String> rooms = [];
  Map<String, IconData> roomIcons = {};

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
  String? timeError;
  String? daysError;

  @override
  void initState() {
    super.initState();
    _fetchInitialData(); // Fetch rooms and relays

    // Initialize error states to null to prevent showing errors initially
    timeError = null;
    daysError = null;
  }

  void _fetchInitialData() async {
    setState(() {
      _isLoading = true;
    });

    // Await both fetching functions before setting isLoading to false
    await _fetchRoomsFromFirestore();
    await _fetchAndFilterRelays();

    if (widget.deviceData != null) {
      isEditing = true;
      // Populate fields with existing device data
      final String? editingId = widget.deviceData!['id'] as String?;

      applianceNameController.text = widget.deviceData!['applianceName'] as String;
      wattageController.text = (widget.deviceData!['wattage'] ?? 0.0).toString();
      selectedRoom = widget.deviceData!['roomName'] as String?;
      deviceType = widget.deviceData!['deviceType'] as String? ?? 'Light';
      selectedRelay = widget.deviceData!['relay'] as String?;
      selectedIcon = IconData(widget.deviceData!['icon'] as int? ?? Icons.device_hub.codePoint, fontFamily: 'MaterialIcons');

      // Parse start and end times
      final startTimeString = widget.deviceData!['startTime'] as String?;
      final endTimeString = widget.deviceData!['endTime'] as String?;
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
      final daysList = List<String>.from(widget.deviceData!['days'] as List? ?? []);
      for (var day in selectedDays.keys) {
        selectedDays[day] = daysList.contains(day);
      }
    } else if (widget.initialRoomName != null) {
      // If not editing and initialRoomName is provided, set it
      selectedRoom = widget.initialRoomName;
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _fetchAndFilterRelays() async {
    final userId = DatabaseService().getCurrentUserId();
    if (userId == null) {
      print("User not authenticated. Cannot fetch appliances.");
      setState(() {
        _availableRelays = [];
      });
      return;
    }

    try {
      // Query the 'appliances' collection to find assigned relays
      final appliancesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('appliances')
          .get();

      final occupiedRelays = <String>{};
      for (final doc in appliancesSnapshot.docs) {
        final data = doc.data();
        final assignedRelay = data['relay'] as String?;
        if (assignedRelay != null && assignedRelay.isNotEmpty) {
           // A relay is considered "occupied" if it's assigned to an appliance,
           // unless we are in edit mode and this is the relay currently assigned to the device being edited.
           if (isEditing && selectedRelay != null && assignedRelay == selectedRelay) {
               // If we are editing and this is the current device's relay, it's available
               continue;
           }
           occupiedRelays.add(assignedRelay);
        }
      }

      setState(() {
        _availableRelays = _allRelays.where((relay) => !occupiedRelays.contains(relay)).toList();
        // If in edit mode and the current relay is not in the available list, add it back.
        if (isEditing && selectedRelay != null && !_availableRelays.contains(selectedRelay)) {
           _availableRelays.add(selectedRelay!);
           _availableRelays.sort(); // Keep the list sorted
        }
      });

      print("Fetched and filtered relays based on appliances. Available: ${_availableRelays.length}");

    } catch (e) {
      print("Error fetching and filtering relays based on appliances: $e");
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
      backgroundColor: const Color(0xFFE9E7E6), //frame
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
                    offset: Offset(-40, -30),
                    child: Text(
                      isEditing ? ' Edit appliance' : ' Add appliance', // Change title based on mode
                      textAlign: TextAlign.center,
                      style: GoogleFonts.jaldi(
                        textStyle: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                        color: Colors.black,
                      ),
                    ),
                  ),

                  SizedBox(height: 5),
                  Transform.translate(  // icon profile
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

                  // Required text
                  _buildRequiredTextField(
                    applianceNameController,
                    "Appliance Name",
                    Icons.device_hub,
                    errorText: applianceNameError
                  ),
                  _buildRequiredTextField(
                    wattageController,
                    "Watts",
                    Icons.energy_savings_leaf,
                    keyboardType: TextInputType.number,
                    errorText: wattageError
                  ),
                  SizedBox(height: 10),

                  // Required room
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                prefixIcon: Icon(
                                  selectedRoom != null ? (roomIcons[selectedRoom] ?? Icons.home) : Icons.home,
                                  size: 30,
                                  color: Colors.black
                                ),
                                labelText: 'Room',
                                labelStyle: GoogleFonts.jaldi(
                                  textStyle: TextStyle(fontSize: 20),
                                  color: Colors.black,
                                ),
                                border: OutlineInputBorder(),
                                errorText: roomError,
                              ),
                              dropdownColor: Colors.grey[200],
                              style: GoogleFonts.jaldi(
                                textStyle: TextStyle(fontSize: 18, color: Colors.black87),
                              ),
                              value: selectedRoom,
                              items: rooms.isEmpty
                                ? [DropdownMenuItem(value: 'No Rooms', child: Text('No Rooms Available'))]
                                : rooms.map((room) {
                                    return DropdownMenuItem(
                                      value: room,
                                      child: Text(room),
                                    );
                                  }).toList(),
                              onChanged: (value) {
                                if (value == 'No Rooms') return;
                                setState(() {
                                  selectedRoom = value;
                                  roomError = null;
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty || value == 'No Rooms') {
                                  return "Room is required";
                                }
                                return null;
                              },
                            ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add, size: 30, color: Colors.black),
                        onPressed: _addRoomDialog,
                      )
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

                        if (deviceType == 'Light') {
                          socketError = null;
                        }
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
                    items: _availableRelays.map((relay) { // Use _availableRelays
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

                  // Time selection
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: timeError != null ? Colors.red : Colors.black
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
                        if (timeError != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 12, bottom: 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                timeError!,
                                style: TextStyle(color: Colors.red, fontSize: 12),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
// title
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

                  // Repeating days
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
                                fontSize: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      SizedBox(width: isEditing ? 10 : 0), // Add spacing if delete button is present
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
                            isEditing ? 'Save Changes' : 'Add Device', // Change button text
                            style: GoogleFonts.judson(
                              fontSize: isEditing ? 20 : 24, // Adjust font size if needed
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

  void _addRoomDialog() {
    TextEditingController roomInput = TextEditingController();

    showDialog(    // room content
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFE9E7E6),
        titleTextStyle: GoogleFonts.jaldi(
          fontSize: 25,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
        title: Text('Add Room'),
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: roomInput,
                    style: GoogleFonts.inter(
                      textStyle: TextStyle(fontSize: 17),
                      color: Colors.black,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                      hintText: "Room name",
                      hintStyle: GoogleFonts.inter(
                        color: Colors.grey,
                        fontSize: 15,
                      ),
                      prefixIcon: Icon(
                        roomIconSelected,
                        color: Colors.black,
                        size: 24,
                      ),
                    ),
                  ),
                  SizedBox(height: 15),
                  Text(
                    'Select Icon',
                    style: GoogleFonts.jaldi(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 5),
                  Container(  // icon picker
                    height: 200,
                    width: double.maxFinite,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      children: [
                        Icons.living, Icons.bed, Icons.kitchen, Icons.dining,
                        Icons.bathroom, Icons.meeting_room, Icons.workspace_premium, Icons.chair,
                        Icons.stairs, Icons.garage, Icons.yard, Icons.balcony,
                      ].map((icon) {
                        return IconButton(
                          icon: Icon(
                            icon,
                            color: roomIconSelected == icon ? Theme.of(context).colorScheme.secondary : Colors.black,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              roomIconSelected = icon;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          }
        ),

        actions: [
          TextButton(  // room add btn
            onPressed: () {
              if (roomInput.text.isNotEmpty) {
                // Add room to Firestore
                _addRoomToFirestore(roomInput.text, roomIconSelected);

                setState(() {
                  rooms.add(roomInput.text);
                  selectedRoom = roomInput.text;
                  roomIcons[roomInput.text] = roomIconSelected;
                  roomError = null;
                });
              }
              Navigator.pop(context);
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Colors.black),
              foregroundColor: WidgetStateProperty.all(Colors.white),
            ),
            child: Text(
              'Add',
              style: GoogleFonts.jaldi(
                textStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

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

        timeError = null;
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

        if (endTime != null) {
          timeError = null;
        }
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

        if (startTime != null) {
          timeError = null;
        }
      });
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

    if (selectedRoom == null) {
      setState(() {
        roomError = "Room is required";
      });
      isValid = false;
    } else {
      setState(() {
        roomError = null;
      });
    }

    if (selectedRelay == null || selectedRelay!.isEmpty) {
      setState(() {
        socketError = "Relay is required"; // Update error message
      });
      isValid = false;
    } else {
      setState(() {
        socketError = null;
      });
    }


    setState(() {
      timeError = null;
    });


    setState(() {
      daysError = null;
    });

    if (isValid) {
      if (isEditing) {
        _updateDevice();
      } else {
        _submitDevice();
      }
      Navigator.of(context).pop();
    }
  }

  void _submitDevice() async { // Made async
    final DatabaseService dbService = DatabaseService();
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      print("User not authenticated. Cannot add device.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("User not authenticated. Cannot add device."))
        );
      }
      return;
    }

    // Fetch presentYear from the user document
    String presentYear = DateTime.now().year.toString(); // Default to current year
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists) {
        presentYear = (userDoc.data()?['presentYear'] as String?) ?? presentYear;
      }
    } catch (e) {
      print("Error fetching presentYear: $e");
    }


    // all data
    final Map<String, dynamic> deviceData = {
      "applianceName": applianceNameController.text,
      "deviceType": deviceType,
      "wattage": double.tryParse(wattageController.text) ?? 0.0,
      "roomName": selectedRoom!, // selectedRoom is validated to not be null
      "icon": selectedIcon.codePoint,
      "startTime": startTime != null ? "${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}" : null,
      "endTime": endTime != null ? "${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}" : null,
      "days": selectedDays.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList(),
      "relay": selectedRelay, // Always include relay for all device types
      "applianceStatus": 'OFF', // Default status for new device as STRING
    };

    print("Attempting to add appliance: $deviceData");

    try {
      // Add the appliance document and get its reference
      final DocumentReference applianceRef = await dbService.addAppliance(applianceData: deviceData);
      print("Device successfully added to Firestore via DatabaseService with ID: ${applianceRef.id}");

      // Update the relay_states document for the selected relay
      if (selectedRelay != null) {
        try {
          // We no longer set the 'assigned' field. Just ensure the relay_states document exists.
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('relay_states')
              .doc(selectedRelay)
              .set({}, SetOptions(merge: true)); // Create or merge with empty data
          print("Ensured relay_states document exists for $selectedRelay.");
        } catch (e) {
          print("Error ensuring relay_states document for $selectedRelay: $e");
        }
      }

      // Initialize the yearly_usage document using presentYear
      final yearlyUsageRef = applianceRef.collection('yearly_usage').doc(presentYear);
      await yearlyUsageRef.set({
        'kwh': 0.0,
        'kwhrcost': 0.0,
      });
      print("Initialized yearly_usage for appliance ${applianceRef.id} with document for year $presentYear");

      // Initialize monthly_usage collection and nested structures
      final List<String> months = [
        'jan_usage', 'feb_usage', 'mar_usage', 'apr_usage', 'may_usage', 'jun_usage',
        'jul_usage', 'aug_usage', 'sep_usage', 'oct_usage', 'nov_usage', 'dec_usage'
      ];

      for (String month in months) {
        final monthlyUsageRef = yearlyUsageRef.collection('monthly_usage').doc(month);
        await monthlyUsageRef.set({
          'kwh': 0.0,
          'kwhrcost': 0.0,
        });

        // Calculate the number of days in the current month, considering leap years for February
        final now = DateTime.now();
        final currentYearInt = int.tryParse(presentYear) ?? now.year; // Use presentYear for leap year check
        final monthIndex = months.indexOf(month);
        int numberOfDays;

        if (month == 'feb_usage') {
          numberOfDays = isLeapYear(currentYearInt) ? 29 : 28;
        } else if (month == 'apr_usage' || month == 'jun_usage' || month == 'sep_usage' || month == 'nov_usage') {
          numberOfDays = 30;
        } else {
          numberOfDays = 31;
        }

        // Initialize week_usage collection and nested structures based on actual dates
        int currentDay = 1;
        int weekCounter = 1;
        while (currentDay <= numberOfDays) {
        final weeklyUsageRef = monthlyUsageRef.collection('week_usage').doc('week${weekCounter}_usage');
          await weeklyUsageRef.set({
          'kwh': 0.0,
          'kwhrcost': 0.0,
        });

        // Initialize day_usage collection with exact dates
        for (int day = 0; day < 7 && currentDay <= numberOfDays; day++) {
            final currentDate = DateTime(currentYearInt, monthIndex + 1, currentDay); // Use currentYearInt
            final formattedDate = DateFormat('yyyy-MM-dd').format(currentDate);
            final dailyUsageRef = weeklyUsageRef.collection('day_usage').doc(formattedDate);
            await dailyUsageRef.set({
              'kwh': 0.0,
              'kwhrcost': 0.0,
              'usagetimeon': [],
              'usagetimeoff': [],
            });
            currentDay++;
          }
          weekCounter++;
        }
      }

      print("Initialized monthly, weekly, and daily usage structures with exact dates for appliance ${applianceRef.id}");


      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${deviceData['applianceName']} added successfully!"))
        );
        Navigator.of(context).pop(); // Pop after successful submission
      }
    } catch (e) {
      print("Error adding device via DatabaseService: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error adding device: ${e.toString()}"))
        );
      }
    }
  }

  void _updateDevice() async { // Made async
    final DatabaseService dbService = DatabaseService();
    if (widget.deviceData == null || widget.deviceData!['id'] == null) {
      print("Error: Cannot update device without an ID.");
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: Device ID not found for update."))
        );
      }
      return;
    }
    final String applianceId = widget.deviceData!['id'] as String;

    // Data to update. Only include fields that are editable on this screen.
    // applianceStatus is typically handled by toggle switches, not directly set here unless intended.
    final Map<String, dynamic> updatedData = {
      "applianceName": applianceNameController.text,
      "deviceType": deviceType,
      "wattage": double.tryParse(wattageController.text) ?? 0.0,
      "roomName": selectedRoom!,
      "icon": selectedIcon.codePoint,
      "startTime": startTime != null ? "${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}" : null,
      "endTime": endTime != null ? "${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}" : null,
      "days": selectedDays.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList(),
      "relay": selectedRelay, // Always include relay for all device types
      // "presentHourlyusage": widget.deviceData!['presentHourlyusage'], // Preserve if not editable here
      // "applianceStatus": widget.deviceData!['applianceStatus'], // Preserve if not editable here
    };


    print("Attempting to update device $applianceId with data: $updatedData");

    try {
      await dbService.updateApplianceData(applianceId: applianceId, dataToUpdate: updatedData);
      print("Device $applianceId successfully updated via DatabaseService.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${updatedData['applianceName']} updated successfully!"))
        );
        Navigator.of(context).pop(); // Pop after successful submission
      }
    } catch (e) {
      print("Error updating device $applianceId via DatabaseService: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating device: ${e.toString()}"))
        );
      }
    }
  }

  void _deleteDevice() async { // Made async
    final DatabaseService dbService = DatabaseService();
    if (widget.deviceData == null || widget.deviceData!['id'] == null) {
      print("Error: Cannot delete device without an ID.");
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: Device ID not found for deletion."))
        );
      }
      return;
    }
    final String applianceId = widget.deviceData!['id'] as String;
    final String applianceNameToDelete = widget.deviceData!['applianceName'] as String? ?? "Device";

    // Show a confirmation dialog before deleting
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Delete'),
          content: Text('Are you sure you want to delete "$applianceNameToDelete"? This will erase all associated usage data.'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false); // Dismiss the dialog, return false
              },
            ),
            TextButton(
              child: Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop(true); // Dismiss the dialog, return true
              },
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        // Delete yearly_usage subcollection
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId != null) {
          final yearlyUsageSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('appliances')
              .doc(applianceId)
              .collection('yearly_usage')
              .get();

          for (final doc in yearlyUsageSnapshot.docs) {
            await doc.reference.delete();
          }
           print("Deleted yearly_usage subcollection for appliance $applianceId.");
        }


        await dbService.deleteAppliance(applianceId: applianceId);
        print("Device $applianceId successfully deleted via DatabaseService.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("$applianceNameToDelete deleted successfully!"))
          );
          Navigator.of(context).pop(); // Pop the AddDeviceScreen
        }
      } catch (e) {
        print("Error deleting device $applianceId via DatabaseService: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error deleting device: ${e.toString()}"))
          );
        }
      }
    }
  }

  // Fetch rooms from Firestore
  Future<void> _fetchRoomsFromFirestore() async {
    // Removed setState(_isLoadingRooms = true) as it's handled by _fetchInitialData
    try {
      final userId = DatabaseService().getCurrentUserId();
      if (userId == null) {
        print("User not authenticated. Cannot fetch rooms.");
        setState(() {
          rooms = [];
          roomIcons = {};
          // Removed _isLoadingRooms = false
        });
        return;
      }

      final roomsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('Rooms') // Use the user-specific Rooms subcollection
          .get();

      final List<String> fetchedRooms = [];
      final Map<String, IconData> fetchedIcons = {};

      for (final doc in roomsSnapshot.docs) {
        final data = doc.data();
        final roomName = data['roomName'] as String?;
        final iconCodePoint = data['icon'] as int?;

        if (roomName != null && roomName.isNotEmpty) {
          fetchedRooms.add(roomName);
          fetchedIcons[roomName] = iconCodePoint != null
              ? IconData(iconCodePoint, fontFamily: 'MaterialIcons')
              : Icons.home;
        }
      }

      setState(() {
        rooms = fetchedRooms;
        roomIcons = fetchedIcons;
        // Removed _isLoadingRooms = false

        // If initialRoomName is provided, select it
        if (widget.initialRoomName != null && rooms.contains(widget.initialRoomName)) {
          selectedRoom = widget.initialRoomName;
        } else if (rooms.isNotEmpty) {
          // If no initial room and rooms are available, select the first one
          selectedRoom = rooms.first;
        }
      });

      print("Fetched ${rooms.length} rooms from user's Rooms subcollection");

    } catch (e) {
      print("Error fetching rooms from user's subcollection: $e");
      setState(() {
        rooms = [];
        roomIcons = {};
        // Removed _isLoadingRooms = false
      });
    }
  }

  // Add a new room to Firestore
  void _addRoomToFirestore(String roomName, IconData icon) async {
    try {
      final userId = DatabaseService().getCurrentUserId();
      if (userId == null) {
        print("User not authenticated. Cannot add room.");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("User not authenticated. Cannot add room."))
        );
        return;
      }

      final roomData = {
        'roomName': roomName,
        'icon': icon.codePoint,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('Rooms') // Add to the user-specific Rooms subcollection
          .add(roomData);
      print("Added room '$roomName' to user's Rooms subcollection");
    } catch (e) {
      print("Error adding room to user's subcollection: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Room added locally but failed to save to database: ${e.toString()}"))
      );
    }
  }
}
