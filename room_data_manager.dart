import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth

class RoomDataManager {
  static final RoomDataManager _instance = RoomDataManager._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Get Firestore instance
  
  factory RoomDataManager() {
    return _instance;
  }
  
  RoomDataManager._internal();

  // Fetch devices from Firestore
  Future<Map<String, List<Map<String, dynamic>>>> fetchDevices() async {
    final Map<String, List<Map<String, dynamic>>> fetchedRoomDevices = {};

    try {
      final querySnapshot = await _firestore.collection('appliances').get();
      
      print('Fetched ${querySnapshot.docs.length} devices from Firestore');

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final roomName = data['roomName'] as String? ?? 'Unknown Room';
        final deviceType = data['deviceType'] as String? ?? 'Unknown Type';
        final applianceName = data['applianceName'] as String? ?? 'Unknown Device';

        if (!fetchedRoomDevices.containsKey(roomName)) {
          fetchedRoomDevices[roomName] = [];
        }

        // Create a map with all the device data, including the document ID
        final deviceData = {
          'id': doc.id, // Include the document ID
          'applianceName': applianceName,
          'roomName': roomName,
          'deviceType': deviceType,
          'relay': data['relay'] as String? ?? '',
          'icon': data['icon'] is int ? data['icon'] as int : 0xe333, // Default icon if not present
          'wattage': data['wattage'] is num ? (data['wattage'] as num).toDouble() : 0.0,
          'startTime': data['startTime'] as String? ?? '',
          'endTime': data['endTime'] as String? ?? '',
          'days': data['days'] is List ? List<String>.from(data['days'] as List) : <String>[],
          'applianceStatus': data['applianceStatus'] as String? ?? 'OFF',
          'presentHourlyusage': data['presentHourlyusage'] is num ? (data['presentHourlyusage'] as num).toDouble() : 0.0,
        };

        fetchedRoomDevices[roomName]!.add(deviceData);
        print('Added device: ${deviceData['applianceName']} to room: $roomName');
      }
    } catch (e) {
      print('Error fetching devices: $e');
      // Handle error appropriately
    }

    return fetchedRoomDevices;
  }

  // Add a new device to Firestore
  Future<void> addDevice(Map<String, dynamic> deviceData) async {
    try {
      final roomName = deviceData['roomName'] as String;
      final deviceType = deviceData['deviceType'] as String;
      final applianceName = deviceData['applianceName'] as String;

      await _firestore
          .collection('appliances')
          .doc(roomName)
          .collection(deviceType)
          .doc(applianceName)
          .set(deviceData);
    } catch (e) {
      print('Error adding device: $e');
      // Handle error appropriately
    }
  }

  // Update an existing device in Firestore
  Future<void> updateDevice(String roomName, String deviceType, String applianceName, Map<String, dynamic> updatedData) async {
    try {
      await _firestore
          .collection('appliances')
          .doc(roomName)
          .collection(deviceType)
          .doc(applianceName)
          .update(updatedData);
    } catch (e) {
      print('Error updating device: $e');
      // Handle error appropriately
    }
  }

  // Delete a device from Firestore
  Future<void> deleteDevice(String roomName, String deviceType, String applianceName) async {
    try {
      await _firestore
          .collection('appliances')
          .doc(roomName)
          .collection(deviceType)
          .doc(applianceName)
          .delete();
    } catch (e) {
      print('Error deleting device: $e');
      // Handle error appropriately
    }
  }

  // Fetch room details by room name
  Future<Map<String, dynamic>?> fetchRoomDetails(String roomName) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        print("User not authenticated. Cannot fetch room details.");
        return null;
      }

      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('Rooms') // Use the user-specific Rooms subcollection
          .where('roomName', isEqualTo: roomName)
          .limit(1) // Assuming room names are unique within a user's collection
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      } else {
        return null; // Room not found
      }
    } catch (e) {
      print('Error fetching room details for $roomName from user subcollection: $e');
      return null;
    }
  }

  // No hardcoded room data - all data comes from Firestore
  
  // update room name
  Future<void> updateRoomName(String oldName, String newName) async {
    try {
      // Fetch devices with the old room name
      final querySnapshot = await _firestore
          .collection('appliances')
          .where('roomName', isEqualTo: oldName)
          .get();

      print('Found ${querySnapshot.docs.length} devices to update from room $oldName to $newName');

      // Use a batched write for efficiency
      final batch = _firestore.batch();

      for (final doc in querySnapshot.docs) {
        // Simply update the roomName field in each document
        batch.update(doc.reference, {'roomName': newName});
        print('Updating device ${doc.id} to new room name: $newName');
      }

      // Also update the room document if it exists
      final roomQuerySnapshot = await _firestore
          .collection('rooms')
          .where('roomName', isEqualTo: oldName)
          .get();
          
      for (final roomDoc in roomQuerySnapshot.docs) {
        batch.update(roomDoc.reference, {'roomName': newName});
        print('Updating room document ${roomDoc.id} to new name: $newName');
      }

      // Commit the batched write
      await batch.commit();
      print('Successfully updated room name from $oldName to $newName');

    } catch (e) {
      print('Error updating room name: $e');
      // Handle error appropriately
    }
  }
}
