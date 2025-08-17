import 'package:flutter/material.dart';
import 'package:homesync/deviceinfo.dart';
import 'package:homesync/usage.dart'; // Import UsageService directly
import 'package:homesync/welcome_screen.dart';
import 'package:weather/weather.dart';
import 'package:homesync/electricity_usage_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:homesync/notification_screen.dart';
import 'package:homesync/profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'dart:async'; // Import for StreamSubscription
import 'package:homesync/scheduling_service.dart'; // Import the new scheduling service
// Import for date formatting
// Import OverallDetailedUsageScreen

// TODO: Replace 'YOUR_API_KEY' with your actual OpenWeatherMap API key
const String _apiKey = 'YOUR_API_KEY'; // Placeholder for Weather API Key
const String _cityName = 'Manila'; // Default city for weather

class HomepageScreen extends StatefulWidget {
  const HomepageScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomepageScreen> {
  String _selectedPeriod = 'Weekly'; // State variable for selected period
  Weather? _currentWeather; // Renamed for clarity
  int _selectedIndex = 0;
  bool _isRefreshing = false; // State for refresh indicator

  double _totalUsageKwh = 0.0; // State variable for total usage
  double _totalElectricityCost = 0.0; // State variable for total cost
  double _kwhrRate = DEFAULT_KWHR_RATE; // Cached user's kWh rate

  final FirebaseAuth _auth = FirebaseAuth.instance; // FirebaseAuth instance
  StreamSubscription? _appliancesSubscription; // StreamSubscription for appliances
  StreamSubscription? _summarySubscription; // StreamSubscription for summary usage
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _appliances = []; // List to hold appliance data
  final UsageService _usageService = UsageService(); // Instantiate UsageService
  // late ApplianceSchedulingService _schedulingService; // Removed local instance variable

  // Helper method to fetch and cache the user's kWh rate
  Future<void> _fetchUserKwhrRate() async {
    final user = _auth.currentUser;
    if (user == null) {
      print("Homepage: User not authenticated. Using default kWh rate.");
      if (mounted) setState(() => _kwhrRate = DEFAULT_KWHR_RATE);
      return;
    }
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _kwhrRate = (data['kwhr'] as num?)?.toDouble() ?? DEFAULT_KWHR_RATE;
          });
        }
      } else {
         if (mounted) setState(() => _kwhrRate = DEFAULT_KWHR_RATE);
      }
    } catch (e) {
      print("Homepage: Error fetching user kWh rate: $e. Using default.");
      if (mounted) setState(() => _kwhrRate = DEFAULT_KWHR_RATE);
    }
  }

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

  // State for selected appliance REMOVED
  // String? _selectedApplianceId;
  // String _selectedApplianceName = "";
  // double _selectedApplianceKwh = 0.0;
  // double _selectedApplianceCost = 0.0;
  // bool _isFetchingApplianceData = false;
  // StreamSubscription? _selectedApplianceUsageSubscription;


  @override
  void initState() {
    super.initState();
    // Initialize the singleton ApplianceSchedulingService
    ApplianceSchedulingService.initService(
      auth: _auth,
      firestore: FirebaseFirestore.instance,
      usageService: _usageService,
    );
    // _schedulingService.initialize(); // Initialization is now handled within initService
    _initializeHomepageData();
  }

  Future<void> _fetchWeather() async {
    if (_apiKey == 'YOUR_API_KEY') {
      print("Weather API key is a placeholder. Please replace it.");
      // Optionally set a default weather or error state
      if (mounted) {
        setState(() {
          // _currentWeather = Weather({ // Example of setting a default or error weather object
          //   "weather_description": "API Key Needed",
          //   "temp": null
          // });
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
        // setState(() { _currentWeather = ... });
      }
    }
  }

  Future<void> _initializeHomepageData() async {
    await _fetchUserKwhrRate(); // Fetch and cache kwhrRate first
    _fetchWeather(); // Fetch weather data
    try {
      final user = _auth.currentUser;
      if (user != null && user.uid.isNotEmpty) {
        print("Homepage: User ${user.uid} authenticated. Ensuring yearly_usage structure exists.");
        // Ensure the yearly_usage structure exists
        await _usageService.ensureUserYearlyUsageStructureExists(user.uid, DateTime.now());
      } else {
        print("Homepage: User not authenticated or UID is empty during initState. Cannot ensure yearly_usage structure or listen to data.");
        // Handle case where user is somehow null or uid is empty
        // This might prevent listeners from being set up if user is not valid.
        if (mounted) {
          setState(() {
            _appliances = [];
            _totalUsageKwh = 0.0;
            _totalElectricityCost = 0.0;
          });
        }
        return; // Exit early if no valid user
      }
      
      // Proactively update/create all summary documents for the current reference date
      // This will ensure documents like 'week_total_summary' exist before _listenToSummaryUsage tries to read them.
      print("Homepage: Proactively updating all summary totals for user ${user.uid}.");
      // Use the cached _kwhrRate
      print("Homepage: Using cached kWh rate: $_kwhrRate for initial data refresh.");
      // Using refreshAllUsageDataForDate to ensure per-appliance data is also up-to-date before overall totals.
      await _usageService.refreshAllUsageDataForDate(
          userId: user.uid,
          kwhrRate: _kwhrRate, // Use cached rate
          referenceDate: DateTime.now()
      );

      // Now proceed with other initializations only if user is valid
      _listenToAppliances();
      _listenToSummaryUsage();
    } catch (e, s) {
      print("Homepage: CRITICAL ERROR during _initializeHomepageData: $e");
      print("Homepage: Stacktrace: $s");
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error initializing homepage data: $e. Please try restarting the app.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
      }
      // Optionally, navigate to an error screen or attempt recovery
    }
  }

  // Removed unused _parseTimeString function

  @override
  void dispose() {
    ApplianceSchedulingService.instance.dispose(); // Dispose the singleton instance
    _appliancesSubscription?.cancel(); // Cancel the appliances subscription
    _summarySubscription?.cancel(); // Cancel the summary usage subscription
    // _selectedApplianceUsageSubscription?.cancel(); // REMOVED
    super.dispose();
  }

  void _listenToAppliances() {
    _appliancesSubscription?.cancel(); // Cancel any existing subscription

    final user = _auth.currentUser;
    if (user == null) {
      print("User not authenticated. Cannot fetch appliances.");
      if (mounted) {
        setState(() {
          _appliances = [];
        });
      }
      return;
    }

    _appliancesSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('appliances')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _appliances = snapshot.docs;
          // Call sumallkwh and sumallkwhr for each appliance and period
          _updateAllUsageTotals();
        });
      }
    }, onError: (error) {
      print("Error listening to appliances: $error");
      if (mounted) {
        setState(() {
          _appliances = [];
        });
      }
    });
  }

  // Function to call sumallkwh and sumallkwhr for all appliances and periods
  Future<void> _updateAllUsageTotals() async {
    // This method's original purpose (retroactive calculation and aggregation trigger)
    // is now largely handled by UsageService.
    // The homepage should primarily fetch and display data that UsageService maintains.
    // If specific on-demand aggregation is needed here, it would require a different approach
    // that queries the new data structures.
    // For now, this method can be simplified or removed if _listenToSummaryUsage
    // correctly fetches the aggregated data.
    print("INFO: _updateAllUsageTotals in homepage_screen.dart is simplified. UsageService handles ongoing calculations.");

    // We still need to ensure _listenToSummaryUsage is called to fetch the latest totals.
    _listenToSummaryUsage();
  }

  // Helper for month name (consistent with UsageService)
  String _getMonthName(int month) {
    const monthNames = [
      '', 'january', 'february', 'march', 'april', 'may', 'june',
      'july', 'august', 'september', 'october', 'november', 'december'
    ];
    return monthNames[month].toLowerCase();
  }

  // Helper for week of month (consistent with UsageService)
  int _getWeekOfMonth(DateTime date) {
    if (date.day <= 7) return 1;
    if (date.day <= 14) return 2;
    if (date.day <= 21) return 3;
    if (date.day <= 28) return 4;
    return 5;
  }

  // Function to listen to total usage and cost for the selected period
  void _listenToSummaryUsage() {
    _summarySubscription?.cancel(); // Cancel any existing subscription

    final user = _auth.currentUser;
    if (user == null) {
      print("User not authenticated. Cannot listen to summary usage.");
      if (mounted) {
        setState(() {
          _totalUsageKwh = 0.0;
          _totalElectricityCost = 0.0;
        });
      }
      return;
    }

    String targetDocPath; // This will be the full path to the specific document to listen to.

    // Instantiate UsageService to access its path helpers if they are not static
    // (they are instance methods in the provided usage.dart)
    // UsageService usageService = UsageService(); // _usageService is already a member

    DateTime now = DateTime.now(); // For daily path

    switch (_selectedPeriod) {
      case 'Daily':
        // To access instance methods like getOverallDailyDocPath, we need an instance.
        // Assuming _usageService is accessible here.
        targetDocPath = _usageService.getOverallDailyDocPath(user.uid, now);
        break;
      case 'Weekly':
        targetDocPath = _usageService.getOverallWeeklyDocPath(user.uid, now.year, now.month, _getWeekOfMonth(now));
        break;
      case 'Monthly':
        targetDocPath = _usageService.getOverallMonthlyDocPath(user.uid, now.year, now.month);
        break;
      case 'Yearly':
        targetDocPath = _usageService.getOverallYearlyDocPath(user.uid, now.year);
        break;
      default:
        print("Warning: Unknown period '$_selectedPeriod', defaulting to weekly summary path.");
        targetDocPath = _usageService.getOverallWeeklyDocPath(user.uid, now.year, now.month, _getWeekOfMonth(now));
    }

    print("Listening to summary usage document: $targetDocPath for period: $_selectedPeriod");

    _summarySubscription = FirebaseFirestore.instance
        .doc(targetDocPath) // Listen to the specific document
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        double newTotalKwh = 0.0;
        double newTotalCost = 0.0;

        print("Homepage: _listenToSummaryUsage received snapshot for $targetDocPath. Exists: ${snapshot.exists}");

        if (snapshot.exists && snapshot.data() != null) {
          final Map<String, dynamic> summaryDocumentData = snapshot.data()!;
          print("Homepage: Data from snapshot for $targetDocPath: $summaryDocumentData");
          newTotalKwh = (summaryDocumentData['totalKwh'] as num?)?.toDouble() ?? 0.0;
          newTotalCost = (summaryDocumentData['totalKwhrCost'] as num?)?.toDouble() ?? 0.0;
        } else {
          print("Homepage: Summary document not found at path: $targetDocPath for period $_selectedPeriod. Attempting to create with defaults.");
          // If document not found, create it with defaults.
          // This is an async call, but we won't await it here to avoid holding up the stream listener.
          // The next snapshot from the stream should then pick up the newly created document.
          _usageService.createMissingSummaryDocumentWithDefaults(targetDocPath);
          // Values will remain 0.0 for this snapshot, will update on next snapshot if creation is successful.
        }
        
        print("Homepage: Setting state: _totalUsageKwh = $newTotalKwh, _totalElectricityCost = $newTotalCost for period $_selectedPeriod");
        setState(() {
          _totalUsageKwh = newTotalKwh;
          _totalElectricityCost = newTotalCost;
        });
      }
    }, onError: (error) {
      print("Homepage: Error listening to summary usage document $targetDocPath for period $_selectedPeriod: $error");
      if (mounted) {
        setState(() {
          _totalUsageKwh = 0.0;
          _totalElectricityCost = 0.0;
        });
      }
    });
  }

  // Function to fetch usage for a selected appliance REMOVED
  // Future<void> _fetchSelectedApplianceUsage() async { ... }


  @override // whole frame
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Scaffold(
       backgroundColor: const Color(0xFFE9E7E6),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [

///////////////////////////////////////////////////////////////////////////////////////////////////



             Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector( // profile icon flyout
                    onTap: () => _showFlyout(context),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Transform.translate(
                      offset: Offset(0, 20),
                       child:  CircleAvatar(
                          backgroundColor: Colors.grey,
                          radius: 25,
                          child: Icon(Icons.home, color: Colors.black, size: 35),
                        ),
                        ),
                        SizedBox(width: 10,),
                        // UPDATED to show username instead of hardcoded 'My Home'
                        
                        Transform.translate(
                      offset: Offset(0, 20),
                       child: SizedBox(
                        width: 110,
                        child:FutureBuilder<String>( 
                          future: getCurrentUsername(),
                          builder: (context, snapshot) {
                            return Text(
                              snapshot.data ?? " ", // Display username or "My Home" as fallback
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                               maxLines: 1, // Prevents overflow to multiple lines
                              overflow: TextOverflow.ellipsis,
                            
                            );
                        
                        
                          },
                        ),
                        ),
                        ),
                    
                      ],
                    ),
                  ),
             

