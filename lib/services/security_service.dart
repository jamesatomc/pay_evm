import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class SecurityService {
  static const String _pinKey = 'user_pin_hash';
  static const String _biometricEnabledKey = 'biometric_enabled';
  
  final LocalAuthentication _localAuth = LocalAuthentication();

  // Hash PIN for secure storage
  String _hashPin(String pin) {
    var bytes = utf8.encode(pin);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Set up PIN
  Future<void> setupPin(String pin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hashedPin = _hashPin(pin);
      await prefs.setString(_pinKey, hashedPin);
    } catch (e) {
      throw Exception('Failed to setup PIN: $e');
    }
  }

  // Verify PIN
  Future<bool> verifyPin(String pin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedHash = prefs.getString(_pinKey);
      if (storedHash == null) return false;
      
      final inputHash = _hashPin(pin);
      return storedHash == inputHash;
    } catch (e) {
      return false;
    }
  }

  // Check if PIN is set up
  Future<bool> isPinSetup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_pinKey);
    } catch (e) {
      return false;
    }
  }

  // Check if biometric is available
  Future<bool> isBiometricAvailable() async {
    try {
      // Check if device supports biometric authentication
      final isAvailable = await _localAuth.isDeviceSupported();
      if (!isAvailable) return false;
      
      // Check if biometric sensors are available
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      if (!canCheckBiometrics) return false;
      
      // Get available biometric methods
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } catch (e) {
      // Handle platform-specific errors including FragmentActivity requirement
      if (e is PlatformException) {
        if (e.code == 'no_fragment_activity') {
          print('Biometric authentication requires FragmentActivity');
          return false;
        }
      }
      print('Biometric availability check error: $e');
      return false;
    }
  }

  // Enable/disable biometric
  Future<void> setBiometricEnabled(bool enabled) async {
    try {
      // Only proceed if biometric is actually available
      if (enabled) {
        final isAvailable = await isBiometricAvailable();
        if (!isAvailable) {
          print('Biometric not available, skipping enable');
          return;
        }
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_biometricEnabledKey, enabled);
    } catch (e) {
      print('Failed to set biometric preference: $e');
      // Don't throw exception to prevent app crashes
    }
  }

  // Check if biometric is enabled
  Future<bool> isBiometricEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool(_biometricEnabledKey) ?? false;
      
      // Double-check if biometric is still available
      if (isEnabled) {
        final isAvailable = await isBiometricAvailable();
        if (!isAvailable) {
          // Disable if no longer available
          await setBiometricEnabled(false);
          return false;
        }
      }
      
      return isEnabled;
    } catch (e) {
      print('Error checking biometric enabled status: $e');
      return false;
    }
  }

  // Authenticate with biometric
  Future<bool> authenticateWithBiometric() async {
    try {
      // First check if biometric is available
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        print('Biometric not available for authentication');
        return false;
      }

      final isAuthenticated = await _localAuth.authenticate(
        localizedReason: 'Please verify your identity to access your wallet',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      return isAuthenticated;
    } catch (e) {
      // Handle common biometric authentication errors
      if (e is PlatformException) {
        switch (e.code) {
          case 'no_fragment_activity':
            print('Biometric authentication requires FragmentActivity');
            // Disable biometric features
            await setBiometricEnabled(false);
            break;
          case 'NotAvailable':
            print('Biometric authentication not available');
            break;
          case 'NotEnrolled':
            print('No biometric credentials enrolled');
            break;
          case 'LockedOut':
            print('Biometric authentication locked out');
            break;
          case 'PermanentlyLockedOut':
            print('Biometric authentication permanently locked out');
            break;
          default:
            print('Biometric authentication error: ${e.code} - ${e.message}');
        }
      } else {
        print('Biometric authentication error: $e');
      }
      return false;
    }
  }

  // Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      print('Error getting available biometrics: $e');
      return [];
    }
  }

  // Clear all security data
  Future<void> clearSecurityData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pinKey);
      await prefs.remove(_biometricEnabledKey);
    } catch (e) {
      throw Exception('Failed to clear security data: $e');
    }
  }
}
