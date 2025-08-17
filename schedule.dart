import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:homesync/databaseservice.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Schedule extends StatefulWidget {
  final Map<String, dynamic>? routeArgs;

  const Schedule({super.key, this.routeArgs});

  @override
  State<Schedule> createState() => ScheduleState();
}

class ScheduleState extends State<Schedule> {
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController applianceNameController = TextEditingController();
  final TextEditingController wattageController = TextEditingController();
  final TextEditingController roomController = TextEditingController(); // Using text field instead of dropdown
  final TextEditingController socketController = TextEditingController(); // For relay name

  final _formKey = GlobalKey<FormState>();

  String deviceType = 'Light';
  String? selectedRoom;
  List<String> rooms = ['Living Area', 'Kitchen Area', 'Bedroom', 'Dining Area']; // Can be dynamic later
  Map<String, IconData> roomIcons = {
    'Living Area': Icons.living,
    'Kitchen Area': Icons.kitchen,
    'Bedroom': Icons.bed,
    'Dining Area': Icons.dining,
  };

  TimeOfDay? startTime;
  TimeOfDay? endTime;

  final Map<String, Map<String, TimeOfDay>> presetTimes = {
    'Morning': {'start': TimeOfDay(hour: 6, minute: 0), 'end': TimeOfDay(hour: 12, minute: 0)},
    'Afternoon': {'start': TimeOfDay(hour: 12, minute: 0), 'end': TimeOfDay(hour: 18, minute: 0)},
    'Evening': {'start': TimeOfDay(hour: 18, minute: 0), 'end': TimeOfDay(hour: 23, minute: 0)},
  };

  final List<String> weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  Map<String, bool> selectedDays = {
    'Mon': false, 'Tue': false, 'Wed': false, 'Thu': false, 'Fri': false, 'Sat': false, 'Sun': false,
  };

  IconData selectedIcon = Icons.device_hub; // Default icon

  bool isEditing = false;
  bool _isLoading = true; // Add loading state to prevent UI errors
  String? editingApplianceId; // Firestore document ID of the appliance being edited
  Map<String, dynamic>? _initialApplianceData; // To store original data for status preservation

  String? applianceNameError;
  String? wattageError;
  String? roomError;
  String? socketError; // For relay
  String? timeError;
  String? daysError;

  @override
  void initState() {
    super.initState();
    // Initialize error states to null to prevent showing errors initially
    timeError = null;
    daysError = null;
    
    // Initialize UI state
    _isLoading = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = widget.routeArgs ?? (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?);

    if (args != null && args['applianceId'] != null) {
      isEditing = true;
      editingApplianceId = args['applianceId'] as String;
      
      // Set loading state
      setState(() {
        _isLoading = true;
      });
      
      // Fetch full appliance data to populate the form accurately
      _loadApplianceDataForEditing(editingApplianceId!);
    } else if (args != null) {
        // If args are present but no applianceId, it might be pre-fill for a new device
        applianceNameController.text = args['applianceName'] ?? '';
        selectedRoom = args['roomName'];
        if (selectedRoom != null) {
          roomController.text = selectedRoom!;
        }
        deviceType = args['deviceType'] ?? 'Light';
        if (args['relay'] != null) {
          socketController.text = args['relay'] as String;
        }
    }
  }

