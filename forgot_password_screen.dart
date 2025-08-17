import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:homesync/login_screen.dart';
import 'package:homesync/signup_screen.dart';
import 'package:homesync/welcome_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:homesync/homepage_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadRememberMe();
  }

  void _loadRememberMe() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _rememberMe = prefs.getBool('remember_me') ?? false;
    });
  }

  void _saveRememberMe(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('remember_me', value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9E7E6),
      appBar: null,
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.all(14),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: EdgeInsets.only(left: 5, top: 65),
                      child: IconButton(
                        icon: Icon(Icons.arrow_back, size: 50, color: Colors.black),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => WelcomeScreen()),
                          );
                        },
                        style: ButtonStyle(
                          overlayColor: WidgetStateProperty.all(Colors.transparent),
                        ),
                      ),
                    ),
                  ),

                  Center(
                    child: Transform.translate(
                      offset: Offset(0, -20),
                      child: Padding(
                        padding: EdgeInsets.only(top: 1, bottom: 10),
                        child: Image.asset(
                          'assets/homesync_logo.png',
                          height: 120,
                          errorBuilder: (context, error, stackTrace) {
                            return Text('HomeSync', style: TextStyle(fontSize: 30));
                          },
                        ),
                      ),
                    ),
                  ),

                  Transform.translate(
                    offset: Offset(-55, -182),
                    child: Text(
                      'LOG IN',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.jaldi(
                        textStyle: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                        color: Colors.black,
                      ),
                    ),
                  ),

                  Transform.translate(
                    offset: Offset(1, -80),
                    child: Text(
                      'HOMESYNC',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.instrumentSerif(
                        textStyle: TextStyle(fontSize: 25),
                        color: Colors.black,
                      ),
                    ),
                  ),
                  SizedBox(height: 50),
                  Transform.translate(
                    offset: Offset(0, -100),
                    child: TextField(
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: Icon(Icons.email, color: Colors.black),
                        hintText: 'Email Address',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),

                  SizedBox(height: 15),
                  Transform.translate(
                    offset: Offset(0, -90),
                    child: TextField(
                      obscureText: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: Icon(Icons.lock, color: Colors.black),
                        hintText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),

                  SizedBox(height: 10),
                  Transform.translate(
                    offset: Offset(110, -98),
                    child: TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/forgot-password');
                      },
                      child: Text(
                        'Forgot Password?',
                        style: GoogleFonts.inter(
                          textStyle: TextStyle(fontSize: 13),
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                  Transform.translate(
                    offset: const Offset(-7, -155),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (bool? value) {
                                setState(() {
                                  _rememberMe = value!;
                                });
                                _saveRememberMe(value!);
                              },
                            ),
                            Text(
                              "Remember Me",
                              style: GoogleFonts.inter(
                                textStyle: TextStyle(fontSize: 13),
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Transform.translate(
                    offset: Offset(0, -115),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => HomepageScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 13, horizontal: 10),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(0),
                          side: BorderSide(color: Colors.black, width: 1),
                        ),
                        elevation: 5,
                        shadowColor: Colors.black.withOpacity(0.5),
                        splashFactory: NoSplash.splashFactory,
                      ),
                      child: Text(
                        'Log In',
                        style: GoogleFonts.judson(fontSize: 24, color: Colors.black),
                      ),
                    ),
                  ),

                  Transform.translate(
                    offset: Offset(3, -55),
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => SignUpScreen()),
                        );
                      },
                      style: ButtonStyle(
                        minimumSize: WidgetStateProperty.all(Size.zero),
                        padding: WidgetStateProperty.all(EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        overlayColor: WidgetStateProperty.all(Colors.transparent),
                      ),
                      child: Text(
                        'Don\'t have an account? SIGN UP',
                        style: GoogleFonts.inter(
                          textStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Stack(
            children: [
              Positioned(
                top: -100,
                bottom: 0,
                left: 0,
                right: 0,
                child: SizedBox(
                  width: double.infinity,
                  height: 100,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.all(0),
                      backgroundColor: const Color(0x80000000),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(0),
                      ),
                      splashFactory: NoSplash.splashFactory,
                    ),
                    child: Text(''),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => LoginScreen()),
                      );
                    },
                  ),
                ),
              ),

              Positioned(
                bottom: 235,
                left: 20,
                right: 20,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.white, width: 9),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Transform.translate(
                        offset: Offset(5, -15),
                        child: Text(
                          'Forgot password?',
                          style: GoogleFonts.jaldi(
                            textStyle: TextStyle(
                                fontSize: 25, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(6, -10),
                        child: Text(
                          'Enter the code that been sent in your email.',
                          style: GoogleFonts.fredoka(
                            textStyle: TextStyle(fontSize: 15),
                          ),
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(1, 15),
                        child: TextField(
                          decoration: InputDecoration(
                            prefixIcon: Padding(
                              padding: EdgeInsets.only(left: 1, right: 15, bottom: 1),
                              child: Icon(
                                Icons.qr_code,
                                color: Colors.black,
                                size: 35,
                              ),
                            ),
                            hintText: 'Enter Code',
                            contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 2),
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 6, 
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          )
        ], 
      ),
    );
  }
}