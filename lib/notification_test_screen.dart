import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:homesync/notification_manager.dart';
import 'package:homesync/notification_service.dart';

class NotificationTestScreen extends StatefulWidget {
  const NotificationTestScreen({super.key});

  @override
  State<NotificationTestScreen> createState() => _NotificationTestScreenState();
}

class _NotificationTestScreenState extends State<NotificationTestScreen> {
  final NotificationManager _notificationManager = NotificationManager();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    try {
      await _notificationManager.initialize();
      setState(() {
        _isInitialized = true;
      });
      _showSnackBar('Notification system initialized successfully', Colors.green);
    } catch (e) {
      _showSnackBar('Failed to initialize notifications: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9E7E6),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.only(left: 5, top: 25),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 50, color: Colors.black),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      'Notification Test',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.jaldi(
                        textStyle: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                        ),
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 50), // Balance the back button
                ],
              ),
            ),

            // Status indicator
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isInitialized ? Colors.green[100] : Colors.orange[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isInitialized ? Colors.green : Colors.orange,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isInitialized ? Icons.check_circle : Icons.hourglass_empty,
                      color: _isInitialized ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isInitialized 
                          ? 'Notification system ready'
                          : 'Initializing notification system...',
                      style: GoogleFonts.jaldi(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Test buttons
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionTitle('Device Notifications'),
                    _buildTestButton(
                      'Device Status Change',
                      'Test device on/off notification',
                      Icons.power_settings_new,
                      () => _testDeviceStatusChange(),
                    ),
                    _buildTestButton(
                      'Device Disconnected',
                      'Test device disconnection alert',
                      Icons.wifi_off,
                      () => _testDeviceDisconnected(),
                    ),
                    _buildTestButton(
                      'New Device Found',
                      'Test new device discovery',
                      Icons.add_circle,
                      () => _testNewDeviceFound(),
                    ),

                    const SizedBox(height: 20),
                    _buildSectionTitle('Energy Notifications'),
                    _buildTestButton(
                      'High Energy Usage',
                      'Test energy usage alert',
                      Icons.flash_on,
                      () => _testHighEnergyUsage(),
                    ),
                    _buildTestButton(
                      'Daily Energy Report',
                      'Test daily usage report',
                      Icons.assessment,
                      () => _testDailyEnergyReport(),
                    ),
                    _buildTestButton(
                      'Energy Spike Alert',
                      'Test unusual energy spike',
                      Icons.warning,
                      () => _testEnergySpike(),
                    ),

                    const SizedBox(height: 20),
                    _buildSectionTitle('System Notifications'),
                    _buildTestButton(
                      'Firmware Update',
                      'Test firmware update notification',
                      Icons.system_update,
                      () => _testFirmwareUpdate(),
                    ),
                    _buildTestButton(
                      'System Maintenance',
                      'Test maintenance notification',
                      Icons.build,
                      () => _testSystemMaintenance(),
                    ),
                    _buildTestButton(
                      'Connectivity Issue',
                      'Test connectivity problem alert',
                      Icons.signal_wifi_off,
                      () => _testConnectivityIssue(),
                    ),

                    const SizedBox(height: 20),
                    _buildSectionTitle('Alert Notifications'),
                    _buildTestButton(
                      'Overload Warning',
                      'Test electrical overload alert',
                      Icons.electrical_services,
                      () => _testOverloadWarning(),
                    ),
                    _buildTestButton(
                      'Temperature Alert',
                      'Test temperature warning',
                      Icons.thermostat,
                      () => _testTemperatureAlert(),
                    ),

                    const SizedBox(height: 20),
                    _buildSectionTitle('Other Notifications'),
                    _buildTestButton(
                      'Weather Update',
                      'Test weather notification',
                      Icons.wb_sunny,
                      () => _testWeatherUpdate(),
                    ),
                    _buildTestButton(
                      'Data Sync Complete',
                      'Test sync completion',
                      Icons.sync,
                      () => _testDataSyncCompleted(),
                    ),
                    _buildTestButton(
                      'Energy Saving Tip',
                      'Test energy saving suggestion',
                      Icons.eco,
                      () => _testEnergySavingTip(),
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: GoogleFonts.jaldi(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildTestButton(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton(
        onPressed: _isInitialized ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 3,
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.black87),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.jaldi(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.jaldi(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }

  // Test methods
  Future<void> _testDeviceStatusChange() async {
    await _notificationManager.notifyDeviceStatusChange(
      deviceName: 'Living Room Light',
      room: 'Living Room',
      isOn: true,
    );
    _showSnackBar('Device status notification sent!', Colors.blue);
  }

  Future<void> _testDeviceDisconnected() async {
    await _notificationManager.notifyDeviceDisconnected(
      deviceName: 'Kitchen Plug',
      room: 'Kitchen',
    );
    _showSnackBar('Device disconnection alert sent!', Colors.orange);
  }

  Future<void> _testNewDeviceFound() async {
    await _notificationManager.notifyNewDeviceFound(
      deviceName: 'Smart Thermostat',
      deviceType: 'Climate Control',
    );
    _showSnackBar('New device notification sent!', Colors.green);
  }

  Future<void> _testHighEnergyUsage() async {
    await _notificationManager.notifyHighEnergyUsage(
      currentUsage: 15.2,
      threshold: 12.0,
      period: 'today',
    );
    _showSnackBar('High energy usage alert sent!', Colors.red);
  }

  Future<void> _testDailyEnergyReport() async {
    await _notificationManager.notifyDailyEnergyReport(
      totalUsage: 12.4,
      previousDayUsage: 11.8,
    );
    _showSnackBar('Daily energy report sent!', Colors.blue);
  }

  Future<void> _testEnergySpike() async {
    await _notificationManager.notifyEnergySpike(
      deviceName: 'Air Conditioner',
      room: 'Bedroom',
      currentPower: 2500.0,
    );
    _showSnackBar('Energy spike alert sent!', Colors.red);
  }

  Future<void> _testFirmwareUpdate() async {
    await _notificationManager.notifyFirmwareUpdate(
      deviceName: 'Smart Hub',
      version: '2.1.3',
    );
    _showSnackBar('Firmware update notification sent!', Colors.blue);
  }

  Future<void> _testSystemMaintenance() async {
    await _notificationManager.notifySystemMaintenance(
      scheduledTime: 'Saturday, 2:00 AM',
      description: 'System optimization and updates',
    );
    _showSnackBar('Maintenance notification sent!', Colors.orange);
  }

  Future<void> _testConnectivityIssue() async {
    await _notificationManager.notifyConnectivityIssue(
      deviceName: 'IoT Hub',
      issue: 'Wi-Fi connection unstable',
    );
    _showSnackBar('Connectivity issue alert sent!', Colors.red);
  }

  Future<void> _testOverloadWarning() async {
    await _notificationManager.notifyOverloadWarning(
      deviceName: 'Kitchen Outlet',
      room: 'Kitchen',
      currentAmperage: 18.5,
      maxAmperage: 15.0,
    );
    _showSnackBar('Overload warning sent!', Colors.red);
  }

  Future<void> _testTemperatureAlert() async {
    await _notificationManager.notifyTemperatureAlert(
      deviceName: 'Smart Switch',
      room: 'Garage',
      temperature: 65.0,
      severity: 'High',
    );
    _showSnackBar('Temperature alert sent!', Colors.orange);
  }

  Future<void> _testWeatherUpdate() async {
    await _notificationManager.notifyWeatherUpdate(
      condition: 'Sunny',
      temperature: 27.0,
      recommendation: 'Consider using natural lighting',
    );
    _showSnackBar('Weather update sent!', Colors.blue);
  }

  Future<void> _testDataSyncCompleted() async {
    await _notificationManager.notifyDataSyncCompleted();
    _showSnackBar('Data sync notification sent!', Colors.green);
  }

  Future<void> _testEnergySavingTip() async {
    await _notificationManager.notifyEnergySavingTip(
      tip: 'Set lights to auto-off at night',
      potentialSavings: '5% energy',
    );
    _showSnackBar('Energy saving tip sent!', Colors.green);
  }
}
