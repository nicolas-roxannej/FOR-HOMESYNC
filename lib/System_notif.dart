import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SystemNotif extends StatefulWidget {
  const SystemNotif({super.key});

  @override
  State<SystemNotif> createState() => SystemNotifState();
}

class SystemNotifState extends State<SystemNotif> {
  bool firmwareUpdateEnabled = true;
  bool newDeviceFoundEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9E7E6), // frame
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 25), // back
              child: IconButton(
                icon: Icon(Icons.arrow_back, size: 50, color: Colors.black),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ),

            Transform.translate(  // title
              offset: Offset(75, -51),
              child: Text(
                'System Notifications',
                style: GoogleFonts.jaldi(
                  textStyle: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                  color: Colors.black,
                ),
              ),
            ),

            Padding( // function and title
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                children: [
                  _buildNotificationToggle(
                    title: 'Firmware Update',
                    isEnabled: firmwareUpdateEnabled,
                    onChanged: (value) {
                      setState(() {
                        firmwareUpdateEnabled = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildNotificationToggle(
                    title: 'New Device Found',
                    isEnabled: newDeviceFoundEnabled,
                    onChanged: (value) {
                      setState(() {
                        newDeviceFoundEnabled = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationToggle({
    required String title,
    required bool isEnabled,
    required Function(bool) onChanged,
  }) {
    return Column(
      children: [
        const SizedBox(height: 15),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.jaldi(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Switch(
                value: isEnabled,
                onChanged: onChanged,
                activeColor: Colors.white,
                activeTrackColor: Colors.black,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: Colors.black,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
