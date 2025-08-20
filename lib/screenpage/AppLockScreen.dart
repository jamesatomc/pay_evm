import 'package:flutter/material.dart';
import '../services/security_service.dart';
import '../utils/app_theme.dart';
import 'PinVerificationScreen.dart';
import 'PinSetupScreen.dart';

class AppLockScreen extends StatefulWidget {
  final VoidCallback? onSuccess;
  final VoidCallback? onUnlocked;
  final bool isSetup;

  const AppLockScreen({
    super.key,
    this.onSuccess,
    this.onUnlocked,
    this.isSetup = false,
  });

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final SecurityService _securityService = SecurityService();
  bool _isLoading = true;
  bool _isPinSetup = false;
  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkSecurityStatus();
  }

  Future<void> _checkSecurityStatus() async {
    try {
      final isPinSetup = await _securityService.isPinSetup();
      
      // Check biometric separately with error handling
      bool isBiometricAvailable = false;
      bool isBiometricEnabled = false;
      
      try {
        isBiometricAvailable = await _securityService.isBiometricAvailable();
        if (isBiometricAvailable) {
          isBiometricEnabled = await _securityService.isBiometricEnabled();
        }
      } catch (e) {
        print('Biometric check failed: $e');
        // Continue without biometric features
      }

      if (mounted) {
        setState(() {
          _isPinSetup = isPinSetup;
          _isBiometricAvailable = isBiometricAvailable;
          _isBiometricEnabled = isBiometricEnabled;
          _isLoading = false;
          _errorMessage = null;
        });

        // Only try biometric if everything is properly set up
        if (_isPinSetup && _isBiometricAvailable && _isBiometricEnabled) {
          await Future.delayed(const Duration(milliseconds: 800));
          if (mounted) {
            _tryBiometricAuth();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Security initialization failed: $e';
        });
      }
    }
  }

  Future<void> _tryBiometricAuth() async {
    try {
      final isAuthenticated = await _securityService.authenticateWithBiometric();
      if (isAuthenticated && mounted) {
        widget.onUnlocked?.call();
        widget.onSuccess?.call();
      }
    } catch (e) {
      print('Biometric authentication failed: $e');
      // Don't show error to user, just fall back to PIN
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.surfaceColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Initializing Security...',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: AppTheme.surfaceColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppTheme.errorColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'Security Error',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });
                    _checkSecurityStatus();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_isPinSetup) {
      return PinSetupScreen(
        onPinSetup: (pin) async {
          try {
            await _securityService.setupPin(pin);
            widget.onSuccess?.call();
          } catch (e) {
            setState(() {
              _errorMessage = 'Failed to setup PIN: $e';
            });
          }
        },
      );
    }

    return PinVerificationScreen(
      title: 'Welcome Back',
      subtitle: 'Please enter your PIN to access your wallet',
      onPinVerified: (pin) {
        widget.onUnlocked?.call();
        widget.onSuccess?.call();
      },
      showBiometric: _isBiometricAvailable && _isBiometricEnabled,
      onBiometricPressed: _isBiometricAvailable ? _tryBiometricAuth : null,
    );
  }
}
