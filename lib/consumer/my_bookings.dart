import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MyBookingsScreen extends StatelessWidget {
  const MyBookingsScreen({super.key});

  final Color hazirBlue = const Color.fromRGBO(2, 62, 138, 1);

Future<bool> _cancelBooking(BuildContext context, Map<String, dynamic> booking, String userId) async {
  try {
    final shopId = booking['providerId'];
    final bookingId = booking['bookingId'];

    if (shopId == null || bookingId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid booking data")),
        );
      }
      return false;
    }

    final batch = FirebaseFirestore.instance.batch();

    final userRef = FirebaseFirestore.instance.collection('userConsumer').doc(userId);
    batch.update(userRef, {
      'currentQueue': FieldValue.arrayRemove([booking])
    });

    final shopRef = FirebaseFirestore.instance.collection('userProvider').doc(shopId);
    final shopDoc = await shopRef.get();

    if (shopDoc.exists) {
      final data = shopDoc.data() as Map<String, dynamic>;
      final customers = List<Map<String, dynamic>>.from(data['customers'] ?? []);

      final updated = customers.where((c) => c['bookingId'] != bookingId).toList();

      for (int i = 0; i < updated.length; i++) {
        updated[i]['queuePosition'] = i + 1;
      }

      batch.update(shopRef, {'customers': updated});
    }

    await batch.commit();
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Booking cancelled successfully"),
          backgroundColor: Colors.green,
        ),
      );
    }

    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error cancelling booking: $e")),
      );
    }
    return false;
  }
}

  Future<bool?> _showCancelDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Cancel Booking"),
        content: const Text("Are you sure you want to cancel this booking?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("No")),
          TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text("Yes, Cancel")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("My Bookings"),
        backgroundColor: Colors.white,
        foregroundColor: hazirBlue,
      ),
      body: user == null
          ? const Center(child: Text("Please log in to see bookings."))
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('userConsumer').doc(user.uid).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final data = snapshot.data!.data() as Map<String, dynamic>?;
                final raw = data?['currentQueue'];

                final bookings = <Map<String, dynamic>>[];

                if (raw is List) {
                  for (var v in raw) {
                    if (v is Map<String, dynamic> && v['status'] != 'Completed') {
                      bookings.add(v);
                    }
                  }
                }

                if (bookings.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy, size: 60, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text("No active bookings", style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: bookings.length,
                  itemBuilder: (context, index) {
                    final b = bookings[index];

                    return Dismissible(
                      key: Key(b['bookingId']),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) async {
                        final confirm = await _showCancelDialog(context);
                        if (confirm == true) {
                          return await _cancelBooking(context, b, user.uid);
                        }
                        return false;
                      },
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.only(right: 20),
                        alignment: Alignment.centerRight,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete, color: Colors.white, size: 32),
                            SizedBox(height: 4),
                            Text("Cancel", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      child: BookingCard(b, hazirBlue),
                    );
                  },
                );
              },
            ),
    );
  }
}

class BookingCard extends StatelessWidget {
  final Map<String, dynamic> b;
  final Color hazirBlue;

  const BookingCard(this.b, this.hazirBlue, {super.key});

  @override
  Widget build(BuildContext context) {
    final shopName = b['shopName'] ?? "Unknown Shop";
    final service = b['service'] ?? "Service";
    final position = b['queuePosition'] ?? 0;
    final status = b['status'] ?? "Waiting";
    final price = b['price'] ?? 0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: hazirBlue.withOpacity(0.1))),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shopName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(service, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: status == "Waiting" ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    status,
                    style: TextStyle(color: status == "Waiting" ? Colors.orange : Colors.green, fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
            const Divider(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _info("Ticket", "#$position"),
                _info("Price", "Rs. $price"),
                _info("Est. Wait", "${position * 15}m"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: hazirBlue, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}
