import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart' show ApiConfig;

class ChangeEmailScreen extends StatefulWidget {
  final String currentEmail;
  final String userName;

  const ChangeEmailScreen({
    super.key,
    required this.currentEmail,
    required this.userName,
  });

  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  // Step indicator: 1 = Verify Current, 2 = Enter New, 3 = Confirm Code
  int _currentStep = 1;

  // Controllers
  final TextEditingController _currentEmailCtrl = TextEditingController();
  final TextEditingController _newEmailCtrl = TextEditingController();
  final TextEditingController _confirmEmailCtrl = TextEditingController();
  final TextEditingController _codeCtrl = TextEditingController();

  // State flags
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  bool _isCurrentEmailVerified = false;
  String _targetNewEmail = "";
  
  // Resend code timer
  Timer? _resendTimer;
  int _resendCountdown = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _currentEmailCtrl.dispose();
    _newEmailCtrl.dispose();
    _confirmEmailCtrl.dispose();
    _codeCtrl.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _resendCountdown = 60;
      _canResend = false;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 1) {
        setState(() {
          _resendCountdown--;
        });
      } else {
        timer.cancel();
        setState(() {
          _canResend = true;
        });
      }
    });
  }

  // ==================== STEP 1: VERIFY CURRENT EMAIL ====================
  void _verifyCurrentEmail() {
    final entered = _currentEmailCtrl.text.trim().toLowerCase();
    final registered = widget.currentEmail.trim().toLowerCase();

    setState(() {
      _errorMessage = null;
    });

    if (entered.isEmpty) {
      setState(() {
        _errorMessage = "Please enter your current email address.";
      });
      return;
    }

    if (entered != registered) {
      setState(() {
        _errorMessage = "The email entered does not match your current registered address. Please check and try again.";
      });
      return;
    }

    // Success: Lock step 1 and advance to step 2
    setState(() {
      _isCurrentEmailVerified = true;
      _currentStep = 2;
      _errorMessage = null;
      _successMessage = "Existing email verified successfully. You may now enter your new email.";
    });
  }

  // ==================== STEP 2: REQUEST CHANGE CODE ====================
  Future<void> _requestEmailChangeCode() async {
    final newEmail = _newEmailCtrl.text.trim().toLowerCase();
    final confirmEmail = _confirmEmailCtrl.text.trim().toLowerCase();
    final currentEmail = widget.currentEmail.trim().toLowerCase();

    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    if (newEmail.isEmpty) {
      setState(() {
        _errorMessage = "Please enter your new email address.";
      });
      return;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(newEmail)) {
      setState(() {
        _errorMessage = "Please enter a valid email format (e.g., name@domain.com).";
      });
      return;
    }

    if (newEmail == currentEmail) {
      setState(() {
        _errorMessage = "New email cannot be the same as your existing email.";
      });
      return;
    }

    if (newEmail != confirmEmail) {
      setState(() {
        _errorMessage = "New email and confirmation email do not match.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final url = Uri.parse(ApiConfig.mobileEmailRequestChangeUrl);
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': widget.userName,
          'current_email': currentEmail,
          'new_email': newEmail,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          _targetNewEmail = newEmail;
          _currentStep = 3;
          _isLoading = false;
          _successMessage = "Confirmation message and 6-digit code sent to $newEmail.";
        });
        _startResendTimer();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = data['error'] ?? "Failed to send confirmation email. Please try again.";
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Connection error. Make sure your backend server is running.";
      });
    }
  }

  // ==================== STEP 3: VERIFY CONFIRMATION CODE ====================
  Future<void> _verifyCodeAndSubmit() async {
    final code = _codeCtrl.text.trim();

    setState(() {
      _errorMessage = null;
    });

    if (code.isEmpty || code.length < 6) {
      setState(() {
        _errorMessage = "Please enter the complete 6-digit confirmation code.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final url = Uri.parse(ApiConfig.mobileEmailVerifyChangeUrl);
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': widget.userName,
          'new_email': _targetNewEmail,
          'code': code,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          _isLoading = false;
        });

        // Save to local SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_email', _targetNewEmail);

        if (mounted) {
          _showSuccessModal(_targetNewEmail);
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = data['error'] ?? "Invalid or expired confirmation code. Please try again.";
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Connection error. Failed to verify code with server.";
      });
    }
  }

  // ==================== SUCCESS CELEBRATION MODAL ====================
  void _showSuccessModal(String updatedEmail) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(28),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.check_rounded, color: Color(0xFF16A34A), size: 40),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Email Updated!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your AttendancePro email has been successfully updated in the database to:\n\n$updatedEmail',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0084FF),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.pop(ctx); // Close dialog
                  Navigator.pop(context, updatedEmail); // Return to settings with new email
                },
                child: const Text(
                  'Back to Settings',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF0F172A),
              size: 20,
            ),
          ),
        ),
        title: const Text(
          'Change Email',
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
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Icon and Title
              Center(
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE0F2FE),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.mark_email_unread_outlined, color: Color(0xFF0084FF), size: 32),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Center(
                child: Text(
                  'Update Email Address',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  'Verify your existing email before applying a new address to protect your attendance account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Step Progress Indicator
              _buildStepIndicator(),
              const SizedBox(height: 20),

              // Alert messages (Error or Success)
              if (_errorMessage != null) ...[
                _buildAlertBanner(
                  icon: Icons.error_outline_rounded,
                  text: _errorMessage!,
                  isError: true,
                ),
                const SizedBox(height: 16),
              ],
              if (_successMessage != null) ...[
                _buildAlertBanner(
                  icon: Icons.check_circle_outline_rounded,
                  text: _successMessage!,
                  isError: false,
                ),
                const SizedBox(height: 16),
              ],

              // STEP 1 CARD: Existing Email Verification
              _buildStep1Card(),
              const SizedBox(height: 16),

              // STEP 2 CARD: New Email Entry
              if (_isCurrentEmailVerified) ...[
                _buildStep2Card(),
                const SizedBox(height: 16),
              ],

              // STEP 3 CARD: Confirmation Code Entry
              if (_currentStep == 3) ...[
                _buildStep3Card(),
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== STEP PROGRESS BAR ====================
  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStepPill(step: 1, label: '1. Existing', isActive: _currentStep == 1, isDone: _isCurrentEmailVerified),
          const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFFCBD5E1)),
          _buildStepPill(step: 2, label: '2. New Email', isActive: _currentStep == 2, isDone: _currentStep > 2),
          const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFFCBD5E1)),
          _buildStepPill(step: 3, label: '3. Verify Code', isActive: _currentStep == 3, isDone: false),
        ],
      ),
    );
  }

  Widget _buildStepPill({required int step, required String label, required bool isActive, required bool isDone}) {
    Color bg = const Color(0xFFF1F5F9);
    Color fg = const Color(0xFF64748B);

    if (isDone) {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF16A34A);
    } else if (isActive) {
      bg = const Color(0xFFE0F2FE);
      fg = const Color(0xFF0084FF);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isDone) ...[
            const Icon(Icons.check_rounded, size: 14, color: Color(0xFF16A34A)),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ALERT BANNER ====================
  Widget _buildAlertBanner({required IconData icon, required String text, required bool isError}) {
    final bg = isError ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7);
    final border = isError ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0);
    final color = isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== STEP 1 CARD ====================
  Widget _buildStep1Card() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isCurrentEmailVerified ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
          width: _isCurrentEmailVerified ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _isCurrentEmailVerified ? const Color(0xFFDCFCE7) : const Color(0xFFE0F2FE),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    _isCurrentEmailVerified ? Icons.check_rounded : Icons.lock_outline_rounded,
                    color: _isCurrentEmailVerified ? const Color(0xFF16A34A) : const Color(0xFF0084FF),
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '1. Verify Existing Email',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              if (_isCurrentEmailVerified)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'VERIFIED',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF16A34A)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter your current registered email address to verify your identity.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.3),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _currentEmailCtrl,
            enabled: !_isCurrentEmailVerified,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF0084FF), size: 20),
              hintText: 'e.g. ${widget.currentEmail}',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              filled: true,
              fillColor: _isCurrentEmailVerified ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0084FF), width: 1.5)),
            ),
          ),
          if (!_isCurrentEmailVerified) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0084FF),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _verifyCurrentEmail,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield_outlined, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Verify Existing Email',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==================== STEP 2 CARD ====================
  Widget _buildStep2Card() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _currentStep > 2 ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
          width: _currentStep > 2 ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _currentStep > 2 ? const Color(0xFFDCFCE7) : const Color(0xFFE0F2FE),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    _currentStep > 2 ? Icons.check_rounded : Icons.alternate_email_rounded,
                    color: _currentStep > 2 ? const Color(0xFF16A34A) : const Color(0xFF0084FF),
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '2. Enter New Email',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter your new email address. We will send a confirmation message with a verification code.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.3),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _newEmailCtrl,
            enabled: _currentStep == 2 && !_isLoading,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'New Email Address',
              labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
              prefixIcon: const Icon(Icons.alternate_email_rounded, color: Color(0xFF0084FF), size: 20),
              hintText: 'e.g. newaddress@gmail.com',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0084FF), width: 1.5)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmEmailCtrl,
            enabled: _currentStep == 2 && !_isLoading,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Confirm New Email Address',
              labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
              prefixIcon: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF0084FF), size: 20),
              hintText: 'Re-enter your new email address',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0084FF), width: 1.5)),
            ),
          ),
          if (_currentStep == 2) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0084FF),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoading ? null : _requestEmailChangeCode,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Send Confirmation Code',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==================== STEP 3 CARD ====================
  Widget _buildStep3Card() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF0084FF), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0084FF).withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Color(0xFFE0F2FE),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.key_rounded, color: Color(0xFF0084FF), size: 16),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '3. Confirm Verification Code',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the 6-digit verification code sent to $_targetNewEmail.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.3),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _codeCtrl,
            enabled: !_isLoading,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 8,
              color: Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '• • • • • •',
              hintStyle: const TextStyle(letterSpacing: 6, color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0084FF), width: 1.5)),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981), // Solid green action button
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isLoading ? null : _verifyCodeAndSubmit,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Confirm & Update Email',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _canResend ? _requestEmailChangeCode : null,
              child: Text(
                _canResend ? 'Resend Confirmation Code' : 'Resend code in $_resendCountdown seconds',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _canResend ? const Color(0xFF0084FF) : const Color(0xFF94A3B8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

