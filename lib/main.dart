
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'firebase_options.dart';






// import 'atulogin.dart';
import '../provider/provider_screen.dart';

import '../consumer/consumer_screen.dart';

import '../authentication/login.dart';
// import '../authentication/sign_up.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
    overlays: [SystemUiOverlay.top],
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final seed = const Color.fromRGBO(2, 62, 138, 1);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
      ),
      home: AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<String?> _getUserRole(String uid) async {
    try {

      DocumentSnapshot providerDoc = await FirebaseFirestore.instance
          .collection('userProvider')
          .doc(uid)
          .get();

      if (providerDoc.exists) {
        return 'provider';
      }

      DocumentSnapshot consumerDoc = await FirebaseFirestore.instance
          .collection('userConsumer')
          .doc(uid)
          .get();

      if (consumerDoc.exists) {
        return 'consumer';
      }

      return null;
    } catch (e) {
      print("Error getting user role: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return LoginScreen();
        }

        return FutureBuilder<String?>(
          future: _getUserRole(snapshot.data!.uid),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (roleSnapshot.hasData && roleSnapshot.data != null) {
              if (roleSnapshot.data == 'provider') {
                return ProviderScreen();
              } else if (roleSnapshot.data == 'consumer') {
                return ConsumerScreen();
              }
            }

            FirebaseAuth.instance.signOut();
            return LoginScreen();
          },
        );
      },
    );
  }
}