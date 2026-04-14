import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:messenger/models/provider_model.dart';


class AddService extends StatefulWidget {
  final ProviderData providerData;
  const AddService({super.key , required this.providerData});
  
  @override
  State<AddService> createState() => _AddService();
}

class _AddService extends State<AddService> {
  final TextEditingController serviceController = TextEditingController();
  final TextEditingController priceController = TextEditingController();

  void _FailedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Something is Missing'),
        content: const Text('Check service and price should be there'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void addRate() async {
  String service = serviceController.text.trim();
  String price = priceController.text.trim();

  if (service.isNotEmpty && price.isNotEmpty) {
    await FirebaseFirestore.instance
        .collection('userProvider')
        .doc(widget.providerData.uid)
        .set({
      "rateList": FieldValue.arrayUnion([
        {
          "service": service,
          "price": int.parse(price),
        }
      ])
    }, SetOptions(merge: true));

    serviceController.clear();
    priceController.clear();
    setState(() {
      widget.providerData.rateList.add({"service": service, "price": int.parse(price)});
    });
  } else {
    _FailedDialog();
  }
}

  Future<void> removeRate(int index)async{

    final document = FirebaseFirestore.instance.collection('userProvider')
    .doc(widget.providerData.uid);
      
    List<Map<String, dynamic>> updatedList =
      List<Map<String, dynamic>>.from(widget.providerData.rateList);

    updatedList.removeAt(index);
    await document.update({"rateList" : updatedList});

    setState(() {
      widget.providerData.rateList = updatedList;
    });

  }

  void editRate(int index) {
    final item = widget.providerData.rateList[index];
    TextEditingController editService = TextEditingController(text: item['service']);
    TextEditingController editPrice = TextEditingController(text: item['price'].toString());

    showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text("Edit Service"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: editService,
              decoration: const InputDecoration(labelText: "Service Name"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: editPrice,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Price"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              List<Map<String, dynamic>> updatedList =
                  List<Map<String, dynamic>>.from(widget.providerData.rateList);

              updatedList[index] = {
                "service": editService.text.trim(),
                "price": int.parse(editPrice.text.trim())
              };

              await FirebaseFirestore.instance
                  .collection('userProvider')
                  .doc(widget.providerData.uid)
                  .update({"rateList": updatedList});

              setState(() {
                widget.providerData.rateList = updatedList;
              });

              Navigator.pop(context);
            },
            child: const Text("Update"),
          ),
        ],
      );
    },
  );
}



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Service"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            
            TextField(
              controller: serviceController,
              decoration: const InputDecoration(
                labelText: "Service Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Price",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (){addRate();},
                icon: const Icon(Icons.add),
                label: const Text("Add to Rate List"),
              ),
            ),
            const Divider(height: 30),

            Expanded(
              child: widget.providerData.rateList.isEmpty
                  ? const Center(child: Text("No services added yet"))
                  : ListView.builder(
                      itemCount:  widget.providerData.rateList.length,
                      itemBuilder: (context, index) {
                        final item =  widget.providerData.rateList[index];
                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: const Icon(Icons.design_services),
                            title: Text(item['service']),
                            subtitle: Text("Price: ${item['price']}"),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: (){editRate(index);},
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {removeRate(index);},
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
