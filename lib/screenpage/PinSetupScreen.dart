import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_theme.dart';
import '../services/security_service.dart';

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
  final SecurityService _securityService = SecurityService();
  
  String _firstPin = '';
  bool _isConfirmingPin = false;
  bool _isLoading = false;
  String _errorMessage = '';
  bool _showBiometricOption = false;
  bool _enableBiometric = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pinFocusNodes.isNotEmpty && mounted) {
        _pinFocusNodes[0].requestFocus();
      }
    });
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final isAvailable = await _securityService.isBiometricAvailable();
      if (mounted) {
        setState(() {
          _showBiometricOption = isAvailable;
        });
      }
    } catch (e) {
      print('Biometric availability check failed: $e');
      if (mounted) {
        setState(() {
          _showBiometricOption = false;
        });
      }
    }
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
          if (_enableBiometric && _showBiometricOption) {
            try {
              await _securityService.setBiometricEnabled(true);
            } catch (e) {
              print('Failed to enable biometric, continuing with PIN only: $e');
            }
          }
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
    if (_pinFocusNodes.isNotEmpty) {
      _pinFocusNodes[0].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: const Text('Security Setup'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.security,
                      size: 40,
                      color: AppTheme.primaryColor,
                    ),
                  ),

                  const SizedBox(height: 32),

                  Text(
                    _isConfirmingPin ? 'Confirm Your PIN' : 'Create Your PIN',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    _isConfirmingPin 
                        ? 'Please enter your PIN again to confirm'
                        : 'Create a 6-digit PIN to secure your wallet',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 48),

                  // Responsive PIN input fields
                  LayoutBuilder(
                    builder: (context, constraints) {
                      double maxWidth = constraints.maxWidth;
                      double totalSpacing = 5 * 8.0;
                      double availableWidth = maxWidth - totalSpacing;
                      double fieldWidth = (availableWidth / 6).clamp(40.0, 60.0);
                      
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(6, (index) => 
                          _buildPinField(index, fieldWidth)
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
                          Icon(Icons.error_outline, color: AppTheme.errorColor, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage,
                              style: TextStyle(color: AppTheme.errorColor, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_showBiometricOption && !_isConfirmingPin) ...[
                    const SizedBox(height: 32),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.fingerprint, color: AppTheme.primaryColor),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Enable Biometric Authentication',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: _enableBiometric,
                                  onChanged: (value) {
                                    setState(() => _enableBiometric = value);
                                  },
                                  activeColor: AppTheme.primaryColor,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Use fingerprint or face unlock for faster access',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  if (_isLoading)
                    CircularProgressIndicator(color: AppTheme.primaryColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinField(int index, double width) {
    bool hasValue = _pinControllers[index].text.isNotEmpty;
    bool hasError = _errorMessage.isNotEmpty;
    
    return Container(
      width: width,
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
          fontSize: width > 45 ? 24 : 20,
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
          _pinControllers[index].selection = TextSelection.fromPosition(
            TextPosition(offset: _pinControllers[index].text.length),
          );
        },
      ),
    );
  }
}