  Future<void> _loadApplianceDataForEditing(String applianceId) async {
    try {
      DocumentSnapshot<Map<String, dynamic>>? snapshot = await _dbService.getDocument(
          collectionPath: 'users/${_dbService.getCurrentUserId()}/appliances',
          docId: applianceId
      );

      if (snapshot != null && snapshot.exists) {
        final data = snapshot.data()!;
        _initialApplianceData = data; // Store initial data

        setState(() {
          applianceNameController.text = data['applianceName'] ?? '';
          wattageController.text = (data['wattage'] ?? 0.0).toString();
          
          // Set room to both controller and selectedRoom
          selectedRoom = data['roomName'];
          if (selectedRoom != null) {
            roomController.text = selectedRoom!;
          }
          
          deviceType = data['deviceType'] ?? 'Light';
          selectedIcon = IconData(data['icon'] ?? Icons.device_hub.codePoint, fontFamily: 'MaterialIcons');
          
          // Always set relay value regardless of device type
          socketController.text = data['relay'] ?? '';

          if (data['startTime'] != null) {
            try {
              final stParts = (data['startTime'] as String).split(':');
              startTime = TimeOfDay(hour: int.parse(stParts[0]), minute: int.parse(stParts[1]));
            } catch (e) {
              print("Error parsing start time: $e");
            }
          }
          
          if (data['endTime'] != null) {
            try {
              final etParts = (data['endTime'] as String).split(':');
              endTime = TimeOfDay(hour: int.parse(etParts[0]), minute: int.parse(etParts[1]));
            } catch (e) {
              print("Error parsing end time: $e");
            }
          }

          final daysList = List<String>.from(data['days'] ?? []);
          selectedDays.forEach((key, value) {
            selectedDays[key] = daysList.contains(key);
          });
          
          // Loading complete
          _isLoading = false;
        });
      } else {
        print("Error: Could not load appliance data for editing.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Could not load device data for ID: $applianceId"))
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      print("Error fetching appliance data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading device data: ${e.toString()}"))
        );
        Navigator.of(context).pop();
      }
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
                      isEditing ? 'Edit Schedule' : 'Set Schedule',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.jaldi(
                        textStyle: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                        color: Colors.black,
                      ),
                    ),
                  ),

                  SizedBox(height: 5),
                  Transform.translate(
                    offset: Offset(0, -15),
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

                  // Room input as TextFormField instead of dropdown to avoid assertion errors
                  TextFormField(
                    controller: roomController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: Icon(Icons.home, size: 30, color: Colors.black),
                      labelText: 'Room',
                      labelStyle: GoogleFonts.jaldi(
                        textStyle: TextStyle(fontSize: 20),
                        color: Colors.grey[700],
                      ),
                      hintText: "Enter room name",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      errorText: roomError,
                    ),
                    onChanged: (value) {
                      setState(() {
                        selectedRoom = value;
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

                  SizedBox(height: 15),

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

                  // Required relay for all device 
                  SizedBox(height: 5),
                  _buildRequiredTextField(
                    socketController,
                    "Relay Name",
                    Icons.electrical_services,
                    hint: "Enter relay identifier",
                    errorText: socketError
                  ),

                  SizedBox(height: 10),

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

                 // rep days
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
                                child: Text(daysError!, style: TextStyle(color: Colors.red, fontSize: 12)),
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
                                    color: selectedDays[day] ?? false ? Colors.white : Colors.black,
                                  ),
                                  selected: selectedDays[day] ?? false,
                                  onSelected: (selected) {
                                    setState(() {
                                      selectedDays[day] = selected;
                                    });
                                  },
                                  backgroundColor: Colors.grey[300],
                                  selectedColor: Colors.black,
                                  checkmarkColor: Colors.white,
                                  side: BorderSide(
                                    color: daysError != null && !(selectedDays[day] ?? false) ? Colors.red : Colors.grey,
                                    width: 1
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20),

                  ElevatedButton(
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
                      isEditing ? 'Save Changes' : 'Add Device with Schedule',
                      style: GoogleFonts.judson(
                        fontSize: 20,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequiredTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    String? hint,
    String? errorText,
  }) {
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
            color: Colors.grey[700],
          ),
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          errorText: errorText,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
          ),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return "$label is required";
          }
          if (label == "KWH" && double.tryParse(value) == null) {
            return "Please enter a valid number for KWH";
          }
          return null;
        },
      ),
    );
  }

  void _pickIcon() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFE9E7E6),
      builder: (_) => Container(
        padding: EdgeInsets.all(12),
        child: GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          children: <IconData>[
            Icons.lightbulb_outline, Icons.tv_outlined, Icons.power_outlined, Icons.kitchen_outlined,
            Icons.speaker_group_outlined, Icons.laptop_chromebook_outlined, Icons.ac_unit_outlined, Icons.microwave_outlined,
            Icons.router_outlined, Icons.videogame_asset_outlined, Icons.local_laundry_service_outlined, Icons.air_outlined,
          ].map<Widget>((IconData icon) {
            return IconButton(
              icon: Icon(icon, color: Colors.black, size: 30),
              onPressed: () {
                setState(() {
                  selectedIcon = icon;
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      )
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
        timeError = null;
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
        timeError = null;
      });
    }
  }

  void _validateAndSubmitDevice() {
    bool isValid = true;
    setState(() {
      applianceNameError = null;
      wattageError = null;
      roomError = null;
      socketError = null;
      timeError = null;
      daysError = null;
    });

    if (applianceNameController.text.isEmpty) {
      setState(() { applianceNameError = "Appliance name is required"; });
      isValid = false;
    }
    
    if (wattageController.text.isEmpty) {
      setState(() { wattageError = "Wattage is required"; });
      isValid = false;
    } else if (double.tryParse(wattageController.text) == null) {
      setState(() { wattageError = "Invalid Wattage value"; });
      isValid = false;
    }
    
    if (roomController.text.isEmpty) {
      setState(() { roomError = "Room is required"; });
      isValid = false;
    } else {
      // Make sure selectedRoom is set from controller
      selectedRoom = roomController.text;
    }
    
    if (socketController.text.isEmpty) {
      setState(() { socketError = "Relay name is required"; });
      isValid = false;
    }

    

    if (isValid) {
      _submitDeviceToFirestore();
    }
  }

  Future<void> _submitDeviceToFirestore() async {
    final Map<String, dynamic> firestoreData = {
      'applianceName': applianceNameController.text.trim(),
      'deviceType': deviceType,
      'wattage': double.tryParse(wattageController.text) ?? 0.0,
      'roomName': selectedRoom!,
      'icon': selectedIcon.codePoint,
      'startTime': startTime != null ? "${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}" : null,
      'endTime': endTime != null ? "${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}" : null,
      'days': selectedDays.entries.where((entry) => entry.value).map((entry) => entry.key).toList(),
      'relay': socketController.text.trim(), // Always include relay for all device types
      'applianceStatus': isEditing ? (_initialApplianceData?['applianceStatus'] ?? 'OFF') : 'OFF',
      'presentHourlyusage': isEditing ? (_initialApplianceData?['presentHourlyusage'] ?? 0.0) : 0.0,
    };

    try {
      if (isEditing && editingApplianceId != null) {
        await _dbService.updateApplianceData(
          applianceId: editingApplianceId!,
          dataToUpdate: firestoreData,
        );
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Device schedule updated successfully!')));
      } else {
        // This is for adding a new device with its schedule
        await _dbService.addAppliance(applianceData: firestoreData);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('New device with schedule added!')));
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      print("Error submitting device to Firestore: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving device: ${e.toString()}'))
        );
      }
    }
  }
}
