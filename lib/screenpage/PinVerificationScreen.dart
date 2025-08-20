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
    _shakeAnimation = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
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
    // Hidden PIN input fields, kept for logic but not visible
    final hiddenPinFields = Opacity(
      opacity: 0.0,
      child: SizedBox(
        height: 0, // Make it take no space
        child: Row(
          children: List.generate(
            6,
            (index) => Expanded(
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
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: widget.onCancel != null
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  widget.onCancel?.call();
                  Navigator.of(context).pop(false);
                },
              ),
            )
          : null,
      body: SafeArea(
        child: Stack( // Use Stack to keep hidden fields out of layout flow
          children: [
            hiddenPinFields,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  _buildHeader(),
                  const SizedBox(height: 48),
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_shakeAnimation.value * 10, 0),
                        child: _buildPinDots(),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildErrorMessage(),
                  const Spacer(flex: 3),
                  _buildNumpad(),
                  _buildFooterStatus(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
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
        Text(
          widget.title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          widget.subtitle,
          style: TextStyle(
            fontSize: 16,
            color: AppTheme.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPinDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        bool isFilled = _pinControllers[index].text.isNotEmpty;
        bool hasError = _errorMessage.isNotEmpty;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled
                ? (hasError ? AppTheme.errorColor : AppTheme.primaryColor)
                : Colors.transparent,
            border: Border.all(
              color: hasError
                  ? AppTheme.errorColor
                  : AppTheme.textMuted.withOpacity(0.5),
              width: 1.5,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildErrorMessage() {
    if (_errorMessage.isEmpty) return const SizedBox(height: 24);
    return SizedBox(
      height: 24,
      child: Text(
        _errorMessage,
        style: TextStyle(
          color: AppTheme.errorColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        children: [
          ...List.generate(9, (index) => _buildNumButton('${index + 1}')),
          widget.showBiometric && widget.onBiometricPressed != null
              ? _buildBiometricButton()
              : const SizedBox(),
          _buildNumButton('0'),
          _buildBackspaceButton(),
        ],
      ),
    );
  }

  Widget _buildFooterStatus() {
    return SizedBox(
      height: 50,
      child: Center(
        child: _isLoading
      ? CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                color: AppTheme.primaryColor,
                strokeWidth: 3,
              )
            : _attemptCount > 0
                ? Text(
                    '${3 - _attemptCount} attempts left',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  )
                : const SizedBox(),
      ),
    );
  }

  Widget _buildNumButton(String number) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onNumberPressed(number),
        borderRadius: BorderRadius.circular(40),
        child: Center(
          child: Text(
            number,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w400,
              color: AppTheme.textPrimary,
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
        borderRadius: BorderRadius.circular(40),
        child: Center(
          child: Icon(
            Icons.backspace_outlined,
            color: AppTheme.textSecondary,
            size: 24,
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
        borderRadius: BorderRadius.circular(40),
        child: Center(
          child: Icon(
            Icons.fingerprint,
            color: AppTheme.primaryColor,
            size: 28,
          ),
        ),
      ),
    );
  }
}
