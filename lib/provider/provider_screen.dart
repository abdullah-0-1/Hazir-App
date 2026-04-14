import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:messenger/models/provider_model.dart';


import 'package:messenger/authentication/login.dart';

import 'Queue_screen.dart';
import 'walkin_screen.dart';
import 'catalog_screen.dart';


class ProviderScreen extends StatefulWidget {
  const ProviderScreen({super.key});

  @override
  State<ProviderScreen> createState() => _ProviderScreenState();
}

class _ProviderScreenState extends State<ProviderScreen> {

  bool isLoading = true;

  ProviderData? providerData;


  @override
  void initState(){
    super.initState();
    _fetchProviderData();
  }


  Future<void> _fetchProviderData() async {
  try {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final doc = await FirebaseFirestore.instance
        .collection('userProvider')
        .doc(uid)
        .get();

    if (doc.exists) {
      providerData = ProviderData.fromMap(uid , doc.data()!);
    } else {
      debugPrint("Document does not exist for UID: $uid");
    }
  } catch (e) {
    debugPrint("Error fetching provider data: $e");
  } finally {
    setState(() {
      isLoading = false; 
    });
  }
}

  @override
Widget build(BuildContext context) {
  return DefaultTabController(
    length: 3,
    child: Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            "HAZIR \n Provider",
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        actions: [
          if (providerData != null)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: providerData!.status == "Open"
                    ? Colors.green[100]
                    : Colors.red[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                providerData!.status == "Open" ? "Open" : "Closed",
                style: TextStyle(
                  color: providerData!.status == "Open"
                      ? Colors.green[700]
                      : Colors.red[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        
          TextButton(
            onPressed: () async {
              if (providerData != null) {
                setState(() {
                  providerData!.status =
                      providerData!.status == "Open" ? "Closed" : "Open";
                });

                await FirebaseFirestore.instance
                    .collection("userProvider")
                .doc(providerData!.uid)   
                .update({
              "status": providerData!.status,
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
            content: Text("Status updated to ${providerData!.status}")),
          );
            }
          },
          child: const Text(
            "Toggle",
            style: TextStyle(color: Colors.black, fontSize: 15),
          ),
        ),

          TextButton(
              onPressed: () {
                FirebaseAuth.instance.signOut();
                
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );

              },

              child: const Text(
                "Logout",
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

        
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(48),
          child: TabBar(
            indicatorColor: Colors.green,
            labelColor: Colors.green,
            unselectedLabelColor: Colors.black54,
            labelStyle:
                TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            tabs: [
              Tab(text: "Queue"),
              Tab(text: "Walk-in"),
              Tab(text: "Catalog"),
            ],
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : providerData == null
              ? const Center(child: Text("No provider data found"))
              : TabBarView(
                  children: [
                    Queue(providerId: providerData!.uid),
                    Walkin(providerId: providerData!.uid),
                    Catalog(providerData: providerData!),
                  ],
                ),
    ),
  );
}

}
