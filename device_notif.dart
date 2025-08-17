import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DeviceNotif extends StatefulWidget {
  const DeviceNotif({super.key});

  @override
  State<DeviceNotif> createState() => DeviceNotifState();
}

class DeviceNotifState extends State<DeviceNotif> {
   final Map<String, bool> _notifications = {
    'Kitchen Plug': true,
    'Kitchen Lights': true, // status toggle
    'Bedroom Plug': true,
    'Bedroom Lights': true,
    'Living Room Plug': true,
    'Living Room Lights': true,
    'Dining Area Plug': true,
  };

  IconData _getIcon(String name) { // icon string
    if (name.contains('Lights')) {
      return Icons.light;
    } else {
      return Icons.power;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
     backgroundColor: const Color(0xFFE9E7E6),  // frame design
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
             
             
             Transform.translate(  
            offset: Offset(-10,18),  //back
            child: IconButton(
              icon: Icon(Icons.arrow_back, size: 50, color: Colors.black),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ),
                    Transform.translate(  // title
            offset: Offset(65,-34),
            child: Text(
              'System Notifications',
              style: GoogleFonts.jaldi(
                    textStyle: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                    color: Colors.black,
                  ),
                  ),
          ),
        
              const SizedBox(height: 30),

              // Notification Toggles
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: _notifications.keys.map((device) {
                    return Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(_getIcon(device), size: 22),
                                const SizedBox(width: 10),
                                Text(
                                  device,
                                   style: GoogleFonts.jaldi(
                                  fontSize: 20,
                                ),
                              ),
                              ],
                            ),
                            Switch(
                              value: _notifications[device]!,
                              onChanged: (val) {
                                setState(() {
                                  _notifications[device] = val;
                                 
                                });
                              },
                              activeColor: Colors.white,
                              activeTrackColor: Colors.black,
                                inactiveThumbColor: Colors.white,
                                inactiveTrackColor: Colors.black,
                            ),
                          ],
                        ),
                        if (device != _notifications.keys.last)
                          const Divider(thickness: 1),
                      ],
                    
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );      
  }
}
