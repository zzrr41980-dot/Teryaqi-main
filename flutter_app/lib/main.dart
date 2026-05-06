import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'auth.dart';
import 'home.dart';
import 'config/api_config.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  tz.initializeTimeZones();
  String timeZoneName = 'Asia/Riyadh'; // Default fallback
  try {
    final dynamic tzInfo = await FlutterTimezone.getLocalTimezone();
    if (tzInfo is String) {
      timeZoneName = tzInfo;
    } else {
      try { timeZoneName = tzInfo.name; } catch (_) { timeZoneName = tzInfo.toString(); }
    }
  } catch (e) {
    // Ignore and use fallback
  }

  try {
    tz.setLocalLocation(tz.getLocation(timeZoneName));
  } catch (e) {
    tz.setLocalLocation(tz.getLocation('Asia/Riyadh'));
  }
  
  // Initialize our Singleton NotificationService
  await NotificationService().init();
  
  runApp(const TeriaqiApp());
}

class TeriaqiApp extends StatelessWidget {
  const TeriaqiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'تِرياقي',
        builder: (context, child) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          );
        },
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF065F46)),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _requestPermissionsAndCheckAuth();
  }

  Future<void> _requestPermissionsAndCheckAuth() async {
    // Request Notifications and Exact Alarms natively
    await NotificationService().requestPermissions();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final p = await SharedPreferences.getInstance();
    final savedIp = p.getString('teryaqi_host_ip');
    if (savedIp != null) {
      ApiConfig.savedIp = savedIp;
    }
    
    final pid = p.getInt('teryaqi_patient_id');
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted) {
      if (pid != null) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WelcomeScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF065F46),
      body: Center(
        child: Image.asset(
          'assets/logotregy.png',
          width: 200,
          height: 200,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
