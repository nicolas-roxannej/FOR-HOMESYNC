import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Default cost per kWh. This should ideally be configurable.
const double DEFAULT_KWHR_RATE = 0.15; // Example rate

class UsageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _liveUpdateTimer;

  String _getMonthName(int month) {
    const monthNames = ['', 'jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
    return monthNames[month].toLowerCase();
  }

  int _getWeekOfMonth(DateTime date) {
    if (date.day <= 7) return 1;
    if (date.day <= 14) return 2;
    if (date.day <= 21) return 3;
    if (date.day <= 28) return 4;
    return 5;
  }

  String _getApplianceDailyPath(String userId, String applianceId, DateTime date) {
    String year = date.year.toString();
    String monthName = _getMonthName(date.month);
    int weekOfMonth = _getWeekOfMonth(date);
    String dayStr = DateFormat('yyyy-MM-dd').format(date);
    return 'users/$userId/appliances/$applianceId/yearly_usage/$year/monthly_usage/${monthName}_usage/week_usage/week${weekOfMonth}_usage/day_usage/$dayStr';
  }

  String _getApplianceWeeklyPath(String userId, String applianceId, DateTime date) {
    String year = date.year.toString();
    String monthName = _getMonthName(date.month);
    int weekOfMonth = _getWeekOfMonth(date);
    return 'users/$userId/appliances/$applianceId/yearly_usage/$year/monthly_usage/${monthName}_usage/week_usage/week${weekOfMonth}_usage';
  }

  String _getApplianceMonthlyPath(String userId, String applianceId, DateTime date) {
    String year = date.year.toString();
    String monthName = _getMonthName(date.month);
    return 'users/$userId/appliances/$applianceId/yearly_usage/$year/monthly_usage/${monthName}_usage';
  }

  String _getApplianceYearlyPath(String userId, String applianceId, DateTime date) {
    String year = date.year.toString();
    return 'users/$userId/appliances/$applianceId/yearly_usage/$year';
  }

  String getOverallYearlyDocPath(String userId, int year) {
    return 'users/$userId/yearly_usage/$year';
  }

  String getOverallMonthlyDocPath(String userId, int year, int month) {
    String monthName = _getMonthName(month);
    return 'users/$userId/yearly_usage/$year/monthly_usage/${monthName}_usage';
  }

  String getOverallWeeklyDocPath(String userId, int year, int month, int weekOfMonth) {
    String monthName = _getMonthName(month);
    return 'users/$userId/yearly_usage/$year/monthly_usage/${monthName}_usage/week_usage/week${weekOfMonth}_usage';
  }

  String getOverallDailyDocPath(String userId, DateTime date) {
    String yearStr = date.year.toString();
    String monthName = _getMonthName(date.month);
    int weekOfMonth = _getWeekOfMonth(date);
    String dayFormatted = DateFormat('yyyy-MM-dd').format(date);
    return 'users/$userId/yearly_usage/$yearStr/monthly_usage/${monthName}_usage/week_usage/week${weekOfMonth}_usage/day_usage/$dayFormatted';
  }

  Future<void> handleApplianceToggle({
    required String userId,
    required String applianceId,
    required bool isOn,
    required double wattage,
    double kwhrRate = DEFAULT_KWHR_RATE,
  }) async {
    DateTime now = DateTime.now();
    String timeStr = DateFormat('HH:mm:ss').format(now); 
    print("DEBUG: handleApplianceToggle - Formatted timeStr for storage: $timeStr (isOn: $isOn)");

    String dailyPathForEvent = _getApplianceDailyPath(userId, applianceId, now);
    DocumentReference currentActionDailyDocRef = _firestore.doc(dailyPathForEvent);
    DocumentReference mainApplianceDocRef = _firestore.collection('users').doc(userId).collection('appliances').doc(applianceId);

    if (isOn) {
      print('DEBUG: Attempting to set usagetimeon for path: ${currentActionDailyDocRef.path} with time: $timeStr');
      try {
        await currentActionDailyDocRef.set({
          'usagetimeon': FieldValue.arrayUnion([timeStr]),
          'last_event_timestamp': FieldValue.serverTimestamp(),
          'wattage': wattage,
          'kwhr_rate': kwhrRate,
        }, SetOptions(merge: true));
        print('DEBUG: Successfully set usagetimeon for path: ${currentActionDailyDocRef.path}');
      } catch (e) {
        print('DEBUG: ERROR setting usagetimeon for path ${currentActionDailyDocRef.path}: $e');
      }
      await mainApplianceDocRef.update({'last_live_calc_timestamp': now});
      print('Appliance $applianceId ON. Doc: $dailyPathForEvent, Time: $timeStr');
    } else {
      print('DEBUG: Attempting to set usagetimeoff for path: ${currentActionDailyDocRef.path} with time: $timeStr');
      try {
        await currentActionDailyDocRef.set({
          'usagetimeoff': FieldValue.arrayUnion([timeStr]),
          'last_event_timestamp': FieldValue.serverTimestamp(),
          'wattage': wattage,
          'kwhr_rate': kwhrRate,
        }, SetOptions(merge: true));
        print('DEBUG: Successfully set usagetimeoff for path: ${currentActionDailyDocRef.path}');
      } catch (e) {
        print('DEBUG: ERROR setting usagetimeoff for path ${currentActionDailyDocRef.path}: $e');
      }
      print('Appliance $applianceId OFF. Doc: $dailyPathForEvent, Time: $timeStr');
      await _calculateAndRecordUsageForCompletedSession(
        userId: userId, applianceId: applianceId, wattage: wattage, kwhrRate: kwhrRate, offTime: now,
      );
    }
    await _triggerAggregationsForAppliance(userId, applianceId, kwhrRate, now);
    await updateAllAppliancesTotalUsage(userId: userId, kwhrRate: kwhrRate, referenceDate: now);
  }

  Future<void> _calculateAndRecordUsageForCompletedSession({
    required String userId,
    required String applianceId,
    required double wattage,
    required double kwhrRate,
    required DateTime offTime, 
  }) async {
    DocumentReference? onDayDocRef;
    String? onDateStr;
    String? correspondingOnTimeStr; 

    String offTimeFormattedForComparison = DateFormat('HH:mm:ss').format(offTime);
    print('DEBUG_CALC: _calculateAndRecordUsageForCompletedSession started for $applianceId. OffTime: $offTime, Formatted OffTime for comparison: $offTimeFormattedForComparison');

    for (int i = 0; i < 7; i++) {
        DateTime dateToQuery = offTime.subtract(Duration(days: i));
        String dailyPath = _getApplianceDailyPath(userId, applianceId, dateToQuery);
        print('DEBUG_CALC: Querying path in loop: $dailyPath for appliance $applianceId');
        DocumentSnapshot dailyDoc = await _firestore.doc(dailyPath).get();
        
        if (dailyDoc.exists) {
            print('DEBUG_CALC: Document exists at $dailyPath. Raw Data: ${dailyDoc.data()}');
            Map<String, dynamic> data = dailyDoc.data() as Map<String, dynamic>;
            List<String> usageTimeOn = List<String>.from(data['usagetimeon'] ?? []);
            List<String> usageTimeOff = List<String>.from(data['usagetimeoff'] ?? []);
            print('DEBUG_CALC: Extracted usagetimeon from $dailyPath: $usageTimeOn');
            print('DEBUG_CALC: Extracted usagetimeoff from $dailyPath: $usageTimeOff');
            
            if (usageTimeOn.isNotEmpty) {
                print('DEBUG_CALC: usagetimeon is not empty. Length: ${usageTimeOn.length}, usagetimeoff Length: ${usageTimeOff.length}');
                bool foundOnTime = false;

                if (usageTimeOn.length > usageTimeOff.length) {
                    correspondingOnTimeStr = usageTimeOn.last;
                    foundOnTime = true;
                    print('DEBUG_CALC: Condition (on.length > off.length) MET. correspondingOnTimeStr = ${usageTimeOn.last}');
                } else if (usageTimeOff.contains(offTimeFormattedForComparison)) {
                    if (usageTimeOn.length == usageTimeOff.length) {
                        int offIdx = usageTimeOff.lastIndexOf(offTimeFormattedForComparison);
                        if (offIdx != -1 && offIdx < usageTimeOn.length) {
                            correspondingOnTimeStr = usageTimeOn[offIdx];
                            foundOnTime = true;
                            print('DEBUG_CALC: Condition (on.length == off.length AND offList contains current) MET. Index: $offIdx. correspondingOnTimeStr = $correspondingOnTimeStr');
                        } else {
                             print('DEBUG_CALC: (on.length == off.length AND offList contains current) but index mapping failed.');
                        }
                    } else if (usageTimeOn.length == usageTimeOff.length - 1) {
                        correspondingOnTimeStr = usageTimeOn.last;
                        foundOnTime = true;
                        print('DEBUG_CALC: Condition (on.length == off.length - 1 AND offList contains current) MET. Using last onTime: ${usageTimeOn.last}');
                    } else {
                        print('DEBUG_CALC: offList contains current offTime, but on/off length mismatch is complex (on:${usageTimeOn.length}, off:${usageTimeOff.length}).');
                    }
                } else {
                     print('DEBUG_CALC: Conditions for finding correspondingOnTimeStr NOT MET. (on.length=${usageTimeOn.length}, off.length=${usageTimeOff.length}, offList.contains=${usageTimeOff.contains(offTimeFormattedForComparison)})');
                }
                
                if (foundOnTime && correspondingOnTimeStr != null) {
                    print('DEBUG_CALC: Successfully determined correspondingOnTimeStr: $correspondingOnTimeStr');
                    onDayDocRef = dailyDoc.reference;
                    onDateStr = DateFormat('yyyy-MM-dd').format(dateToQuery);
                    break; 
                }
            } else {
                 print('DEBUG_CALC: usagetimeon list is empty for $dailyPath.');
            }
        } else {
            print('DEBUG_CALC: Document does NOT exist at $dailyPath');
        }
        if (onDayDocRef != null) break;
    }

    if (onDayDocRef != null && onDateStr != null && correspondingOnTimeStr != null) {
      DateTime onDateTime;
      try { 
        print('DEBUG_CALC: Parsing onDateTime from onDateStr: $onDateStr, correspondingOnTimeStr: $correspondingOnTimeStr (Format: HH:mm:ss)');
        onDateTime = DateFormat('yyyy-MM-dd HH:mm:ss').parse('$onDateStr $correspondingOnTimeStr'); 
      } 
      catch (e) { 
        try { 
          print('DEBUG_CALC: Retrying parse onDateTime (Format: HH:mm:ss.SSS) due to error: $e');
          onDateTime = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').parse('$onDateStr $correspondingOnTimeStr'); 
        } 
        catch (e2) { 
          print("Error parsing onDateTime: $e2. onDateStr: $onDateStr, correspondingOnTimeStr: $correspondingOnTimeStr"); 
          return; 
        }
      }
      print('DEBUG_CALC: Parsed onDateTime: $onDateTime, Actual offTime object: $offTime');
      
      if (offTime.isAfter(onDateTime)) {
        Duration duration = offTime.difference(onDateTime);
        double hours = duration.inMilliseconds / (3600.0 * 1000.0); 
        double kwh = (wattage * hours) / 1000.0;
        print('DEBUG_CALC: Duration: ${duration.inSeconds}s, Hours: $hours, Wattage: $wattage, kWh: $kwh');
        
        if (kwh < 0) {
            print('DEBUG_CALC: Calculated kWh is negative ($kwh). Setting to 0. This might indicate a clock sync issue or rapid toggling.');
            kwh = 0;
        }

        await onDayDocRef.set({'kwh': FieldValue.increment(kwh), 'wattage': wattage, 'kwhr_rate': kwhrRate,}, SetOptions(merge: true));
        DocumentSnapshot updatedDailyDoc = await onDayDocRef.get(); 
        double totalDailyKwh = (updatedDailyDoc.data() as Map<String, dynamic>)['kwh'] ?? 0.0;
        double totalDailyCost = totalDailyKwh * kwhrRate;
        await onDayDocRef.set({'kwhrcost': totalDailyCost}, SetOptions(merge: true)); 
        print("CALC_SESSION $applianceId: kWh $kwh added. Daily Total: $totalDailyKwh, Cost: $totalDailyCost. Path: ${onDayDocRef.path}");
        
        await _triggerAggregationsForAppliance(userId, applianceId, kwhrRate, onDateTime);
        if (onDateStr != DateFormat('yyyy-MM-dd').format(offTime)) {
            await _triggerAggregationsForAppliance(userId, applianceId, kwhrRate, offTime);
        }
      } else {
         print('DEBUG_CALC: offTime ($offTime) is NOT after onDateTime ($onDateTime). No calculation performed.');
      }
    } else {
      print("CALC_SESSION No ON time for $applianceId (OFF at $offTime). Details: onDayDocRef is null: ${onDayDocRef == null}, onDateStr is null: ${onDateStr == null}, correspondingOnTimeStr is null: ${correspondingOnTimeStr == null}");
    }
  }

  Future<void> handleManualRefreshForAppliance({
    required String userId,
    required String applianceId,
    required double kwhrRate,
    required DateTime refreshTime,
  }) async {
    print("DEBUG_REFRESH: Manual refresh requested for $applianceId at $refreshTime");
    DocumentReference mainApplianceDocRef = _firestore.collection('users').doc(userId).collection('appliances').doc(applianceId);
    DocumentSnapshot applianceSnap = await mainApplianceDocRef.get();

    if (!applianceSnap.exists) {
      print("DEBUG_REFRESH: Appliance $applianceId not found during manual refresh.");
      return;
    }

    Map<String, dynamic> applianceData = applianceSnap.data() as Map<String, dynamic>;
    String? status = applianceData['applianceStatus'] as String?;
    double? wattage = (applianceData['wattage'] as num?)?.toDouble();

    if (wattage == null) {
      print("DEBUG_REFRESH: Wattage not found for $applianceId. Cannot perform segmented calculation.");
    } else if (status == 'ON') {
      print("DEBUG_REFRESH: Appliance $applianceId is ON. Performing segmented calculation for refresh.");
      String timeStr = DateFormat('HH:mm:ss').format(refreshTime);
      String dailyPath = _getApplianceDailyPath(userId, applianceId, refreshTime);
      DocumentReference dailyDocRef = _firestore.doc(dailyPath);

      print("DEBUG_REFRESH: Adding temporary OFF event ($timeStr) to $dailyPath for $applianceId");
      await dailyDocRef.set({
        'usagetimeoff': FieldValue.arrayUnion([timeStr]),
        'last_event_timestamp': FieldValue.serverTimestamp(),
        'wattage': wattage,
        'kwhr_rate': kwhrRate,
      }, SetOptions(merge: true));

      print("DEBUG_REFRESH: Calling _calculateAndRecordUsageForCompletedSession for segment ending at $refreshTime for $applianceId");
      await _calculateAndRecordUsageForCompletedSession(
        userId: userId,
        applianceId: applianceId,
        wattage: wattage,
        kwhrRate: kwhrRate,
        offTime: refreshTime,
      );

      print("DEBUG_REFRESH: Adding new ON event ($timeStr) to $dailyPath to continue session for $applianceId");
      await dailyDocRef.set({
        'usagetimeon': FieldValue.arrayUnion([timeStr]),
        'last_event_timestamp': FieldValue.serverTimestamp(),
        'wattage': wattage, 
        'kwhr_rate': kwhrRate, 
      }, SetOptions(merge: true));
      
      print("DEBUG_REFRESH: Updating last_live_calc_timestamp for $applianceId to $refreshTime");
      await mainApplianceDocRef.update({'last_live_calc_timestamp': refreshTime});
    } else {
      print("DEBUG_REFRESH: Appliance $applianceId is OFF. Skipping segmented calculation for refresh.");
    }

    print("DEBUG_REFRESH: Triggering aggregations for $applianceId and updating overall totals for $refreshTime.");
    await _triggerAggregationsForAppliance(userId, applianceId, kwhrRate, refreshTime);
    await updateAllAppliancesTotalUsage(userId: userId, kwhrRate: kwhrRate, referenceDate: refreshTime);
    print("DEBUG_REFRESH: Manual refresh for $applianceId completed.");
  }

  Future<DateTime?> calculateAndUpdateInterimUsage({
    required String userId,
    required String applianceId,
    required Map<String, dynamic> applianceData, 
    required double kwhrRate,
    required DateTime currentTime, 
  }) async {
    double? wattage = (applianceData['wattage'] as num?)?.toDouble();
    String? status = applianceData['applianceStatus'] as String?;

    if (wattage == null || status != 'ON') {
      return null; 
    }

    DocumentReference? sessionStartDailyDocRef;
    String? sessionStartDateStr;
    String? sessionLastOnTimeStr;

    for (int i = 0; i < 7; i++) {
        DateTime dateToQuery = currentTime.subtract(Duration(days: i));
        String dailyPath = _getApplianceDailyPath(userId, applianceId, dateToQuery);
        DocumentSnapshot dailyDocSnap = await _firestore.doc(dailyPath).get();

        if (dailyDocSnap.exists) {
            Map<String, dynamic> data = dailyDocSnap.data() as Map<String, dynamic>;
            List<String> usageTimeOn = List<String>.from(data['usagetimeon'] ?? []);
            List<String> usageTimeOff = List<String>.from(data['usagetimeoff'] ?? []);

            if (usageTimeOn.isNotEmpty && usageTimeOn.length > usageTimeOff.length) {
                sessionStartDailyDocRef = dailyDocSnap.reference;
                sessionStartDateStr = DateFormat('yyyy-MM-dd').format(dateToQuery);
                sessionLastOnTimeStr = usageTimeOn.last;
                break; 
            }
        }
    }
    
    if (sessionStartDailyDocRef != null && sessionStartDateStr != null && sessionLastOnTimeStr != null) {
      DateTime actualSessionOnDateTime;
      try { actualSessionOnDateTime = DateFormat('yyyy-MM-dd HH:mm:ss').parse('$sessionStartDateStr $sessionLastOnTimeStr'); } 
      catch(e) { try { actualSessionOnDateTime = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').parse('$sessionStartDateStr $sessionLastOnTimeStr');} 
        catch(e2){ print("Error parsing actualSessionOnDateTime: $e2"); return null;}
      }
            
      DateTime lastCalcTimestamp = (applianceData['last_live_calc_timestamp'] as Timestamp?)?.toDate() ?? actualSessionOnDateTime;
      DateTime calculationStartTime = lastCalcTimestamp.isAfter(actualSessionOnDateTime) ? lastCalcTimestamp : actualSessionOnDateTime;

      if (currentTime.isAfter(calculationStartTime)) {
        Duration duration = currentTime.difference(calculationStartTime);
        if (duration.inMilliseconds <= 0) {
          await _firestore.collection('users').doc(userId).collection('appliances').doc(applianceId).update({'last_live_calc_timestamp': currentTime});
          return null;
        }

        double hours = duration.inMilliseconds / (3600.0 * 1000.0);
        double incrementalKwh = (wattage * hours) / 1000.0;

        if (incrementalKwh > 0) {
          await sessionStartDailyDocRef.set({
            'kwh': FieldValue.increment(incrementalKwh),
            'wattage': wattage, 
            'kwhr_rate': kwhrRate,
          }, SetOptions(merge: true));
          
          DocumentSnapshot updatedDailyDoc = await sessionStartDailyDocRef.get();
          double totalDailyKwh = (updatedDailyDoc.data() as Map<String, dynamic>)['kwh'] ?? 0.0;
          double totalDailyCost = totalDailyKwh * kwhrRate;
          await sessionStartDailyDocRef.set({'kwhrcost': totalDailyCost}, SetOptions(merge: true));
          
          print("[UsageService REFRESH_INTERIM] $applianceId: Added $incrementalKwh kWh to ${sessionStartDailyDocRef.path}. New Total: $totalDailyKwh kWh, Cost: $totalDailyCost.");
        }
        await _firestore.collection('users').doc(userId).collection('appliances').doc(applianceId).update({'last_live_calc_timestamp': currentTime});
        return DateFormat('yyyy-MM-dd').parse(sessionStartDateStr);
      } else {
        await _firestore.collection('users').doc(userId).collection('appliances').doc(applianceId).update({'last_live_calc_timestamp': currentTime});
      }
    } else {
       if(status == 'ON') { 
         await _firestore.collection('users').doc(userId).collection('appliances').doc(applianceId).update({'last_live_calc_timestamp': currentTime});
       }
    }
    return null;
  }

  Future<Set<DateTime>> _updateLiveUsageForAllAppliances({
    required String userId,
    required double kwhrRate,
    required DateTime currentTime,
  }) async {
    QuerySnapshot appliancesSnap = await _firestore.collection('users').doc(userId).collection('appliances').get();
    Set<DateTime> updatedDates = {};
    for (QueryDocumentSnapshot applianceDocSnap in appliancesSnap.docs) {
      Map<String, dynamic> applianceData = applianceDocSnap.data() as Map<String, dynamic>;
      if (applianceData['applianceStatus'] == 'ON') {
        DateTime? updatedDate = await calculateAndUpdateInterimUsage(
          userId: userId, applianceId: applianceDocSnap.id, applianceData: applianceData, 
          kwhrRate: kwhrRate, currentTime: currentTime,
        );
        if (updatedDate != null) updatedDates.add(updatedDate);
      }
    }
    print("[UsageService REFRESH_ALL] Interim usage calculation complete. Impacted daily doc dates: $updatedDates");
    return updatedDates;
  }
  
  void startLiveUsageUpdates({required String userId, required double kwhrRate}) {
    _liveUpdateTimer?.cancel();
    _liveUpdateTimer = Timer.periodic(const Duration(minutes: 1), (timer) async { 
      DateTime now = DateTime.now();
      await _updateLiveUsageForAllAppliances(userId: userId, kwhrRate: kwhrRate, currentTime: now);
      QuerySnapshot appliancesSnap = await _firestore.collection('users').doc(userId).collection('appliances').get();
      for (var appDoc in appliancesSnap.docs) {
        await _triggerAggregationsForAppliance(userId, appDoc.id, kwhrRate, now);
      }
      await updateAllAppliancesTotalUsage(userId: userId, kwhrRate: kwhrRate, referenceDate: now);
    });
    print("UsageService: Timer-based live updates started.");
  }

  void stopLiveUsageUpdates() {
    _liveUpdateTimer?.cancel();
    print("UsageService: Live usage updates stopped.");
  }

  Future<void> _triggerAggregationsForAppliance(String userId, String applianceId, double kwhrRate, DateTime referenceDate) async {
    print("AGGREGATE: For $applianceId on $referenceDate");
    await _aggregateDailyToWeekly(userId, applianceId, kwhrRate, referenceDate);
    await _aggregateWeeklyToMonthly(userId, applianceId, kwhrRate, referenceDate);
    await _aggregateMonthlyToYearly(userId, applianceId, kwhrRate, referenceDate);
  }

  Future<void> _aggregateDailyToWeekly(String userId, String applianceId, double kwhrRate, DateTime referenceDate) async {
    String weeklyPath = _getApplianceWeeklyPath(userId, applianceId, referenceDate);
    String dailyDocsCollectionPath = '${_getApplianceWeeklyPath(userId, applianceId, referenceDate)}/day_usage'; 
     dailyDocsCollectionPath = 'users/$userId/appliances/$applianceId/yearly_usage/${referenceDate.year}/monthly_usage/${_getMonthName(referenceDate.month)}_usage/week_usage/week${_getWeekOfMonth(referenceDate)}_usage/day_usage';

    QuerySnapshot dailyDocsSnap = await _firestore.collection(dailyDocsCollectionPath).get();
    double totalKwh = 0;
    for (var doc in dailyDocsSnap.docs) {
      totalKwh += (doc.data() as Map<String, dynamic>)['kwh'] ?? 0.0;
    }
    double totalKwhCost = totalKwh * kwhrRate;
    await _firestore.doc(weeklyPath).set({'kwh': totalKwh, 'kwhrcost': totalKwhCost, 'last_updated': FieldValue.serverTimestamp(), 'rate_used_for_cost': kwhrRate,}, SetOptions(merge: true));
    print('AGGREGATE: Weekly $applianceId ($weeklyPath): $totalKwh kWh');
  }

  Future<void> _aggregateWeeklyToMonthly(String userId, String applianceId, double kwhrRate, DateTime referenceDate) async {
    String monthlyPath = _getApplianceMonthlyPath(userId, applianceId, referenceDate);
    String weeklyDocsCollectionPath = '${_getApplianceMonthlyPath(userId, applianceId, referenceDate)}/week_usage'; 
    weeklyDocsCollectionPath = 'users/$userId/appliances/$applianceId/yearly_usage/${referenceDate.year}/monthly_usage/${_getMonthName(referenceDate.month)}_usage/week_usage';


    QuerySnapshot weeklyDocsSnap = await _firestore.collection(weeklyDocsCollectionPath).get();
    double totalKwh = 0;
    for (var doc in weeklyDocsSnap.docs) {
      totalKwh += (doc.data() as Map<String, dynamic>)['kwh'] ?? 0.0;
    }
    double totalKwhCost = totalKwh * kwhrRate;
    await _firestore.doc(monthlyPath).set({'kwh': totalKwh, 'kwhrcost': totalKwhCost, 'last_updated': FieldValue.serverTimestamp(), 'rate_used_for_cost': kwhrRate,}, SetOptions(merge: true));
     print('AGGREGATE: Monthly $applianceId ($monthlyPath): $totalKwh kWh');
  }

  Future<void> _aggregateMonthlyToYearly(String userId, String applianceId, double kwhrRate, DateTime referenceDate) async {
    String yearlyPath = _getApplianceYearlyPath(userId, applianceId, referenceDate);
    String monthlyDocsCollectionPath = '${_getApplianceYearlyPath(userId, applianceId, referenceDate)}/monthly_usage'; 
    monthlyDocsCollectionPath = 'users/$userId/appliances/$applianceId/yearly_usage/${referenceDate.year}/monthly_usage';

    QuerySnapshot monthlyDocsSnap = await _firestore.collection(monthlyDocsCollectionPath).get();
    double totalKwh = 0;
    for (var doc in monthlyDocsSnap.docs) {
      totalKwh += (doc.data() as Map<String, dynamic>)['kwh'] ?? 0.0;
    }
    double totalKwhCost = totalKwh * kwhrRate;
    await _firestore.doc(yearlyPath).set({'kwh': totalKwh, 'kwhrcost': totalKwhCost, 'last_updated': FieldValue.serverTimestamp(), 'rate_used_for_cost': kwhrRate,}, SetOptions(merge: true));
    print('AGGREGATE: Yearly $applianceId ($yearlyPath): $totalKwh kWh');
  }

  Future<void> refreshAllUsageDataForDate({
    required String userId,
    required double kwhrRate,
    required DateTime referenceDate,
  }) async {
    print("UsageService: Full data structure refresh (aggregations only) for user $userId on $referenceDate.");
    QuerySnapshot appliancesSnap = await _firestore.collection('users').doc(userId).collection('appliances').get();
    for (var applianceDoc in appliancesSnap.docs) {
      await _triggerAggregationsForAppliance(userId, applianceDoc.id, kwhrRate, referenceDate);
    }
    await updateAllAppliancesTotalUsage(userId: userId, kwhrRate: kwhrRate, referenceDate: referenceDate);
    print("UsageService: Full data structure refresh (aggregations only) completed.");
  }

  Future<void> updateAndAggregateLiveUsage({
    required String userId,
    required double kwhrRate,
    required DateTime currentTime,
  }) async {
    print("REFRESH_FLOW: Starting updateAndAggregateLiveUsage for user $userId up to $currentTime.");
    Set<DateTime> updatedDailyDocDates = await _updateLiveUsageForAllAppliances(userId: userId, kwhrRate: kwhrRate, currentTime: currentTime);

    QuerySnapshot appliancesSnap = await _firestore.collection('users').doc(userId).collection('appliances').get();
    for (var applianceDoc in appliancesSnap.docs) {
      String applianceId = applianceDoc.id;
      for (DateTime updatedDate in updatedDailyDocDates) {
        await _triggerAggregationsForAppliance(userId, applianceId, kwhrRate, updatedDate);
      }
      if (!updatedDailyDocDates.contains(DateTime(currentTime.year, currentTime.month, currentTime.day))) {
         await _triggerAggregationsForAppliance(userId, applianceId, kwhrRate, currentTime);
      }
    }
    await updateAllAppliancesTotalUsage(userId: userId, kwhrRate: kwhrRate, referenceDate: currentTime);
    print("REFRESH_FLOW: updateAndAggregateLiveUsage completed for user $userId.");
  }
  
  Future<void> updateAllAppliancesTotalUsage({required String userId, required double kwhrRate, required DateTime referenceDate}) async {
    print("TOTALS: Updating overall usage for user $userId, ref date: $referenceDate");
    await _calculateAndStoreOverallTotalForPeriod(userId: userId, kwhrRate: kwhrRate, referenceDate: referenceDate, targetDocPath: getOverallDailyDocPath(userId, referenceDate), periodType: 'daily');
    await _calculateAndStoreOverallTotalForPeriod(userId: userId, kwhrRate: kwhrRate, referenceDate: referenceDate, targetDocPath: getOverallWeeklyDocPath(userId, referenceDate.year, referenceDate.month, _getWeekOfMonth(referenceDate)), periodType: 'weekly');
    await _calculateAndStoreOverallTotalForPeriod(userId: userId, kwhrRate: kwhrRate, referenceDate: referenceDate, targetDocPath: getOverallMonthlyDocPath(userId, referenceDate.year, referenceDate.month), periodType: 'monthly');
    await _calculateAndStoreOverallTotalForPeriod(userId: userId, kwhrRate: kwhrRate, referenceDate: referenceDate, targetDocPath: getOverallYearlyDocPath(userId, referenceDate.year), periodType: 'yearly');
  }

  Future<void> _calculateAndStoreOverallTotalForPeriod({
    required String userId,
    required double kwhrRate,
    required DateTime referenceDate,
    required String targetDocPath, 
    required String periodType 
  }) async {
    QuerySnapshot appliancesSnap = await _firestore.collection('users').doc(userId).collection('appliances').get();
    double totalKwhForAllAppliances = 0;
    for (var applianceDoc in appliancesSnap.docs) {
      String applianceId = applianceDoc.id;
      String applianceDetailedPeriodPath;
      switch (periodType) {
        case 'daily': applianceDetailedPeriodPath = _getApplianceDailyPath(userId, applianceId, referenceDate); break;
        case 'weekly': applianceDetailedPeriodPath = _getApplianceWeeklyPath(userId, applianceId, referenceDate); break;
        case 'monthly': applianceDetailedPeriodPath = _getApplianceMonthlyPath(userId, applianceId, referenceDate); break;
        case 'yearly': applianceDetailedPeriodPath = _getApplianceYearlyPath(userId, applianceId, referenceDate); break;
        default: print("Error: Unknown periodType '$periodType'"); return;
      }
      DocumentSnapshot appliancePeriodDoc = await _firestore.doc(applianceDetailedPeriodPath).get();
      if (appliancePeriodDoc.exists && appliancePeriodDoc.data() != null) {
        totalKwhForAllAppliances += (appliancePeriodDoc.data() as Map<String, dynamic>)['kwh'] ?? 0.0;
      }
    }
    double finalTotalKwhCost = totalKwhForAllAppliances * kwhrRate;
    await _firestore.doc(targetDocPath).set({'totalKwh': totalKwhForAllAppliances, 'totalKwhrCost': finalTotalKwhCost, 'last_updated': FieldValue.serverTimestamp(), 'rate_used_for_cost': kwhrRate,}, SetOptions(merge: true));
    print('TOTALS: Overall $periodType for $userId (Doc: $targetDocPath): $totalKwhForAllAppliances kWh');
  }

  Future<void> ensureUserYearlyUsageStructureExists(String userId, DateTime date) async {
    if (userId.isEmpty) return;
    final Map<String, dynamic> defaultData = {'totalKwh': 0.0, 'totalKwhrCost': 0.0, 'last_initialized': FieldValue.serverTimestamp()};
    try {
      String yearPath = getOverallYearlyDocPath(userId, date.year);
      if (!(await _firestore.doc(yearPath).get()).exists) await _firestore.doc(yearPath).set(defaultData, SetOptions(merge: true));
      String monthPath = getOverallMonthlyDocPath(userId, date.year, date.month);
      if (!(await _firestore.doc(monthPath).get()).exists) await _firestore.doc(monthPath).set(defaultData, SetOptions(merge: true));
      String weekPath = getOverallWeeklyDocPath(userId, date.year, date.month, _getWeekOfMonth(date));
      if (!(await _firestore.doc(weekPath).get()).exists) await _firestore.doc(weekPath).set(defaultData, SetOptions(merge: true));
      String dayPath = getOverallDailyDocPath(userId, date);
      if (!(await _firestore.doc(dayPath).get()).exists) await _firestore.doc(dayPath).set(defaultData, SetOptions(merge: true));
    } catch (e) {
      print('CRITICAL ERROR ensuring yearly_usage structure for $userId: $e');
    }
  }

  Future<void> createMissingSummaryDocumentWithDefaults(String docPath) async {
    try {
      await _firestore.doc(docPath).set({'totalKwh': 0.0, 'totalKwhrCost': 0.0, 'last_updated': FieldValue.serverTimestamp(), 'isInitializedByListener': true }, SetOptions(merge: true));
    } catch (e) {
      print('CRITICAL ERROR creating summary document $docPath: $e');
    }
  }

  Future<void> refreshApplianceUsage({
    required String userId,
    required String applianceId,
    required double kwhrRate,
    required double wattage, 
    required DateTime referenceDate,
  }) async {
    print("REFRESH_FLOW: Manual refresh for $applianceId, user $userId, date $referenceDate");
    DocumentSnapshot applianceSnap = await _firestore.collection('users').doc(userId).collection('appliances').doc(applianceId).get();
    DateTime? updatedDate;
    if (applianceSnap.exists && applianceSnap.data() != null) {
      Map<String, dynamic> applianceData = applianceSnap.data() as Map<String, dynamic>;
      if (applianceData['applianceStatus'] == 'ON') {
        updatedDate = await calculateAndUpdateInterimUsage(
          userId: userId, applianceId: applianceId, applianceData: applianceData, 
          kwhrRate: kwhrRate, currentTime: referenceDate,
        );
      }
    } else {
      print("REFRESH_FLOW: Appliance $applianceId not found.");
      return; 
    }
    
    if (updatedDate != null) { 
        await _triggerAggregationsForAppliance(userId, applianceId, kwhrRate, updatedDate);
    }
    await _triggerAggregationsForAppliance(userId, applianceId, kwhrRate, referenceDate);
    
    await updateAllAppliancesTotalUsage(userId: userId, kwhrRate: kwhrRate, referenceDate: referenceDate);
    print("REFRESH_FLOW: Manual refresh completed for $applianceId.");
  }
}
