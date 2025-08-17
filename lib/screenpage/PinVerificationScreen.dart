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
    
    // ไม่ต้อง autofocus เพราะเราใช้ numpad
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

  void _onNumberPressed(String number) {
    // Find the first empty field
    for (int i = 0; i < 6; i++) {
      if (_pinControllers[i].text.isEmpty) {
        _pinControllers[i].text = number;
        setState(() {});
        
        // Check if PIN is complete
        String currentPin = _pinControllers.map((e) => e.text).join();
        if (currentPin.length == 6) {
          _verifyPin(currentPin);
        }
        break;
      }
    }
  }

  void _onBackspacePressed() {
    // Find the last filled field and clear it
    for (int i = 5; i >= 0; i--) {
      if (_pinControllers[i].text.isNotEmpty) {
        _pinControllers[i].text = '';
        setState(() {});
        break;
      }
    }
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
    // ไม่ต้อง focus เพราะเราใช้ numpad
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
      appBar: widget.onCancel != null ? AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            widget.onCancel?.call();
            Navigator.of(context).pop(false);
          },
        ),
      ) : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              // Top spacing
              SizedBox(height: widget.onCancel != null ? 20 : 60),
              
              // Header section
              Column(
                children: [
                  // Simple lock icon
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_outlined,
                      size: 28,
                      color: AppTheme.primaryColor,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Title
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),

              const SizedBox(height: 60),

              // PIN dots indicator with shake animation
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_shakeAnimation.value * 10, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(6, (index) {
                        bool isFilled = _pinControllers[index].text.isNotEmpty;
                        bool hasError = _errorMessage.isNotEmpty;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hasError
                                ? AppTheme.errorColor.withOpacity(0.2)
                                : isFilled 
                                    ? AppTheme.primaryColor 
                                    : AppTheme.textMuted.withOpacity(0.3),
                            border: Border.all(
                              color: hasError
                                  ? AppTheme.errorColor
                                  : isFilled 
                                      ? AppTheme.primaryColor 
                                      : AppTheme.textMuted.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              // Hidden PIN input (read-only to prevent keyboard)
              Opacity(
                opacity: 0.0,
                child: SizedBox(
                  height: 1,
                  child: Row(
                    children: List.generate(6, (index) => 
                      Expanded(
                        child: TextField(
                          controller: _pinControllers[index],
                          focusNode: _pinFocusNodes[index],
                          readOnly: true,
                          keyboardType: TextInputType.none,
                          maxLength: 1,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            counterText: '',
                            border: InputBorder.none,
                          ),
                          onChanged: (value) => _onPinChanged(index, value),
                        ),
                      )
                    ),
                  ),
                ),
              ),

              // Numpad
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: GridView.count(
                    crossAxisCount: 3,
                    childAspectRatio: 1.1,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    children: [
                      // Numbers 1-9
                      ...List.generate(9, (index) => _buildNumButton('${index + 1}')),
                      
                      // Biometric button, 0, backspace
                      widget.showBiometric && widget.onBiometricPressed != null
                          ? _buildBiometricButton()
                          : const SizedBox(),
                      _buildNumButton('0'),
                      _buildBackspaceButton(),
                    ],
                  ),
                ),
              ),

              // Error message
              if (_errorMessage.isNotEmpty) 
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: AppTheme.errorColor,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _errorMessage,
                        style: TextStyle(
                          color: AppTheme.errorColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

              // Attempt counter
              if (_attemptCount > 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Attempts: ${3 - _attemptCount} left',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              // Loading indicator
              if (_isLoading)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumButton(String number) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onNumberPressed(number),
        borderRadius: BorderRadius.circular(30),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.textMuted.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _onBackspacePressed,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.textMuted.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.backspace_outlined,
              color: AppTheme.textSecondary,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onBiometricPressed,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.3),
              width: 1,
            ),
            color: AppTheme.primaryColor.withOpacity(0.05),
          ),
          child: Center(
            child: Icon(
              Icons.fingerprint,
              color: AppTheme.primaryColor,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
