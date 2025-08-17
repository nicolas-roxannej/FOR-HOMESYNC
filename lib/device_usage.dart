import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class DeviceUsage extends StatefulWidget {
  final String userId;
  final String applianceId;

  const DeviceUsage({
    super.key,
    required this.userId,
    required this.applianceId,
  });

  @override
  State<DeviceUsage> createState() => DeviceUsageState();
}

class DeviceUsageState extends State<DeviceUsage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); 
  }

  Widget usageTile(String leading, String title, String usage, String cost, {bool showCircle = true, Widget? customTitle}) {
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
         BoxShadow( 
        color: Colors.grey.withOpacity(0.5),
        spreadRadius: 1,
        blurRadius: 5,
        offset: Offset(0, 3),
        
         ),
        ],
      ),

      child: Row(
        children: [
          if (showCircle) 
            Container(
              width: 44, 
              height: 45, 
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue[300],
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 2,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              
              child: Center(
               child:  Transform.translate( 
                        offset: Offset(1, 2),
                child: Text(
                  leading,
                  style: GoogleFonts.jaldi(
                    color: Colors.white,
                    fontSize: 25,
                    
                  ),
                ),
              ),
            ),
            ),
                           
          if (showCircle) const SizedBox(width: 10), 
                
          // Use Expanded with flex to prevent overflow
          Expanded(
            flex: 3,
            child: customTitle ?? Text(
              title,  
              style: GoogleFonts.jaldi(fontSize: 20, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            )
          ),

          const SizedBox(width: 8),

          // Constrain usage container
          Flexible(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[300], 
                borderRadius: BorderRadius.circular(20), 
                border: Border.all()
              ),
              child: Text(
                usage,  
                style: GoogleFonts.jaldi(fontSize: 15),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ), 
            ),
          ),

          const SizedBox(width: 8),
          
          // Constrain cost container
          Flexible(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green[100], 
                borderRadius: BorderRadius.circular(8),
                border: Border.all()
              ),
              child: Text(
                cost,  
                style: TextStyle(fontSize: 15),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ), 
            ),
          ),
        ],
      ),
    );
  }

  // Helper for month name (consistent with UsageService and DeviceInfoScreen)
  String _getMonthNameHelper(int month) {
    const monthNames = [
      '', 'january', 'february', 'march', 'april', 'may', 'jun', // Corrected "june" to "jun"
      'july', 'august', 'september', 'october', 'november', 'december'
    ];
    return monthNames[month].toLowerCase();
  }

  // Helper to get week of month (1-5) for a given date
  // Week 1: days 1-7, Week 2: days 8-14, ..., Week 5: days 29-31
  int getWeekOfMonth(DateTime date) {
    return ((date.day - 1) ~/ 7) + 1;
  }

  Widget buildYearlyUsage() {
    final String currentYear = DateTime.now().year.toString();
    final String path = '/users/${widget.userId}/appliances/${widget.applianceId}/yearly_usage/$currentYear';

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.doc(path).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error fetching yearly data: ${snapshot.error}'));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Center(child: Text('No usage data for $currentYear.'));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final kwhRaw = data['kwh'];
        final kwhrcostRaw = data['kwhrcost'];

        String kwhDisplay;
        if (kwhRaw is num) {
          kwhDisplay = (kwhRaw).toDouble().toStringAsFixed(2);
        } else {
          kwhDisplay = 'N/A';
        }

        String kwhrcostDisplay;
        if (kwhrcostRaw is num) {
          kwhrcostDisplay = '₱${(kwhrcostRaw).toDouble().toStringAsFixed(2)}';
        } else {
          kwhrcostDisplay = 'N/A';
        }

        // Yearly display: "{year}" '{kwh specific value in that year}' '{kwhrcost specific value in that year}'
        return ListView(
          children: [
            usageTile(
              '', // leading is not used for yearly as showCircle is false
              currentYear, // title: {year}
              kwhDisplay, // usage
              kwhrcostDisplay, // cost
              showCircle: false,
            ),
          ],
        );
      },
    );
  }

  Widget buildMonthlyUsage() {
    final String currentYear = DateTime.now().year.toString();
    // Use numbers 1-12 for months and format with _getMonthNameHelper
    final List<int> monthNumbers = List.generate(12, (index) => index + 1);

    return ListView.builder(
      itemCount: monthNumbers.length, // Iterate 12 times
      itemBuilder: (context, i) { // Use 'i' for the direct loop index 0..11
        // To get reverse chronological order (Dec, Nov, ... Jan)
        final int reversedMonthIndex = monthNumbers.length - 1 - i; // 11, 10, ..., 0
        final int monthNumber = monthNumbers[reversedMonthIndex]; // 12, 11, ...
        final String monthNameForDisplay = DateFormat.MMMM().format(DateTime(DateTime.now().year, monthNumber)); // For display "December"
        final String monthNameForPath = _getMonthNameHelper(monthNumber); // For path "dec" or "jun"
        
        final String monthDocId = "${monthNameForPath}_usage"; // e.g., "dec_usage", "jun_usage"
        final String path = '/users/${widget.userId}/appliances/${widget.applianceId}/yearly_usage/$currentYear/monthly_usage/$monthDocId';

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.doc(path).get(),
          builder: (context, snapshot) {
            String displayKwh = 'Loading...';
            String displayCost = 'Loading...';

            if (snapshot.connectionState == ConnectionState.done) {
              if (snapshot.hasError || !snapshot.data!.exists) {
                displayKwh = 'N/A';
                displayCost = 'N/A';
              } else {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                final kwhRaw = data['kwh'];
                final kwhrcostRaw = data['kwhrcost'];

                if (kwhRaw is num) {
                  displayKwh = (kwhRaw).toDouble().toStringAsFixed(2);
                } else {
                  displayKwh = 'N/A';
                }

                if (kwhrcostRaw is num) {
                  displayCost = '₱${(kwhrcostRaw).toDouble().toStringAsFixed(2)}';
                } else {
                  displayCost = 'N/A';
                }
              }
            }
            
            return usageTile(
              monthNumber.toString(), 
              monthNameForDisplay, // Display full month name
              displayKwh,
              displayCost,
            );
          },
        );
      },
    );
  }

  Widget buildWeeklyUsage() {
    final DateTime now = DateTime.now();
    final String currentYear = now.year.toString();
    List<Widget> weeklyWidgets = [];

    // Display weeks for the current month and the previous month
    for (int monthOffset = 0; monthOffset < 2; monthOffset++) { 
      DateTime monthToDisplay = DateTime(now.year, now.month - monthOffset, 1);
      String monthNameForDisplay = DateFormat.MMMM().format(monthToDisplay); // For display "June"
      String monthNameForPath = _getMonthNameHelper(monthToDisplay.month); // For path "jun"
      String monthDocId = "${monthNameForPath}_usage";

      weeklyWidgets.add(
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(
            monthNameForDisplay, // Month Name Header (e.g., "June")
            style: GoogleFonts.jaldi(
              fontSize: 25,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ),
      );

      // Iterate 5 weeks for the month, in reverse order (Week 5, 4, 3, 2, 1)
      for (int weekNumberInMonth = 5; weekNumberInMonth >= 1; weekNumberInMonth--) {
        final String weekDocId = "week${weekNumberInMonth}_usage";
        final String path = '/users/${widget.userId}/appliances/${widget.applianceId}/yearly_usage/$currentYear/monthly_usage/$monthDocId/week_usage/$weekDocId';
        
        String weekTitle = "Week $weekNumberInMonth";

        weeklyWidgets.add(
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.doc(path).get(),
            builder: (context, snapshot) {
              String displayKwh = 'Loading...';
              String displayCost = 'Loading...';

              if (snapshot.connectionState == ConnectionState.done) {
                if (snapshot.hasError || !snapshot.data!.exists) {
                  displayKwh = 'N/A';
                  displayCost = 'N/A';
                } else {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  final kwhRaw = data['kwh'];
                  final kwhrcostRaw = data['kwhrcost'];

                  if (kwhRaw is num) {
                    displayKwh = (kwhRaw).toDouble().toStringAsFixed(2);
                  } else {
                    displayKwh = 'N/A';
                  }

                  if (kwhrcostRaw is num) {
                    displayCost = '₱${(kwhrcostRaw).toDouble().toStringAsFixed(2)}';
                  } else {
                    displayCost = 'N/A';
                  }
                }
              }
              return usageTile(
                weekNumberInMonth.toString(), 
                weekTitle, 
                displayKwh,
                displayCost,
              );
            },
          )
        );
      }
      if (monthOffset < 1) { // Add divider if not the last month group
         weeklyWidgets.add(const SizedBox(height: 20));
         weeklyWidgets.add(const Divider(thickness: 1.5));
      }
    }
    return ListView(children: weeklyWidgets);
  }

  Widget buildDailyUsage() {
    List<Widget> dailyWidgets = [];
    DateTime today = DateTime.now();

    // Display usage for the last 14 days
    for (int i = 0; i < 14; i++) {
      DateTime dateToDisplay = today.subtract(Duration(days: i));
      
      String year = dateToDisplay.year.toString();
      String monthNameForPath = _getMonthNameHelper(dateToDisplay.month); // For path "jun"
      String monthDocId = "${monthNameForPath}_usage";
      
      int weekOfMonthNumber = getWeekOfMonth(dateToDisplay); // Helper method
      String weekDocId = "week${weekOfMonthNumber}_usage";
      
      String dayDocId = DateFormat('yyyy-MM-dd').format(dateToDisplay); // Format YYYY-MM-DD

      final String path = '/users/${widget.userId}/appliances/${widget.applianceId}/yearly_usage/$year/monthly_usage/$monthDocId/week_usage/$weekDocId/day_usage/$dayDocId';

      // Daily display: "number of day" "Month date" on first line, "name of the day" on second line
      String leadingText = dateToDisplay.day.toString(); // "number of day"
      String monthDateText = DateFormat('MMMM d').format(dateToDisplay); // "Month date"
      String dayNameText = DateFormat('EEEE').format(dateToDisplay); // "name of the day"

      // Create custom title widget with month/date and day name stacked
      Widget customTitleWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            monthDateText,
            style: GoogleFonts.jaldi(fontSize: 18, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            dayNameText,
            style: GoogleFonts.jaldi(fontSize: 14, fontWeight: FontWeight.w400, color: Colors.grey[600]),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );

      dailyWidgets.add(
        FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.doc(path).get(),
          builder: (context, snapshot) {
            String displayKwh = 'Loading...';
            String displayCost = 'Loading...';

            if (snapshot.connectionState == ConnectionState.done) {
              if (snapshot.hasError || !snapshot.data!.exists) {
                displayKwh = 'N/A';
                displayCost = 'N/A';
              } else {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                final kwhRaw = data['kwh'];
                final kwhrcostRaw = data['kwhrcost'];

                if (kwhRaw is num) {
                  displayKwh = (kwhRaw).toDouble().toStringAsFixed(2);
                } else {
                  displayKwh = 'N/A';
                }

                if (kwhrcostRaw is num) {
                  displayCost = '₱${(kwhrcostRaw).toDouble().toStringAsFixed(2)}';
                } else {
                  displayCost = 'N/A';
                }
              }
            }
            return usageTile(
              leadingText,
              '', // Empty string since we're using customTitle
              displayKwh,
              displayCost,
              customTitle: customTitleWidget,
            );
          },
        )
      );
    }
    return ListView(children: dailyWidgets);
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFFE9E7E6),
    body: SafeArea(
      child: Column(
        children: [
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, size: 50, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
                Text(
                  _tabController.index == 0
                      ? 'Yearly Usage'
                      : _tabController.index == 1
                          ? 'Monthly Usage'
                          : _tabController.index == 2
                              ? 'Weekly Usage'
                              : 'Daily Usage',
                  style: GoogleFonts.jaldi(
                    textStyle: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.brown,
             labelStyle: GoogleFonts.jaldi(
    fontSize: 18,
    fontWeight: FontWeight.bold,
             ),
            onTap: (_) => setState(() {}),
            tabs: const [
              Tab(text: 'Yearly'),
              Tab(text: 'Monthly'),
              Tab(text: 'Weekly'),
              Tab(text: 'Daily'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                buildYearlyUsage(),
                buildMonthlyUsage(),
                buildWeeklyUsage(),
                buildDailyUsage(),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
}
