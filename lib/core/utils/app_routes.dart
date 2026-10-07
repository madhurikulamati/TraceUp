import 'package:flutter/material.dart';
import '../../models/device_model.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/devices/device_list_screen.dart';
import '../../screens/devices/device_details_screen.dart';
import '../../screens/devices/add_device_screen.dart';
import '../../screens/location/location_status_screen.dart';
import '../../screens/location/map_screen.dart';
import '../../screens/location/location_history_screen.dart';
import '../../screens/location/background_tracking_screen.dart';

class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String deviceList = '/devices';
  static const String addDevice = '/devices/add';
  static const String deviceDetails = '/devices/details';
  static const String location = '/location';
  static const String map = '/map';
  static const String locationHistory = '/devices/history';
  static const String backgroundTracking = '/location/background';

  static Map<String, WidgetBuilder> get routes => {
        splash: (context) => const SplashScreen(),
        login: (context) => const LoginScreen(),
        register: (context) => const RegisterScreen(),
        home: (context) => const HomeScreen(),
        deviceList: (context) => const DeviceListScreen(),
        addDevice: (context) => const AddDeviceScreen(),
        location: (context) => const LocationStatusScreen(),
        map: (context) => const MapScreen(),
        locationHistory: (context) => const LocationHistoryScreen(),
        backgroundTracking: (context) => const BackgroundTrackingScreen(),
      };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    if (settings.name == deviceDetails) {
      final args = settings.arguments;
      if (args is DeviceModel) {
        return MaterialPageRoute(
          builder: (context) => DeviceDetailsScreen(initialDevice: args),
        );
      } else if (args is int) {
        return MaterialPageRoute(
          builder: (context) => DeviceDetailsScreen(deviceId: args),
        );
      }
      return MaterialPageRoute(
        builder: (context) => const DeviceDetailsScreen(),
      );
    }

    if (settings.name == map) {
      final args = settings.arguments;
      if (args is DeviceModel) {
        return MaterialPageRoute(
          builder: (context) => MapScreen(device: args),
        );
      } else if (args is int) {
        return MaterialPageRoute(
          builder: (context) => MapScreen(deviceId: args),
        );
      }
      return MaterialPageRoute(
        builder: (context) => const MapScreen(),
      );
    }

    if (settings.name == locationHistory) {
      final args = settings.arguments;
      if (args is DeviceModel) {
        return MaterialPageRoute(
          builder: (context) => LocationHistoryScreen(device: args),
        );
      } else if (args is int) {
        return MaterialPageRoute(
          builder: (context) => LocationHistoryScreen(deviceId: args),
        );
      }
      return MaterialPageRoute(
        builder: (context) => const LocationHistoryScreen(),
      );
    }

    if (settings.name == backgroundTracking) {
      final args = settings.arguments;
      if (args is DeviceModel) {
        return MaterialPageRoute(
          builder: (context) => BackgroundTrackingScreen(device: args),
        );
      } else if (args is int) {
        return MaterialPageRoute(
          builder: (context) => BackgroundTrackingScreen(deviceId: args),
        );
      }
      return MaterialPageRoute(
        builder: (context) => const BackgroundTrackingScreen(),
      );
    }

    return null;
  }
}
