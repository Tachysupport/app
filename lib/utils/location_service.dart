import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/material.dart';

class LocationService {
  static Future<String> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return 'Location services disabled';
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return 'Location permission denied';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return 'Location permissions are permanently denied';
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Convert coordinates to address
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String location = _formatAddress(place);
        return location;
      } else {
        return '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      return 'Unable to get location';
    }
  }

  static String _formatAddress(Placemark place) {
    List<String> parts = [];

    // Prefer street-level address if available
    if (place.street?.isNotEmpty == true) {
      parts.add(place.street!);
    }
    if (place.subLocality?.isNotEmpty == true) {
      parts.add(place.subLocality!);
    }
    if (place.locality?.isNotEmpty == true) {
      parts.add(place.locality!);
    }
    if (place.administrativeArea?.isNotEmpty == true) {
      parts.add(place.administrativeArea!);
    }
    if (place.country?.isNotEmpty == true) {
      parts.add(place.country!);
    }

    // Return formatted address or fallback
    return parts.isNotEmpty ? parts.join(', ') : 'Unknown Location';
  }

  static Future<bool> requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }
}
