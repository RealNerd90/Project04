import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'main.dart'; // For ApiConfig

class RecalibrateFaceScreen extends StatefulWidget {
  final String userName;

  const RecalibrateFaceScreen({
    super.key,
    required this.userName,
  });

  @override
  State<RecalibrateFaceScreen> createState() => _RecalibrateFaceScreenState();
}

class _RecalibrateFaceScreenState extends State<RecalibrateFaceScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  bool _hasPermission = false;
  bool _isInitializing = true;
  bool _isCapturing = false;
  bool _isSubmitting = false;

  int _currentStepIndex = 0;
  final Map<String, String> _capturedAnglesBase64 = {};

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<Map<String, dynamic>> _angleSteps = [
    {
      'key': 'front',
      'label': 'Front Face',
      'instruction': 'Look directly into the camera with a neutral expression.',
      'icon': Icons.face_rounded,
      'hint': 'Keep your head level and centered',
    },
    {
      'key': 'right',
      'label': 'Right Profile',
      'instruction': 'Turn your head slightly to the right (about 20°).',
      'icon': Icons.arrow_forward_rounded,
      'hint': 'Turn slowly to the right',
    },
    {
      'key': 'left',
      'label': 'Left Profile',
      'instruction': 'Turn your head slightly to the left (about 20°).',
      'icon': Icons.arrow_back_rounded,
      'hint': 'Turn slowly to the left',
    },
    {
      'key': 'up',
      'label': 'Upward Angle',
      'instruction': 'Tilt your chin and head slightly upward.',
      'icon': Icons.arrow_upward_rounded,
      'hint': 'Tilt upward while keeping eyes visible',
    },
    {
      'key': 'down',
      'label': 'Downward Angle',
      'instruction': 'Tilt your chin and head slightly downward.',
      'icon': Icons.arrow_downward_rounded,
      'hint': 'Tilt downward towards the camera',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _checkPermissionAndInit();
  }

  Future<void> _checkPermissionAndInit() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      setState(() => _hasPermission = true);
      await _initializeCamera();
    } else {
      final requestStatus = await Permission.camera.request();
      if (requestStatus.isGranted) {
        setState(() => _hasPermission = true);
        await _initializeCamera();
      } else {
        setState(() {
          _hasPermission = false;
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _isInitializing = false);
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
        setState(() => _isInitializing = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _captureCurrentAngle() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (_isCapturing || _isSubmitting) return;

    setState(() => _isCapturing = true);

    try {
      HapticFeedback.mediumImpact();
      final image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();
      final base64Str = base64Encode(bytes);

      final currentKey = _angleSteps[_currentStepIndex]['key'] as String;
      _capturedAnglesBase64[currentKey] = base64Str;

      if (!mounted) return;

      if (_currentStepIndex < _angleSteps.length - 1) {
        // Move to next angle
        setState(() {
          _currentStepIndex++;
          _isCapturing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${_angleSteps[_currentStepIndex - 1]['label']} captured successfully!',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(milliseconds: 1400),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        // All 5 angles captured! Auto-submit
        setState(() => _isCapturing = false);
        _submitRecalibration();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCapturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Capture failed: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _submitRecalibration() async {
    setState(() => _isSubmitting = true);

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.mobileRecalibrateFaceUrl),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'name': widget.userName,
              'angles': _capturedAnglesBase64,
            }),
          )
          .timeout(const Duration(seconds: 25));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _showSuccessModal();
        } else {
          _handleError(data['error'] ?? 'Recalibration failed.');
        }
      } else {
        _handleError('Server responded with error code: ${response.statusCode}');
      }
    } catch (e) {
      _handleError('Connection failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _handleError(String err) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(err, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccessModal() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFA7F3D0), width: 3),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_rounded,
                      color: Color(0xFF10B981),
                      size: 42,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Biometrics Recalibrated!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'All 5 face angles for ${widget.userName} have been updated. Your old face data was removed and new biometric vectors were registered.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop(); // Close sheet
                      Navigator.of(context).pop(true); // Return to settings
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0084FF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Done & Return to Settings',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = _angleSteps[_currentStepIndex];
    final stepNum = _currentStepIndex + 1;
    final totalSteps = _angleSteps.length;
    final allAnglesCaptured = _capturedAnglesBase64.length == totalSteps;

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
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF0F172A),
              size: 20,
            ),
          ),
        ),
        title: const Text(
          'Recalibrate Face Data',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFE2E8F0), height: 1.0),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // User Identification Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0084FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'User: ${widget.userName}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Old biometrics will be replaced with new multi-angle vectors',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Horizontal 5-Step Angle Progress Strip
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(totalSteps, (index) {
                  final angle = _angleSteps[index];
                  final isCaptured = _capturedAnglesBase64.containsKey(angle['key']);
                  final isCurrent = index == _currentStepIndex;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        // Allow switching to an already captured angle or current
                        if (isCaptured || index <= _currentStepIndex) {
                          setState(() => _currentStepIndex = index);
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? const Color(0xFF0084FF)
                              : (isCaptured
                                  ? const Color(0xFFD1FAE5)
                                  : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isCurrent
                                ? const Color(0xFF0084FF)
                                : (isCaptured
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFE2E8F0)),
                            width: isCurrent ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              isCaptured
                                  ? Icons.check_circle_rounded
                                  : (angle['icon'] as IconData),
                              size: 16,
                              color: isCurrent
                                  ? Colors.white
                                  : (isCaptured
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              angle['key'].toString().toUpperCase(),
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: isCurrent
                                    ? Colors.white
                                    : (isCaptured
                                        ? const Color(0xFF065F46)
                                        : const Color(0xFF64748B)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),

              // Camera Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Camera Circular Frame with Glow
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        width: 210,
                        height: 210,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF0F172A),
                          border: Border.all(
                            color: const Color(0xFF0084FF),
                            width: 3.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0084FF).withOpacity(0.2),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: _isInitializing
                              ? const Center(
                                  child: CircularProgressIndicator(color: Colors.white),
                                )
                              : (_hasPermission &&
                                      _cameraController != null &&
                                      _cameraController!.value.isInitialized)
                                  ? Stack(
                                      alignment: Alignment.center,
                                      fit: StackFit.expand,
                                      children: [
                                        Transform.scale(
                                          scale: _cameraController!.value.aspectRatio < 1
                                              ? 1 / _cameraController!.value.aspectRatio
                                              : _cameraController!.value.aspectRatio,
                                          child: Center(
                                            child: CameraPreview(_cameraController!),
                                          ),
                                        ),
                                        // Subtle directional overlay arrow
                                        if (currentStep['key'] != 'front')
                                          Align(
                                            alignment: _getOverlayAlignment(currentStep['key']),
                                            child: Container(
                                              margin: const EdgeInsets.all(16),
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.4),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                currentStep['icon'] as IconData,
                                                color: Colors.white,
                                                size: 24,
                                              ),
                                            ),
                                          ),
                                      ],
                                    )
                                  : const Center(
                                      child: Icon(
                                        Icons.person,
                                        size: 80,
                                        color: Colors.white24,
                                      ),
                                    ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Step Indicator Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFDBEAFE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0084FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Step $stepNum of $totalSteps',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            currentStep['label'],
                            style: const TextStyle(
                              color: Color(0xFF1E3A8A),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Angle Instruction Text
                    Text(
                      currentStep['instruction'],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentStep['hint'],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Action Buttons Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    // Capture Angle Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: (_hasPermission && !_isSubmitting && !_isCapturing)
                            ? _captureCurrentAngle
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0084FF),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF94A3B8),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: (_isCapturing || _isSubmitting)
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(currentStep['icon'] as IconData, size: 20),
                        label: Text(
                          _isSubmitting
                              ? 'Saving Recalibrated Face...'
                              : (_isCapturing
                                  ? 'Capturing...'
                                  : 'Capture ${currentStep['label']} ($stepNum/$totalSteps)'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),

                    // Retake or Jump controls
                    if (_capturedAnglesBase64.containsKey(currentStep['key'])) ...[
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: _isCapturing || _isSubmitting
                            ? null
                            : () {
                                setState(() {
                                  _capturedAnglesBase64.remove(currentStep['key']);
                                });
                              },
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: Text('Retake ${currentStep['label']}'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                        ),
                      ),
                    ],

                    if (allAnglesCaptured && !_isSubmitting) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _submitRecalibration,
                          icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                          label: const Text('Update & Save All Angles Now'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF10B981),
                            side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Alignment _getOverlayAlignment(String key) {
    switch (key) {
      case 'right':
        return Alignment.centerRight;
      case 'left':
        return Alignment.centerLeft;
      case 'up':
        return Alignment.topCenter;
      case 'down':
        return Alignment.bottomCenter;
      default:
        return Alignment.center;
    }
  }
}

