import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_theme.dart';

class PinSetupScreen extends StatefulWidget {
  final Function(String) onPinSetup;

  const PinSetupScreen({
    super.key,
    required this.onPinSetup,
  });

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final List<TextEditingController> _pinControllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _pinFocusNodes = List.generate(6, (index) => FocusNode());
  
  String _firstPin = '';
  bool _isConfirmingPin = false;
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    // ไม่ต้อง autofocus เพราะเราใช้ numpad
  }

  @override
  void dispose() {
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
    // Find the last filled field and clear it
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
        _errorMessage = '';
      });
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        _clearPinFields();
      }
    } else {
      if (pin == _firstPin) {
        setState(() => _isLoading = true);
        
        try {
          widget.onPinSetup(pin);
        } catch (e) {
          if (mounted) {
            setState(() {
              _errorMessage = 'Error setting up PIN: $e';
              _isLoading = false;
            });
          }
        }
      } else {
        setState(() {
          _errorMessage = 'PINs do not match. Please try again.';
          _isConfirmingPin = false;
          _firstPin = '';
        });
        await Future.delayed(const Duration(milliseconds: 300));
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
    // ไม่ต้อง focus เพราะเราใช้ numpad
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              // Top spacing
              const SizedBox(height: 60),
              
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
                    _isConfirmingPin ? 'Confirm PIN' : 'Create PIN',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    _isConfirmingPin 
                        ? 'Enter your PIN again'
                        : 'Create a 6-digit PIN',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 60),

              // PIN dots indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  bool isFilled = _pinControllers[index].text.isNotEmpty;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFilled 
                          ? AppTheme.primaryColor 
                          : AppTheme.textMuted.withOpacity(0.3),
                      border: Border.all(
                        color: isFilled 
                            ? AppTheme.primaryColor 
                            : AppTheme.textMuted.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                  );
                }),
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
                      
                      // Empty space, 0, backspace
                      const SizedBox(),
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
}
