import 'package:cloud_firestore/cloud_firestore.dart';

class ProviderData {
  String? contactNumber;                
  // Map<String, dynamic>? customers;   
  List<dynamic>? customers;

  GeoPoint location;                    
  String email;
  String shopName;
  String ownerName;
  List<Map<String, dynamic>> rateList;       
  String description;
  bool isVerified;
  String? status;     

  final uid;       

  String? shopType;                  

  ProviderData({
    this.contactNumber,
    this.customers,
    required this.location,
    required this.email,
    required this.ownerName,
    required this.shopName,
    required this.rateList,
    required this.description,
    required this.isVerified,
    required this.status,
    required this.uid,
    required this.shopType,
  });

  factory ProviderData.fromMap(String? uid , Map<String, dynamic> data) {
    return ProviderData(
      uid: uid,
      contactNumber: data['contactNumber'],                   
      shopType: data.containsKey('shopType') ? data['shopType'] : null,
      customers: data['customers'],                           
      location: data['location'] is GeoPoint
      ? data['location']
      : const GeoPoint(0, 0),
      email: data['mail'] ?? '',                              
      ownerName: data['ownerName'] ?? '',                          
      shopName: data['name'] ?? '',                                                   
      description: data['description'] ?? '',
      isVerified: data['isVerified'] ?? false,
      status: data['status'] ?? 'Closed',
        rateList: (() {
        final value = data['rateList'];
        if (value is List) {
          return value.map((e) => Map<String, dynamic>.from(e)).toList();
        } else if (value is Map) {
          return [Map<String, dynamic>.from(value)];
        } else {
          return <Map<String, dynamic>>[];
        }
      })(),                     
    );
  }
}



