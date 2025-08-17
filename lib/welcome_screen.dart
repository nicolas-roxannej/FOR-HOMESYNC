import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:homesync/homepage_screen.dart';




class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Color(0xFFE9E7E6), // whole frame
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          
          children: [ // logo
            Image.asset('assets/homesync_logo.png', height: 137, width: 149),
            SizedBox(height: 110),
            Column(
              children: [

                Transform.translate( // title na homesync
                offset: Offset(1, -130),
                child: Text(
                  'HOMESYNC',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.instrumentSerif(
                  textStyle: TextStyle(fontSize: 25,),
                  color: Colors.black, 
                  ),
                ),
                ),
            
                Transform.translate( // description 
                offset: Offset(1, -125),
                child:Text(
                  'A Connected Home to a Connected Life',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.black,
                    fontWeight: FontWeight.bold, 
                  ),
                ),
                ),
              ],
            ),

            Transform.translate( // description 2
                offset: Offset(2, -120),
                 child: SizedBox(
                 width: 220,
                child:Text(
                  'Welcome to HomeSync, Where Smart Living Begins.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: Colors.black,
                  ),
                  ),
                ),
                ),
      
            Transform.translate( //btn Login
            offset: Offset(2.5, -75),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/login');
              },
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                 backgroundColor: Colors.white,
                 shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(0), 
                side: BorderSide(
                color: Colors.black, 
                width: 1,
                ),
                 ),
          elevation: 5, 
          shadowColor: Colors.black.withOpacity(0.5),
              ),
            
              child: Text(
                'LOG IN',
                style: GoogleFonts.jaldi(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black, 
                ),
            ),
            ),
            ),
      
      

Transform.translate( // btn sign up
  offset: Offset(2.5, -40),
            child: OutlinedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/signup');
              },
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                backgroundColor: Colors.white,
                 shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(0), 
                side: BorderSide(
                color: Colors.black, 
                width: 1,
              ),
               ),
                 elevation: 5, 
                 shadowColor: Colors.black.withOpacity(0.5),
              ),
              
              child: Text(
                'SIGN UP',
                style: GoogleFonts.jaldi(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black, 
                ),

            
            ),
            ),
),

 Transform.translate(
              offset: Offset(3, 115),
            child:TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => HomepageScreen()),
                );  
              },
           child: Text(
                'Login as guest',
                style: GoogleFonts.inter(
                  textStyle: TextStyle(
                    fontSize: 16,
                  ),
                  color: Colors.grey,
                ),
              ),
              ),
            ),
          ],
      ),
      ),
    );
  }
}