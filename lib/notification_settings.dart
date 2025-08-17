import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:homesync/System_notif.dart';
import 'package:homesync/device_notif.dart';



class NotificationSettings extends StatefulWidget {
  const NotificationSettings({super.key});

  @override
  State<NotificationSettings> createState() => NotificationSettingsState();
}

class NotificationSettingsState extends State<NotificationSettings> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
    backgroundColor: const Color(0xFFE9E7E6), // frame
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
         
            Padding( // btn and title
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 30),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, size: 50, color: Colors.black),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(width: 1),
                  Text(
                    'Notification Settings',
                     textAlign: TextAlign.center,
                  style: GoogleFonts.jaldi(
                    textStyle: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                    color: Colors.black,
                  ),
                  ),
                ],
              ),
            ),
            
            // title and function of each box
             Transform.translate( 
              offset: Offset(1,-25),
           child: Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      'System Notifications',
                       style: GoogleFonts.jaldi(
                    textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    color: Colors.black,
                      ),
                    ),
                
                    const SizedBox(height: 10),
                    _buildNotificationTile(
                      title: 'System',
                      subtitle: 'Updates & New devices',
                       onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => SystemNotif()),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Device Notifications',
                     style: GoogleFonts.jaldi(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        textStyle: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildNotificationTile(
                      title: 'Device',
                      subtitle: '',
                     onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => DeviceNotif()),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Testing & Debug',
                     style: GoogleFonts.jaldi(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        textStyle: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildNotificationTile(
                      title: 'Test Notifications',
                      subtitle: 'Test Android notification pop-ups',
                     onTap: () {
                        Navigator.pushNamed(context, '/notificationtest');
                      },
                    ),
                  ],
                ),
              ),
            ),
             ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNotificationTile({ // container design
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8.0),
         boxShadow: [
         BoxShadow( 
        color: Colors.grey.withOpacity(0.3),
        spreadRadius: 1,
        blurRadius: 5,
        offset: Offset(0, 3),
      ),
      ]
      ),
      child: ListTile(
        title: Text(
          title,
          style: GoogleFonts.jaldi(
            fontWeight: FontWeight.bold,
            fontSize: 18
          ),
        ),
        subtitle: subtitle.isNotEmpty
            ? Text(
                subtitle,
                style: GoogleFonts.jaldi(
                  fontSize: 15,
                  color: Colors.black,
                ),
              )
            : null,
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 25,
          color: Colors.black,
        ),
        onTap: onTap,
      ),
    );
  }
}
