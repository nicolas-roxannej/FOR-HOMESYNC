import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // For getting current user
import 'dart:async';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  // --- Generic Firestore Operations ---

  // Set data for a document with a specific ID
  Future<void> setDocument({
    required String collectionPath,
    required String docId,
    required Map<String, dynamic> data,
    bool merge = false, // Set to true to merge data instead of overwriting
  }) async {
    try {
      await _firestore.collection(collectionPath).doc(docId).set(data, SetOptions(merge: merge));
    } catch (e) {
      print("Error setting document at $collectionPath/$docId: $e");
      rethrow;
    }
  }

  // Add a document to a collection (Firestore generates ID)
  Future<DocumentReference> addDocumentToCollection({
    required String collectionPath,
    required Map<String, dynamic> data,
  }) async {
    try {
      return await _firestore.collection(collectionPath).add(data);
    } catch (e) {
      print("Error adding document to $collectionPath: $e");
      rethrow;
    }
  }

  // Get a single document
  Future<DocumentSnapshot<Map<String, dynamic>>?> getDocument({
    required String collectionPath,
    required String docId,
  }) async {
    try {
      final snapshot = await _firestore.collection(collectionPath).doc(docId).get();
      if (snapshot.exists) {
        return snapshot;
      }
      return null;
    } catch (e) {
      print("Error getting document $collectionPath/$docId: $e");
      rethrow;
    }
  }

  // Get all documents in a collection
  // WARNING: Fetches ALL documents. Use with caution on large collections.
  // Consider pagination or specific queries if performance is a concern.
  Future<QuerySnapshot<Map<String, dynamic>>> getCollection({
    required String collectionPath,
  }) async {
    try {
      return await _firestore.collection(collectionPath).get();
    } catch (e) {
      print("Error getting collection $collectionPath: $e");
      rethrow;
    }
  }

  // Update a document
  Future<void> updateDocument({
    required String collectionPath,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    try {
      // Check if updating the 'users' collection and if 'year' key is present
      if (collectionPath == 'users' && data.containsKey('year')) {
        // If 'year' is present, assume it should be 'presentYear'
        data['presentYear'] = data['year'];
        data.remove('year');
        print("Warning: Replaced 'year' key with 'presentYear' for user document update.");
      }
      await _firestore.collection(collectionPath).doc(docId).update(data);
    } catch (e) {
      print("Error updating document $collectionPath/$docId: $e");
      rethrow;
    }
  }

  // Delete a document
  Future<void> deleteDocument({
    required String collectionPath,
    required String docId,
  }) async {
    try {
      await _firestore.collection(collectionPath).doc(docId).delete();
    } catch (e) {
      print("Error deleting document $collectionPath/$docId: $e");
      rethrow;
    }
  }

  // Stream a single document
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamDocument({
    required String collectionPath,
    required String docId,
  }) {
    return _firestore.collection(collectionPath).doc(docId).snapshots();
  }

  // Stream a collection
  // WARNING: Streams ALL documents. Use with caution on large collections.
  // Consider filtered or paginated streams if performance is a concern.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamCollection({
    required String collectionPath,
  }) {
    return _firestore.collection(collectionPath).snapshots();
  }

  // --- Appliance Specific Operations ---

  // Get a stream of appliances from the top-level collection
  Stream<QuerySnapshot<Map<String, dynamic>>> getAppliancesStream() {
    // Access the top-level 'appliances' collection directly
    return _firestore.collection('appliances').snapshots();
  }

  // Get a single appliance document for the current user by ID
  Future<Map<String, dynamic>?> getApplianceData(String applianceId) async {
    final userId = getCurrentUserId();
    if (userId == null) {
      print("User not logged in. Cannot get appliance data.");
      return null;
    }
    try {
      final docSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('appliances')
          .doc(applianceId)
          .get();

      if (docSnapshot.exists) {
        // Include the document ID in the returned data
        return {...docSnapshot.data()!, 'id': docSnapshot.id};
      } else {
        return null;
      }
    } catch (e) {
      print("Error getting appliance data for ID $applianceId: $e");
      rethrow;
    }
  }

  // Add a new appliance for the current user
  // This function handles uniqueness check and incremental ID generation.
  Future<DocumentReference> addAppliance({
    required Map<String, dynamic> applianceData, // Contains 'applianceName', 'relay', 'deviceType', etc.
  }) async {
    final userId = getCurrentUserId();
    if (userId == null) {
      throw Exception("User not logged in. Cannot add appliance.");
    }

    final String deviceType = applianceData['deviceType'] as String; // e.g., "Light", "Socket"
    final String applianceName = applianceData['applianceName'] as String;
    final String relay = applianceData['relay'] as String;

    final appliancesCollectionRef = _firestore.collection('users').doc(userId).collection('appliances');

    // 1. Uniqueness Check:
    // Check if an appliance with the same name, relay, AND deviceType already exists for this user.
    // IMPORTANT: This query requires a composite index in Firestore on
    // ('applianceName', 'relay', 'deviceType') for the 'appliances' subcollection
    // to be performant.
    final uniquenessQuery = await appliancesCollectionRef
        .where('applianceName', isEqualTo: applianceName)
        .where('relay', isEqualTo: relay)
        .where('deviceType', isEqualTo: deviceType)
        .limit(1)
        .get();

    if (uniquenessQuery.docs.isNotEmpty) {
      throw Exception("Appliance with the same name, relay, and type already exists.");
    }

    // 2. Incremental ID Generation:
    // Find existing appliances of the same deviceType to determine the next number.
    final typeQuery = await appliancesCollectionRef
        .where('deviceType', isEqualTo: deviceType)
        .get();

    int maxNumber = 0;
    for (var doc in typeQuery.docs) {
      // Document IDs are like "light1", "socket2", etc.
      final docId = doc.id;
      final typePrefix = deviceType.toLowerCase();
      if (docId.startsWith(typePrefix)) {
        try {
          final numberPart = docId.substring(typePrefix.length);
          final number = int.parse(numberPart);
          if (number > maxNumber) {
            maxNumber = number;
          }
        } catch (e) {
          // Ignore IDs that don't match the pattern (e.g., if manually added or different format)
          print("Could not parse number from appliance ID: $docId for type: $deviceType");
        }
      }
    }
    final newNumber = maxNumber + 1;
    final newApplianceId = '${deviceType.toLowerCase()}$newNumber'; // e.g., "light3", "socket1"

    // 3. Add the appliance
    // Ensure all required fields are present as per your rules/data model
    // Example: 'icon' is expected as int (codepoint), 'wattage' and 'usagetime' as double/num
    // 'assigned' as String
    // 'days' as List<String>
    // 'applianceStatus' as String
    // 'presentHourlyusage' as String (or number, ensure consistency)

    // Validate or transform data if necessary before setting
    // For example, 'icon' might be coming as a string from a form
    if (applianceData['icon'] is String) {
        try {
            applianceData['icon'] = int.parse(applianceData['icon'] as String);
        } catch (e) {
            applianceData['icon'] = 0xe333; // Default icon if parsing fails
            print("Warning: Could not parse icon string, using default. Error: $e");
        }
    } else if (applianceData['icon'] == null) {
        applianceData['icon'] = 0xe333; // Default icon if null
    }

    // Ensure 'wattage' is a number (double)
    if (applianceData['wattage'] is String) {
        try {
            applianceData['wattage'] = double.parse(applianceData['wattage'] as String);
        } catch (e) {
            applianceData['wattage'] = 0.0; // Default wattage if parsing fails
             print("Warning: Could not parse wattage string, using default. Error: $e");
        }
    } else if (applianceData['wattage'] == null) {
        applianceData['wattage'] = 0.0; // Default wattage if null
    } else if (applianceData['wattage'] is! double && applianceData['wattage'] is! int) {
        // If it's not a string, double, int, or null, default to 0.0
        applianceData['wattage'] = 0.0;
        print("Warning: wattage has unexpected type ${applianceData['wattage'].runtimeType}. Defaulting to 0.0");
    }


    // Ensure 'usagetime' is a number (double)
    if (applianceData['usagetime'] is String) {
        try {
            applianceData['usagetime'] = double.parse(applianceData['usagetime'] as String);
        } catch (e) {
            applianceData['usagetime'] = 0.0; // Default usagetime if parsing fails
             print("Warning: Could not parse usagetime string, using default. Error: $e");
        }
    } else if (applianceData['usagetime'] == null) {
        applianceData['usagetime'] = 0.0; // Default usagetime if null
    } else if (applianceData['usagetime'] is! double && applianceData['usagetime'] is! int) {
        // If it's not a string, double, int, or null, default to 0.0
        applianceData['usagetime'] = 0.0;
        print("Warning: usagetime has unexpected type ${applianceData['usagetime'].runtimeType}. Defaulting to 0.0");
    }

    // Ensure 'assigned' is a string
    if (applianceData['assigned'] != null && applianceData['assigned'] is! String) {
        applianceData['assigned'] = applianceData['assigned'].toString();
        print("Warning: Converted assigned field to string.");
    } else if (applianceData['assigned'] == null) {
        applianceData['assigned'] = ''; // Default to empty string if null
    }
    
    // Ensure 'days' is a List<String>
    if (applianceData['days'] is! List<String> && applianceData['days'] != null) {
        // Attempt to convert if it's List<dynamic> or handle error
        if (applianceData['days'] is List) {
            applianceData['days'] = List<String>.from(applianceData['days'] as List);
        } else {
            applianceData['days'] = <String>[]; // Default to empty list if not a list
        }
    } else if (applianceData['days'] == null) {
        applianceData['days'] = <String>[];
    }


    // Ensure 'presentHourlyusage' is a number (double)
    if (applianceData['presentHourlyusage'] is String) {
        try {
            applianceData['presentHourlyusage'] = double.parse(applianceData['presentHourlyusage'] as String);
        } catch (e) {
            applianceData['presentHourlyusage'] = 0.0; // Default if parsing fails
            print("Warning: Could not parse presentHourlyusage string, using default. Error: $e");
        }
    } else if (applianceData['presentHourlyusage'] == null) {
         applianceData['presentHourlyusage'] = 0.0;
    }


    // Add creation timestamp
    applianceData['createdAt'] = FieldValue.serverTimestamp();


    final applianceDocRef = appliancesCollectionRef.doc(newApplianceId);
    await applianceDocRef.set(applianceData);
    // Update the corresponding relay document
    if (applianceData['relay'] != null) {
      final relayDocRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('relay_states')
          .doc(applianceData['relay'] as String);

      await relayDocRef.set({
        'assigned': newApplianceId, // Use the newly generated appliance ID
        'wattage': applianceData['wattage'] ?? 0.0,
      }, SetOptions(merge: true));
      print("Relay state updated for ${applianceData['relay']}");
    }

    print("Appliance added with ID: $newApplianceId");
    return applianceDocRef; // Return the DocumentReference
  }

  // Update appliance data and corresponding relay state
  Future<void> updateApplianceData({
    required String applianceId, // e.g., "light1"
    required Map<String, dynamic> dataToUpdate,
  }) async {
    if (dataToUpdate.isEmpty) {
      print("No data provided for update.");
      return;
    }

    final userId = getCurrentUserId();
    if (userId == null) {
      throw Exception("User not logged in. Cannot update appliance.");
    }

    // Fetch the current appliance data to check for relay changes
    final currentApplianceSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('appliances')
        .doc(applianceId)
        .get();

    if (!currentApplianceSnapshot.exists) {
      throw Exception("Appliance with ID $applianceId not found.");
    }

    final currentApplianceData = currentApplianceSnapshot.data();
    final oldRelay = currentApplianceData?['relay'] as String?;
    final newRelay = dataToUpdate['relay'] as String?;
    final newWattage = dataToUpdate['wattage'] ?? currentApplianceData?['wattage'] ?? 0.0;
    final newUsagetime = dataToUpdate['usagetime'] ?? currentApplianceData?['usagetime'] ?? 0.0;
    final newApplianceName = dataToUpdate['applianceName'] ?? currentApplianceData?['applianceName'] ?? applianceId;


    // Update the appliance document
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('appliances') // Target the user-specific subcollection
          .doc(applianceId)
          .update(dataToUpdate);

      print("Updated appliance $applianceId for user $userId with data: $dataToUpdate");

      // Update relay state based on changes
      if (oldRelay != newRelay) {
        // Relay has changed
        // Clear old relay state
        if (oldRelay != null && oldRelay.isNotEmpty) {
          final oldRelayDocRef = _firestore
              .collection('users')
              .doc(userId)
              .collection('relay_states')
              .doc(oldRelay);
          await oldRelayDocRef.update({
            'assigned': null,
            'wattage': null,
            'state': 0, // Set the state of the old relay to OFF (assuming 0 represents OFF)
          });
          print("Cleared old relay state and set state to OFF for $oldRelay");
        }

        // Set new relay state
        if (newRelay != null && newRelay.isNotEmpty) {
          final newRelayDocRef = _firestore
              .collection('users')
              .doc(userId)
              .collection('relay_states')
              .doc(newRelay);
          await newRelayDocRef.set({
            'assigned': applianceId, // Use the appliance ID
            'wattage': newWattage,
          }, SetOptions(merge: true));
          print("Set new relay state for $newRelay");
        }
      } else if (newRelay != null && newRelay.isNotEmpty && (dataToUpdate.containsKey('applianceName') || dataToUpdate.containsKey('wattage') || dataToUpdate.containsKey('usagetime'))) {
        // Relay is the same, but applianceName, wattage, or usagetime changed
        final currentRelayDocRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('relay_states')
            .doc(newRelay);
         await currentRelayDocRef.set({
            'assigned': applianceId, // Use the appliance ID
            'wattage': newWattage,
          }, SetOptions(merge: true));
          print("Updated relay state for $newRelay with new applianceName, wattage, or usagetime");
      }


    } catch (e) {
      print("Error updating appliance $applianceId for user $userId: $e");
      rethrow; // Re-throw the error for the caller to handle
    }
  }

  // Delete an appliance and clear its relay state
  Future<void> deleteAppliance({required String applianceId}) async {
    final userId = getCurrentUserId();
    if (userId == null) {
      throw Exception("User not logged in. Cannot delete appliance.");
    }

    // Fetch the appliance data before deleting to get the relay
    final applianceSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('appliances')
        .doc(applianceId)
        .get();

    String? assignedRelay;
    if (applianceSnapshot.exists) {
      assignedRelay = applianceSnapshot.data()?['relay'] as String?;
    }

    // Delete the appliance document
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('appliances') // Target the user-specific subcollection
          .doc(applianceId)
          .delete();

      print("Deleted appliance $applianceId for user $userId");

      // Clear the corresponding relay state
      if (assignedRelay != null && assignedRelay.isNotEmpty) {
        final relayDocRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('relay_states')
            .doc(assignedRelay);
        await relayDocRef.update({
          'assigned': FieldValue.delete(),
          'wattage': FieldValue.delete(),
        });
        print("Cleared relay state for $assignedRelay after appliance deletion");
      }

    } catch (e) {
      print("Error deleting appliance $applianceId for user $userId: $e");
      rethrow; // Re-throw the error for the caller to handle
    }
  }

  // --- Methods for other collections (personal_information, usage) ---
  // You can add similar methods for 'personal_information' and 'usage' if needed.
  // For example:
  Future<void> setUserPersonalInformation({required Map<String, dynamic> data}) async {
    final userId = getCurrentUserId();
    if (userId == null) throw Exception("User not logged in.");
    // Assuming a single document for personal info, e.g., 'details'
    // Ensure presentYear is stored as a number if it exists
    if (data.containsKey('presentYear')) {
      final dynamic yearValue = data['presentYear'];
      if (yearValue is String) {
        try {
          data['presentYear'] = int.parse(yearValue);
        } catch (e) {
          print("Warning: Could not parse presentYear string '$yearValue' to int. Removing field. Error: $e");
          data.remove('presentYear'); // Remove if parsing fails
        }
      } else if (yearValue == null) {
        data.remove('presentYear'); // Remove if null
      } else if (yearValue is! int) {
         // If it's not a string, int, or null, remove it to avoid errors
         print("Warning: presentYear has unexpected type ${yearValue.runtimeType}. Removing field.");
         data.remove('presentYear');
      }
    }
    await _firestore.collection('users').doc(userId).collection('personal_information').doc('details').set(data, SetOptions(merge: true));
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamUserPersonalInformation() {
    final userId = getCurrentUserId();
    if (userId == null) return Stream.error("User not logged in.");
    return _firestore.collection('users').doc(userId).collection('personal_information').doc('details').snapshots();
  }

  Future<void> addUserUsageRecord({required Map<String, dynamic> data}) async {
    final userId = getCurrentUserId();
    if (userId == null) throw Exception("User not logged in.");
    // Firestore will generate an ID for each usage record
    await _firestore.collection('users').doc(userId).collection('usage').add(data);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamUserUsageRecords() {
    final userId = getCurrentUserId();
    if (userId == null) return Stream.error("User not logged in.");
    // Order by timestamp, for example
    return _firestore.collection('users').doc(userId).collection('usage').orderBy('timestamp', descending: true).snapshots();
  }

}
