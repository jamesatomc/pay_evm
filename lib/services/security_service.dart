import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:cryptography/cryptography.dart';

class SecurityService {
  static const String _pinKey = 'user_pin_hash';
  static const String _pinSaltKey = 'user_pin_salt';
  static const String _biometricEnabledKey = 'biometric_enabled';
  
  final LocalAuthentication _localAuth = LocalAuthentication();

  // Derive Argon2id hash (returns base64 encoded hash and salt)
  Future<Map<String, String>> _deriveHashAndSalt(String pin) async {
    final algorithm = Argon2id(
      memory: 10 * 1000, // 10 MB
      parallelism: 2,
      iterations: 1,
      hashLength: 32,
    );

    // generate a 16-byte random salt (nonce)
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final secretKey = await algorithm.deriveKeyFromPassword(
      password: pin,
      nonce: salt,
    );
    final secretBytes = await secretKey.extractBytes();
    return {
      'hash': base64.encode(secretBytes),
      'salt': base64.encode(salt),
    };
  }

  // Derive hash with an existing salt (base64 compare)
  Future<String> _deriveHashWithSalt(String pin, List<int> salt) async {
    final algorithm = Argon2id(
      memory: 10 * 1000,
      parallelism: 2,
      iterations: 1,
      hashLength: 32,
    );
    final secretKey = await algorithm.deriveKeyFromPassword(
      password: pin,
      nonce: salt,
    );
    final secretBytes = await secretKey.extractBytes();
    return base64.encode(secretBytes);
  }

  // Set up PIN
  Future<void> setupPin(String pin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final result = await _deriveHashAndSalt(pin);
      await prefs.setString(_pinKey, result['hash']!);
      await prefs.setString(_pinSaltKey, result['salt']!);
    } catch (e) {
      throw Exception('Failed to setup PIN: $e');
    }
  }

  // Verify PIN
  Future<bool> verifyPin(String pin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedHash = prefs.getString(_pinKey);
      final storedSaltBase64 = prefs.getString(_pinSaltKey);
      if (storedHash == null || storedSaltBase64 == null) return false;
      
      final salt = base64.decode(storedSaltBase64);
      final derivedHash = await _deriveHashWithSalt(pin, salt);
      return storedHash == derivedHash;
    } catch (e) {
      return false;
    }
  }

  // Check if PIN is set up
  Future<bool> isPinSetup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // ensure both hash and salt are present
      return prefs.containsKey(_pinKey) && prefs.containsKey(_pinSaltKey);
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
      await prefs.remove(_pinSaltKey);
      await prefs.remove(_biometricEnabledKey);
    } catch (e) {
      throw Exception('Failed to clear security data: $e');
    }
  }
}
