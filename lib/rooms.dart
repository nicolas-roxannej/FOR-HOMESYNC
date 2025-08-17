import 'package:flutter/material.dart';
import 'package:homesync/notification_screen.dart';
import 'package:homesync/profile_screen.dart';
import 'package:weather/weather.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:homesync/welcome_screen.dart';
import 'package:homesync/room_data_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// TODO: Replace 'YOUR_API_KEY' with your actual OpenWeatherMap API key
const String _apiKey = 'YOUR_API_KEY'; // Placeholder for Weather API Key
const String _cityName = 'Manila'; // Default city for weather

class Rooms extends StatefulWidget {
  const Rooms({super.key});

  @override
  State<Rooms> createState() => RoomsState();
}

class RoomsState extends State<Rooms> {
  Weather? _currentWeather;
  int _selectedIndex = 2;
  final RoomDataManager _roomDataManager = RoomDataManager();

  // Search functionality variables
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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

  // Weather fetching method
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

  // Helper method to filter rooms based on search query
  List<RoomItem> _filterRooms(List<RoomItem> allRooms) {
    if (_searchQuery.isEmpty) {
      return allRooms;
    } else {
      return allRooms.where((room) {
        final String roomName = room.title.toLowerCase();
        final String searchLower = _searchQuery.toLowerCase();
        return roomName.contains(searchLower);
      }).toList();
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchWeather();
    
    // Initialize search controller listener
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFFE9E7E6),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddRoomDialog(context);
        },
        backgroundColor: Colors.black,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Header section
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
                                  snapshot.data ?? "My Home",
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

                  // Weather section
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

              const SizedBox(height: 20),
              
              // Search bar
              SizedBox(
                width: 355,
                height: 47,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search rooms...',
                    hintStyle: TextStyle(fontSize: 16),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Color(0xFFD9D9D9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide(
                        color: Colors.grey,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  ),
                  style: TextStyle(fontSize: 16),
                ),
              ),