/////////////////////////////////////////////////////////////////////////////////////////////////////////
                 Transform.translate(
                      offset: Offset(0, 20),
                 
                 child: Container(  // weather
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
                           child:  _currentWeather == null
                                ? (_apiKey == 'YOUR_API_KEY'
                                    ? Text('Set API Key', style: GoogleFonts.inter(fontSize: 12))
                                    : Text('Loading...', style: GoogleFonts.inter(fontSize: 12)))
                                :Text(
                                    '${_currentWeather?.temperature?.celsius?.toStringAsFixed(0) ?? '--'}°C',
                                    style: GoogleFonts.inter(fontSize: 16),
                                  ),
                            ),
                          ],
                        ),
                        Transform.translate(
                      offset: Offset(40, -15),
                        child:Text( 
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
//////////////////////////////////////////////////////////////////////////////////////////////////////

              SizedBox(height: 20), // Add some spacing

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
                width: double.infinity, // Make the divider take full width
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.black38,
                ),
              ),
          
 //////////////////////////////////////////////////////////////////////////////////////////////////////////////////           
             
            Expanded( // Usage Graph
  child: SingleChildScrollView(
    child: Column(
      children: [
        // UPDATED: Moved Usage section inside the scrollable area
        Padding(
          padding: EdgeInsets.only(top: 10, bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Usage text with refresh button beside it
              Row(
                children: [
                  Text('Usage',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(width: 8),
                  _isRefreshing 
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2,))
                    : GestureDetector(
                        onTap: _handleRefresh,
                        child: Icon(Icons.refresh, color: Colors.black, size: 20),
                      ),
                ],
              ),
              
              // Period selector on the right side
              Row(
                children: [
                  Text(_selectedPeriod),
                  IconButton(
                    icon: Icon(Icons.calendar_month),
                    onPressed: () => _showPeriodPicker(),
                  ),
                ],
              ),
            ],
          ),
        ),
        Transform.translate(
                          offset: Offset(0, -10),
       child: Container( // Removed Transform.translate
            height: 300,
            width: double.infinity, // Make the graph take full width
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[350],  
              
            
            ),
            child: ElectricityUsageChart(selectedPeriod: _selectedPeriod), // Pass selectedPeriod
          ),
        ),
        _buildUsageStat(  // usage status
          'Total Electricity Usage',
          '${_totalUsageKwh.toStringAsFixed(3)} kWh', // Display calculated usage with more precision
          Icons.electric_bolt,
        ),
        _buildUsageStat(      // cost usage
          'Total Estimated Cost',
          '₱${_totalElectricityCost.toStringAsFixed(2)}', // Display calculated cost
          Icons.attach_money,
        ),

        // Conditionally display selected appliance stats REMOVED
        // if (_selectedApplianceId != null) ...[ ... ]
        // Devices List
        _buildDevicesList(),
      ],
    ),
  ),
),
            ],
          ),
        ),
      ),
    );
  }

