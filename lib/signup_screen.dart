import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:homesync/homepage_screen.dart';
import 'package:homesync/login_screen.dart';
import 'package:homesync/welcome_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  
 
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  // visible pass
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  
  // Form validation state
  String? _emailError;
  String? _passwordError;
  String? _addressError;
  
  // valid email
  final _emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  
  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // email format
  bool _isValidEmail(String email) {
    return _emailRegex.hasMatch(email);
  }
  
  // valid address
  bool _isValidAddress(String address) {
    return address.trim().isNotEmpty && address.trim().length >= 5;
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9E7E6),
      appBar: null,
      body: Padding(
        padding: EdgeInsets.all(14),
        child: Form(
          key: _formKey,
          child: ListView(  
            children: [
              Align( // Back arrow
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: 5, top: 30), 
                  child: IconButton(
                    icon: Icon(Icons.arrow_back, size: 50, color: Colors.black),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => WelcomeScreen()),
                      );
                    },
                  ),
                ),
              ),
  
              Center( // logo
                child: Transform.translate(
                  offset: Offset(0, -20),
                  child: Image.asset(
                    'assets/homesync_logo.png',
                    height: 120,
                    errorBuilder: (context, error, stackTrace) {
                      return Text('HomeSync', style: TextStyle(fontSize: 40));
                    },
                  ),
                ),
              ),
  
              Transform.translate( //title
                offset: Offset(-55, -170),
                child: Text(
                  'SIGN UP',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.jaldi(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
  
              Transform.translate( // title
                offset: Offset(1, -70),
                child: Text(
                  'HOMESYNC',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.instrumentSerif(
                    fontSize: 25,
                    color: Colors.black,
                  ),
                ),
              ),
  
              // inputs 
              Transform.translate(
                offset: Offset(0, -20), 
                child: _buildValidatedTextField(
                  controller: _emailController,
                  icon: Icons.email, 
                  hintText: 'Email Address',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email is required';
                    }
                    if (!_isValidEmail(value)) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
              ),
  
              Transform.translate(
                offset: Offset(0, -20),
                child: _buildValidatedTextField(
                  controller: _usernameController,
                  icon: Icons.person, 
                  hintText: 'Username',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Username is required';
                    }
                    return null;
                  },
                ),
              ),
  
              Transform.translate(
                offset: Offset(0, -20),
                child: _buildValidatedTextField(
                  controller: _addressController,
                  icon: Icons.house, 
                  hintText: 'House Address',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'House address is required';
                    }
                    if (!_isValidAddress(value)) {
                      return 'Please enter a valid house address';
                    }
                    return null;
                  },
                ),
              ),
  
              Transform.translate(
                offset: Offset(0, -20),
                child: _buildPasswordField(
                  controller: _passwordController,
                  hintText: 'Password',
                  obscureText: _obscurePassword,
                  toggleVisibility: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    if (value.length < 8) {
                      return 'Password must be at least 8 characters long';
                    }
                    return null;
                  },
                ),
              ),
  
              Transform.translate(
                offset: Offset(0, -20), 
                child: _buildPasswordField(
                  controller: _confirmPasswordController,
                  hintText: 'Re-Enter Password',
                  obscureText: _obscureConfirmPassword,
                  toggleVisibility: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
              ),
  
              Transform.translate(
                offset: Offset(0, -9),
                child: ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      // Code inside the if block was the duplicated code, it has been removed.
                      // The actual logic for signup is below:
                      try {
                        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                          email: _emailController.text.trim(),
                          password: _passwordController.text.trim(),
                        );

                        // Add user information to Firestore
                        // This uses the new path /users/{uid}
                        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
                          'email': _emailController.text.trim(),
                          'username': _usernameController.text.trim(),
                          'address': _addressController.text.trim(),
                          'createdAt': Timestamp.now(), // Optional: add a timestamp
                          'presentYear': DateTime.now().year.toString(), // Added presentYear field
                        });

                        // Create initial subcollections for the new user
                        final userDocRef = FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid);

                        // Create an empty 'appliances' subcollection (or with default data if needed)
                        // Example: Adding a placeholder document to ensure the collection exists
                        // await userDocRef.collection('appliances').doc('initial_placeholder').set({'info': 'Appliances collection created'});
                        // For now, we'll just ensure the user document is created.
                        // The logic to add actual appliances will be in adddevices.dart or similar.

                        // Create an empty 'personal_information' subcollection
                        // await userDocRef.collection('personal_information').doc('details').set({'info': 'Personal info collection created'});

                        // Create an empty 'usage' subcollection
                        // await userDocRef.collection('usage').doc('summary').set({'info': 'Usage collection created'});


                        // Navigate to the next screen upon successful signup
                        if (mounted) { // Check if the widget is still in the tree
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => HomepageScreen()),
                          );
                        }
                      } on FirebaseAuthException catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.message ?? 'An error occurred during signup.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('An unexpected error occurred: ${e.toString()}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 13,),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(1),
                      side: BorderSide(color: Colors.black, width: 1),
                    ),
                    elevation: 5,
                    shadowColor: Colors.black.withOpacity(0.5),
                  ),
                  child: Text(
                    'Create Account',
                    style: GoogleFonts.judson(
                      fontSize: 20,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),

              Transform.translate(
                offset: Offset(0, 5),
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => LoginScreen()),
                    );
                  },
                  child: Text(
                    'Already have an account? LOG IN',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // valid text field with notice
  Widget _buildValidatedTextField({
    required TextEditingController controller,
    required IconData icon,
    required String hintText,
    required String? Function(String?) validator,
    bool obscureText = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10,),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        validator: validator,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.transparent,
          prefixIcon: Icon(icon, color: Colors.black),
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey),
          errorStyle: TextStyle(color: Colors.red),
          border: UnderlineInputBorder(),
        ),
      ),
    );
  }

  // password field
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required bool obscureText,
    required VoidCallback toggleVisibility,
    required String? Function(String?) validator,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10,),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        validator: validator,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.transparent,
          prefixIcon: Icon(Icons.lock, color: Colors.black),
          suffixIcon: IconButton(
            icon: Icon(
              obscureText ? Icons.visibility : Icons.visibility_off,
              color: Colors.black54,
            ),
            onPressed: toggleVisibility,
          ),
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey),
          errorStyle: TextStyle(color: Colors.red),
          border: UnderlineInputBorder(),
        ),
      ),
    );
  }
}