              // Room List
              const SizedBox(height: 20),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                   
                    FocusScope.of(context).unfocus();
                  },
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseAuth.instance.currentUser != null
                        ? FirebaseFirestore.instance
                            .collection('users')
                            .doc(FirebaseAuth.instance.currentUser!.uid)
                            .collection('Rooms')
                            .snapshots()
                        : Stream.empty(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        print("Error fetching rooms: ${snapshot.error}");
                        return Center(child: Text('Error loading rooms: ${snapshot.error}'));
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }
                      
                      if (FirebaseAuth.instance.currentUser == null) {
                         return Center(child: Text('Please log in to view your rooms.'));
                      }

                      // Convert Firestore documents to RoomItem objects
                      final List<RoomItem> allRooms = snapshot.data!.docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final roomName = data['roomName'] as String? ?? 'Unknown Room';
                        final iconCodePoint = data['icon'] as int? ?? Icons.home.codePoint;
                        
                        return RoomItem(
                          title: roomName,
                          icon: _getIconFromCodePoint(iconCodePoint),
                          appliances: [],
                        );
                      }).toList();

                      if (allRooms.isEmpty) {
                        return Center(child: Text('No rooms found. Add a room to get started.'));
                      }

                      
                      final List<RoomItem> filteredRooms = _filterRooms(allRooms);

                      if (filteredRooms.isEmpty && _searchQuery.isNotEmpty) {
                        return Center(
                          child: Text(
                            "No rooms found matching '$_searchQuery'",
                            style: GoogleFonts.inter(),
                            textAlign: TextAlign.center,
                          )
                        );
                      }

                      return _buildRoomsList(filteredRooms);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteRoom(String roomName) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        print("User not authenticated. Cannot delete room.");
        return;
      }

      // Find the room document by roomName in the user's Rooms subcollection
      final roomQuerySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('Rooms')
          .where('roomName', isEqualTo: roomName)
          .limit(1)
          .get();

      if (roomQuerySnapshot.docs.isNotEmpty) {
        final roomIdToDelete = roomQuerySnapshot.docs.first.id;
        
        // Delete the room document
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('Rooms')
            .doc(roomIdToDelete)
            .delete();
            
        print('Deleted room: $roomName');
      } else {
        print('Room not found for deletion: $roomName');
      }

      // Also delete all devices associated with the room from the user's appliances subcollection
      final deviceQuerySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('appliances')
          .where('roomName', isEqualTo: roomName)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in deviceQuerySnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      print('Deleted ${deviceQuerySnapshot.docs.length} devices associated with room: $roomName');

    } catch (e) {
      print('Error deleting room: $e');
    }
  }

  void _editRoomName(String oldName, String newName) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        print("User not authenticated. Cannot edit room name.");
        return;
      }

      // Find the room document by oldName in the user's Rooms subcollection
      final roomQuerySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('Rooms')
          .where('roomName', isEqualTo: oldName)
          .limit(1)
          .get();

      if (roomQuerySnapshot.docs.isNotEmpty) {
        final roomIdToUpdate = roomQuerySnapshot.docs.first.id;
        
        // Update the room document with the new name
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('Rooms')
            .doc(roomIdToUpdate)
            .update({'roomName': newName});
            
        print('Updated room name from $oldName to $newName');
      } else {
        print('Room not found for editing: $oldName');
      }

      // Also update the roomName field in all associated devices in the user's appliances subcollection
      final deviceQuerySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('appliances')
          .where('roomName', isEqualTo: oldName)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in deviceQuerySnapshot.docs) {
        batch.update(doc.reference, {'roomName': newName});
      }
      await batch.commit();
      
      print('Updated room name for ${deviceQuerySnapshot.docs.length} devices associated with room: $oldName');

    } catch (e) {
      print('Error editing room name: $e');
    }
  }

  void _showAddRoomDialog(BuildContext context) {
    TextEditingController roomInput = TextEditingController();
    IconData roomIconSelected = Icons.home;

    showDialog(
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
                  Container(
                    height: 200,
                    width: double.maxFinite,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      children: const [
                        Icons.living, Icons.bed, Icons.kitchen, Icons.dining,
                        Icons.bathroom, Icons.meeting_room,Icons.garage, Icons.local_library, Icons.stairs,
                      ].map((icon) {
                        return IconButton(
                          icon: Icon(
                            icon,
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
          TextButton(
            onPressed: () async {
              if (roomInput.text.isNotEmpty) {
                final newRoomName = roomInput.text;
                final iconCodePoint = roomIconSelected.codePoint;

                final userId = FirebaseAuth.instance.currentUser?.uid;
                if (userId == null) {
                  print("User not authenticated. Cannot add room.");
                  if (mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("User not authenticated. Cannot add room."))
                    );
                  }
                  Navigator.pop(context);
                  return;
                }

                // Add a room document to the user's Rooms subcollection
                final roomData = {
                  'roomName': newRoomName,
                  'icon': iconCodePoint,
                  'createdAt': FieldValue.serverTimestamp(),
                };

                try {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .collection('Rooms')
                      .add(roomData);

                  print('Added room: $newRoomName to user $userId Rooms subcollection with auto-generated ID');

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Room '$newRoomName' added successfully!"))
                    );
                  }

                } catch (e) {
                  print('Error adding room to user subcollection: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Failed to add room: ${e.toString()}"))
                    );
                  }
                }
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

  /// Flyout Menu
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
            offset: const Offset(-90, 0),
            child: Container(
              width: screenSize.width * 0.75,
              height: screenSize.height,
              decoration: const BoxDecoration(
                color: Color(0xFF3D3D3D),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(0),
                  bottomLeft: Radius.circular(0),
                ),
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
                            FutureBuilder<String>(
                              future: getCurrentUsername(),
                              builder: (context, snapshot) {
                                return Text(
                                  snapshot.data ?? "User",
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
                              FirebaseAuth.instance.currentUser?.email ?? "email@example.com",
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ProfileScreen()),
                      );
                    },
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
                      padding: EdgeInsets.only(left: 5),
                      child: Icon(Icons.logout, color: Colors.white, size: 35),
                    ),
                    title: Text('Logout', style: GoogleFonts.inter(color: Colors.white)),
                     onTap: () async {
                      await FirebaseAuth.instance.signOut();
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

  /// Navigation Button
  Widget _buildNavButton(String title, bool isSelected, int index) {
    return Column(
      children: [
        TextButton(
          onPressed: () {
            setState(() => _selectedIndex = index);
            switch (index) {
              case 0:
                Navigator.pushNamed(context, '/homepage');
                break;
              case 1:
                Navigator.pushNamed(context, '/devices');
                break;
              case 2:
                Navigator.pushNamed(context, '/rooms');
                break;
            }
          },
          child: Text(
            title,
            style: GoogleFonts.inter(
              color: isSelected ? Colors.black : Colors.grey[400],
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
              fontSize: 17,
            ),
          ),
        ),
        if (isSelected)
          Transform.translate(
            offset: const Offset(0, -10),
            child: Container(
              height: 2,
              width: 70,
              color: Colors.brown,
              margin: const EdgeInsets.only(top: 1),
            ),
          ),
      ],
    );
  }
  
  // Helper method to build the rooms list
  Widget _buildRoomsList(List<RoomItem> rooms) {
    return ListView.separated(
      itemCount: rooms.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: Colors.grey[300],
      ),
      itemBuilder: (context, index) {
        return RoomListTile(
          room: rooms[index],
          onDelete: () {
            _deleteRoom(rooms[index].title);
          },
          onEdit: (newName) {
            _editRoomName(rooms[index].title, newName);
          },
        );
      },
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

class RoomItem {
  final String title;
  final IconData icon;
  final List<String> appliances;

  RoomItem({
    required this.title,
    required this.icon,
    this.appliances = const [],
  });
}

class RoomListTile extends StatelessWidget {
  final RoomItem room;
  final VoidCallback onDelete;
  final Function(String) onEdit;

  const RoomListTile({
    super.key,
    required this.room,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final String title = room.title;
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/roominfo', arguments: title);
      },
      onDoubleTap: () {
        _showAppliancesDialog(context);
      },
      onLongPress: () {
        _showEditDialog(context);
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 25, horizontal: 16),
        color: Colors.transparent,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.transparent),
                color: Colors.transparent,
              ),
              child: Icon(
                room.icon,
                color: Colors.black87,
                size: 40,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                room.title,
                style: GoogleFonts.judson(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.black,
              size: 40,
            ),
          ],
        ),
      ),
    );
  }

  // Show appliances in this room
  void _showAppliancesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFE9E7E6),
          title: Text('Appliances in ${room.title}',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: room.appliances.isEmpty
              ? Text('No appliances in this room',
                  style: GoogleFonts.inter())
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: room.appliances.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: Icon(Icons.devices),
                      title: Text(room.appliances[index],
                        style: GoogleFonts.inter()),
                    );
                  },
                ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(Colors.black),
                foregroundColor: WidgetStateProperty.all(Colors.white),
              ),
              child: Text('Close', style: GoogleFonts.inter()),
            ),
          ],
        );
      },
    );
  }
  
  // edit name content
  void _showEditDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController(text: room.title);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFE9E7E6),
          title: Text('Edit Room Name', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(
              hintText: 'Room Name',
              filled: true,
              fillColor: Colors.grey[200],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel', style: GoogleFonts.inter(color: Colors.black)),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  onEdit(nameController.text);
                }
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.transparent,
              ),
              child: Text('Save', style: GoogleFonts.inter(color: Colors.black)),
            ),
            TextButton(
              onPressed: () {
                onDelete();
                Navigator.of(context).pop();
              },
              child: Text('Delete', style: GoogleFonts.inter(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}
