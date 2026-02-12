import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_theme.dart';

class PinSetupScreen extends StatefulWidget {
  // Expect an async callback so callers can perform async setup (e.g. store PIN)
  final Future<void> Function(String) onPinSetup;

  const PinSetupScreen({
    super.key,
    required this.onPinSetup,
  });

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> with TickerProviderStateMixin {
  final List<TextEditingController> _pinControllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _pinFocusNodes = List.generate(6, (index) => FocusNode());
  
  String _firstPin = '';
  bool _isConfirmingPin = false;
  bool _isLoading = false;
  String _errorMessage = '';
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

    String currentPin = _pinControllers.map((e) => e.text).join();
    
    if (currentPin.length == 6) {
      for (var focusNode in _pinFocusNodes) {
        focusNode.unfocus();
      }
      
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          _handlePinComplete(currentPin);
        }
      });
    }
    
    if (_errorMessage.isNotEmpty) {
      setState(() {
        _errorMessage = '';
      });
    }
  }

  void _onNumberPressed(String number) {
    for (int i = 0; i < 6; i++) {
      if (_pinControllers[i].text.isEmpty) {
        _pinControllers[i].text = number;
        setState(() {});
        
        String currentPin = _pinControllers.map((e) => e.text).join();
        if (currentPin.length == 6) {
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              _handlePinComplete(currentPin);
            }
          });
        }
        break;
      }
    }
  }

  void _onBackspacePressed() {
    for (int i = 5; i >= 0; i--) {
      if (_pinControllers[i].text.isNotEmpty) {
        _pinControllers[i].text = '';
        setState(() {});
        break;
      }
    }
  }

  Future<void> _handlePinComplete(String pin) async {
    if (!_isConfirmingPin) {
      setState(() {
        _firstPin = pin;
        _isConfirmingPin = true;
      });
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        _clearPinFields();
      }
    } else {
      if (pin == _firstPin) {
        setState(() => _isLoading = true);
        try {
          // Await caller's async setup so we can update loading state correctly.
          await widget.onPinSetup(pin);
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _errorMessage = 'Error setting up PIN: $e';
              _isLoading = false;
            });
          }
        }
      } else {
        _shakeController.forward(from: 0);
        setState(() {
          _errorMessage = 'PINs do not match. Please try again.';
          _isConfirmingPin = false;
          _firstPin = '';
        });
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          _clearPinFields();
        }
      }
    }
  }

  void _clearPinFields() {
    for (var controller in _pinControllers) {
      controller.clear();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hiddenPinFields = Opacity(
      opacity: 0.0,
      child: SizedBox(
        height: 0,
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
      body: SafeArea(
        child: Stack(
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
            _isConfirmingPin ? Icons.enhanced_encryption_outlined : Icons.lock_open_outlined,
            size: 28,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _isConfirmingPin ? 'Confirm PIN' : 'Create a PIN',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _isConfirmingPin ? 'Enter your PIN again to confirm' : 'Create a 6-digit PIN for your wallet',
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
    bool hasError = _errorMessage.isNotEmpty && !_isConfirmingPin;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        bool isFilled = _pinControllers[index].text.isNotEmpty;
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
          const SizedBox(), // Placeholder
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
                color: AppTheme.primaryColor,
                strokeWidth: 3,
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
}