///////////////////////////////////////////////////////////////////////////////////////////////////////////

void _showFlyout(BuildContext context) { //flyout na nakaka baliw ayusin
  final screenSize = MediaQuery.of(context).size;
  showModalBottomSheet(
     isScrollControlled: true,
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Align(
        alignment: Alignment.centerRight,
        child: Transform.translate(
          offset: Offset(-90, -0), 
          child: Container(
            width: screenSize.width * 0.75,
            height: screenSize.height -0,
            decoration: BoxDecoration(
              color: const Color(0xFF3D3D3D),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(0),
                bottomLeft: Radius.circular(0),
              ),
            ),

         
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

               SizedBox(height: 60),

                Row( //profile icon, name, and email display
                  children: [
                    Icon(Icons.home, size: 50, color: Colors.white), 
                    SizedBox(width: 10),
                    Expanded( 
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // UPDATED to use FutureBuilder for username
                          FutureBuilder<String>(
                            future: getCurrentUsername(),
                            builder: (context, snapshot) {
                              return Text(
                                snapshot.data ?? "User", // Display username or "User" as fallback
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              );
                            },
                          ),
                          Text(
                            _auth.currentUser?.email ?? "No email", // Display actual user email
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis, 
                            maxLines: 1, 
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

          SizedBox(height: 40),
          
              ListTile(
                
                leading: Icon(Icons.person, color: Colors.white,size: 35,),
                title: Text('Profile', style: GoogleFonts.inter( color: Colors.white)),
                onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileScreen()),
              );
            },
              ),  

          SizedBox(height: 15),
              ListTile(
                leading: Icon(Icons.notifications, color: Colors.white, size: 35,),
                title: Text('Notification', style: GoogleFonts.inter(color: Colors.white)),
                 onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => NotificationScreen()),
              );
            },
              ),  

              SizedBox(height: 15),
                ListTile(
              leading: Padding(
                padding: EdgeInsets.only(left: 5),
                child: Icon(Icons.logout, color: Colors.white, size: 35,),
              ),
                title: Text('Logout', style: GoogleFonts.inter(color: Colors.white)),
               onTap: () async {
                await _auth.signOut(); // Actually sign out
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

//////////////////////////////////////////////////////////////////////////////////////////////////////////

Widget _buildNavButton(String title, bool isSelected, int index) { // nav bar function
  return Column(
    children: [
      TextButton(
        onPressed: () {
          setState(() {
            _selectedIndex = index;
          });
          
          setState(() {
            _selectedIndex = index;
          });
          
          // Only navigate for 'Appliance' and 'Rooms'. 
          // 'Electricity' (index 0) will just update the selected state,
          // assuming the main content of HomepageScreen is the "Electricity" view.
          switch (index) {
            case 0:
              // Do nothing further, just update _selectedIndex to show this tab as active.
              // The content for "Electricity" is assumed to be the default view of HomepageScreen.
              break;
            case 1: // Appliance
              Navigator.pushNamed(context, '/devices');
              break;
            case 2: // Rooms
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
  offset: Offset(-0, -10),
        child:Container(
          height: 2,
          width: 70,
          color: Colors.brown,
          margin: EdgeInsets.only(top: 1),
        ),
                ),
    ],
  );
}
 /////////////////////////////////////////////////////////////////////////////////////////////////////////////// 
  
 Widget _buildUsageStat(String title, String value, IconData icon) { // usage and cost 
  return Transform.translate(
  offset: Offset(-0, 10),
    child: Row(
      children: [
        Icon(icon),
        SizedBox(width: 5,height: 40,),
        Text(title, style: GoogleFonts.judson(color: Colors.black,fontSize: 16)),
        Spacer(),
        Text(value, style: TextStyle(color: Colors.black,fontWeight: FontWeight.bold,fontSize: 17)),
      ],
    ),
  );
}
//////////////////////////////////////////////////////////////////////////////////////////////////

  Widget _buildDevicesList() { // devices
    return 
    Transform.translate(
  offset: Offset(-0, 15),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text('Appliance',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), // UPDATED: Increased font size from 18 to 20
        ),
        _appliances.isEmpty
            ? Center(child: Text("No appliances found."))
            : ListView.builder(
                shrinkWrap: true, // Important for nested ListView
                physics: NeverScrollableScrollPhysics(), // Disable scrolling for the inner ListView
                itemCount: _appliances.length,
                itemBuilder: (context, index) {
                  final applianceDoc = _appliances[index];
                  final applianceData = applianceDoc.data();
                  final String applianceId = applianceDoc.id;
                  final String applianceName = applianceData['applianceName'] as String? ?? 'Unknown Device';
                  // We won't display usage here, it will be displayed in DeviceInfoScreen
                  // final String usage = applianceData['totalKwhr']?.toStringAsFixed(1) ?? '0.0'; // Assuming totalKwhr exists
                  final int iconCodePoint = (applianceData['icon'] is int) ? (applianceData['icon'] as int) : Icons.devices.codePoint;
                  final IconData icon = _getIconFromCodePoint(iconCodePoint);

                  return Column( // UPDATED: Wrapped in Column to add divider
                    children: [
                      _buildDeviceItem(applianceId, applianceName, '', icon), // Pass empty string for usage for now
                      if (index < _appliances.length - 1) // UPDATED: Add divider between items (except after last item)
                        Divider(
                          color: Colors.grey[400],
                          thickness: 0.5,
                          indent: 50, // Indent to align with text content
                          endIndent: 16,
                        ),
                    ],
                  );
                },
              ),
      ],
    ),
    );
  }

  /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
Widget _buildDeviceItem(String id, String name, String usage, IconData icon) { // device settings // Added id parameter
  // bool isSelected = _selectedApplianceId == id; // REMOVED
  return GestureDetector(
    onTap: () {
      // Reverted to original navigation logic
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => DeviceInfoScreen( 
          applianceId: id, 
          initialDeviceName: name,
          schedulingService: ApplianceSchedulingService.instance, // Pass the singleton instance
          // initialDeviceUsage: usage, // Usage will be fetched from Firestore by DeviceInfoScreen
        )),
      );
    },
      child: Padding( // Reverted from Container to Padding
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 10), // UPDATED: Increased vertical padding from 10 to 12
        child: Row(
          children: [
            Icon(icon, size: 35), // UPDATED: Increased icon size from default (~24) to 35
            SizedBox(width: 12), // UPDATED: Increased spacing from 8 to 12
            Text(name, style: GoogleFonts.judson(color: Colors.black, fontSize: 18)), // UPDATED: Increased font size from 16 to 18
            Spacer(),
            Text(usage, style: GoogleFonts.jaldi(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20)), // UPDATED: Increased font size from 18 to 20
            SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  // calendar picker function
  void _showPeriodPicker() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white, 
      title: Text('Select Period',
      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            tileColor: Colors.white, 
            title: Text('Monthly'),
            onTap: () {
              setState(() {
                _selectedPeriod = 'Monthly';
              });
              _listenToSummaryUsage();
              // if (_selectedApplianceId != null) { // REMOVED
              //   _fetchSelectedApplianceUsage();
              // }
              Navigator.pop(context); // Close the dialog
            },
          ),
          ListTile(
            tileColor: Colors.white,
            title: Text('Weekly'),
            onTap: () {
              setState(() {
                _selectedPeriod = 'Weekly';
              });
              _listenToSummaryUsage();
              // if (_selectedApplianceId != null) { // REMOVED
              //  _fetchSelectedApplianceUsage();
              // }
              Navigator.pop(context); // Close the dialog
            },
          ),
          ListTile(
            tileColor: Colors.white,
            title: Text('Yearly'),
            onTap: () {
              setState(() {
                _selectedPeriod = 'Yearly';
              });
              _listenToSummaryUsage();
              // if (_selectedApplianceId != null) { // REMOVED
              //   _fetchSelectedApplianceUsage();
              // }
              Navigator.pop(context); // Close the dialog
            },
          ),
           ListTile(
            tileColor: Colors.white,
            title: Text('Daily'),
            onTap: () {
              setState(() {
                _selectedPeriod = 'Daily';
              });
              _listenToSummaryUsage();
              //  if (_selectedApplianceId != null) { // REMOVED
              //   _fetchSelectedApplianceUsage();
              // }
              Navigator.pop(context); // Close the dialog
            },
          ),
        ],
      ),
    ),
  );
}

  Future<void> _handleRefresh() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User not authenticated. Cannot refresh.')),
      );
      return;
    }
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      print("Homepage: Manual refresh initiated by user ${user.uid}.");
      DateTime refreshTimestamp = DateTime.now();
      print("Homepage: Using cached kWh rate: $_kwhrRate for manual refresh for all appliances.");

      if (_appliances.isEmpty) {
        print("Homepage: No appliances to refresh individually. Triggering general aggregation.");
        // If no appliances, still good to ensure overall totals are processed for the current time.
        // This might call updateAllAppliancesTotalUsage which is also called by handleManualRefreshForAppliance.
        // Consider if a lighter aggregation is needed or if this is fine.
        // For now, let's use refreshAllUsageDataForDate which focuses on aggregations.
        await _usageService.refreshAllUsageDataForDate(
          userId: user.uid,
          kwhrRate: _kwhrRate,
          referenceDate: refreshTimestamp
        );
      } else {
        for (var applianceDoc in _appliances) {
          final String applianceId = applianceDoc.id;
          print("Homepage: Refreshing appliance $applianceId using handleManualRefreshForAppliance.");
          // Note: handleManualRefreshForAppliance itself calls aggregation functions.
          // This means aggregations will run for each appliance.
          await _usageService.handleManualRefreshForAppliance(
            userId: user.uid,
            applianceId: applianceId,
            kwhrRate: _kwhrRate,
            refreshTime: refreshTimestamp,
          );
        }
      }

      // After all individual refreshes (which include their own aggregations),
      // ensure listeners are updated.
      _listenToSummaryUsage(); // Re-listen to ensure UI updates with latest overall totals
      _listenToAppliances();   // Re-listen to ensure appliance list is fresh (if it could change)
      _fetchWeather(); // Fetch the latest weather data

      if (!mounted) return; // Check if the widget is still in the tree
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Usage data refreshed!')),
      );
    } catch (e, s) {
      print("Homepage: Error during manual refresh: $e");
      print("Homepage: Stacktrace: $s");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error refreshing data: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }
}
 main

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
 wout_notif
