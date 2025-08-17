import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:homesync/notification_settings.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool _isDeleteMode = false;
  bool _selectAll = false;
  List<NotificationItem> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _loadNotifications() async {
    final fetchedNotifications = await _fetchNotificationsFromBackend();
    setState(() {
      _notifications = fetchedNotifications;
    });
  }

  Future<List<NotificationItem>> _fetchNotificationsFromBackend() async {
    await Future.delayed(Duration(seconds: 2)); // simulate network delay

    return [
      NotificationItem(
        id: '1',
        title: 'Daily Energy Report Available',
        description: 'You used 12.4 kWh today. Tap to view detailed insights.',
        time: 'Today, 8:00 AM',
        isSelected: false,
      ),
      NotificationItem(
        id: '2',
        title: 'Appliance Left On',
        description: 'The air conditioner ran longer than usual.',
        time: 'Today, 7:45 AM',
        isSelected: false,
      ),
      NotificationItem(
        id: '3',
        title: 'Appliance Turned Off Automatically',
        description: 'To save energy, the electric fan was turned off automatically.',
        time: 'Today, 6:30 AM',
        isSelected: false,
      ),
      NotificationItem(
        id: '4',
        title: 'Appliance Scheduled to Run Soon',
        description: 'Automation for the lamp starts in 15 minutes.',
        time: 'Today, 7:45 PM',
        isSelected: false,
      ),
      NotificationItem(
        id: '7',
        title: 'New Appliance Added',
        description: 'Smart Light added successfully in Bedroom.',
        time: 'Today, 3:30 AM',
        isSelected: false,
      ),
      NotificationItem(
        id: '8',
        title: 'Unusual Pattern Detected',
        description: 'Unusual energy usage pattern detected in bedroom light.',
        time: 'Yesterday, 9:30 PM',
        isSelected: false,
      ),
      NotificationItem(
        id: '9',
        title: 'New Automation Feature',
        description: 'You can now schedule appliance using automatic alarm set.',
        time: 'Yesterday, 6:00 PM',
        isSelected: false,
      ),
      NotificationItem(
        id: '10',
        title: 'Connectivity Issue',
        description: 'IoT Hub is not responding. Check your Wi-Fi.',
        time: 'Today, 4:00 AM',
        isSelected: false,
      ),
      NotificationItem(
        id: '11',
        title: 'Data Sync Completed',
        description: 'Your data has been successfully synced with the cloud.',
        time: 'Today, 5:00 AM',
        isSelected: false,
      ),
      NotificationItem(
        id: '12',
        title: 'High Energy Usage Detected',
        description: 'Your home\'s energy usage is 20% higher than usual today.',
        time: 'Today, 7:00 AM',
        isSelected: false,
      ),
      NotificationItem(
        id: '13',
        title: 'Appliance Disconnected',
        description: 'Socket (bedroom) disconnected.',
        time: 'Yesterday, 10:00 PM',
        isSelected: false,
      ),
      NotificationItem(
        id: '14',
        title: 'Appliance Reconnected',
        description: 'Socket (bedroom) reconnected.',
        time: 'Today, 12:00 AM',
        isSelected: false,
      ),
      NotificationItem(
        id: '15',
        title: 'Overload Warning',
        description: 'High current detected on Socket (Fridge).',
        time: 'Today, 1:00 AM',
        isSelected: false,
      ),
      NotificationItem(
        id: '16',
        title: 'System Maintenance Coming Up',
        description: 'Maintenance scheduled for Saturday.',
        time: '3 days ago',
        isSelected: false,
      ),
      NotificationItem(
        id: '17',
        title: 'App Update Available',
        description: 'Version 2.3.0 is now available.',
        time: 'Yesterday, 4:00 PM',
        isSelected: false,
      ),
      NotificationItem(
        id: '18',
        title: 'Weather Notification',
        description: 'Current weather: 27°C, Sunny.',
        time: 'Today, 6:30 AM',
        isSelected: false,
      ),
      NotificationItem(
        id: '19',
        title: 'Notification Setting Triggered',
        description: 'The fan was turned off as per your notification setting.',
        time: 'Today, 9:30 AM',
        isSelected: false,
      ),
      NotificationItem(
        id: '20',
        title: 'Unusual Energy Spike',
        description: 'The air conditioner ran longer than usual. Check usage now.',
        time: 'Today, 10:00 AM',
        isSelected: false,
      ),
      NotificationItem(
        id: '21',
        title: 'Monthly Comparison Ready',
        description: 'Your home used 5% less energy compared to last month.',
        time: '2 days ago',
        isSelected: false,
      ),
      NotificationItem(
        id: '22',
        title: 'Energy Saving Tip',
        description: 'Set lights to auto-off at night to save up to 5% energy.',
        time: 'Yesterday, 3:00 PM',
        isSelected: false,
      ),
    ];
  }

  void _toggleDeleteMode() {
    setState(() {
      _isDeleteMode = !_isDeleteMode;
      if (!_isDeleteMode) {
        _selectAll = false;
        for (var notification in _notifications) {
          notification.isSelected = false;
        }
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      _selectAll = !_selectAll;
      for (var notification in _notifications) {
        notification.isSelected = _selectAll;
      }
    });
  }

  void _deleteSelected() {
    setState(() {
      _notifications.removeWhere((notification) => notification.isSelected);
      _isDeleteMode = false;
      _selectAll = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9E7E6),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(left: 5, top: 65),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, size: 50, color: Colors.black),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Transform.translate(
                  offset: Offset(1, -1),
                  child: Expanded(
                    child: Text(
                      'Notification',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.jaldi(
                        textStyle: TextStyle(
                            fontSize: 23, fontWeight: FontWeight.bold),
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(70, -1),
                  child: IconButton(
                    icon: Icon(
                      _isDeleteMode ? Icons.delete : Icons.delete_sharp,
                      color: Colors.black,
                      size: 30,
                    ),
                    onPressed: _toggleDeleteMode,
                  ),
                ),
                Transform.translate(
                  offset: Offset(65, -1),
                  child: IconButton(
                    icon: Icon(Icons.settings, color: Colors.black, size: 30),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => NotificationSettings()),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _notifications.isEmpty
                ? _buildEmptyNotifications()
                : _buildNotificationsList(),
          ),
        ],
      ),
      bottomNavigationBar: _isDeleteMode && _notifications.isNotEmpty
          ? _buildDeleteModeBar()
          : null,
    );
  }

  Widget _buildEmptyNotifications() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Transform.translate(
            offset: Offset(0, -70),
            child: Icon(
              Icons.notifications,
              size: 100,
              color: const Color(0xFF757575),
            ),
          ),
          SizedBox(height: 16),
          Transform.translate(
            offset: Offset(0, -85),
            child: Text(
              'No Notification',
              style: GoogleFonts.inter(
                color: Colors.grey[600],
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList() {
    return ListView.builder(
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        return NotificationCard(
          notification: notification,
          isDeleteMode: _isDeleteMode,
          onToggleSelection: () {
            setState(() {
              notification.isSelected = !notification.isSelected;
              if (!notification.isSelected) {
                _selectAll = false;
              } else {
                _selectAll =
                    _notifications.every((n) => n.isSelected == true);
              }
            });
          },
        );
      },
    );
  }

  Widget _buildDeleteModeBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFE9E7E6),
      child: Row(
        children: [
          Row(
            children: [
              Checkbox(
                value: _selectAll,
                onChanged: (value) {
                  _toggleSelectAll();
                },
              ),
              Transform.translate(
                offset: Offset(-5, 0),
                child: Text(
                  'Select All',
                  style: GoogleFonts.jaldi(
                    textStyle: TextStyle(
                      fontSize: 18,
                    ),
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          Spacer(),
          ElevatedButton(
            onPressed: _deleteSelected,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Delete Selected',
              style: TextStyle(
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationItem {
  final String id;
  final String title;
  final String description;
  final String time;
  bool isSelected;

  NotificationItem({
    required this.id,
    required this.title,
    required this.description,
    required this.time,
    required this.isSelected,
  });
}

class NotificationCard extends StatelessWidget {
  final NotificationItem notification;
  final bool isDeleteMode;
  final VoidCallback onToggleSelection;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.isDeleteMode,
    required this.onToggleSelection,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, -15),
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          contentPadding: EdgeInsets.all(16),
          leading: isDeleteMode
              ? Checkbox(
                  value: notification.isSelected,
                  onChanged: (value) {
                    onToggleSelection();
                  },
                )
              : CircleAvatar(
                  backgroundColor: Colors.grey,
                  child: Icon(
                    Icons.notifications,
                    color: Colors.black,
                  ),
                ),
          title: Text(
            notification.title,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 4),
              Text(notification.description),
              SizedBox(height: 4),
              Text(
                notification.time,
                style: GoogleFonts.inter(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
