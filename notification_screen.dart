import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:homesync/notification_settings.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool _isDeleteMode = false; // function mode for delete all and delete btn
  bool _selectAll = false;
  List<NotificationItem> _notifications = [];

  @override
  void initState() { // pero ito stay lang
    super.initState();

   //example dummy lang po ito para ma try ko po yung fucntion if na gana 
    _notifications = [
      NotificationItem(
        id: '1',
        title: 'New Message',
        description: 'You have add new device',
        time: '10:30 AM',
        isSelected: false,
      ),
      NotificationItem(
        id: '2',
        title: 'Energy Alert',
        description: 'You left your lights open',
        time: 'Yesterday',
        isSelected: false,
      ),
    ];
  }
//////////////////////////////////////////////////////////////////////////////////////
  void _toggleDeleteMode() { //exit btn for the delete
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
////////////////////////////////////////////////////////////////////////

  void _toggleSelectAll() { // for the select all 
    setState(() {
      _selectAll = !_selectAll;
      for (var notification in _notifications) {
        notification.isSelected = _selectAll;
      }
    });
  }
  ///////////////////////////////////////////////////////////////////////
 
  void _deleteSelected() { //for delete selected btn
    setState(() {
      _notifications.removeWhere((notification) => notification.isSelected);
      _isDeleteMode = false;
      _selectAll = false;
    });
  }
/////////////////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {
    return Scaffold(
    backgroundColor: const Color(0xFFE9E7E6), // whole frame
      body: Column(
        children: [
          
          Container(
            padding: EdgeInsets.only(left: 5, top: 65), // back
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, size: 50, color: Colors.black),
                  onPressed: ()  => Navigator.of(context).pop(), 
                ),
                 Transform.translate( //title
              offset: Offset(1,-1),
                child: Expanded(
                  child: Text(
                  'Notification',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.jaldi(
                    textStyle: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                    color: Colors.black,
                  ),
              ),
                  ),
                ),
              Transform.translate( 
              offset: Offset(70,-1),
                child:IconButton( // delete icont btn
                  icon: Icon(
                    _isDeleteMode ? Icons.delete : Icons.delete_sharp,
                    color: Colors.black,
                    size: 30,
                  ),
                  onPressed: _toggleDeleteMode,
                ),
),

//////////////////////////////////////////////////////////////////
              Transform.translate( //settings btn
              offset: Offset(65,-1),
                child:IconButton(
                  icon: Icon(Icons.settings, color: Colors.black,size: 30,),
         onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => NotificationSettings()),
      );
    },
  ),
),

              ],
            ),
          ),
    
          // placeholder function
          Expanded(
            child: _notifications.isEmpty
                ? _buildEmptyNotifications()
                : _buildNotificationsList(),
          ),
        ],
      ),
      // 
      bottomNavigationBar: _isDeleteMode && _notifications.isNotEmpty // to pop up the delete bar
          ? _buildDeleteModeBar()
          : null,
    );
  }
////////////////////////////////////////////
  Widget _buildEmptyNotifications() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
           Transform.translate( //placeholder design
              offset: Offset(0,-70),
          child: Icon(
            Icons.notifications,
            size: 100,
            color: const Color(0xFF757575),
          ),
          ),
          SizedBox(height: 16),
          Transform.translate( 
              offset: Offset(0,-85),
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
//////////////////////////////////////////////////////////
  Widget _buildNotificationsList() { // function for notification checkbox for delete select all and scroll settings
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
                _selectAll = _notifications.every((n) => n.isSelected);
              }
            });
          },
        );
      },
    );
  }
  ///////////////////////////////////////////////////

  Widget _buildDeleteModeBar() { // delete bar design
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
              Transform.translate( //title
              offset: Offset(-5, 0),
             child: Text('Select All',
              style: GoogleFonts.jaldi(
                textStyle: TextStyle(fontSize: 18,),
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
            child: Text('Delete Selected',
            style: TextStyle(fontSize: 15,),
              ),
          ),
        ],
      ),
    );
  }
}
///////
class NotificationItem { // notification items display settings
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

  const NotificationCard({super.key, 
    required this.notification,
    required this.isDeleteMode,
    required this.onToggleSelection,
  });
///////////////////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {
     return Transform.translate(
  offset: Offset(0, -15),// notification message designs
  child: Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 10,),
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