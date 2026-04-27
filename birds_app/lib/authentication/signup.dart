import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  bool _isPasswordVisible = false;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  Future<void> signUpUser() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Please fill all fields")));
      return;
    }

    try {
      // 1️⃣ Create user with email & password
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      // 2️⃣ Update display name in Firebase Auth
      await userCredential.user!.updateDisplayName(name);

      // 3️⃣ Optional: Store additional user info in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
            'full_name': name,
            'email': email,
            'createdAt': Timestamp.now(),
          });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Signup successful! Welcome, $name")),
      );

      // 4️⃣ Navigate to Home Page
      // Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage()));
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message ?? "Signup failed")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("An error occurred")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none, // IMPORTANT
                    children: [
                      Container(
                        width: 50,
                        height: 80,
                        margin: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 217, 101, 243),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      Positioned(
                        top: 30, // Move image outside top
                        left: 0, // Move image outside left
                        child: Image.asset(
                          "assets/images/signup.png",
                          width: 80,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Welcome to",
                        style: GoogleFonts.inriaSans(
                          fontSize: 30,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 0),
                        child: Text(
                          "Serendib Chirps",
                          style: GoogleFonts.inriaSans(
                            fontSize: 30,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        "Please fill the information needed below",
                        style: GoogleFonts.inriaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color.fromARGB(106, 41, 41, 41),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Full Name",
                                style: GoogleFonts.inriaSans(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w200,
                                  color: const Color.fromARGB(255, 0, 0, 0),
                                ),
                              ),
                              SizedBox(height: 10),
                              TextField(
                                controller: nameController,
                                decoration: InputDecoration(
                                  hintText: 'Bird Me',
                                  filled: true,

                                  fillColor: const Color.fromARGB(
                                    255,
                                    223,
                                    223,
                                    223,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                "Email Address",
                                style: GoogleFonts.inriaSans(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w200,
                                  color: const Color.fromARGB(255, 0, 0, 0),
                                ),
                              ),
                              SizedBox(height: 10),
                              TextField(
                                controller: emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  hintText: "birds@example.com",
                                  filled: true,
                                  fillColor: const Color.fromARGB(
                                    255,
                                    223,
                                    223,
                                    223,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                "Password",
                                style: GoogleFonts.inriaSans(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w200,
                                  color: const Color.fromARGB(255, 0, 0, 0),
                                ),
                              ),
                              SizedBox(height: 10),
                              TextField(
                                controller: passwordController,
                                obscureText: !_isPasswordVisible,
                                decoration: InputDecoration(
                                  hintText: 'Password',
                                  filled: true,
                                  fillColor: const Color.fromARGB(
                                    255,
                                    223,
                                    223,
                                    223,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isPasswordVisible
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isPasswordVisible =
                                            !_isPasswordVisible;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              Column(
                                children: [
                                  Padding(
                                    padding: EdgeInsets.only(top: 20),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.radio_button_checked,
                                          color: Color.fromARGB(
                                            106,
                                            41,
                                            41,
                                            41,
                                          ),
                                          size: 15,
                                        ),
                                        SizedBox(width: 20),
                                        Text(
                                          "At least eight characteristic long",
                                          style: GoogleFonts.inriaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: const Color.fromARGB(
                                              106,
                                              41,
                                              41,
                                              41,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.radio_button_checked,
                                        color: Color.fromARGB(106, 41, 41, 41),
                                        size: 15,
                                      ),
                                      SizedBox(width: 20),
                                      Text(
                                        "Contain numbers",
                                        style: GoogleFonts.inriaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: const Color.fromARGB(
                                            106,
                                            41,
                                            41,
                                            41,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.radio_button_checked,
                                        color: Color.fromARGB(106, 41, 41, 41),
                                        size: 15,
                                      ),
                                      SizedBox(width: 20),
                                      Text(
                                        "Contain upper lattes",
                                        style: GoogleFonts.inriaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: const Color.fromARGB(
                                            106,
                                            41,
                                            41,
                                            41,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Padding(
                                    padding: EdgeInsetsGeometry.only(top: 15),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          color: Color.fromARGB(106, 255, 2, 2),
                                          size: 15,
                                        ),
                                        SizedBox(width: 20),
                                        Text(
                                          "Read the information below before  proceed ",
                                          style: GoogleFonts.inriaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: const Color.fromARGB(
                                              106,
                                              255,
                                              2,
                                              2,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  RichText(
                                    text: TextSpan(
                                      style: GoogleFonts.inriaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: const Color.fromARGB(
                                          106,
                                          41,
                                          41,
                                          41,
                                        ),
                                      ),
                                      children: [
                                        const TextSpan(
                                          text:
                                              "By tapping the next button, you acknowledge that you agree to the ",
                                        ),
                                        TextSpan(
                                          text:
                                              "BirdVox AI Service Terms and Conditions",
                                          style: GoogleFonts.inriaSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: const Color.fromARGB(
                                              121,
                                              0,
                                              55,
                                              255,
                                            ), // Blue color
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 10),
                          child: ElevatedButton(
                            onPressed: () {
                              signUpUser();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(
                                255,
                                152,
                                69,
                                254,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Next",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
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
    );
  }
}
