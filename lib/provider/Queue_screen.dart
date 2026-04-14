import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Queue extends StatefulWidget {
  final String providerId; 

  Queue({super.key, required this.providerId});

  @override
  State<Queue> createState() => _QueueState();
}

class _QueueState extends State<Queue> {
  String nowServing = "No one yet";

  Stream<List<Map<String, dynamic>>> _queueStream() {
    return FirebaseFirestore.instance
        .collection("userProvider")
        .doc(widget.providerId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return [];

      final data = doc.data()!;
      final customers = List<Map<String, dynamic>>.from(data["customers"] ?? []);

      return customers;
    });
  }


  Future<void> _updateQueue(List<Map<String, dynamic>> updated) async {
    await FirebaseFirestore.instance
        .collection("userProvider")
        .doc(widget.providerId)
        .update({"customers": updated});
  }

  Future<void> _updateConsumerQueueStatus(String visitorUid, String bookingId, String newStatus) async {
    if (visitorUid.isEmpty) return;
    
    try {
      DocumentSnapshot consumerDoc = await FirebaseFirestore.instance
          .collection('userConsumer')
          .doc(visitorUid)
          .get();
      
      if (consumerDoc.exists) {
        var consumerData = consumerDoc.data() as Map<String, dynamic>;
        List<dynamic> currentQueue = List.from(consumerData['currentQueue'] ?? []);
        
        for (int i = 0; i < currentQueue.length; i++) {
          if (currentQueue[i]['bookingId'] == bookingId) {
            currentQueue[i]['status'] = newStatus;
            break;
          }
        }
        
        await FirebaseFirestore.instance
            .collection('userConsumer')
            .doc(visitorUid)
            .update({'currentQueue': currentQueue});
      }
    } catch (e) {
      debugPrint("Error updating consumer queue status: $e");
    }
  }

  Future<void> _removeFromConsumerQueue(String visitorUid, String bookingId) async {
    if (visitorUid.isEmpty) return;
    
    try {
      DocumentSnapshot consumerDoc = await FirebaseFirestore.instance
          .collection('userConsumer')
          .doc(visitorUid)
          .get();
      
      if (consumerDoc.exists) {
        var consumerData = consumerDoc.data() as Map<String, dynamic>;
        List<dynamic> currentQueue = List.from(consumerData['currentQueue'] ?? []);
        
        currentQueue.removeWhere((item) => item['bookingId'] == bookingId);
        
        await FirebaseFirestore.instance
            .collection('userConsumer')
            .doc(visitorUid)
            .update({'currentQueue': currentQueue});
      }
    } catch (e) {
      debugPrint("Error removing from consumer queue: $e");
    }
  }

  Future<void> _updateConsumerQueuePositions(List<Map<String, dynamic>> queue) async {
    for (int i = 0; i < queue.length; i++) {
      String visitorUid = queue[i]['uid'] ?? '';
      String bookingId = queue[i]['bookingId'] ?? '';
      int newPosition = i + 1;
      
      if (visitorUid.isEmpty) continue;
      
      try {
        DocumentSnapshot consumerDoc = await FirebaseFirestore.instance
            .collection('userConsumer')
            .doc(visitorUid)
            .get();
        
        if (consumerDoc.exists) {
          var consumerData = consumerDoc.data() as Map<String, dynamic>;
          List<dynamic> currentQueue = List.from(consumerData['currentQueue'] ?? []);
          
          for (int j = 0; j < currentQueue.length; j++) {
            if (currentQueue[j]['bookingId'] == bookingId) {
              currentQueue[j]['queuePosition'] = newPosition;
              break;
            }
          }
          
          await FirebaseFirestore.instance
              .collection('userConsumer')
              .doc(visitorUid)
              .update({'currentQueue': currentQueue});
        }
      } catch (e) {
        debugPrint("Error updating consumer queue position: $e");
      }
    }
  }

  void _startService(Map<String, dynamic> customer) async {
    String visitorUid = customer['uid'] ?? '';
    String bookingId = customer['bookingId'] ?? '';
    
    setState(() => nowServing = customer['name']);

    await _updateConsumerQueueStatus(visitorUid, bookingId, "Serving");
  }

  // void _skipCustomer(int index, List<Map<String, dynamic>> queue) {
  //   ScaffoldMessenger.of(context)
  //       .showSnackBar(SnackBar(content: Text("${queue[index]['name']} skipped")));
  // }

  Future<void> _removeCustomer(
      int index, List<Map<String, dynamic>> queue) async {
    Map<String, dynamic> removedCustomer = queue[index];
    String visitorUid = removedCustomer['uid'] ?? '';
    String bookingId = removedCustomer['bookingId'] ?? '';
    
    queue.removeAt(index);
    await _updateQueue(queue);

    await _removeFromConsumerQueue(visitorUid, bookingId);

    await _updateConsumerQueuePositions(queue);
  }

  Future<void> _callNext(List<Map<String, dynamic>> queue) async {
    if (queue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No one left in queue!")));
      return;
    }

    Map<String, dynamic> servedCustomer = queue.first;
    String visitorUid = servedCustomer['uid'] ?? '';
    String bookingId = servedCustomer['bookingId'] ?? '';

    setState(() => nowServing = servedCustomer["name"]);

    queue.removeAt(0);
    await _updateQueue(queue);

    await _removeFromConsumerQueue(visitorUid, bookingId);

    await _updateConsumerQueuePositions(queue);
  }


  String _generateTicket(int index) => "#A${(index + 1).toString().padLeft(2, '0')}";

  String _eta(int index) => "${(index + 1) * 8}m";


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _queueStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          List<Map<String, dynamic>> liveQueue = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Live Queue",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                const SizedBox(height: 4),
                const SizedBox(height: 16),

                if (liveQueue.isEmpty)
                  const Text("No one in queue.",
                      style: TextStyle(color: Colors.black54))
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: liveQueue.length,
                    itemBuilder: (context, index) {
                      final c = liveQueue[index];

                      return Card(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c['name'],
                                  style:
                                      const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              Text("• ${c['service']}",
                                  style: const TextStyle(color: Colors.black54)),
                              const SizedBox(height: 6),
                              Text(
                                "Ticket ${_generateTicket(index)} • ETA ${_eta(index)}",
                                style: const TextStyle(
                                    color: Colors.black45, fontSize: 13),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _queueActionButton(
                                    "Start",
                                    Colors.green[100]!,
                                    Colors.green[800]!,
                                    () => _startService(c),
                                  ),
                                  const SizedBox(width: 8),
                                  const SizedBox(width: 8),
                                  _queueActionButton(
                                    "Remove",
                                    Colors.red[100]!,
                                    Colors.red[800]!,
                                    () => _removeCustomer(index, liveQueue),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 12),

                Text("Total in queue: ${liveQueue.length}",
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87)),

                const SizedBox(height: 4),
                const Text("Est. wait for new ticket: 27m",
                    style: TextStyle(color: Colors.black54, fontSize: 13)),
                const SizedBox(height: 24),

                const Text("Now Serving",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    nowServing,
                    style: const TextStyle(fontSize: 15, color: Colors.black87),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _bottomButton("Call Next", Colors.green[700]!,
                        () => _callNext(liveQueue)),
                    _bottomButton("No-show", Colors.amber[700]!, () {_callNext(liveQueue);}),
                    _bottomButton("Done", Colors.green[700]!,
                        () => _callNext(liveQueue)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _queueActionButton(
    String label,
    Color bgColor,
    Color textColor,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: textColor, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }

  Widget _bottomButton(String text, Color color, VoidCallback onTap) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(text,
              style: const TextStyle(color: Colors.white, fontSize: 15)),
        ),
      ),
    );
  }

}






