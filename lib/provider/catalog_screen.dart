import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:messenger/models/provider_model.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';

import 'add_Service.dart';
import 'map_screen.dart';

class Catalog extends StatefulWidget {
  final ProviderData providerData;
  const Catalog({super.key, required this.providerData});

  @override
  State<Catalog> createState() => _CatalogState();
}

class _CatalogState extends State<Catalog> {
  late TextEditingController _shopNameController;
  late TextEditingController _descriptionController;
  late TextEditingController _ownerNameController;
  late TextEditingController _contactController;
  late TextEditingController _emailController;

  late TextEditingController locationController;
  late LatLng currentLatLng;
  late GeoPoint currentGeoPoint;

  List<Map<String, dynamic>> rateList = [];
  bool isSaving = false;

  final List<String> categories = [
    "Karyana Store",
    "Barber",
    "Car Mechanic",
    "Bike Mechanic",
    "Carpenter",
    "Meat Shop",
  ];

  String? selectedCategory;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    String? currentType = widget.providerData.shopType;
    if (currentType != null && categories.contains(currentType)) {
      selectedCategory = currentType;
    } else {
      selectedCategory = null;
    }
  }

  void _initializeControllers() {
    _shopNameController =
        TextEditingController(text: widget.providerData.shopName);
    _descriptionController =
        TextEditingController(text: widget.providerData.description);
    _ownerNameController =
        TextEditingController(text: widget.providerData.ownerName);
    _contactController =
        TextEditingController(text: widget.providerData.contactNumber);
    _emailController = TextEditingController(text: widget.providerData.email);

    currentGeoPoint = widget.providerData.location;
    currentLatLng = LatLng(currentGeoPoint.latitude, currentGeoPoint.longitude);
    locationController = TextEditingController();

    rateList = List<Map<String, dynamic>>.from(widget.providerData.rateList);

    getLocationName(currentLatLng).then((name) {
      locationController.text = name;
    });
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _descriptionController.dispose();
    _ownerNameController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('userProvider')
          .doc(widget.providerData.uid)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _shopNameController.text = data['name'] ?? '';
          _descriptionController.text = data['description'] ?? '';
          _ownerNameController.text = data['ownerName'] ?? '';
          _contactController.text = data['contactNumber'] ?? '';
          _emailController.text = data['mail'] ?? '';

          String dbType = data['shopType'] ?? '';
          if (categories.contains(dbType)) {
            selectedCategory = dbType;
          } else {
            selectedCategory = null;
          }

          if (data['location'] != null) {
            currentGeoPoint = data['location'] as GeoPoint;
            currentLatLng =
                LatLng(currentGeoPoint.latitude, currentGeoPoint.longitude);
            getLocationName(currentLatLng).then((name) {
              locationController.text = name;
            });
          }

          rateList = List<Map<String, dynamic>>.from(data['rateList'] ?? []);
        });
      }
    } catch (e) {
      print("Error refreshing data: $e");
    }
  }

  Future<String> getLocationName(LatLng latLng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        List<String> parts = [];

        if (p.street != null && p.street!.isNotEmpty) parts.add(p.street!);
        if (p.subLocality != null && p.subLocality!.isNotEmpty)
          parts.add(p.subLocality!);
        if (p.locality != null && p.locality!.isNotEmpty)
          parts.add(p.locality!);
        if (p.country != null && p.country!.isNotEmpty) parts.add(p.country!);

        if (parts.isNotEmpty) {
          return parts.join(', ');
        }
      }
    } catch (e) {
      print("Error getting location name: $e");
    }

    return "${latLng.latitude}, ${latLng.longitude}";
  }

  Future<void> saveButton() async {
    String shopname = _shopNameController.text.trim();
    String description = _descriptionController.text.trim();
    String name = _ownerNameController.text.trim();

    if (shopname.isEmpty ||
        description.isEmpty ||
        name.isEmpty ||
        selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields including Category'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('userProvider')
          .doc(widget.providerData.uid)
          .update({
        'name': shopname,
        'description': description,
        'ownerName': name,
        'location': currentGeoPoint,
        'shopType': selectedCategory,
      });

      widget.providerData.shopName = shopname;
      widget.providerData.description = description;
      widget.providerData.ownerName = name;
      widget.providerData.location = currentGeoPoint;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      await _refreshData();
    } catch (e) {
      print("Error saving profile: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Shop Profile",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _shopNameController,
                decoration: InputDecoration(
                  labelText: "Shop Name",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: "Description",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _ownerNameController,
                decoration: InputDecoration(
                  labelText: "Owner Name",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: locationController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: "Location",
                  border: OutlineInputBorder(),
                ),
                onTap: () async {
                  LatLng? newLocation = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MapPick(initialLocation: currentLatLng),
                    ),
                  );

                  if (newLocation != null) {
                    setState(() {
                      currentLatLng = newLocation;
                      currentGeoPoint = GeoPoint(
                          newLocation.latitude, newLocation.longitude);
                    });
                    final name = await getLocationName(newLocation);
                    locationController.text = name;
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _contactController,
                keyboardType: TextInputType.phone,
                readOnly: true,
                enabled: false,
                decoration: InputDecoration(
                  labelText: "Contact Number",
                  hintText: "+92 300 1234567",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey[200],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                readOnly: true,
                enabled: false,
                decoration: InputDecoration(
                  labelText: "Email Address",
                  hintText: "****@example.com",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey[200],
                ),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: InputDecoration(
                  labelText: "Select Shop Category",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedCategory = value;
                  });
                },
              ),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isSaving ? null : saveButton,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Text(
                    "Save Profile",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Rate List",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => AddService(
                                providerData: widget.providerData,
                              )));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                    child: const Text(
                      "Add Service",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('userProvider')
                    .doc(widget.providerData.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    final rateList =
                    List<Map<String, dynamic>>.from(data['rateList'] ?? []);

                    if (rateList.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Text(
                          "No services added yet.",
                          style: TextStyle(color: Colors.black54),
                        ),
                      );
                    } else {
                      return Column(
                        children: rateList.map((service) {
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              title: Text(service['service'] ?? 'Unnamed'),
                              subtitle:
                              Text('Price: Rs ${service['price'] ?? 'N/A'}'),
                            ),
                          );
                        }).toList(),
                      );
                    }
                  }

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Text(
                      "No services added yet.",
                      style: TextStyle(color: Colors.black54),
                    ),
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