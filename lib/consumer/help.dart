import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  Future<void> _sendEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=Hazir App Support',
    );

    try {
      if (!await launchUrl(emailUri)) {
        debugPrint("Could not launch email app");
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color hazirBlue = const Color.fromRGBO(2, 62, 138, 1);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: hazirBlue),
        title: Text(
          "Help & Support",
          style: TextStyle(color: hazirBlue, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Contact Developers",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Tap on a developer to send an email directly.",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: hazirBlue.withOpacity(0.1),
                  child: Text("AS", style: TextStyle(color: hazirBlue, fontWeight: FontWeight.bold)),
                ),
                title: const Text("Abdullah Shafique", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("bsai24060@itu.edu.pk"),
                trailing: Icon(Icons.email_outlined, color: hazirBlue),
                onTap: () {
                  _sendEmail("bsai24060@itu.edu.pk");
                },
              ),
            ),

            const SizedBox(height: 12),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: hazirBlue.withOpacity(0.1),
                  child: Text("AS", style: TextStyle(color: hazirBlue, fontWeight: FontWeight.bold)),
                ),
                title: const Text("Abdullah Shahzad", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("bsai24082@itu.edu.pk"),
                trailing: Icon(Icons.email_outlined, color: hazirBlue),
                onTap: () {
                  _sendEmail("bsai24082@itu.edu.pk");
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}