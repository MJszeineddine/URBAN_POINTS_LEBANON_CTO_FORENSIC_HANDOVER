import 'package:geolocator/geolocator.dart';
import '../models/location.dart';

class LocationService {
  static const double DEFAULT_RADIUS_KM = 50.0;

  /// Request location permission from user
  static Future<bool> requestLocationPermission() async {
    try {
      final status = await Geolocator.checkPermission();
      
      if (status == LocationPermission.denied) {
        final result = await Geolocator.requestPermission();
        return result == LocationPermission.whileInUse || 
               result == LocationPermission.always;
      }
      
      if (status == LocationPermission.deniedForever) {
        await Geolocator.openLocationSettings();
        return false;
      }
      
      return true;
    } catch (e) {
      print('Error requesting location permission: $e');
      return false;
    }
  }

  /// Capture current user location (with fallback if denied)
  /// Returns null if permission denied and no fallback available
  static Future<UserLocation?> getCurrentLocation() async {
    try {
      final hasPermission = await requestLocationPermission();
      
      if (!hasPermission) {
        print('Location permission denied - using national catalog fallback');
        return null; // Fallback: national catalog
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      return UserLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        capturedAt: DateTime.now(),
      );
    } catch (e) {
      print('Error getting location: $e - using national catalog fallback');
      return null; // Fallback: national catalog
    }
  }

  /// Check if location is fresh (within 5 minutes)
  static bool isLocationFresh(UserLocation? location) {
    if (location == null) return false;
    
    final age = DateTime.now().difference(location.capturedAt);
    return age.inMinutes < 5;
  }

  /// Refresh location if stale
  static Future<UserLocation?> refreshLocationIfStale(UserLocation? location) async {
    if (!isLocationFresh(location)) {
      return await getCurrentLocation();
    }
    return location;
  }
}
