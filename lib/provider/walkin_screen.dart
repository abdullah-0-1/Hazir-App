import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Walkin extends StatefulWidget {
  final String providerId; 

  const Walkin({super.key, required this.providerId});

  @override
  State<Walkin> createState() => _WalkinState();
}

class _WalkinState extends State<Walkin> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedService;
  String _prepaid = 'No';

  List<String> prepaidOptions = ['Yes', 'No'];
  List<Map<String, dynamic>> rateList = []; 


  Future<void> _loadRateList() async {
    final doc = await FirebaseFirestore.instance
        .collection('userProvider')
        .doc(widget.providerId)
        .get();

    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;

      if (data.containsKey('rateList')) {
        rateList = List<Map<String, dynamic>>.from(data['rateList']);
      }
      setState(() {});
    }
  }


  Future<void> _addWalkin() async {
  if (_formKey.currentState!.validate()) {
    final selected = rateList.firstWhere(
      (item) =>
          "${item['service']} — Rs. ${item['price']}" == _selectedService,
    );

    final data = {
      'name': _nameController.text.trim(),
      'service': selected['service'],
      'price': selected['price'],
      'prepaid': _prepaid,
      'notes': _notesController.text.trim(),
      'timestamp': DateTime.now().toIso8601String(),
    };

    await FirebaseFirestore.instance
        .collection('userProvider')
        .doc(widget.providerId)
        .update({
      "customers": FieldValue.arrayUnion([data]),
    });

    _nameController.clear();
    _notesController.clear();
    _selectedService = null;
    _prepaid = 'No';

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Customer added to queue!")),
    );

    setState(() {});
  }
}

  @override
  void initState() {
    super.initState();
    _loadRateList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              const Text(
                "Add Walk-in Customer",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: "Customer name",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? "Please enter customer name"
                        : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedService,
                decoration: InputDecoration(
                  labelText: "Select Service",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: rateList
                    .map(
                      (item) => DropdownMenuItem(
                        value: "${item['service']} — Rs. ${item['price']}",
                        child: Text("${item['service']} — Rs. ${item['price']}"),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedService = value);
                },
                validator: (value) =>
                    value == null ? "Please select a service" : null,
              ),
              const SizedBox(height: 16),

              
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        labelText: "Notes",
                        hintText: "optional",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      value: _prepaid,
                      decoration: InputDecoration(
                        labelText: "Prepaid?",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      items: prepaidOptions
                          .map((option) => DropdownMenuItem(
                                value: option,
                                child: Text(option),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() => _prepaid = value!);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _addWalkin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text("Add to Queue",
                      style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 30),

              const Text(
                "Recent Walk-ins",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 10),

              FutureBuilder(
                future: FirebaseFirestore.instance
                    .collection('userProvider')
                    .doc(widget.providerId)
                    .get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return Text("Loading...");

                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  final customers = List<Map<String, dynamic>>.from(data['customers'] ?? []);

                  if (customers.isEmpty) return Text("No walk-ins yet.");

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: customers.length,
                    itemBuilder: (context, index) {
                      final c = customers[index];
                      return Card(
                        child: ListTile(
                          title: Text(c['name']),
                          subtitle: Text("${c['service']} — Rs. ${c['price']}"),
                          trailing: Text(
                            c['prepaid'] == 'Yes' ? "Prepaid" : "Pay Later",
                          ),
                        ),
                      );
                    },
                  );
                },
              )
            
            ],
          ),
        ),
      ),
    );
  }
}
