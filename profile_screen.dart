import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
     return MaterialApp(
    title: 'Profile Account',
    theme: ThemeData(
      textTheme: GoogleFonts.jaldiTextTheme(
        Theme.of(context).textTheme,
      ),
      primaryTextTheme: GoogleFonts.jaldiTextTheme(
        Theme.of(context).primaryTextTheme,
      ),
    ),
  ); 
}
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  ProfileScreenState createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  // Controllers to handle text input
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _isLoading = true;
  String _displayUsername = 'My Home'; // For the title

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Method to load user data from Firestore
  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists && mounted) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          
          setState(() {
            _emailController.text = userData['email'] ?? user.email ?? 'No email';
            _usernameController.text = userData['username'] ?? 'No username';
            _addressController.text = userData['address'] ?? 'No address';
            _passwordController.text = '••••••••'; // Don't show actual password for security
            _displayUsername = userData['username'] ?? 'My Home';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile data: $e')),
        );
      }
    }
  }

  // Method to update user data in Firestore
  Future<void> _updateUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'email': _emailController.text,
          'username': _usernameController.text,
          'address': _addressController.text,
          // Note: We're not updating password here for security reasons
          // Password updates should be handled separately through Firebase Auth
        });

        if (mounted) {
          setState(() {
            _displayUsername = _usernameController.text;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')),
          );
        }
      }
    } catch (e) {
      print('Error updating user data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9E7E6),
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    
                    Padding(   // back btn
                        padding: EdgeInsets.only(left: 1, top: 8),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_back, size: 50, color: Colors.black),
                            onPressed: ()  => Navigator.of(context).pop(), 
                             
                            
                          ),
                          Text(
                            'Profile Account',
                           style: GoogleFonts.jaldi(
                            textStyle: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                            color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Home Icon and Title - UPDATED to show username
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            child:CircleAvatar(
                            backgroundColor: Colors.grey,
                          radius: 50,
                          child: Icon(Icons.home, color: Colors.black, size: 60),
                        ),
                         ),
                      
                          const SizedBox(height: 3),
                          Text(
                            _displayUsername, // Show actual username instead of hardcoded "My Home"
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Profile information fields
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          // Email 
                          _buildInfoRow(
                            Icons.email,
                            'Email Address',
                            _emailController,
                            false,
                          ),
                              Transform.translate(
                      offset: Offset(0, -10),
                          child: Divider(height: 0,),

                          ),
                          
                          // Username field
                          _buildInfoRow(
                            Icons.person,
                            'Username',
                            _usernameController,
                            false,
                          ),
                          
                              Transform.translate(
                      offset: Offset(0, -10),
                          child: Divider(height: 0,),

                          ),
                          
                          // Address field
                          _buildInfoRow(
                            Icons.home,
                            'House Address',
                            _addressController,
                            false,
                          ),
                          
                          Transform.translate(
                      offset: Offset(0, -10),
                          child: Divider(height: 0,),

                          ),
                          // Password field
                          _buildInfoRow(
                            Icons.lock,
                            'Password',
                            _passwordController,
                            true,
                          ),

                             Transform.translate(
                      offset: Offset(0, -20),
                          child: Divider(height: 0,),

                          ),

                          const SizedBox(height: 20),

                          
                          ElevatedButton(
                            onPressed: _updateUserData, // Actually update the database
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(0),
                                side: BorderSide(color: Colors.black, width: 1),
                              ),
                              elevation: 5,
                        shadowColor: Colors.black.withOpacity(0.5),
                            ),
                            child: Text(
                              'Update Profile',
                              style: GoogleFonts.judson(
                          fontSize: 24,
                          color: Colors.black,
                        ),
                          ),
                          
                          ),

                          const SizedBox(height: 20),

                          // Add password change section
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Password Security',
                                  style: GoogleFonts.jaldi(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'For security reasons, passwords are not displayed. To change your password, please use the password reset option.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 12),
                                TextButton(
                                  onPressed: _resetPassword,
                                  child: Text(
                                    'Reset Password',
                                    style: TextStyle(
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ),
      );
  }

  // Method to reset password via email
  Future<void> _resetPassword() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Password reset email sent to ${user.email}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending password reset email: $e')),
        );
      }
    }
  }

  Widget _buildInfoRow(IconData icon, String title, TextEditingController controller, bool isPassword) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.black),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                TextField(
                  controller: controller,
                  obscureText: isPassword && _obscurePassword,
                  enabled: !isPassword, // Disable password field for security
                  decoration: isPassword
                      ? InputDecoration(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                                  size: 25,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                          isDense: true,
                          border: InputBorder.none,
                        )
                      : const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(vertical: 4),
                          isDense: true,
                          border: InputBorder.none,
                        ),
                  style: TextStyle(
                    fontSize: 16,
                    color: isPassword ? Colors.grey : Colors.black,
                  ),
                ),
              ],
            ),
          ),
         
        ],
      ),
    );
  }
}