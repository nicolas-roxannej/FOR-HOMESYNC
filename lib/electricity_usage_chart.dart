import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ChartDataPoint {
  final String xLabel;
  final double kwh;
  final double cost;
  final int xIndex;

  ChartDataPoint({required this.xIndex, required this.xLabel, required this.kwh, required this.cost});
}

class ElectricityUsageChart extends StatefulWidget {
  final String selectedPeriod; // "Daily", "Weekly", "Monthly", "Yearly"
  // final String userId; // Passed from homepage

  const ElectricityUsageChart({
    super.key, 
    required this.selectedPeriod,
    // required this.userId, // userId will be fetched from FirebaseAuth
  });

  @override
  State<ElectricityUsageChart> createState() => _ElectricityUsageChartState();
}

class _ElectricityUsageChartState extends State<ElectricityUsageChart> {
  bool _isLoading = true;
  String _displayMode = 'kWh'; // 'kWh' or 'cost'
  List<ChartDataPoint> _chartDataPoints = [];
  double _maxY = 10.0; // Default, will adjust
  String _chartTitle = '';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _fetchChartData();
  }

  @override
  void didUpdateWidget(covariant ElectricityUsageChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedPeriod != oldWidget.selectedPeriod) {
      _fetchChartData();
    }
  }

  // Helper to get month name, week of month (can be moved to a utility file)
  String _getMonthName(int month) {
    const monthNames = ['', 'january', 'february', 'march', 'april', 'may', 'jun', 'july', 'august', 'september', 'october', 'november', 'december']; // "june" changed to "jun"
    return monthNames[month].toLowerCase();
  }

  int _getWeekOfMonth(DateTime date) {
    if (date.day <= 7) return 1;
    if (date.day <= 14) return 2;
    if (date.day <= 21) return 3;
    if (date.day <= 28) return 4;
    return 5; 
  }

  Future<List<String>> _getApplianceIds(String userId) async {
    final snapshot = await _firestore.collection('users').doc(userId).collection('appliances').get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  Future<void> _fetchChartData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _chartDataPoints = []; // Clear previous data
    });

    final User? user = _auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    final userId = user.uid;
    final now = DateTime.now();
    List<ChartDataPoint> newPoints = [];

    // IMPORTANT: This client-side aggregation can be read-intensive for many appliances.
    // A more optimized solution would involve backend aggregation into time-series collections.
    List<String> applianceIds = await _getApplianceIds(userId);
    if (!mounted) return;

    try {
      switch (widget.selectedPeriod) {
        case 'Daily': // Shows last 7 days (Sun-Sat of current week)
          _chartTitle = 'Daily Usage (Current Week)';
          DateTime firstDayOfWeek = now.subtract(Duration(days: now.weekday % 7)); // Assuming Sunday is 0 or 7
          if (now.weekday == DateTime.sunday) { // Dart's Sunday is 7
             firstDayOfWeek = now.subtract(Duration(days: 6)); // Adjust if Sunday is start
          } else {
             firstDayOfWeek = now.subtract(Duration(days: now.weekday - DateTime.monday));
          }


          for (int i = 0; i < 7; i++) {
            DateTime dayToFetch = firstDayOfWeek.add(Duration(days: i));
            String dayLabel = DateFormat('EEE').format(dayToFetch); // Mon, Tue
            double dailyTotalKwh = 0;
            double dailyTotalCost = 0;

            // Parallel fetch for all appliances for this specific day
            List<Future<DocumentSnapshot>> applianceDayFutures = applianceIds.map((applianceId) {
              String path = 'users/$userId/appliances/$applianceId/yearly_usage/${dayToFetch.year}/monthly_usage/${_getMonthName(dayToFetch.month)}_usage/week_usage/week${_getWeekOfMonth(dayToFetch)}_usage/day_usage/${DateFormat('yyyy-MM-dd').format(dayToFetch)}';
              return _firestore.doc(path).get();
            }).toList();

            List<DocumentSnapshot> applianceDaySnaps = await Future.wait(applianceDayFutures);

            for (final docSnap in applianceDaySnaps) {
              if (docSnap.exists && docSnap.data() != null) {
                final data = docSnap.data() as Map<String, dynamic>;
                dailyTotalKwh += (data['kwh'] as num?)?.toDouble() ?? 0.0;
                dailyTotalCost += (data['kwhrcost'] as num?)?.toDouble() ?? 0.0;
              }
            }
            newPoints.add(ChartDataPoint(xIndex: i, xLabel: dayLabel, kwh: dailyTotalKwh, cost: dailyTotalCost));
          }
          break;

        case 'Weekly': // Shows weeks of current month
          _chartTitle = 'Weekly Usage (Current Month)';
          int year = now.year;
          int month = now.month;
          // Calculate number of weeks in the month (approx 4 or 5)
          for (int weekNum = 1; weekNum <= 5; weekNum++) { // Max 5 weeks for simplicity
            String weekLabel = 'W$weekNum';
            double weeklyTotalKwh = 0;
            double weeklyTotalCost = 0;

            // Parallel fetch for all appliances for this specific week
            List<Future<DocumentSnapshot>> applianceWeekFutures = applianceIds.map((applianceId) {
              String path = 'users/$userId/appliances/$applianceId/yearly_usage/$year/monthly_usage/${_getMonthName(month)}_usage/week_usage/week${weekNum}_usage';
              return _firestore.doc(path).get();
            }).toList();

            List<DocumentSnapshot> applianceWeekSnaps = await Future.wait(applianceWeekFutures);

            for (final docSnap in applianceWeekSnaps) {
              if (docSnap.exists && docSnap.data() != null) {
                final data = docSnap.data() as Map<String, dynamic>;
                weeklyTotalKwh += (data['kwh'] as num?)?.toDouble() ?? 0.0;
                weeklyTotalCost += (data['kwhrcost'] as num?)?.toDouble() ?? 0.0;
              }
            }

            // Only add if there's data or it's a valid week for the month
            // (crude check to avoid empty weeks at the end of short months if no data)
            bool isPotentiallyValidWeek = weekNum <= (DateUtils.getDaysInMonth(year, month) / 7.0).ceil();
            if (weeklyTotalKwh > 0 || weeklyTotalCost > 0 || isPotentiallyValidWeek) {
                 newPoints.add(ChartDataPoint(xIndex: weekNum - 1, xLabel: weekLabel, kwh: weeklyTotalKwh, cost: weeklyTotalCost));
            }
          }
          // Ensure we don't have too many empty weeks if month is short and has no data for later weeks
          // This logic might need refinement based on how strictly "5 weeks" should be shown
          // For now, if the last point is W5 and has no data, and it's beyond the month's actual weeks, remove it.
          if (newPoints.isNotEmpty && newPoints.last.xLabel == 'W5' && newPoints.last.kwh == 0 && newPoints.last.cost == 0) {
            if ( (DateUtils.getDaysInMonth(year, month) / 7.0).ceil() < 5) {
                newPoints.removeLast();
            }
          }
          break;

        case 'Monthly': // Shows months of current year
        case 'Yearly': // For now, Yearly will also show monthly breakdown of current year
          _chartTitle = widget.selectedPeriod == 'Yearly' ? 'Monthly Usage (${now.year})' : 'Monthly Usage (Current Year)';
          for (int monthNum = 1; monthNum <= 12; monthNum++) {
            String monthLabel = DateFormat('MMM').format(DateTime(now.year, monthNum));
            double monthlyTotalKwh = 0;
            double monthlyTotalCost = 0;

            // Parallel fetch for all appliances for this specific month
            List<Future<DocumentSnapshot>> applianceMonthFutures = applianceIds.map((applianceId) {
              String path = 'users/$userId/appliances/$applianceId/yearly_usage/${now.year}/monthly_usage/${_getMonthName(monthNum)}_usage';
              return _firestore.doc(path).get();
            }).toList();

            List<DocumentSnapshot> applianceMonthSnaps = await Future.wait(applianceMonthFutures);

            for (final docSnap in applianceMonthSnaps) {
              if (docSnap.exists && docSnap.data() != null) {
                final data = docSnap.data() as Map<String, dynamic>;
                monthlyTotalKwh += (data['kwh'] as num?)?.toDouble() ?? 0.0;
                monthlyTotalCost += (data['kwhrcost'] as num?)?.toDouble() ?? 0.0;
              }
            }
            newPoints.add(ChartDataPoint(xIndex: monthNum - 1, xLabel: monthLabel, kwh: monthlyTotalKwh, cost: monthlyTotalCost));
            }
          // Removed extra closing brace here
          break;
      }
    } catch (e) {
      print("Error fetching chart data: $e");
      // Handle error state if necessary
    }

    if (!mounted) return;
    setState(() {
      _chartDataPoints = newPoints;
      _updateMaxY();
      _isLoading = false;
    });
  }

  void _updateMaxY() {
    if (_chartDataPoints.isEmpty) {
      _maxY = 10;
      return;
    }
    double maxVal = 0;
    for (var point in _chartDataPoints) {
      double currentVal = _displayMode == 'kWh' ? point.kwh : point.cost;
      if (currentVal > maxVal) {
        maxVal = currentVal;
      }
    }
    _maxY = maxVal == 0 ? 10 : (maxVal * 1.2); // Add some padding
  }

  BarChartGroupData _generateBarGroup(int x, double value) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: value,
          color: Theme.of(context).colorScheme.primary,
          width: 15,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
      // Removed showingTooltipIndicators to make tooltips appear on touch
    );
  }

  Widget _getBottomTitles(double value, TitleMeta meta) {
    String text = '';
    if (value.toInt() >= 0 && value.toInt() < _chartDataPoints.length) {
      text = _chartDataPoints[value.toInt()].xLabel;
    }
    return Text(text, style: const TextStyle(fontSize: 10, color: Colors.black54));
  }
  
  Widget _getLeftTitles(double value, TitleMeta meta) {
    if (value == meta.max || value == meta.min) { // Avoid clutter at top/bottom
      return const Text('');
    }
    // Show fewer labels if interval is small to prevent overlap
    if (meta.appliedInterval < 1 && value % 1 != 0) { // if interval is decimal, only show integers
        if(value != value.floor()){
             return const Text('');
        }
    } else if (meta.appliedInterval < 5 && value % 2 != 0 && value != 0) { // if interval is small, skip some labels
        // return const Text(''); // Decided to show all for now, can be adjusted
    }

    return Text(meta.formattedValue, style: const TextStyle(fontSize: 10, color: Colors.black54));
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_chartDataPoints.isEmpty && ! _isLoading) {
        return Center(child: Text('No usage data available for ${widget.selectedPeriod} period.'));
    }


    List<BarChartGroupData> barGroups = [];
    for(var point in _chartDataPoints) {
        barGroups.add(
            _generateBarGroup(
                point.xIndex,
                _displayMode == 'kWh' ? point.kwh : point.cost
            )
        );
    }
     _updateMaxY(); // Recalculate maxY when displayMode changes

    return Column(
      children: [
        Text(_chartTitle, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _displayMode = _displayMode == 'kWh' ? 'cost' : 'kWh';
              _updateMaxY(); // Update maxY based on new display mode
            });
          },
          child: Text(_displayMode == 'kWh' ? 'Show Estimated Cost' : 'Show kWh Usage'),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _maxY,
                minY: 0,
                groupsSpace: 12,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipRoundedRadius: 4, // Matches the example's slight rounding
                    getTooltipColor: (group) => Colors.grey.shade700, // Grey background for the tooltip box
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final point = _chartDataPoints[group.x.toInt()];
                      final val = _displayMode == 'kWh' ? point.kwh : point.cost;
                      final unit = _displayMode == 'kWh' ? 'kWh' : (_displayMode == 'cost' ? '₱' : ''); // Use ₱ for cost
                      
                      String text = '${val.toStringAsFixed(2)} $unit';
                      // The example image shows "14.312 €". If you want 3 decimal places for cost:
                      // if (_displayMode == 'cost') {
                      //   text = '${val.toStringAsFixed(3)} $unit';
                      // }


                      return BarTooltipItem(
                        text,
                        const TextStyle(
                          color: Colors.white, // White text
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    },
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    tooltipMargin: 8, // Margin between the bar and the tooltip
                    // tooltipDirection: TooltipDirection.top, // Ensures tooltip is above the bar
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true, 
                      getTitlesWidget: _getBottomTitles, 
                      reservedSize: 30, // Increased reserved size for potentially longer labels
                    )
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true, 
                      getTitlesWidget: _getLeftTitles, 
                      reservedSize: 42, // Increased reserved size
                      interval: null, // Let fl_chart calculate automatically
                    )
                  ),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300, width: 0.5)),
                gridData: FlGridData(
                  show: true, 
                  drawVerticalLine: false, 
                  horizontalInterval: null, // Let fl_chart calculate automatically
                   getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.shade300,
                      strokeWidth: 0.5,
                    );
                  },
                ),
                barGroups: barGroups,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
