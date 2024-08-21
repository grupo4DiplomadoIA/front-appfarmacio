import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

const MAPBOX_ACCESS_TOKEN =
    'pk.eyJ1IjoiZ2FicmllbHNpcmIiLCJhIjoiY2xyOWZieDFmMDBmNjJrcnZ0NzB5bjJ0YiJ9.A37zj4N-0_SEjrFGFobGUA';

class Pharmacy {
  final String id;
  final String name;
  final LatLng location;
  final bool isOnDuty;
  final String address;
  final String phone;
  final String openingHours;

  Pharmacy({
    required this.id,
    required this.name,
    required this.location,
    this.isOnDuty = false,
    required this.address,
    required this.phone,
    required this.openingHours,
  });
}

class MapScreen extends StatefulWidget {
  final List<Map<String, dynamic>> pharmaciesData;

  const MapScreen({Key? key, required this.pharmaciesData}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController mapController = MapController();
  final LatLng initialPosition = LatLng(-37.444513, -72.336370);
  LatLng? myPosition;
  List<LatLng> routePoints = [];
  List<Pharmacy> pharmacies = [];
  List<Pharmacy> visiblePharmacies = [];

   @override
  void initState() {
    super.initState();
    getCurrentLocation().then((_) => _processPharmaciesData());
  }
  bool isPharmacyOpen(String openingHours) {
    final now = DateTime.now();
    final formatter = DateFormat('HH:mm:ss');
    final currentTime = formatter.format(now);
    
    final List<String> hours = openingHours.split(' - ');
    final openTime = hours[0];
    final closeTime = hours[1];
    
    if (openTime == '00:00:00' && closeTime == '23:59:00') {
      return true;
    }
    
    return currentTime.compareTo(openTime) >= 0 && currentTime.compareTo(closeTime) < 0;
  }

  void _processPharmaciesData() {
    List<Pharmacy> openPharmacies = [];
    Pharmacy? dutyPharmacy;

    for (var pharmacy in widget.pharmaciesData) {
      final newPharmacy = Pharmacy(
        id: pharmacy['local_id'],
        name: pharmacy['local_nombre'],
        location: LatLng(pharmacy['local_lat'], pharmacy['local_lng']),
        isOnDuty: pharmacy['is_on_duty'] ?? false,
        address: pharmacy['local_direccion'],
        phone: pharmacy['local_telefono'],
        openingHours: '${pharmacy['funcionamiento_hora_apertura']} - ${pharmacy['funcionamiento_hora_cierre']}',
      );

      if (newPharmacy.isOnDuty) {
        dutyPharmacy = newPharmacy;
        visiblePharmacies.add(newPharmacy);
      } else if (isPharmacyOpen(newPharmacy.openingHours)) {
        openPharmacies.add(newPharmacy);
        visiblePharmacies.add(newPharmacy);
      }

      pharmacies.add(newPharmacy);
    }

    openPharmacies.sort((a, b) {
      double distanceA = Geolocator.distanceBetween(
        myPosition!.latitude,
        myPosition!.longitude,
        a.location.latitude,
        a.location.longitude,
      );
      double distanceB = Geolocator.distanceBetween(
        myPosition!.latitude,
        myPosition!.longitude,
        b.location.latitude,
        b.location.longitude,
      );
      return distanceA.compareTo(distanceB);
    });

    setState(() {});

    if (openPharmacies.isNotEmpty) {
      _getRoute(openPharmacies[0].location);
    } else if (dutyPharmacy != null) {
      _getRoute(dutyPharmacy.location);
    }
  }
   Future<void> getCurrentLocation() async {
    Position position = await determinePosition();
    setState(() {
      myPosition = LatLng(position.latitude, position.longitude);
    });
  }
 Future<void> _getRoute(LatLng destination) async {
    final response = await http.get(Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/driving/${initialPosition.longitude},${initialPosition.latitude};${destination.longitude},${destination.latitude}?geometries=geojson&access_token=$MAPBOX_ACCESS_TOKEN'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final coords = data['routes'][0]['geometry']['coordinates'];
      setState(() {
        routePoints = coords.map<LatLng>((coord) => LatLng(coord[1], coord[0])).toList();
      });
    }
  }

 Future<Position> determinePosition() async {
    LocationPermission permission;
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('error');
      }
    }
    return await Geolocator.getCurrentPosition();
  }
 
 void _showPharmacyInfo(BuildContext context, Pharmacy pharmacy) {
    final bool isOpen = isPharmacyOpen(pharmacy.openingHours);
    
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Text(
                      pharmacy.name,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(Icons.close, size: 24),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Text('Dirección: ${pharmacy.address}'),
              GestureDetector(
                onTap: () => launch("tel:${pharmacy.phone}"),
                child: Text(
                  'Teléfono: ${pharmacy.phone}',
                  style: TextStyle(
                    color: Colors.blue,
                  ),
                ),
              ),
              Row(
                children: [
                  Text('Horario: ${pharmacy.openingHours}'),
                  SizedBox(width: 10),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOpen ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isOpen ? 'Abierto' : 'Cerrado',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Text(
                pharmacy.isOnDuty ? 'Farmacia de turno' : '',
                style: TextStyle(
                  color: pharmacy.isOnDuty ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
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
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              backgroundImage: AssetImage('assets/images/logo.png'),
              radius: 20,
            ),
            SizedBox(width: 8),
            Text("Farmacias"),
          ],
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              center: initialPosition,
              zoom: 13,
              minZoom: 5,
              maxZoom: 25,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://api.mapbox.com/styles/v1/{id}/tiles/{z}/{x}/{y}?access_token={accessToken}',
                additionalOptions: const {
                  'accessToken': MAPBOX_ACCESS_TOKEN,
                  'id': 'mapbox/streets-v12'
                },
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: routePoints,
                    strokeWidth: 2.0,
                    color: Colors.blue,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  ...visiblePharmacies.map((pharmacy) => Marker(
                        point: pharmacy.location,
                        width: 30,
                        height: 30,
                        child: GestureDetector(
                          onTap: () => _showPharmacyInfo(context, pharmacy),
                          child: pharmacy.isOnDuty
                              ? buildOnDutyPharmacyMarker()
                              : buildPharmacyMarker(),
                        ),
                      )),
                  if (myPosition != null)
                    Marker(
                      point: myPosition!,
                      width: 30,
                      height: 30,
                      child: const Icon(
                        Icons.fmd_good_rounded,
                        color: Colors.blueAccent,
                        size: 30,
                      ),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            right: 20,
            top: 20,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(104, 199, 193, 210).withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    children: [
                      IconButton(
                        icon: Icon(Icons.add, color: Colors.black),
                        onPressed: () {
                          mapController.move(
                              mapController.center, mapController.zoom + 1);
                        },
                      ),
                      Divider(height: 1, color: Colors.grey),
                      IconButton(
                        icon: Icon(Icons.remove, color: Colors.black),
                        onPressed: () {
                          mapController.move(
                              mapController.center, mapController.zoom - 1);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          mapController.move(initialPosition, 13);
        },
        child: Icon(Icons.my_location),
      ),
    );
  }
}

Widget buildPharmacyMarker() {
  return Stack(
    children: [
      const Icon(
        Icons.fmd_good,
        color: Colors.green,
        size: 25,
      )
    ],
  );
}

Widget buildOnDutyPharmacyMarker() {
  return Stack(
    children: [
      const Icon(
        Icons.fmd_good,
        color: Colors.red,
        size: 30,
      ),
      Positioned(
        right: 0,
        bottom: 0,
        child: Container(
          padding: EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          
        ),
      ),
    ],
  );
}