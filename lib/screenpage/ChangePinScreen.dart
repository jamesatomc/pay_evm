import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../services/security_service.dart';
import 'PinVerificationScreen.dart';
import 'PinSetupScreen.dart';

class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  final SecurityService _securityService = SecurityService();
  bool _isVerified = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      body: _isVerified ? _buildNewPinScreen() : _buildVerificationScreen(),
    );
  }

  Widget _buildVerificationScreen() {
    return PinVerificationScreen(
      title: 'Enter Current PIN',
      subtitle: 'Please enter your current PIN to continue',
      onPinVerified: (pin) {
        setState(() {
          _isVerified = true;
        });
      },
      onCancel: () => Navigator.of(context).pop(),
    );
  }

  Widget _buildNewPinScreen() {
    return PinSetupScreen(
      onPinSetup: (newPin) async {
        try {
          await _securityService.setupPin(newPin);
          
          if (mounted) {
            // Show success message
            _showSuccess('PIN changed successfully');
            
            // Navigate back to settings
            Navigator.of(context).pop();
          }
        } catch (e) {
          if (mounted) {
            _showError('Failed to change PIN: $e');
          }
        }
      },
    );
  }

  // Simple notification helpers (consistent with other screens)
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.errorColor),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.secondaryColor),
    );
  }
}
