// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:geocoding/geocoding.dart';

// class LocationProvider extends ChangeNotifier {
//   String? currentAddress;
//   Position? currentPosition;
//   bool isLoading = false;

//   // Office coordinates
//   static const double officeLat = 13.118867; // example
//   static const double officeLng = 80.134060;

//   Future<void> fetchCurrentLocation() async {
//     isLoading = true;
//     notifyListeners();

//     try {
//       // Check permissions
//       bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//       if (!serviceEnabled) {
//         currentAddress = "Location services are disabled.";
//         return;
//       }

//       LocationPermission permission = await Geolocator.checkPermission();
//       if (permission == LocationPermission.denied) {
//         permission = await Geolocator.requestPermission();
//         if (permission == LocationPermission.denied) {
//           currentAddress = "Location permission denied.";
//           return;
//         }
//       }

//       if (permission == LocationPermission.deniedForever) {
//         currentAddress = "Location permission permanently denied.";
//         return;
//       }

//       // Get current position
//       try {
//   currentPosition = await Geolocator.getCurrentPosition(
//       desiredAccuracy: LocationAccuracy.high);
//   print("Position: ${currentPosition.latitude}, ${currentPosition.longitude}");
  
//   List<Placemark> placemarks = await placemarkFromCoordinates(
//       currentPosition!.latitude, currentPosition!.longitude);

//   Placemark place = placemarks.first;
//   currentAddress =
//       "${place.street}, ${place.locality}, ${place.administrativeArea}, ${place.country}";
//   print("Address: $currentAddress");
// } catch (e) {
//   currentAddress = "Unable to fetch location";
//   print("Error fetching location: $e");
// }

//     isLoading = false;
//     notifyListeners();
//   }

//   /// Check if user is within [maxDistance] meters of office
//   bool isWithinOffice({double maxDistance = 200}) {
//     if (currentPosition == null) return false;

//     double distanceInMeters = Geolocator.distanceBetween(
//       currentPosition!.latitude,
//       currentPosition!.longitude,
//       officeLat,
//       officeLng,
//     );

//     return distanceInMeters <= maxDistance;
//   }
// }
