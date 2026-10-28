import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, SocketException;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:shared_preferences/shared_preferences.dart';
import 'admin_dashboard.dart';
import 'registration_screen.dart';

class ApiConfig {
  static String? customHost;

  static String get host {
    if (customHost != null && customHost!.trim().isNotEmpty) {
      return customHost!.trim();
    }
    if (kIsWeb) {
      return '127.0.0.1';
    }
    try {
      if (Platform.isAndroid) {
        return '127.0.0.1'; // We are using adb reverse
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  static String get baseUrl {
    try {
      if (Platform.isAndroid) {
        return 'http://127.0.0.1:8000'; // Uses the adb reverse tcp:8000 tcp:8000 tunnel from start_servers.bat
      }
    } catch (_) {}
    return 'http://$host:8000';
  }
  static String get loginUrl => '$baseUrl/api/mobile/login/';
  static String get registerUrl => '$baseUrl/api/mobile/register/';
  static String get signInScanUrl => '$baseUrl/signin/scan/';
  static String get checkinScanUrl => '$baseUrl/attendance/checkin/scan/';
  static String get checkoutScanUrl => '$baseUrl/attendance/checkout/scan/';
  static String get mobileCheckinUrl => '$baseUrl/api/mobile/checkin/';
  static String get mobileCheckoutUrl => '$baseUrl/api/mobile/checkout/';
  static String get profileUrl => '$baseUrl/api/mobile/profile/';
  static String get adminDashboardUrl => '$baseUrl/api/mobile/admin/dashboard/';
  static String get adminGeofenceGetUrl => '$baseUrl/api/mobile/admin/geofence/';
  static String get adminGeofenceUpdateUrl => '$baseUrl/api/mobile/admin/geofence/update/';
  static String get adminStudentsUrl => '$baseUrl/api/mobile/admin/students/';
  static String get adminStudentsImportUrl => '$baseUrl/api/mobile/admin/students/import/';
  static String adminStudentDeleteUrl(int id) => '$baseUrl/api/mobile/admin/students/$id/delete/';
  static String adminStudentUpdateUrl(int id) => '$baseUrl/api/mobile/admin/students/$id/update/';
  static String dashboardUrl(String name, [int? year, int? month]) {
    String query = 'name=${Uri.encodeComponent(name)}';
    if (year != null && month != null) {
      query += '&year=$year&month=$month';
    }
    return '$baseUrl/api/mobile/dashboard/?$query';
  }

  static String analyticsUrl(String name, [String? monthKey]) {
    final queryParam = monthKey != null && monthKey.isNotEmpty ? '&month=$monthKey' : '';
    return '$baseUrl/api/mobile/analytics/?name=${Uri.encodeComponent(name)}$queryParam';
  }
}

class LocationHelper {
  static double currentLat = 26.11807;
  static double currentLon = 91.81355;
  static double currentAccuracy = 145.0;
  static bool hasResolved = false;

  static Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );

      currentLat = position.latitude;
      currentLon = position.longitude;
      currentAccuracy = position.accuracy > 0 ? position.accuracy : 145.0;
      hasResolved = true;
      return position;
    } catch (_) {
      return null;
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  ApiConfig.customHost = prefs.getString('customHost');
  runApp(const AttendanceMobileApp());
}

class AttendanceMobileApp extends StatelessWidget {
  const AttendanceMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF1F5F9), // bg-gray-light equivalent
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const WelcomeScreen(),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Very light gray/white matching the image
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Color(0xFF94A3B8)),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const ApiSettingsDialog(),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              // Mobile Hero Icon with Badge
              SizedBox(
                width: 150,
                height: 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 150,
                      height: 150,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE0F7FA), // Light cyan
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.portrait_rounded, // Better face icon
                        color: Color(0xFF00E5FF), // Cyan
                        size: 72,
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 18,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E5FF), // Cyan
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFF8F9FA), width: 3),
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              
              // Hero Title
              const Text(
                'Attendance Pro',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  fontFamily: 'Roboto', 
                ),
              ),
              const SizedBox(height: 12),
              
              // Hero Description
              const Text(
                'Effortless check-ins with secure\nface recognition technology.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              
              // Sign In Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SignInScannerScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.login_rounded, size: 20),
                  label: const Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF), // Cyan
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9999),
                    ),
                  ).copyWith(
                    shadowColor: WidgetStateProperty.all(const Color(0xFF00E5FF).withValues(alpha: 0.4)),
                    elevation: WidgetStateProperty.resolveWith<double>(
                      (Set<WidgetState> states) {
                        if (states.contains(WidgetState.pressed)) return 4;
                        return 8; 
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Register Face Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const RegistrationScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                  label: const Text(
                    'Register Face',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A), // Dark text
                    backgroundColor: const Color(0xFFE2E8F0), // Light grey
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9999),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Forgot password link
              TextButton(
                onPressed: () {},
                child: const Text(
                  'Forgot your password?',
                  style: TextStyle(
                    color: Color(0xFF00E5FF), // Cyan
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Security Note
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline_rounded, color: Color(0xFF64748B), size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Securely encrypted biometric data',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SignInScannerScreen extends StatefulWidget {
  const SignInScannerScreen({super.key});

  @override
  State<SignInScannerScreen> createState() => _SignInScannerScreenState();
}

class _SignInScannerScreenState extends State<SignInScannerScreen> {
  CameraController? _cameraController;
  bool _hasPermission = false;
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkPermissionAndInitialize();
  }

  Future<void> _checkPermissionAndInitialize() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      await _initializeCamera();
    }
  }

  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      await _initializeCamera();
    } else {
      setState(() {
        _hasPermission = false;
        _errorMessage = 'Camera permission is required.';
      });
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No camera found.';
        });
        return;
      }
      
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _hasPermission = true;
          _errorMessage = '';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error initializing camera: ';
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _scanNow() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http
          .post(
            Uri.parse(ApiConfig.signInScanUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'image': base64Image,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => data['role'] == 'admin'
                ? const AdminDashboardScreen()
                : DashboardScreen(
                    userName: data['name'],
                    userRole: data['role'] ?? 'User',
                  ),
          ),
        );
      } else {
        setState(() {
          _errorMessage = data['error'] ?? data['message'] ?? 'Sign in failed.';
        });
      }
    } on TimeoutException {
      setState(() {
        _errorMessage = 'Connection timed out. Please ensure backend server is running.';
      });
    } on SocketException {
      setState(() {
        _errorMessage = 'Network error connecting to ${ApiConfig.baseUrl}. Make sure your server is running.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Sign in error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        centerTitle: true,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            color: Colors.transparent,
            padding: const EdgeInsets.all(16.0),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
          ),
        ),
        title: const Text(
          'Sign In',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: const Color(0xFFE2E8F0),
            height: 1.0,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Welcome Back',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF00D4FF),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Verify your identity to log your\nattendance for today.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              
              Container(
                width: 240,
                height: 240,
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black, // Dark background to verify if camera is rendering
                  border: Border.all(
                    color: const Color(0xFFEBF8FF),
                    width: 12,
                  ),
                ),
                child: _hasPermission && _cameraController != null
                    ? (_cameraController!.value.isInitialized
                        ? FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _cameraController!.value.previewSize?.height ?? 480,
                              height: _cameraController!.value.previewSize?.width ?? 640,
                              child: CameraPreview(_cameraController!),
                            ),
                          )
                        : const Center(child: CircularProgressIndicator(color: Colors.white)))
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 32),

              // Permission Box
              if (!_hasPermission) ...[
                GestureDetector(
                  onTap: _requestPermission,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF), // very light blue
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Text(
                      'Allow camera\npermission!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFDC2626), // red
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (_errorMessage.isNotEmpty) ...[
                Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],

              // Scan Now Button
              SizedBox(
                width: 200,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _hasPermission && !_isLoading ? _scanNow : null,
                  icon: _isLoading 
                    ? const SizedBox(
                        width: 20, height: 20, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      )
                    : const Icon(Icons.center_focus_strong_rounded, size: 20, color: Colors.white),
                  label: Text(
                    _isLoading ? 'Scanning...' : 'Scan Now',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007BFF),
                    disabledBackgroundColor: Colors.grey.shade400,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Having trouble
              const Text(
                'Having trouble with the camera?',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),

              // Manual Login Box
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ManualLoginScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.login_rounded, color: Color(0xFF64748B), size: 22),
                      const SizedBox(width: 12),
                      const Text(
                        'Manual Login',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 22),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),

              // Bottom section
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't have an account? ",
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: const Text(
                      'Register Now',
                      style: TextStyle(
                        color: Color(0xFF007BFF),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 16),
                  const SizedBox(width: 6),
                  const Text(
                    'Enterprise-grade biometric security active',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ManualLoginScreen extends StatefulWidget {
  const ManualLoginScreen({super.key});

  @override
  State<ManualLoginScreen> createState() => _ManualLoginScreenState();
}

class _ManualLoginScreenState extends State<ManualLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  bool _obscurePassword = true;

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Please fill in all fields';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.loginUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => data['role'] == 'admin'
                ? const AdminDashboardScreen()
                : DashboardScreen(
                    userName: data['name'],
                    userRole: data['role'] ?? 'User',
                  ),
          ),
        );
      } else {
        setState(() {
          _errorMessage = data['error'] ?? data['message'] ?? 'Login failed. Please check your credentials.';
        });
      }
    } on TimeoutException {
      setState(() {
        _errorMessage = 'Connection timed out. Make sure the backend server is running on port 8000.';
      });
    } on SocketException {
      setState(() {
        _errorMessage = 'Could not connect to ${ApiConfig.baseUrl}. Make sure your Django server is running.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Login error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        centerTitle: true,
        leading: GestureDetector(
          onTap: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
          child: Container(
            color: Colors.transparent,
            padding: const EdgeInsets.all(16.0),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
          ),
        ),
        title: const Text(
          'Manual Login',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: const Color(0xFFE2E8F0),
            height: 1.0,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: Column(
                  children: [
                    // Cyan Icon Box
                    Container(
                      width: 75,
                      height: 75,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00F0FF),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00F0FF).withValues(alpha: 0.4),
                            blurRadius: 25,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        color: Color(0xFF0F172A),
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Subtitle
                    const Text(
                      'Enter your credentials to continue',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (_errorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // Email Input Group
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Text(
                            'EMAIL',
                            style: TextStyle(
                              color: const Color(0xFF64748B),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              hintText: 'name@company.com',
                              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                              prefixIcon: const Icon(Icons.email_rounded, color: Color(0xFF94A3B8), size: 20),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 18),
                            ),
                            style: const TextStyle(color: Color(0xFF334155), fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Password Input Group
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Text(
                            'PASSWORD',
                            style: TextStyle(
                              color: const Color(0xFF64748B),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              hintText: '••••••••',
                              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                              prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFF94A3B8), size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                  color: const Color(0xFF94A3B8),
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 18),
                            ),
                            style: const TextStyle(color: Color(0xFF334155), fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Forgot Password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: Color(0xFF00BCD4),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00F0FF),
                          foregroundColor: const Color(0xFF0F172A),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9999),
                          ),
                        ).copyWith(
                          shadowColor: WidgetStateProperty.all(const Color(0xFF00F0FF).withValues(alpha: 0.4)),
                          elevation: WidgetStateProperty.resolveWith<double>(
                            (Set<WidgetState> states) {
                              if (states.contains(WidgetState.pressed)) return 4;
                              return 8; // Default elevation (simulates box-shadow)
                            },
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Color(0xFF0F172A),
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Face Recognition Link
                    TextButton.icon(
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => const SignInScannerScreen(),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.face_retouching_natural_rounded, color: Color(0xFF94A3B8), size: 18),
                      label: const Text(
                        'Use Face Recognition instead',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Not registered? ', style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const RegistrationScreen(),
                              ),
                            );
                          },
                          child: const Text('Sign Up', style: TextStyle(color: Color(0xFF00BCD4), fontSize: 14, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

class DashboardScreen extends StatefulWidget {
  final String userName;
  final String userRole;

  const DashboardScreen({
    super.key,
    required this.userName,
    required this.userRole,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  late Timer _timer;
  DateTime _currentTime = DateTime.now();

  // Settings state toggles
  bool _autoFaceRecognition = true;
  bool _livenessCheck = true;
  bool _gpsHighAccuracy = true;
  bool _morningReminder = true;
  bool _eveningReminder = true;
  bool _soundEffects = true;

  // Analytics / History State
  List<Map<String, dynamic>> _historyRecords = [];
  bool _isLoadingAnalytics = true;
  String _totalHours = "0.0";
  double _totalHoursProgress = 0.0;
  String _avgStart = "--:--";
  String _avgStartPeriod = "";
  bool _avgIsOnTime = true;
  String _selectedMonthName = "All Records";
  String? _selectedMonthKey;
  List<Map<String, dynamic>> _availableMonths = [];
  bool _showAllRecords = false;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // Dynamic Dashboard / Home State
  double _weeklyHours = 0.0;
  String _weeklyHoursText = "0.0 Hrs";
  int _goalProgressPct = 0;
  double _hoursLeft = 40.0;
  String _hoursLeftText = "40.0 hours left to reach your weekly goal.";
  DateTime _selectedCalendarMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  List<int> _presentDays = [];
  List<Map<String, dynamic>> _recentDashboardLogs = [];
  bool _isDashboardLoading = true;

  // Live Location State
  double _currentLat = LocationHelper.currentLat;
  double _currentLon = LocationHelper.currentLon;
  double _currentAcc = LocationHelper.currentAccuracy;
  bool _isLocationLoading = false;
  StreamSubscription<Position>? _positionStreamSub;
  final MapController _mapController = MapController();

  // Dynamic Profile State
  String _profileFullName = "Amartya";
  String _profileDob = "May 15, 1992";
  String _profileGender = "Male";
  String _profileEmail = "amartyakalita2004@gmail.com";
  String _profileRole = "Employee";
  bool _isLoadingProfile = false;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    _fetchAnalyticsData();
    _fetchProfileData();
    _fetchLiveLocation();
    _initLiveLocationStream();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });
  }

  Future<void> _fetchProfileData() async {
    setState(() {
      _isLoadingProfile = true;
    });
    try {
      final url = Uri.parse(
        '${ApiConfig.profileUrl}?name=${Uri.encodeComponent(widget.userName)}',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic>) {
          setState(() {
            _profileFullName = data['full_name']?.toString() ?? data['name']?.toString() ?? widget.userName;
            _profileDob = data['dob_formatted']?.toString() ?? data['dob_display']?.toString() ?? "May 15, 1992";
            _profileGender = data['gender']?.toString() ?? "Male";
            _profileEmail = data['email']?.toString() ?? "amartyakalita2004@gmail.com";
            _profileRole = data['role_label']?.toString() ?? (data['role']?.toString() ?? widget.userRole).toUpperCase();
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }


  @override
  void dispose() {
    _timer.cancel();
    _positionStreamSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasCheckedInToday {
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    
    for (var log in _recentDashboardLogs) {
      final date = log['date']?.toString();
      final dateDisplay = log['date_display']?.toString();
      
      if (date == todayStr || dateDisplay == 'Today') {
        if (log['check_in'] != null && log['check_in'].toString().isNotEmpty) {
          return true;
        }
      }
    }
    return false;
  }

  bool get _hasCheckedOutToday {
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    
    for (var log in _recentDashboardLogs) {
      final date = log['date']?.toString();
      final dateDisplay = log['date_display']?.toString();
      
      if (date == todayStr || dateDisplay == 'Today') {
        if (log['check_out'] != null && log['check_out'].toString().isNotEmpty && log['check_out'].toString() != '--:--') {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> _fetchDashboardData({int? year, int? month}) async {
    final y = year ?? _selectedCalendarMonth.year;
    final m = month ?? _selectedCalendarMonth.month;

    setState(() {
      _isDashboardLoading = true;
    });

    try {
      final uri = Uri.parse(ApiConfig.dashboardUrl(widget.userName, y, m));
      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List<dynamic> recs = data['history'] ?? [];
          final List<dynamic> rawPresent = data['present_days'] ?? [];

          if (mounted) {
            setState(() {
              _weeklyHours = (data['weekly_hours'] as num?)?.toDouble() ?? 0.0;
              _weeklyHoursText = data['weekly_hours_text']?.toString() ?? "${_weeklyHours.toStringAsFixed(1)} Hrs";
              _goalProgressPct = (data['goal_progress_pct'] as num?)?.toInt() ?? 0;
              _hoursLeft = (data['hours_left'] as num?)?.toDouble() ?? 40.0;
              _hoursLeftText = data['hours_left_text']?.toString() ?? "${_hoursLeft.toStringAsFixed(1)} hours left to reach your weekly goal.";
              _presentDays = rawPresent.map((e) => (e as num).toInt()).toList();
              _recentDashboardLogs = recs.map((e) => Map<String, dynamic>.from(e)).toList();

              if (data['geofence'] != null && !LocationHelper.hasResolved) {
                final geo = data['geofence'];
                if (geo['latitude'] != null && geo['longitude'] != null) {
                  _currentLat = (geo['latitude'] as num).toDouble();
                  _currentLon = (geo['longitude'] as num).toDouble();
                }
              }
            });
          }
        }
      }
    } catch (_) {
      // Graceful fallback
    } finally {
      if (mounted) {
        setState(() {
          _isDashboardLoading = false;
        });
      }
    }
  }

  Future<void> _fetchLiveLocation() async {
    if (!mounted) return;
    setState(() {
      _isLocationLoading = true;
    });

    try {
      final pos = await LocationHelper.getCurrentLocation();
      if (pos != null && mounted) {
        setState(() {
          _currentLat = pos.latitude;
          _currentLon = pos.longitude;
          _currentAcc = pos.accuracy > 0 ? pos.accuracy : 145.0;
        });
        _mapController.move(LatLng(_currentLat, _currentLon), 15.0);
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _isLocationLoading = false;
        });
      }
    }
  }

  void _initLiveLocationStream() {
    try {
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      );
      _positionStreamSub = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
        if (mounted) {
          setState(() {
            _currentLat = position.latitude;
            _currentLon = position.longitude;
            _currentAcc = position.accuracy > 0 ? position.accuracy : 145.0;
          });
        }
      });
    } catch (_) {}
  }

  void _previousMonth() {
    setState(() {
      _selectedCalendarMonth = DateTime(
        _selectedCalendarMonth.year,
        _selectedCalendarMonth.month - 1,
        1,
      );
    });
    _fetchDashboardData(
      year: _selectedCalendarMonth.year,
      month: _selectedCalendarMonth.month,
    );
  }

  void _nextMonth() {
    setState(() {
      _selectedCalendarMonth = DateTime(
        _selectedCalendarMonth.year,
        _selectedCalendarMonth.month + 1,
        1,
      );
    });
    _fetchDashboardData(
      year: _selectedCalendarMonth.year,
      month: _selectedCalendarMonth.month,
    );
  }

  String _getMonthName(int month) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return names[(month - 1).clamp(0, 11)];
  }

  Future<void> _openAttendanceScanner(bool isCheckOut) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AttendanceScannerScreen(isCheckOut: isCheckOut),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${isCheckOut ? "Checked out" : "Checked in"} successfully!',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      _fetchDashboardData();
      _fetchAnalyticsData();
    }
  }

  Future<void> _fetchAnalyticsData({String? monthKey}) async {
    setState(() {
      _isLoadingAnalytics = true;
    });

    try {
      final uri = Uri.parse(ApiConfig.analyticsUrl(widget.userName, monthKey));
      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List<dynamic> recs = data['records'] ?? [];
          final List<dynamic> rawMonths = data['available_months'] ?? [];

          setState(() {
            _totalHours = data['total_hours']?.toString() ?? "0.0";
            _totalHoursProgress = (data['total_hours_progress'] as num?)?.toDouble() ?? 0.0;
            _avgStart = data['avg_start']?.toString() ?? "--:--";
            _avgStartPeriod = data['avg_start_period']?.toString() ?? "";
            _avgIsOnTime = data['avg_is_on_time'] == true;
            _selectedMonthName = data['selected_month']?.toString() ?? "All Records";
            _selectedMonthKey = monthKey;

            _availableMonths = rawMonths.map((e) => Map<String, dynamic>.from(e)).toList();
            _historyRecords = recs.map((e) => Map<String, dynamic>.from(e)).toList();
          });
          return;
        }
      }
    } catch (e) {
      // Network error handled cleanly
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAnalytics = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _getFilteredRecords() {
    if (_searchQuery.isEmpty) {
      return _historyRecords;
    }
    return _historyRecords.where((rec) {
      final dateStr = (rec['date_display'] ?? '').toString().toLowerCase();
      final shiftStr = (rec['shift'] ?? '').toString().toLowerCase();
      final statusStr = (rec['status'] ?? '').toString().toLowerCase();
      return dateStr.contains(_searchQuery) || shiftStr.contains(_searchQuery) || statusStr.contains(_searchQuery);
    }).toList();
  }

  void _openMonthPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        final options = [
          {"key": "all", "label": "All Records"},
          ..._availableMonths,
        ];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Period',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...options.map((monthOpt) {
                  final isSelected = _selectedMonthName == monthOpt['label'];
                  return InkWell(
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _fetchAnalyticsData(monthKey: monthOpt['key']);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFE0F9FD) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF0066FF) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_month_outlined,
                            size: 18,
                            color: isSelected ? const Color(0xFF0066FF) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            monthOpt['label'] ?? '',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? const Color(0xFF0066FF) : const Color(0xFF1E293B),
                            ),
                          ),
                          const Spacer(),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF0066FF), size: 20),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 24),
              SizedBox(width: 10),
              Text(
                'Log Out',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to log out of your session?',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String hours = _twoDigits(_currentTime.hour);
    String minutes = _twoDigits(_currentTime.minute);
    String seconds = _twoDigits(_currentTime.second);

    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    String weekday = days[_currentTime.weekday - 1];
    String month = months[_currentTime.month - 1];
    int day = _currentTime.day;
    String year = _currentTime.year.toString();

    String daySuffix;
    if (day >= 11 && day <= 13) {
      daySuffix = 'th';
    } else {
      switch (day % 10) {
        case 1: daySuffix = 'st'; break;
        case 2: daySuffix = 'nd'; break;
        case 3: daySuffix = 'rd'; break;
        default: daySuffix = 'th';
      }
    }

    String dateStr = '$weekday, $month $day$daySuffix, $year';

    return Scaffold(
      backgroundColor: _currentIndex == 2 ? const Color(0xFFEEF4FA) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: _currentIndex == 2 ? const Color(0xFFEEF4FA) : const Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: _currentIndex == 1
            ? Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFDEC9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(Icons.person_rounded, color: Color(0xFFC2410C), size: 22),
                    ),
                  ),
                ),
              )
            : null,
        title: _currentIndex == 1
            ? const Text(
                'Attendance History',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              )
            : Row(
                children: [
                  const Icon(Icons.check_box_outlined, color: Color(0xFF0066FF), size: 28),
                  const SizedBox(width: 8),
                  Text(
                    _getAppBarTitle(),
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
        actions: _currentIndex == 1
            ? [
                IconButton(
                  icon: Icon(
                    _isSearching ? Icons.close_rounded : Icons.search_rounded,
                    color: const Color(0xFF64748B),
                    size: 24,
                  ),
                  onPressed: () {
                    setState(() {
                      _isSearching = !_isSearching;
                      if (!_isSearching) {
                        _searchQuery = '';
                        _searchController.clear();
                      }
                    });
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: IconButton(
                    icon: const Icon(Icons.notifications_rounded, color: Color(0xFF0066FF), size: 24),
                    onPressed: () {},
                  ),
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF1E293B)),
                  onPressed: () {},
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentIndex = 2; // Switch to Profile tab
                    });
                  },
                  child: const Padding(
                    padding: EdgeInsets.only(right: 16.0, left: 8.0),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFFEFF6FF),
                      child: Icon(Icons.person, color: Color(0xFF0066FF)),
                    ),
                  ),
                ),
              ],
      ),
      body: _buildBody(hours, minutes, seconds, dateStr),
      bottomNavigationBar: _buildCustomBottomNav(),
    );
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'AttendancePro';
      case 1:
        return 'Attendance History';
      case 2:
        return 'Profile';
      case 3:
        return 'Settings';
      default:
        return 'AttendancePro';
    }
  }

  Widget _buildBody(String hours, String minutes, String seconds, String dateStr) {
    switch (_currentIndex) {
      case 0:
        return _buildHomeScreen(hours, minutes, seconds, dateStr);
      case 1:
        return _buildAnalyticsScreen();
      case 2:
        return _buildProfileScreen();
      case 3:
        return _buildSettingsScreen();
      default:
        return _buildHomeScreen(hours, minutes, seconds, dateStr);
    }
  }

  // ==================== 1. HOME SCREEN ====================
  Widget _buildHomeScreen(String hours, String minutes, String seconds, String dateStr) {
    return RefreshIndicator(
      onRefresh: () async {
        await _fetchDashboardData();
        await _fetchLiveLocation();
      },
      color: const Color(0xFF0066FF),
      backgroundColor: Colors.white,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isDashboardLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: LinearProgressIndicator(
                  minHeight: 2.5,
                  color: Color(0xFF0066FF),
                  backgroundColor: Colors.transparent,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Welcome back, ${widget.userName}',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "It's a productive day! Check in to start your session.",
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),

            // 1. CURRENT LOCAL TIME CARD (Restored Clock)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 30,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'CURRENT LOCAL TIME',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTimeBlock(hours, 'HOURS', false),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(':', style: TextStyle(fontSize: 36, color: Color(0xFFCBD5E1), fontWeight: FontWeight.w600)),
                      ),
                      _buildTimeBlock(minutes, 'MINUTES', false),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(':', style: TextStyle(fontSize: 36, color: Color(0xFFCBD5E1), fontWeight: FontWeight.w600)),
                      ),
                      _buildTimeBlock(seconds, 'SECONDS', true),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    dateStr,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. Action Buttons (Check In / Check Out)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (_hasCheckedInToday) {
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Top row with close button
                                  Align(
                                    alignment: Alignment.topRight,
                                    child: InkWell(
                                      onTap: () => Navigator.pop(context),
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close, size: 18, color: Colors.black54),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // Icon
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Container(
                                        width: 72,
                                        height: 72,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFE8F1FF), // Light blue background
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.history_toggle_off, color: Color(0xFF0066FF), size: 32),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0066FF),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 3),
                                          ),
                                          child: const Icon(Icons.check, color: Colors.white, size: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  // Title
                                  const Text(
                                    'Already Checked In',
                                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                  ),
                                  const SizedBox(height: 12),
                                  // Message
                                  const Text(
                                    'You have already checked in for today. Next window opens at 05:00 PM.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5),
                                  ),
                                  const SizedBox(height: 28),
                                  // Button
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () => Navigator.pop(context),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF0066FF),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      ),
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text('Got It', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                          SizedBox(width: 8),
                                          Icon(Icons.arrow_forward, size: 18),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      } else {
                        _openAttendanceScanner(false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0066FF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      shadowColor: const Color(0xFF0066FF).withValues(alpha: 0.3),
                    ).copyWith(
                      elevation: WidgetStateProperty.all(6),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.login_rounded, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Check In',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: OutlinedButton(
                    onPressed: (_hasCheckedInToday && !_hasCheckedOutToday) ? () => _openAttendanceScanner(true) : null,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0066FF),
                      disabledForegroundColor: Colors.grey.shade400,
                      side: BorderSide(
                        color: (_hasCheckedInToday && !_hasCheckedOutToday) ? const Color(0xFF0066FF) : Colors.grey.shade300, 
                        width: 2
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Check Out',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // 3. Recent Logs Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Logs',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _currentIndex = 1; // Switch to Analytics/History
                    });
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'VIEW ALL',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0066FF),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (_recentDashboardLogs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: const Center(
                  child: Text(
                    'No attendance logs recorded yet for this period.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  ),
                ),
              )
            else
              ..._recentDashboardLogs.take(3).expand((item) {
                final checkInStr = item['check_in'] as String?;
                final checkOutStr = item['check_out'] as String?;
                final dateDisplay = item['date_display']?.toString() ?? item['date']?.toString() ?? 'Today';

                List<Widget> logs = [];

                logs.add(_buildLogItem(
                  isCheckIn: true,
                  time: (item['status'] == 'OUT OF RADIUS') ? '--:--' : (checkInStr ?? '--:--'),
                  date: dateDisplay,
                ));

                if (checkOutStr != null) {
                  logs.add(_buildLogItem(
                    isCheckIn: false,
                    time: (item['status'] == 'OUT OF RADIUS') ? '--:--' : checkOutStr,
                    date: dateDisplay,
                  ));
                }
                return logs;
              }),
            const SizedBox(height: 24),

            // 4. THIS WEEK CARD (Placed below Recent Logs as requested)
            _buildWeeklyHoursCard(),
            const SizedBox(height: 20),

            // 5. ATTENDANCE LOG (CALENDAR) CARD
            _buildAttendanceLogCard(),
            const SizedBox(height: 20),

            // 6. LIVE LOCATION CARD
            _buildLiveLocationCard(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeBlock(String value, String label, bool isAccent) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.w900,
            color: isAccent ? const Color(0xFF0066FF) : const Color(0xFF1E293B),
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF94A3B8),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // --- THIS WEEK CARD ---
  Widget _buildWeeklyHoursCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0066FF), // Royal Blue as in user image
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0066FF).withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'THIS WEEK',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const Icon(
                Icons.bar_chart_rounded,
                color: Colors.white,
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _weeklyHoursText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'GOAL PROGRESS',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
              Text(
                '$_goalProgressPct%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 6,
              color: Colors.white.withValues(alpha: 0.25),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: (_goalProgressPct / 100.0).clamp(0.0, 1.0),
                  child: Container(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _hoursLeftText,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // --- ATTENDANCE LOG (CALENDAR) CARD ---
  Widget _buildAttendanceLogCard() {
    final monthName = _getMonthName(_selectedCalendarMonth.month);
    final year = _selectedCalendarMonth.year;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Attendance Log',
                style: TextStyle(
                  color: Color(0xFF0066FF),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              Row(
                children: [
                  InkWell(
                    onTap: _previousMonth,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(Icons.chevron_left_rounded, color: Color(0xFF334155), size: 22),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _nextMonth,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(Icons.chevron_right_rounded, color: Color(0xFF334155), size: 22),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$monthName $year',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),

          // Days of week header (SU..SA)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _CalendarHeaderCell('SU'),
              _CalendarHeaderCell('MO'),
              _CalendarHeaderCell('TU'),
              _CalendarHeaderCell('WE'),
              _CalendarHeaderCell('TH'),
              _CalendarHeaderCell('FR'),
              _CalendarHeaderCell('SA'),
            ],
          ),
          const SizedBox(height: 12),

          // Calendar Grid
          _buildCalendarGrid(),

          const SizedBox(height: 20),

          // Legend
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981), // Emerald Green
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Successful Attendance',
                style: TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFF94A3B8), // Slate Grey
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Absent',
                style: TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final year = _selectedCalendarMonth.year;
    final month = _selectedCalendarMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    // Sunday is 0, Monday is 1, ..., Saturday is 6
    final firstDayWeekday = DateTime(year, month, 1).weekday % 7;

    final now = DateTime.now();

    List<Widget> dayWidgets = [];

    // Empty leading cells for Sunday alignment
    for (int i = 0; i < firstDayWeekday; i++) {
      dayWidgets.add(const SizedBox(height: 36));
    }

    for (int d = 1; d <= daysInMonth; d++) {
      final isPresent = _presentDays.contains(d);
      
      final cellDate = DateTime(year, month, d);
      final todayDate = DateTime(now.year, now.month, now.day);
      final isPastWeekday = cellDate.isBefore(todayDate) && cellDate.weekday <= 5;
      final isAbsent = isPastWeekday && !isPresent;

      BoxDecoration? decoration;
      Color textColor = const Color(0xFF1E293B);
      FontWeight fontWeight = FontWeight.w600;

      if (isPresent) {
        decoration = BoxDecoration(
          color: const Color(0xFF10B981), // Emerald Green
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        );
        textColor = Colors.white;
        fontWeight = FontWeight.w800;
      } else if (isAbsent) {
        decoration = BoxDecoration(
          color: const Color(0xFF94A3B8), // Slate Grey
          borderRadius: BorderRadius.circular(8),
        );
        textColor = Colors.white;
        fontWeight = FontWeight.w800;
      }

      dayWidgets.add(
        Center(
          child: Container(
            width: 36,
            height: 36,
            decoration: decoration,
            alignment: Alignment.center,
            child: Text(
              '$d',
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: fontWeight,
              ),
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 4,
      children: dayWidgets,
    );
  }

  // --- LIVE LOCATION CARD ---
  Widget _buildLiveLocationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF), // Light blue circle
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.location_on,
                    color: Color(0xFF0066FF),
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Live Location',
                      style: TextStyle(
                        color: Color(0xFF0066FF),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Lat ${_currentLat.toStringAsFixed(5)}, Lon ${_currentLon.toStringAsFixed(5)} ±${_currentAcc.toStringAsFixed(0)}m',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: _isLocationLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0066FF)),
                      )
                    : const Icon(Icons.my_location_rounded, color: Color(0xFF0066FF), size: 20),
                onPressed: _fetchLiveLocation,
                tooltip: 'Update Live Location',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Map Visual Container
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFE9ECEF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(_currentLat, _currentLon),
                  initialZoom: 15.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                    userAgentPackageName: 'com.example.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(_currentLat, _currentLon),
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on,
                          color: Color(0xFFEA4335),
                          size: 38,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem({required bool isCheckIn, required String time, required String date}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF8FAFC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isCheckIn ? const Color(0xFFE8FBFF) : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCheckIn ? Icons.login_rounded : Icons.logout_rounded,
              color: isCheckIn ? const Color(0xFF0066FF) : const Color(0xFF94A3B8),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCheckIn ? 'Checked In' : 'Checked Out',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isCheckIn ? const Color(0xFFE0FBEA) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              time,
              style: TextStyle(
                color: isCheckIn ? const Color(0xFF00B368) : const Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 2. ANALYTICS / HISTORY SCREEN ====================
  Widget _buildAnalyticsScreen() {
    final displayRecords = _getFilteredRecords();
    final recordsToShow = _showAllRecords ? displayRecords : displayRecords.take(4).toList();

    return RefreshIndicator(
      onRefresh: () => _fetchAnalyticsData(monthKey: _selectedMonthKey),
      color: const Color(0xFF00BCD4),
      backgroundColor: Colors.white,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Input if active
            if (_isSearching) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.toLowerCase();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by date, status, or shift...',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF00BCD4), size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],

            // Top Two Metric Cards (TOTAL HOURS & AVG. START)
            Row(
              children: [
                // Card 1: TOTAL HOURS
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.025),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TOTAL HOURS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 10),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '$_totalHours ',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                  fontFamily: 'Roboto',
                                ),
                              ),
                              const TextSpan(
                                text: 'hrs',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                  fontFamily: 'Roboto',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          height: 6,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: _totalHoursProgress.clamp(0.1, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF00C8E5),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Card 2: AVG. START
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.025),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AVG. START',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 10),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '$_avgStart ',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                  fontFamily: 'Roboto',
                                ),
                              ),
                              TextSpan(
                                text: _avgStartPeriod,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                  fontFamily: 'Roboto',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _avgIsOnTime ? const Color(0xFFE0F9FD) : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _avgIsOnTime ? 'ON TIME' : 'LATE',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: _avgIsOnTime ? const Color(0xFF00BCD4) : const Color(0xFFEF4444),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Month Header Row (e.g. October 2023 & Select Month Button)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedMonthName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                GestureDetector(
                  onTap: _openMonthPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAEFF4),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.calendar_month_outlined, size: 16, color: Color(0xFF475569)),
                        SizedBox(width: 8),
                        Text(
                          'Select Month',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Daily Attendance History Record Cards
            if (_isLoadingAnalytics)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(color: Color(0xFF00BCD4)),
                ),
              )
            else if (recordsToShow.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.event_busy_rounded, size: 48, color: Color(0xFF94A3B8)),
                    SizedBox(height: 12),
                    Text(
                      'No records found for this period',
                      style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B), fontSize: 15),
                    ),
                  ],
                ),
              )
            else
              ...recordsToShow.map((rec) => _buildHistoryRecordCard(rec)),

            const SizedBox(height: 12),

            // "Show Previous Records" Button
            if (displayRecords.length > 4)
              Center(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _showAllRecords = !_showAllRecords;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  ),
                  child: Text(
                    _showAllRecords ? 'Show Less Records' : 'Show Previous Records',
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryRecordCard(Map<String, dynamic> rec) {
    final status = rec['status']?.toString() ?? 'ON TIME';
    final isOnTime = status == 'ON TIME';
    final isLate = status == 'LATE';

    Color chipBgColor = const Color(0xFFE0F9FD);
    Color chipTextColor = const Color(0xFF00BCD4);

    if (isLate) {
      chipBgColor = const Color(0xFFFEE2E2);
      chipTextColor = const Color(0xFFEF4444);
    } else if (!isOnTime) {
      chipBgColor = const Color(0xFFF1F5F9);
      chipTextColor = const Color(0xFF64748B);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Date & Status Chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rec['date_display'] ?? 'Date',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    rec['shift'] ?? 'Regular Shift',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4.5),
                decoration: BoxDecoration(
                  color: chipBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: chipTextColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Bottom 2-Column Metrics (CLOCK IN, CLOCK OUT)
          Row(
            children: [
              // CLOCK IN
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CLOCK IN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rec['status'] == 'OUT OF RADIUS' ? '--:--' : (rec['check_in'] ?? '--:--'),
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),

              // CLOCK OUT
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'CLOCK OUT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rec['status'] == 'OUT OF RADIUS' ? '--:--' : (rec['check_out'] ?? '--:--'),
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== 3. PROFILE SCREEN ====================
  Widget _buildProfileScreen() {
    return RefreshIndicator(
      onRefresh: _fetchProfileData,
      color: const Color(0xFF0A7DFF),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 18),
              // Top Avatar with Blue Camera Button Badge
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 98,
                      height: 98,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF0F172A),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x1F0F172A),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.person_rounded,
                          size: 58,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _showEditProfileModal,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF007AFF),
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF007AFF).withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.camera_alt_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // User Name
              Text(
                _profileFullName,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Edit profile Button
              GestureDetector(
                onTap: _showEditProfileModal,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A7DFF),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0A7DFF).withValues(alpha: 0.32),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_rounded, color: Colors.white, size: 15),
                      SizedBox(width: 7),
                      Text(
                        'Edit profile',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isLoadingProfile)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    color: Color(0xFF0A7DFF),
                    backgroundColor: Colors.transparent,
                  ),
                ),
              const SizedBox(height: 12),

              // Personal Information Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: const Color(0xFFE2E8F0).withValues(alpha: 0.6)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card Title Row
                    const Row(
                      children: [
                        Icon(Icons.person_rounded, size: 20, color: Color(0xFF0F172A)),
                        SizedBox(width: 10),
                        Text(
                          'Personal Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // Row 1: FULLNAME and DATE OF BIRTH
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildProfileCardField('FULLNAME', _profileFullName),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildProfileCardField('DATE OF BIRTH', _profileDob),
                        ),
                      ],
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                    ),

                    // Row 2: GENDER
                    _buildProfileCardField('GENDER', _profileGender),
                    const SizedBox(height: 18),

                    // Row 3: EMAIL ADDRESS
                    _buildProfileCardField('EMAIL ADDRESS', _profileEmail, isEmail: true),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                    ),

                    // Row 4: ACCOUNT ROLE
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ACCOUNT ROLE',
                          style: TextStyle(
                            color: Color(0xFF0084FF),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            _profileRole,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              // Optional subtle logout button
              Center(
                child: TextButton.icon(
                  onPressed: _showLogoutDialog,
                  icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 16),
                  label: const Text(
                    'Log Out',
                    style: TextStyle(color: Color(0xFFEF4444), fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCardField(String label, String value, {bool isEmail = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF0084FF),
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            fontSize: isEmail ? 14.5 : 16,
            fontWeight: isEmail ? FontWeight.w600 : FontWeight.w800,
            color: isEmail ? const Color(0xFF334155) : const Color(0xFF0F172A),
            height: 1.25,
          ),
        ),
      ],
    );
  }

  void _showEditProfileModal() {
    final nameCtrl = TextEditingController(text: _profileFullName);
    final dobCtrl = TextEditingController(text: _profileDob);
    final emailCtrl = TextEditingController(text: _profileEmail);
    String selectedGender = _profileGender;
    String selectedRole = _profileRole;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 24,
              left: 24,
              right: 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Edit Profile',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: dobCtrl,
                    decoration: InputDecoration(
                      labelText: 'Date of Birth (e.g. May 15, 1992)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      prefixIcon: const Icon(Icons.calendar_today_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: ['Male', 'Female', 'Other'].contains(selectedGender) ? selectedGender : 'Male',
                    decoration: InputDecoration(
                      labelText: 'Gender',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      prefixIcon: const Icon(Icons.people_outline_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Male', child: Text('Male')),
                      DropdownMenuItem(value: 'Female', child: Text('Female')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedGender = val);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: emailCtrl,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: ['Employee', 'Student', 'Teacher', 'Admin'].contains(selectedRole) ? selectedRole : 'Employee',
                    decoration: InputDecoration(
                      labelText: 'Account Role',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      prefixIcon: const Icon(Icons.badge_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Employee', child: Text('Employee')),
                      DropdownMenuItem(value: 'Student', child: Text('Student')),
                      DropdownMenuItem(value: 'Teacher', child: Text('Teacher')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedRole = val);
                      }
                    },
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final navigator = Navigator.of(ctx);
                              final messenger = ScaffoldMessenger.of(context);
                              setModalState(() => isSaving = true);
                              try {
                                final res = await http.post(
                                  Uri.parse(ApiConfig.profileUrl),
                                  headers: {'Content-Type': 'application/json'},
                                  body: json.encode({
                                    'name': widget.userName,
                                    'full_name': nameCtrl.text.trim(),
                                    'dob': dobCtrl.text.trim(),
                                    'gender': selectedGender,
                                    'email': emailCtrl.text.trim(),
                                    'role': selectedRole.toLowerCase(),
                                  }),
                                );
                                if (res.statusCode == 200) {
                                  navigator.pop();
                                  _fetchProfileData();
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: const Text('Profile updated successfully!'),
                                      backgroundColor: const Color(0xFF10B981),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  );
                                }
                              } catch (e) {
                                debugPrint("Error updating profile: $e");
                              } finally {
                                if (ctx.mounted) {
                                  setModalState(() => isSaving = false);
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A7DFF),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Save Changes',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }


  // ==================== 4. SETTINGS SCREEN ====================
  Widget _buildSettingsScreen() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const Text(
              'System Settings',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Manage facial scanner, geofence, and notifications',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),

            // Section: Face & Biometrics
            _buildSettingsCategory('BIOMETRIC SCANNER'),
            _buildSwitchTile(
              title: 'Auto Check-in on Scan',
              subtitle: 'Mark attendance immediately once face verified',
              icon: Icons.face_retouching_natural_rounded,
              value: _autoFaceRecognition,
              onChanged: (v) => setState(() => _autoFaceRecognition = v),
            ),
            _buildSwitchTile(
              title: 'Liveness & Anti-Spoofing',
              subtitle: 'Ensure genuine face detection to avoid spoofing',
              icon: Icons.shield_outlined,
              value: _livenessCheck,
              onChanged: (v) => setState(() => _livenessCheck = v),
            ),
            const SizedBox(height: 20),

            // Section: Location & Geofencing
            _buildSettingsCategory('GEOFENCING & LOCATION'),
            _buildSwitchTile(
              title: 'High Accuracy GPS',
              subtitle: 'Verify within 500m office site perimeter',
              icon: Icons.location_on_outlined,
              value: _gpsHighAccuracy,
              onChanged: (v) => setState(() => _gpsHighAccuracy = v),
            ),
            const SizedBox(height: 20),

            // Section: Reminders & Sounds
            _buildSettingsCategory('REMINDERS & AUDIO'),
            _buildSwitchTile(
              title: 'Morning Check-in Alert',
              subtitle: 'Reminder notify at 08:45 AM',
              icon: Icons.alarm_rounded,
              value: _morningReminder,
              onChanged: (v) => setState(() => _morningReminder = v),
            ),
            _buildSwitchTile(
              title: 'Evening Check-out Alert',
              subtitle: 'Reminder notify at 05:00 PM',
              icon: Icons.alarm_on_rounded,
              value: _eveningReminder,
              onChanged: (v) => setState(() => _eveningReminder = v),
            ),
            _buildSwitchTile(
              title: 'Sound Effects on Scan',
              subtitle: 'Play chime confirmation sound',
              icon: Icons.volume_up_outlined,
              value: _soundEffects,
              onChanged: (v) => setState(() => _soundEffects = v),
            ),
            const SizedBox(height: 20),

            // Section: App Version
            _buildSettingsCategory('APP DETAILS'),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('AttendancePro Version', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                  Text('v2.4.0 (2026)', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                ],
              ),
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCategory(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFF94A3B8),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F9FD),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF00BCD4), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: const Color(0xFF00BCD4),
            activeThumbColor: Colors.white,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // ==================== EXACT BOTTOM NAV BAR ====================
  Widget _buildCustomBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        border: const Border(
          top: BorderSide(color: Color(0xFFF1F5F9), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Row(
            children: [
              _buildNavItem(icon: Icons.home_rounded, label: 'HOME', index: 0),
              _buildNavItem(icon: Icons.history_rounded, label: 'HISTORY', index: 1),
              _buildNavItem(icon: Icons.person_outline_rounded, label: 'PROFILE', index: 2),
              _buildNavItem(icon: Icons.settings_outlined, label: 'SETTINGS', index: 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required String label, required int index}) {
    final isActive = _currentIndex == index;
    const activeCyan = Color(0xFF00BCD4);
    const activeBgCyan = Color(0xFFE0F9FD);
    const inactiveColor = Color(0xFF8E9BAE);

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 38,
              decoration: BoxDecoration(
                color: isActive ? activeBgCyan : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: isActive ? activeCyan : inactiveColor,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w900 : FontWeight.w800,
                color: isActive ? activeCyan : inactiveColor,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FaceRecognitionScannerScreen extends StatefulWidget {
  final bool isCheckOut;
  const FaceRecognitionScannerScreen({super.key, this.isCheckOut = false});

  @override
  State<FaceRecognitionScannerScreen> createState() => _FaceRecognitionScannerScreenState();
}

class _FaceRecognitionScannerScreenState extends State<FaceRecognitionScannerScreen> {
  final String _statusMessage = "Scanning... Please look into the camera";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF2F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 18),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.isCheckOut ? 'Checkout' : 'Checkin',
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
        ),
        centerTitle: true,
        actions: const [
          SizedBox(width: 56), // Balance the leading icon for true centering
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: const Color(0xFFF1F5F9),
            height: 1.0,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isCheckOut ? 'Face Recognition Check-Out' : 'Face Recognition Check-In',
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.isCheckOut 
                ? 'Look at the camera to securely check out.'
                : 'Position your face within the frame for secure biometric verification.',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 32),

            // Circular Camera Scanner
            Center(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF00F0FF).withValues(alpha: 0.2),
                    width: 4,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black12,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: const Center(
                      child: Icon(Icons.face_retouching_natural_rounded, size: 80, color: Colors.black26),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Status Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF1F5F9)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.videocam_rounded, color: Color(0xFF0B69FF)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: const TextStyle(
                        color: Color(0xFF0B69FF),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFEEF2F6),
                      foregroundColor: const Color(0xFF0A7DFF),
                      side: const BorderSide(color: Color(0xFF0A7DFF), width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.close_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00F0FF),
                      foregroundColor: const Color(0xFF002D2D),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      shadowColor: const Color(0xFF00F0FF).withValues(alpha: 0.4),
                    ).copyWith(
                      elevation: WidgetStateProperty.all(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.refresh_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Retry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class SuccessScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final String userName;
  final String role;

  const SuccessScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.userName,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success Badge
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      color: Color(0xFF16A34A),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 16),
              
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),

              // Mobile-Optimized Profile Info Box (Attendance details hidden via mobile-hide)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        role,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              const Text(
                'Redirecting automatically...',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarHeaderCell extends StatelessWidget {
  final String label;
  const _CalendarHeaderCell(this.label);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}


class AttendanceScannerScreen extends StatefulWidget {
  final bool isCheckOut;
  
  const AttendanceScannerScreen({super.key, required this.isCheckOut});

  @override
  State<AttendanceScannerScreen> createState() => _AttendanceScannerScreenState();
}

class _AttendanceScannerScreenState extends State<AttendanceScannerScreen> {
  CameraController? _cameraController;
  bool _hasPermission = false;
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkPermissionAndInitialize();
  }

  Future<void> _checkPermissionAndInitialize() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      await _initializeCamera();
    } else {
      _requestPermission();
    }
  }

  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      await _initializeCamera();
    } else {
      setState(() {
        _hasPermission = false;
        _errorMessage = 'Camera permission is required.';
      });
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No camera found.';
        });
        return;
      }
      
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _hasPermission = true;
          _errorMessage = '';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error initializing camera: $e';
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _scanNow() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      Position? position = await LocationHelper.getCurrentLocation();
      double lat = position?.latitude ?? 0.0;
      double lon = position?.longitude ?? 0.0;

      final url = widget.isCheckOut ? ApiConfig.checkoutScanUrl : ApiConfig.checkinScanUrl;

      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'image': base64Image,
              'lat': lat,
              'lon': lon,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        if (!mounted) return;
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _errorMessage = data['error'] ?? data['message'] ?? 'Action failed.';
        });
      }
    } on TimeoutException {
      setState(() {
        _errorMessage = 'Connection timed out. Please ensure backend server is running.';
      });
    } on SocketException {
      setState(() {
        _errorMessage = 'Network error connecting to ${ApiConfig.baseUrl}. Make sure your server is running.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Scan error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        centerTitle: true,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            color: Colors.transparent,
            padding: const EdgeInsets.all(16.0),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
          ),
        ),
        title: Text(
          widget.isCheckOut ? 'Check Out' : 'Check In',
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: const Color(0xFFE2E8F0),
            height: 1.0,
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          widget.isCheckOut ? 'Check Out Scan' : 'Check In Scan',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0066FF),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Verify your identity with face\nrecognition to log attendance.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 48),
                        
                        // Camera Preview Circle
                        Container(
                          width: 280,
                          height: 280,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFF1F5F9),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0066FF).withValues(alpha: 0.15),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white,
                              width: 8,
                            ),
                          ),
                          child: _hasPermission && _cameraController != null && _cameraController!.value.isInitialized
                              ? ClipOval(
                                  child: Transform.scale(
                                    scale: _cameraController!.value.aspectRatio < 1 
                                        ? 1 / _cameraController!.value.aspectRatio 
                                        : _cameraController!.value.aspectRatio,
                                    child: Center(
                                      child: CameraPreview(_cameraController!),
                                    ),
                                  ),
                                )
                              : const Center(
                                  child: Icon(Icons.camera_alt_rounded, color: Color(0xFFCBD5E1), size: 64),
                                ),
                        ),
                        
                        if (!_hasPermission) ...[
                          const SizedBox(height: 32),
                          GestureDetector(
                            onTap: _requestPermission,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: const Color(0xFFFECACA)),
                              ),
                              child: const Text(
                                'Tap to allow camera permission',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFFEF4444),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ],
          
                        if (_errorMessage.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _errorMessage,
                              style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
          
                        const Spacer(),
                        const SizedBox(height: 32),
          
                        // Scan Now Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: _hasPermission && !_isLoading ? _scanNow : null,
                            icon: _isLoading 
                              ? const SizedBox(
                                  width: 24, height: 24, 
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
                                )
                              : const Icon(Icons.face_retouching_natural_rounded, size: 24, color: Colors.white),
                            label: Text(
                              _isLoading ? 'Scanning Face...' : 'Scan Now',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0066FF),
                              disabledBackgroundColor: const Color(0xFF94A3B8),
                              elevation: 8,
                              shadowColor: const Color(0xFF0066FF).withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class ApiSettingsDialog extends StatefulWidget {
  const ApiSettingsDialog({super.key});

  @override
  State<ApiSettingsDialog> createState() => _ApiSettingsDialogState();
}

class _ApiSettingsDialogState extends State<ApiSettingsDialog> {
  final TextEditingController _ipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ipController.text = ApiConfig.customHost ?? '';
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final newIp = _ipController.text.trim();
    if (newIp.isNotEmpty) {
      await prefs.setString('customHost', newIp);
      ApiConfig.customHost = newIp;
    } else {
      await prefs.remove('customHost');
      ApiConfig.customHost = null;
    }
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server IP updated. Please restart the app for full effect.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Server Configuration'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Enter your computer\'s local IP address (e.g. 192.168.1.5 or 172.23.110.7) or 10.0.2.2 for Android Emulator.'),
          const SizedBox(height: 16),
          TextField(
            controller: _ipController,
            decoration: const InputDecoration(
              labelText: 'Server IP',
              hintText: 'Leave empty for default',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}


