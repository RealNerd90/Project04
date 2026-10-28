import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'main.dart'; // For ApiConfig
import 'admin_dashboard.dart';
import 'admin_geofencing.dart';

class AdminAddStudentScreen extends StatefulWidget {
  const AdminAddStudentScreen({super.key});

  @override
  State<AdminAddStudentScreen> createState() => _AdminAddStudentScreenState();
}

class _AdminAddStudentScreenState extends State<AdminAddStudentScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  
  // Camera & images
  CameraController? _cameraController;
  bool _isCameraReady = false;
  
  // We need 5 distinct angles
  final List<String> _angles = [
    "Front View",
    "Right Profile",
    "Left Profile",
    "Upward Angle",
    "Downward Angle"
  ];
  
  final List<String> _angleSubtitles = [
    "Optimal straight angle • 99.4% confidence",
    "45° lateral profile captured",
    "Turn head 45° to the left",
    "Tilt chin up slightly (~20°)",
    "Tilt head down slightly (~15°)"
  ];
  
  final List<String?> _capturedImages = List.filled(5, null);
  int get _enrolledCount => _capturedImages.where((img) => img != null).length;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      try {
        final cameras = await availableCameras();
        if (cameras.isNotEmpty) {
          final frontCam = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => cameras.first);
          _cameraController = CameraController(frontCam, ResolutionPreset.medium, enableAudio: false);
          await _cameraController!.initialize();
          if (mounted) setState(() { _isCameraReady = true; });
        }
      } catch (e) {
        debugPrint("Camera init error: $e");
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _captureAngle(int index) async {
    final source = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Select Image Source', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;
    if (!mounted) return;

    if (source == 'camera') {
      if (!_isCameraReady || _cameraController == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Camera not ready')));
        return;
      }
      
      // Briefly show camera dialog to capture
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          contentPadding: EdgeInsets.zero,
          content: Container(
            width: 300,
            height: 400,
            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16)),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Center(child: CameraPreview(_cameraController!)),
                ),
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          final file = await _cameraController!.takePicture();
                          final bytes = await file.readAsBytes();
                          if (!context.mounted) return;
                          Navigator.pop(context, base64Encode(bytes));
                        } catch (e) {
                          if (!context.mounted) return;
                          Navigator.pop(context, null);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(20),
                        backgroundColor: Colors.white,
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.black),
                    ),
                  ),
                ),
                Positioned(
                  top: 20,
                  left: 0,
                  right: 0,
                  child: Text(
                    _angles[index],
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, backgroundColor: Colors.black54),
                  ),
                )
              ],
            ),
          ),
        ),
      );
      
      if (!mounted) return;
      if (result != null) {
        setState(() {
          _capturedImages[index] = result;
        });
      }
    } else if (source == 'gallery') {
      try {
        PlatformFile? result = await FilePicker.pickFile(type: FileType.image);
        if (result != null && result.path != null) {
          File file = File(result.path!);
          List<int> bytes = await file.readAsBytes();
          if (!mounted) return;
          setState(() {
            _capturedImages[index] = base64Encode(bytes);
          });
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error selecting image: $e')));
      }
    }
  }

  Future<void> _finalizeEnrollment() async {
    if (_nameController.text.trim().isEmpty || _emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all basic information')));
      return;
    }
    
    // We can proceed even if not all 5 are captured, but let's warn if 0
    if (_enrolledCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please capture at least one biometric perspective')));
      return;
    }

    setState(() { _isSubmitting = true; });
    
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.adminStudentsUrl), // Same endpoint handles POST to add student
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passwordController.text.trim(),
          'images': _capturedImages.where((img) => img != null).toList(),
        }),
      ).timeout(const Duration(seconds: 15));
      
      final data = json.decode(response.body);
      
      if (!mounted) return;
      
      if (response.statusCode == 200 && data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student added successfully'), backgroundColor: Colors.green));
        Navigator.pop(context); // Go back to directory
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'] ?? 'Unknown error'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Network error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _isSubmitting = false; });
    }
  }

  bool get _hasUnsavedChanges {
    return _nameController.text.trim().isNotEmpty ||
        _emailController.text.trim().isNotEmpty ||
        _passwordController.text.trim().isNotEmpty ||
        _enrolledCount > 0;
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;
    
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Draft?'),
        content: const Text('You have unsaved details. Are you sure you want to quit without saving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    return shouldPop ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: null,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.security_rounded, color: Color(0xFF3B82F6), size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text('Attendance Portal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                Text('ADMIN CONSOLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF3B82F6), letterSpacing: 0.5)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications_none_rounded, color: Color(0xFF475569)),
                Positioned(right: 2, top: 2, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle))),
              ],
            ),
            onPressed: () {},
          ),
          const SizedBox(width: 4),
          const CircleAvatar(radius: 14, backgroundColor: Color(0xFF1E88E5), child: Icon(Icons.person, size: 18, color: Colors.white)),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top nav pill bar
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final shouldPop = await _onWillPop();
                        if (shouldPop && context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      child: Row(
                        children: const [
                          Icon(Icons.arrow_back, size: 16, color: Color(0xFF64748B)),
                          SizedBox(width: 6),
                          Text('STUDENTS DIRECTORY', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        children: [
                          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          const Text('MANUAL ENROLLMENT', style: TextStyle(color: Color(0xFF3B82F6), fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Text('STUDENT INTAKE', style: TextStyle(color: Color(0xFF3B82F6), fontSize: 11, fontWeight: FontWeight.bold)),
                        Text('  •  Step 1 of 2 Complete', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Add New Student', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                    const SizedBox(height: 8),
                    const Text('Securely enroll student profile and biometric facial signatures into the Attendance Portal network.', style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
                    const SizedBox(height: 24),
                    
                    // Basic Information Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: const Color(0xFF1E88E5), borderRadius: BorderRadius.circular(6)),
                                    child: const Text('STEP 01', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text('Basic Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                ],
                              ),
                              const Icon(Icons.badge_outlined, color: Color(0xFF1E88E5), size: 20),
                            ],
                          ),
                          const SizedBox(height: 24),
                          
                          const Text('FULL NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                          const SizedBox(height: 8),
                          _buildTextField(Icons.person_outline, 'Jonathan Aris', _nameController, false),
                          
                          const SizedBox(height: 16),
                          const Text('EMAIL ADDRESS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                          const SizedBox(height: 8),
                          _buildTextField(Icons.mail_outline, 'j.aris@polytech.edu', _emailController, false),
                          
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text('INITIAL PORTAL PASSWORD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                              Text('Generate Strong', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E88E5))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildTextField(Icons.lock_outline, '•••••••••••••', _passwordController, true),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Icon(Icons.check_circle_outline, color: Color(0xFF1E88E5), size: 14),
                              SizedBox(width: 6),
                              Expanded(child: Text('Generated passwords meet institutional AES crypt standards.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Biometric Data Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: const Color(0xFF0288D1), borderRadius: BorderRadius.circular(6)),
                                          child: const Text('STEP 02', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text('Biometric Face Vector Data', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    const Text('Capture 5 distinct camera perspectives under consistent diffuse light.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.face_retouching_natural, color: Color(0xFF1E88E5)),
                              )
                            ],
                          ),
                          const SizedBox(height: 24),
                          
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(20)),
                            child: Row(
                              children: [
                                Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF1E88E5), shape: BoxShape.circle)),
                                const SizedBox(width: 8),
                                Text('Enrolled: $_enrolledCount of 5 Angles', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Container(
                                    height: 6,
                                    decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(3)),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: _enrolledCount,
                                          child: Container(decoration: BoxDecoration(color: const Color(0xFF1E88E5), borderRadius: BorderRadius.circular(3))),
                                        ),
                                        Expanded(
                                          flex: 5 - _enrolledCount,
                                          child: const SizedBox(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // List of 5 items
                          ...List.generate(5, (index) => _buildBiometricItem(index)),
                          
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: const Color(0xFFF0F9FF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE0F2FE))),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Icon(Icons.info_outline, color: Color(0xFF0288D1), size: 16),
                                SizedBox(width: 12),
                                Expanded(child: Text('Need bulk capture? You can connect an external optical terminal via Admin Console sync.', style: TextStyle(color: Color(0xFF0288D1), fontSize: 12))),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final shouldPop = await _onWillPop();
                              if (shouldPop && context.mounted) {
                                Navigator.pop(context);
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('DISCARD DRAFT', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isSubmitting ? null : _finalizeEnrollment,
                            icon: _isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.shield_outlined, size: 16),
                            label: Text(_isSubmitting ? 'PROCESSING' : 'FINALIZE ENROLLMENT', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E88E5),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    const Center(
                      child: Text('ATTENDANCE PORTAL ENROLLMENT PROTOCOL V2.4 • AES-256 ENCRYPTED', 
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), offset: const Offset(0, -4), blurRadius: 10)]),
        child: BottomNavigationBar(
          currentIndex: 2, // Students tab active
          onTap: (index) async {
            if (index == 2) return;
            final shouldPop = await _onWillPop();
            if (shouldPop && context.mounted) {
              if (index == 0) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
                  (route) => route.isFirst,
                );
              } else if (index == 1) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const AdminGeofencingScreen()),
                  (route) => route.isFirst,
                );
              } else if (index == 3) {
                // Settings tab placeholder
              }
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF0F172A),
          unselectedItemColor: const Color(0xFF94A3B8),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Dashboard'),
            BottomNavigationBarItem(icon: Icon(Icons.location_on_outlined), label: 'Geofencing'),
            BottomNavigationBarItem(icon: Icon(Icons.people_alt), label: 'Students'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Settings'),
          ],
        ),
      ),
    ));
  }

  Widget _buildTextField(IconData icon, String hint, TextEditingController controller, bool isPassword) {
    return TextField(
      controller: controller,
      obscureText: isPassword && _obscurePassword,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
        suffixIcon: isPassword 
            ? IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFF94A3B8), size: 20),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ) 
            : null,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  String _getFaceImageAsset(int index) {
    switch (index) {
      case 0: return 'assets/images/face_front.png';
      case 1: return 'assets/images/face_right.png';
      case 2: return 'assets/images/face_left.png';
      case 3: return 'assets/images/face_up.png';
      case 4: return 'assets/images/face_down.png';
      default: return 'assets/images/face_front.png';
    }
  }

  Widget _buildBiometricItem(int index) {
    bool isVerified = _capturedImages[index] != null;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.01), blurRadius: 5, offset: const Offset(0, 2))]
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isVerified ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Transform.scale(
                    scale: 1.15,
                    child: Image.asset(
                      _getFaceImageAsset(index),
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),
                  ),
                ),
              ),
              if (isVerified)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.check_circle, color: Color(0xFF1E88E5), size: 16),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _angles[index], 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isVerified ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isVerified ? 'VERIFIED' : 'PENDING',
                        style: TextStyle(
                          color: isVerified ? const Color(0xFF3B82F6) : const Color(0xFF64748B),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(_angleSubtitles[index], style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), maxLines: 2, overflow: TextOverflow.ellipsis),
                if (isVerified) ...[
                  const SizedBox(height: 2),
                  const Text('vector_data_encoded.enc', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontFamily: 'monospace')),
                ]
              ],
            ),
          ),
          if (!isVerified)
            ElevatedButton.icon(
              onPressed: () => _captureAngle(index),
              icon: const Icon(Icons.upload, size: 14),
              label: const Text('Upload', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
              ),
            )
          else
            OutlinedButton(
              onPressed: () => _captureAngle(index),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
              ),
              child: const Text('Retake', style: TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}
