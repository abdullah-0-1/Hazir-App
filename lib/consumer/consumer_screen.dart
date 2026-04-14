import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import 'profile.dart';
import 'settings.dart';
import 'help.dart';
import 'customer_join_screen.dart';
import 'my_bookings.dart';
import 'package:flutter/services.dart';

class ConsumerScreen extends StatefulWidget {
  const ConsumerScreen({super.key});

  @override
  State<ConsumerScreen> createState() => _ConsumerScreen();
}

class _ConsumerScreen extends State<ConsumerScreen> {
  final MapController _mapController = MapController();
  LatLng _currentLocation = const LatLng(31.514, 74.354);
  String _currentAddress = "Lahore";
  bool _isLocating = false;
  List<Map<String, dynamic>> _providersOnMap = [];
  Map<String, dynamic>? _selectedShopProfile;
  bool _isProfileLoading = false;

  static const platform = MethodChannel('contact_channel');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLocationFromDatabase();
      _checkAndRequestLocation();
    });
  }

  Future<void> _getPlaceName(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty && mounted) {
        Placemark place = placemarks[0];
        String formattedAddress =
            "${place.subLocality ?? place.thoroughfare ?? ""}, ${place.locality ?? ""}";
        setState(() {
          _currentAddress = formattedAddress.trim();
        });
      }
    } catch (e) {
      debugPrint("Error getting address: $e");
    }
  }

  Future<void> _loadLocationFromDatabase() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('userConsumer')
            .doc(user.uid)
            .get();
        if (doc.exists && doc.data() is Map) {
          var data = doc.data() as Map<String, dynamic>;
          if (data.containsKey('location') && data['location'] is Map) {
            var locMap = data['location'] as Map<String, dynamic>;
            double lat = (locMap['latitude'] as num?)?.toDouble() ?? 0.0;
            double lng = (locMap['longitude'] as num?)?.toDouble() ?? 0.0;
            if (lat != 0.0 && lng != 0.0 && mounted) {
              setState(() => _currentLocation = LatLng(lat, lng));
              _mapController.move(LatLng(lat, lng), 16);
              _getPlaceName(lat, lng);
            }
          }
        }
      } catch (e) {
        debugPrint("Error fetching DB location: $e");
      }
    }
  }

  Future<void> _checkAndRequestLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Location services are disabled.'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Turn On',
              textColor: Colors.white,
              onPressed: () async {
                await Geolocator.openLocationSettings();
                await Future.delayed(const Duration(seconds: 1));
                _checkAndRequestLocation();
              },
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission denied'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Location permission permanently denied. Please enable in settings.'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () async {
                await Geolocator.openAppSettings();
              },
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      _getUserLocation();
    }
  }

  Future<void> _getUserLocation() async {
    if (_isLocating) return;

    setState(() => _isLocating = true);
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      LatLng newPos = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() => _currentLocation = newPos);
        _mapController.move(newPos, 16);
        _getPlaceName(position.latitude, position.longitude);
      }
    } catch (e) {
      debugPrint("Error getting location: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to get location. Please try again.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _openNavigation(double destLat, double destLng, String shopName) async {
    bool? shouldNavigate = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Navigate to Shop'),
          content: Text('Do you want to navigate to $shopName?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(2, 62, 138, 1),
                foregroundColor: Colors.white,
              ),
              child: const Text('Navigate'),
            ),
          ],
        );
      },
    );

    if (shouldNavigate != true) return;

    final List<Map<String, String>> mapOptions = [
      {
        'name': 'Google Maps',
        'url': 'google.navigation:q=$destLat,$destLng',
        'fallback': 'https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLng'
      },
      {
        'name': 'Apple Maps',
        'url': 'maps://?daddr=$destLat,$destLng',
        'fallback': 'https://maps.apple.com/?daddr=$destLat,$destLng'
      },
      {
        'name': 'Waze',
        'url': 'waze://?ll=$destLat,$destLng&navigate=yes',
        'fallback': 'https://www.waze.com/ul?ll=$destLat,$destLng&navigate=yes'
      },
    ];

    bool launched = false;

    for (var mapOption in mapOptions) {
      try {
        final Uri uri = Uri.parse(mapOption['url']!);
        if (await canLaunchUrl(uri)) {
          launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (launched) break;
        }
      } catch (e) {
        debugPrint("Could not launch ${mapOption['name']}: $e");
      }
    }

    if (!launched && mounted) {
      try {
        final Uri webUri = Uri.parse(
            'https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLng');
        launched = await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint("Could not launch web maps: $e");
      }
    }

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open maps app. Please install Google Maps or another navigation app.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<List<Map<String, dynamic>>> getNearbyProviders(
      String category,
      LatLng userLoc, {
        double radiusKm = 20.0,
        int limit = 5,
      }) async {
    double radiusMeters = radiusKm * 1000;
    List<Map<String, dynamic>> nearbyProviders = [];
    final snapshot = await FirebaseFirestore.instance
        .collection("userProvider")
        .where("shopType", isEqualTo: category)
        .get();

    for (var doc in snapshot.docs) {
      final data = doc.data();
      dynamic locationData = data["location"];
      if (locationData is! GeoPoint) continue;
      final GeoPoint gp = locationData;
      double lat = gp.latitude;
      double lng = gp.longitude;
      if (lat == 0.0 && lng == 0.0) continue;

      double distance = Geolocator.distanceBetween(
        userLoc.latitude,
        userLoc.longitude,
        lat,
        lng,
      );

      if (distance <= radiusMeters) {
        nearbyProviders.add({
          "id": doc.id,
          "name": data["name"] ?? data["ownerName"] ?? "Unknown Shop",
          "lat": lat,
          "lng": lng,
          "distance": distance,
          "services": data["services"] ?? {},
          "shopType": category,
        });
      }
    }

    nearbyProviders.sort((a, b) => a["distance"].compareTo(b["distance"]));
    if (nearbyProviders.length > limit) {
      return nearbyProviders.sublist(0, limit);
    }
    return nearbyProviders;
  }

  Future<Map<String, dynamic>?> getProviderProfile(String providerId) async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('userProvider')
          .doc(providerId)
          .get();
      if (doc.exists && doc.data() is Map) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['uid'] = doc.id;
        return data;
      }
    } catch (e) {
      debugPrint("Error fetching provider profile for $providerId: $e");
    }
    return null;
  }

  Future<void> _handleCategoryTap(String category) async {
    setState(() {
      _providersOnMap = [];
      _selectedShopProfile = null;
    });

    final providers = await getNearbyProviders(
      category,
      _currentLocation,
      radiusKm: 20.0,
      limit: 5,
    );

    if (providers.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No $category found near you within 20km")),
        );
      }
      return;
    }

    final closest = providers.first;
    LatLng target = LatLng(closest["lat"], closest["lng"]);
    setState(() {
      _providersOnMap = providers;
    });
    _mapController.move(target, 16);
  }

  Future<void> _handleShopTap(String providerId, double lat, double lng) async {
    setState(() {
      _isProfileLoading = true;
      _selectedShopProfile = null;
    });

    final profile = await getProviderProfile(providerId);
    if (mounted) {
      setState(() {
        _selectedShopProfile = profile;
        _isProfileLoading = false;
      });
      _mapController.move(LatLng(lat, lng), 18);
    }
  }

  List<Marker> _getMarkers() {
    List<Marker> markers = [];
    markers.add(
      Marker(
        point: _currentLocation,
        width: 60,
        height: 60,
        child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
      ),
    );

    for (var provider in _providersOnMap) {
      markers.add(
        Marker(
          point: LatLng(provider["lat"], provider["lng"]),
          width: 60,
          height: 60,
          child: Tooltip(
            message: provider["name"],
            child: const Icon(Icons.store_mall_directory,
                color: Colors.blue, size: 40),
          ),
        ),
      );
    }
    return markers;
  }

  Widget _buildShopProfileView() {
    if (_isProfileLoading) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
    }
    if (_selectedShopProfile == null) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(20),
              child: Text("Shop profile unavailable.")));
    }

    final profile = _selectedShopProfile!;
    final String shopName =
        profile["name"] ?? profile["ownerName"] ?? "Unknown Shop";
    final String ownerName = profile["ownerName"] ?? "N/A";
    final String phone = profile["contactNumber"] ?? "N/A";
    final String shopType = profile["shopType"] ?? "Service Provider";
    final String uid = profile["uid"] ?? "N/A";

    final dynamic locationData = profile["location"];
    double? shopLat;
    double? shopLng;

    if (locationData is GeoPoint) {
      shopLat = locationData.latitude;
      shopLng = locationData.longitude;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  shopName,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() => _selectedShopProfile = null);
                },
              ),
            ],
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.person, color: Colors.grey),
            title: const Text("Owner Name"),
            subtitle: Text(ownerName),
            dense: true,
          ),
          ListTile(
            leading: const Icon(Icons.work, color: Colors.grey),
            title: const Text("Service Type"),
            subtitle: Text(shopType),
            dense: true,
          ),

          ListTile(
            leading: const Icon(Icons.phone, color: Colors.grey),
            title: const Text("Contact"),
            subtitle: Text(phone),
            dense: true,
            onTap: phone != "N/A"
                ? () async {
              final Uri phoneUri = Uri.parse('tel:$phone');
              try {
                await launchUrl(
                  phoneUri,
                  mode: LaunchMode.externalApplication,
                );
              } catch (e) {
                debugPrint("Error launching dialer: $e");
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not open dialer. Please check permissions.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            }
                : null,
          ),
          const SizedBox(height: 20),

          if (shopLat != null && shopLng != null)
            Center(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.directions, size: 24),
                  label: const Text(
                    "Navigate to Shop",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 5,
                  ),
                  onPressed: () {
                    _openNavigation(shopLat!, shopLng!, shopName);
                  },
                ),
              ),
            ),
          const SizedBox(height: 10),

          Center(
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.group, size: 24),
                label: const Text(
                  "See Queue Now",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(2, 62, 138, 1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 5,
                ),
                onPressed: () {
                  if (_selectedShopProfile != null) {
                    String providerId = _selectedShopProfile!["uid"] ?? "";
                    if (providerId.isNotEmpty && providerId != "N/A") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ShopProfileScreen(providerId: providerId),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Error: Invalid Provider ID")),
                      );
                    }
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderListView(List<Map<String, dynamic>> providers) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text("Nearby Providers (Tap for Profile):",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: providers.length,
            itemBuilder: (context, index) {
              final provider = providers[index];
              final distanceKm = (provider["distance"] / 1000).toStringAsFixed(2);
              return ListTile(
                leading: const Icon(Icons.storefront, color: Colors.blue),
                title: Text(provider["name"],
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Distance: $distanceKm km"),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  _handleShopTap(
                      provider["id"], provider["lat"], provider["lng"]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDraggableSheet() {
    final List<Map<String, dynamic>> categories = [
      {
        "name": "Karyana Store",
        "shopType": "Karyana Store",
        "color": Colors.blue,
        "icon": Icons.local_grocery_store
      },
      {
        "name": "Barber",
        "shopType": "Barber",
        "color": Colors.green,
        "icon": Icons.content_cut
      },
      {
        "name": "Car Mechanic",
        "shopType": "Car Mechanic",
        "color": Colors.red,
        "icon": Icons.car_repair
      },
      {
        "name": "Bike Mechanic",
        "shopType": "Bike Mechanic",
        "color": Colors.orange,
        "icon": Icons.motorcycle
      },
      {
        "name": "Carpenter",
        "shopType": "Carpenter",
        "color": Colors.purple,
        "icon": Icons.carpenter
      },
    ];

    return DraggableScrollableSheet(
      initialChildSize: 0.10,
      minChildSize: 0.10,
      maxChildSize: _selectedShopProfile != null ? 0.9 : 0.6,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black26, blurRadius: 10, spreadRadius: 1)
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 45,
                  height: 5,
                  decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              if (_selectedShopProfile != null || _isProfileLoading)
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [_buildShopProfileView()],
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      const Text(
                        "Select a Category",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        height: 80,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: categories.length,
                          separatorBuilder: (_, __) =>
                          const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final item = categories[index];
                            return GestureDetector(
                              onTap: () =>
                                  _handleCategoryTap(item["shopType"]),
                              child: Container(
                                width: 140,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: item["color"].withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                  Border.all(color: item["color"], width: 2),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(item["icon"] as IconData,
                                        color: item["color"], size: 26),
                                    const SizedBox(height: 5),
                                    Text(item["name"],
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: item["color"])),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_providersOnMap.isNotEmpty)
                        SizedBox(
                          height: 400,
                          child: _buildProviderListView(_providersOnMap),
                        )
                      else
                        const Center(
                            child: Text(
                                "Select a category above to find nearby shops.")),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color.fromRGBO(2, 62, 138, 1),
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.red),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      _currentAddress,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w300,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Text(
              'HAZIR',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 30,
              ),
            ),
          ],
        ),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            Container(
              height: 80,
              color: const Color.fromRGBO(2, 62, 138, 1),
              alignment: Alignment.center,
              child: const Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                final User? currentUser = FirebaseAuth.instance.currentUser;
                if (currentUser != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ProfileScreen(userId: currentUser.uid),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("No user logged in!")),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SettingsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.confirmation_number),
              title: const Text('My Bookings'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const MyBookingsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.help),
              title: const Text('Help'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HelpScreen()),
                );
              },
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate:
                'https://api.maptiler.com/maps/basic-v2/{z}/{x}/{y}.png?key=S3Rrhs7ZQnmWbyTvy7Es',
                userAgentPackageName: 'com.example.hazir',
              ),
              MarkerLayer(
                markers: _getMarkers(),
              ),
            ],
          ),
          Positioned(
            top: 20,
            right: 20,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: _getUserLocation,
              child: _isLocating
                  ? const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location, color: Colors.black87),
            ),
          ),
          _buildDraggableSheet(),
        ],
      ),
    );
  }
}