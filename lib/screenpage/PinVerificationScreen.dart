import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_theme.dart';
import '../services/security_service.dart';

class PinVerificationScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final Function(String) onPinVerified;
  final VoidCallback? onCancel;
  final bool showBiometric;
  final VoidCallback? onBiometricPressed;
  
  const PinVerificationScreen({
    super.key,
    this.title = 'Enter Your PIN',
    this.subtitle = 'Please enter your 6-digit PIN to continue',
    required this.onPinVerified,
    this.onCancel,
    this.showBiometric = false,
    this.onBiometricPressed,
  });

  @override
  State<PinVerificationScreen> createState() => _PinVerificationScreenState();
}

class _PinVerificationScreenState extends State<PinVerificationScreen>
    with TickerProviderStateMixin {
  final List<TextEditingController> _pinControllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _pinFocusNodes = List.generate(6, (index) => FocusNode());
  final SecurityService _securityService = SecurityService();
  
  bool _isLoading = false;
  String _errorMessage = '';
  int _attemptCount = 0;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
    
    // Auto focus first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pinFocusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    for (var controller in _pinControllers) {
      controller.dispose();
    }
    for (var focusNode in _pinFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _onPinChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _pinFocusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _pinFocusNodes[index - 1].requestFocus();
    }

    // Collect current PIN
    String currentPin = _pinControllers.map((e) => e.text).join();
    
    if (currentPin.length == 6) {
      _verifyPin(currentPin);
    }
    
    setState(() {
      _errorMessage = '';
    });
  }

  Future<void> _verifyPin(String pin) async {
    setState(() => _isLoading = true);
    
    try {
      // Use SecurityService to verify PIN
      bool isValid = await _securityService.verifyPin(pin);
      
      if (isValid) {
        widget.onPinVerified(pin);
      } else {
        _handleWrongPin();
      }
    } catch (e) {
      _handleWrongPin();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _handleWrongPin() {
    setState(() {
      _isLoading = false;
      _attemptCount++;
      _errorMessage = 'Incorrect PIN. Please try again.';
    });
    
    _shakeController.forward().then((_) {
      _shakeController.reverse();
    });
    
    _clearPinFields();
    
    // Lock after 3 attempts
    if (_attemptCount >= 3) {
      _showLockDialog();
    }
  }

  void _clearPinFields() {
    for (var controller in _pinControllers) {
      controller.clear();
    }
    _pinFocusNodes[0].requestFocus();
  }

  void _showLockDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Too Many Attempts'),
        content: const Text(
          'You have entered an incorrect PIN 3 times. For security reasons, please wait 30 seconds before trying again.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(false);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: const Text('Security Verification'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
        centerTitle: true,
        leading: widget.onCancel != null
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  widget.onCancel?.call();
                  Navigator.of(context).pop(false);
                },
              )
            : null,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Security icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.lock_outline,
                      size: 40,
                      color: AppTheme.primaryColor,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Title and description
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 16),

                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 48),

                  // PIN input fields with shake animation - Make responsive
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_shakeAnimation.value * 10, 0),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // Calculate field width based on available space
                            double maxWidth = constraints.maxWidth;
                            double totalSpacing = 5 * 8.0; // 5 gaps of 8 pixels each
                            double availableWidth = maxWidth - totalSpacing - 32; // 32 for padding
                            double fieldWidth = (availableWidth / 6).clamp(40.0, 60.0);
                            
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(6, (index) => 
                                _buildPinField(index, fieldWidth)
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),

                  if (_errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: AppTheme.errorColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage,
                              style: TextStyle(
                                color: AppTheme.errorColor,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Attempt counter
                  if (_attemptCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Attempts remaining: ${3 - _attemptCount}',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                  const SizedBox(height: 32),

                  // Loading indicator
                  if (_isLoading)
                    CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ),

                  // Biometric button
                  if (widget.showBiometric && widget.onBiometricPressed != null) ...[
                    const SizedBox(height: 32),
                    TextButton.icon(
                      onPressed: widget.onBiometricPressed,
                      icon: Icon(Icons.fingerprint, color: AppTheme.primaryColor),
                      label: Text(
                        'Use Biometric',
                        style: TextStyle(color: AppTheme.primaryColor),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinField(int index, [double? width]) {
    bool hasValue = _pinControllers[index].text.isNotEmpty;
    bool hasError = _errorMessage.isNotEmpty;
    double fieldWidth = width ?? 50;
    
    return Container(
      width: fieldWidth,
      height: 60,
      decoration: BoxDecoration(
        border: Border.all(
          color: hasError 
              ? AppTheme.errorColor
              : hasValue 
                  ? AppTheme.primaryColor 
                  : AppTheme.textMuted,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
        color: hasValue ? AppTheme.primaryColor.withOpacity(0.05) : null,
      ),
      child: TextField(
        controller: _pinControllers[index],
        focusNode: _pinFocusNodes[index],
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: fieldWidth > 45 ? 24 : 20, // Adjust font size based on field width
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimary,
        ),
        keyboardType: TextInputType.number,
        maxLength: 1,
        obscureText: true,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (value) => _onPinChanged(index, value),
        onTap: () {
          // Ensure cursor is at the end and prevent selection issues
          _pinControllers[index].selection = TextSelection.fromPosition(
            TextPosition(offset: _pinControllers[index].text.length),
          );
        },
      ),
    );
  }
}
