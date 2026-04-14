import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class MapPick extends StatefulWidget {
  final LatLng? initialLocation;
  const MapPick({super.key, this.initialLocation});

  @override
  State<MapPick> createState() => _MapPickState();
}

class _MapPickState extends State<MapPick> {
  final LatLng lahore = LatLng(31.5204, 74.3587);
  late LatLng pickedLocation;
  late final MapController mapController;
  String locationName = "";
  bool isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    mapController = MapController();
    
    if (widget.initialLocation != null &&
        (widget.initialLocation!.latitude != 0.0 ||
            widget.initialLocation!.longitude != 0.0)) {
      pickedLocation = widget.initialLocation!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        mapController.move(pickedLocation, 13.0);
        _updateLocationName(pickedLocation);
      });
    } else {
      pickedLocation = lahore;
      locationName = "Tap map to select location or use current location";
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled.')),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are denied.')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Location permissions are permanently denied, please enable them in settings.')),
      );
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final newLocation = LatLng(position.latitude, position.longitude);
      mapController.move(newLocation, 15.0);
      setState(() {
        pickedLocation = newLocation;
      });
      _updateLocationName(newLocation);
    } catch (e) {
      print("Error getting current location: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to get current location.')),
      );
    }
  }

  Future<void> _updateLocationName(LatLng latLng) async {
    if (latLng.latitude == 0.0 && latLng.longitude == 0.0) {
      setState(() {
        locationName = "Invalid coordinates selected.";
        isLoadingLocation = false;
      });
      return;
    }

    setState(() {
      isLoadingLocation = true;
    });

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
          setState(() {
            locationName = parts.join(', ');
          });
        } else {
          setState(() {
            locationName =
                "${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}";
          });
        }
      } else {
        setState(() {
          locationName =
              "${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}";
        });
      }
    } catch (e) {
      print("Error getting location name: $e");
      setState(() {
        locationName =
            "${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}";
      });
    } finally {
      setState(() {
        isLoadingLocation = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pick Location"),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, pickedLocation),
            icon: const Icon(Icons.check, color: Colors.black),
            label: const Text(
              "Confirm",
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: pickedLocation,
              initialZoom: 13,
              onTap: (tapPosition, point) {
                setState(() => pickedLocation = point);
                _updateLocationName(point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://api.maptiler.com/maps/basic-v2/{z}/{x}/{y}.png?key=S3Rrhs7ZQnmWbyTvy7Es',
                userAgentPackageName: 'com.example.hazir',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: pickedLocation,
                    width: 60,
                    height: 60,
                    child: const Icon(Icons.location_pin,
                        color: Colors.red, size: 40),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 20,
            right: 15,
            child: FloatingActionButton(
              heroTag: 'currentLocationBtn',
              onPressed: _getCurrentLocation,
              backgroundColor: Colors.blue.shade600,
              tooltip: 'Go to Current Location',
              child: const Icon(Icons.my_location, color: Colors.white),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 10,
            right: 10,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Icon(Icons.map, color: Colors.green),
                    SizedBox(width: 8),
                    Expanded(
                      child: isLoadingLocation
                          ? const Row(
                              children: [
                                SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                                SizedBox(width: 8),
                                Text("Fetching address..."),
                              ],
                            )
                          : Text(
                              locationName.isNotEmpty
                                  ? locationName
                                  : "Tap to select, or use 📍 button.",
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}