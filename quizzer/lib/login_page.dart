import 'package:flutter/material.dart';

  void submitLogin() {
    print("something");
}
  void newUserSignUp() {
    print("something");
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1929),
      body: Center(
        child: Column(
          children: [
            Image.asset("images/quizzer_logo.png"),

            SizedBox(
              width: 460,
              child: TextField(
                decoration: InputDecoration(
                  labelText:      "Email Address",
                  hintText:       "Enter your email address to login",
                  contentPadding: const EdgeInsets.all(20),
                  filled:         true, 
                  fillColor:    const Color.fromARGB(255, 145, 236, 247),
                  labelStyle:     const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                  hintStyle:      const TextStyle(color:Color.fromARGB(255, 0, 0, 0)),
                  border:         OutlineInputBorder(borderRadius: BorderRadius.circular(21.0)),
                ),
              ),
            ),

            SizedBox(
              width:460,
              child: TextFormField(
                obscureText: true,
                decoration: InputDecoration(
                  labelText:      "Password",
                  hintText:       "Enter your account password to login",
                  contentPadding: const EdgeInsets.all(20),
                  filled:         true, 
                  fillColor:    const Color.fromARGB(255, 145, 236, 247),
                  labelStyle:     const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                  hintStyle:      const TextStyle(color:Color.fromARGB(255, 0, 0, 0)),
                  border:         OutlineInputBorder(borderRadius: BorderRadius.circular(21.0)),
                )
              ),
            ),
            // Submit Button
            
            const SizedBox(height:10), const SizedBox(width: 115, child:ElevatedButton(onPressed: submitLogin, child: Text("Login"))),

            // Grid element to which Social Icons can go
            const SizedBox(height:60),

            // New User Sign Up
            const SizedBox(height:10), const SizedBox(width: 115, child:ElevatedButton(onPressed: newUserSignUp, child: Text("New User"))),
          ],
        ),
      )
    );
  }
}