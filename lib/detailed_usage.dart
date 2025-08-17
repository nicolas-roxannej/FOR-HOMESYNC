import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Import UsageTracker
import 'package:intl/intl.dart'; // Import for date formatting
// Import for StringExtension

class OverallDetailedUsageScreen extends StatefulWidget {
  final String selectedPeriod; // e.g., 'daily', 'weekly', 'monthly', 'yearly'

  const OverallDetailedUsageScreen({
    super.key,
    required this.selectedPeriod,
  });

  @override
  _OverallDetailedUsageScreenState createState() => _OverallDetailedUsageScreenState();
}

class _OverallDetailedUsageScreenState extends State<OverallDetailedUsageScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late Future<List<Map<String, dynamic>>> _overallUsageRecordsFuture;

  @override
  void initState() {
    super.initState();
    _overallUsageRecordsFuture = _fetchOverallUsageRecords();
  }

  Future<List<Map<String, dynamic>>> _fetchOverallUsageRecords() async {
    final user = _auth.currentUser;
    if (user == null) {
      print("User not authenticated. Cannot fetch usage data.");
      return [];
    }

    List<Map<String, dynamic>> overallUsageRecords = [];

    try {
      if (widget.selectedPeriod == 'daily') {
        // Fetch daily summary data for a range of days
        final now = DateTime.now();
        // Fetch data for the last 30 days for daily view
        final startDate = now.subtract(Duration(days: 30));
        final endDate = now;

        // Iterate through days and fetch daily summary for each
        for (int i = 0; i <= endDate.difference(startDate).inDays; i++) {
          final currentDate = startDate.add(Duration(days: i));
          final year = currentDate.year.toString();
          final month = currentDate.month;
          final day = currentDate.day;
          final dateString = "$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}";

          final summaryDocPath = 'users/${user.uid}/summary_usage/day_summary/$dateString';
          final summaryDoc = await FirebaseFirestore.instance.doc(summaryDocPath).get();

          if (summaryDoc.exists && summaryDoc.data() != null) {
            final summaryData = summaryDoc.data()!;
            overallUsageRecords.add({
              'period': dateString, // Use date string as period identifier
              'kwh': (summaryData['totalKwh'] is num) ? (summaryData['totalKwh'] as num).toDouble() : 0.0,
              'kwhcost': (summaryData['totalKwhrCost'] is num) ? (summaryData['totalKwhrCost'] as num).toDouble() : 0.0,
            });
          }
        }
         // Sort daily records by date
        overallUsageRecords.sort((a, b) => a['period'].compareTo(b['period']));

      } else if (widget.selectedPeriod == 'weekly') {
        // Fetch weekly summary data
        final summaryDocPath = 'users/${user.uid}/summary_usage/weekly_summary';
        final summaryDoc = await FirebaseFirestore.instance.doc(summaryDocPath).get();

        if (summaryDoc.exists && summaryDoc.data() != null) {
          final summaryData = summaryDoc.data()!;
          // Assuming weekly summary data is stored as a map where keys are week identifiers
          // and values are maps containing 'totalKwh' and 'totalKwhrCost'.
          // This part needs to be adjusted based on the actual Firestore structure for weekly summaries.
          // For now, let's assume the weekly summary document directly contains the total for the current week.
          // If you need historical weekly data, the Firestore structure needs to support it (e.g., subcollection of weeks).
          // Based on the sumallkwh/sumallkwhr, the weekly summary is a single document.
           overallUsageRecords.add({
              'period': 'Current Week', // Placeholder period identifier
              'kwh': (summaryData['totalKwh'] is num) ? (summaryData['totalKwh'] as num).toDouble() : 0.0,
              'kwhcost': (summaryData['totalKwhrCost'] is num) ? (summaryData['totalKwhrCost'] as num).toDouble() : 0.0,
           });
        }


      } else if (widget.selectedPeriod == 'monthly') {
        // Fetch monthly summary data
        final summaryDocPath = 'users/${user.uid}/summary_usage/monthly_summary';
        final summaryDoc = await FirebaseFirestore.instance.doc(summaryDocPath).get();

        if (summaryDoc.exists && summaryDoc.data() != null) {
          final summaryData = summaryDoc.data()!;
           overallUsageRecords.add({
              'period': 'Current Month', // Placeholder period identifier
              'kwh': (summaryData['totalKwh'] is num) ? (summaryData['totalKwh'] as num).toDouble() : 0.0,
              'kwhcost': (summaryData['totalKwhrCost'] is num) ? (summaryData['totalKwhrCost'] as num).toDouble() : 0.0,
           });
        }


      } else if (widget.selectedPeriod == 'yearly') {
        // Fetch yearly summary data
        final summaryDocPath = 'users/${user.uid}/summary_usage/yearly_summary';
        final summaryDoc = await FirebaseFirestore.instance.doc(summaryDocPath).get();

        if (summaryDoc.exists && summaryDoc.data() != null) {
          final summaryData = summaryDoc.data()!;
           overallUsageRecords.add({
              'period': 'Current Year', // Placeholder period identifier
              'kwh': (summaryData['totalKwh'] is num) ? (summaryData['totalKwh'] as num).toDouble() : 0.0,
              'kwhcost': (summaryData['totalKwhrCost'] is num) ? (summaryData['totalKwhrCost'] as num).toDouble() : 0.0,
           });
        }

      } else {
        print('Invalid period specified for fetching overall usage records: ${widget.selectedPeriod}');
        return [];
      }

    } catch (e) {
      print('Error fetching overall usage records: $e');
      return [];
    }

    return overallUsageRecords;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.selectedPeriod.isNotEmpty ? widget.selectedPeriod[0].toUpperCase() + widget.selectedPeriod.substring(1) : ''} Usage'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _overallUsageRecordsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error loading usage data: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No usage data available for ${widget.selectedPeriod}.'));
          } else {
            final usageRecords = snapshot.data!;

            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: usageRecords.length,
              itemBuilder: (context, index) {
                final record = usageRecords[index];
                final periodIdentifier = record['period'] as String;
                final kwh = record['kwh'] ?? 0.0;
                final kwhcost = record['kwhcost'] ?? 0.0;

                // Determine how to display the period based on the selectedPeriod
                Widget periodWidget;
                if (widget.selectedPeriod == 'daily') {
                  final date = DateTime.parse(periodIdentifier);
                  final dayOfMonth = date.day;
                  final monthAndDayOfWeek = DateFormat('MMM, EEEE').format(date);
                   periodWidget = _buildPeriodItem(
                     mainText: dayOfMonth.toString(),
                     subText: monthAndDayOfWeek,
                     color: Colors.blue,
                   );
                } else if (widget.selectedPeriod == 'weekly') {
                   // Assuming periodIdentifier is like 'month-weekNumber' e.g., '5-week3'
                   final parts = periodIdentifier.split('-');
                   final month = int.parse(parts[0]);
                   final weekNumber = parts[1].replaceAll('week', '');
                   final monthName = DateFormat('MMMM').format(DateTime(DateTime.now().year, month));
                    periodWidget = _buildPeriodItem(
                      mainText: weekNumber,
                      subText: '$monthName Week',
                      color: Colors.blue,
                    );
                } else if (widget.selectedPeriod == 'monthly') {
                   // Assuming periodIdentifier is like 'year-month' e.g., '2023-10'
                   final parts = periodIdentifier.split('-');
                   final year = parts[0];
                   final month = int.parse(parts[1]);
                   final monthName = DateFormat('MMMM').format(DateTime(int.parse(year), month));
                    periodWidget = _buildPeriodItem(
                      mainText: month.toString(),
                      subText: monthName,
                      color: Colors.blue,
                    );
                } else if (widget.selectedPeriod == 'yearly') {
                   // Assuming periodIdentifier is the year string e.g., '2023'
                    periodWidget = _buildPeriodItem(
                      mainText: periodIdentifier,
                      subText: 'Year',
                      color: Colors.blue,
                    );
                } else {
                  periodWidget = SizedBox.shrink(); // Should not happen with valid periods
                }


                return _buildUsageItem(
                  periodWidget: periodWidget,
                  kwh: kwh,
                  cost: kwhcost,
                );
              },
            );
          }
        },
      ),
    );
  }

  Widget _buildPeriodItem({
    required String mainText,
    required String subText,
    required Color color,
  }) {
    return Container(
      width: 60, // Adjusted width
      height: 60, // Adjusted height
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            mainText,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20, // Adjusted font size
              fontWeight: FontWeight.bold,
            ),
          ),
           Text(
            subText,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10, // Adjusted font size
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildUsageItem({
    required Widget periodWidget,
    required double kwh,
    required double cost,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        children: [
          // Period Item (Day, Week, Month, Year)
          periodWidget,
          SizedBox(width: 12.0),
          // Period Name (e.g., May, Monday, Week, December, 2025) - This is now part of periodWidget
          Expanded(
            child: SizedBox.shrink(), // Empty expanded widget to push the usage stats to the right
          ),
          SizedBox(width: 12.0),
          // kWh Usage
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: Colors.yellow[600],
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  kwh.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'kWh',
                  style: TextStyle(
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.0),
          // Cost
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: Colors.green[600],
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '₱${cost.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Cost', // Changed from 'kWh Cost' to 'Cost' to match design
                  style: TextStyle(
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
