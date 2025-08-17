import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityService {
  static const String _pinKey = 'user_pin_hash';
  static const String _pinAttemptsKey = 'pin_attempts';
  static const String _lastAttemptKey = 'last_attempt_time';
  static const String _isSecuritySetupKey = 'is_security_setup';
  static const String _biometricEnabledKey = 'biometric_enabled';
  
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  
  // PIN Management
  Future<bool> hasSecuritySetup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isSecuritySetupKey) ?? false;
  }
  
  Future<void> setupPin(String pin) async {
    final hashedPin = _hashPin(pin);
    await _secureStorage.write(key: _pinKey, value: hashedPin);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isSecuritySetupKey, true);
    await prefs.setInt(_pinAttemptsKey, 0); // Reset attempts
  }
  
  Future<bool> verifyPin(String pin) async {
    final storedHash = await _secureStorage.read(key: _pinKey);
    if (storedHash == null) return false;
    
    final hashedPin = _hashPin(pin);
    final isValid = storedHash == hashedPin;
    
    final prefs = await SharedPreferences.getInstance();
    
    if (isValid) {
      await prefs.setInt(_pinAttemptsKey, 0); // Reset attempts on success
    } else {
      final attempts = (prefs.getInt(_pinAttemptsKey) ?? 0) + 1;
      await prefs.setInt(_pinAttemptsKey, attempts);
      await prefs.setInt(_lastAttemptKey, DateTime.now().millisecondsSinceEpoch);
    }
    
    return isValid;
  }
  
  Future<bool> changePin(String oldPin, String newPin) async {
    if (await verifyPin(oldPin)) {
      await setupPin(newPin);
      return true;
    }
    return false;
  }
  
  // Attempt Management
  Future<int> getFailedAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_pinAttemptsKey) ?? 0;
  }
  
  Future<bool> isTemporarilyLocked() async {
    final prefs = await SharedPreferences.getInstance();
    final attempts = prefs.getInt(_pinAttemptsKey) ?? 0;
    
    if (attempts < 3) return false;
    
    final lastAttempt = prefs.getInt(_lastAttemptKey) ?? 0;
    final lockDuration = Duration(seconds: _getLockDuration(attempts));
    final unlockTime = DateTime.fromMillisecondsSinceEpoch(lastAttempt).add(lockDuration);
    
    return DateTime.now().isBefore(unlockTime);
  }
  
  Future<Duration> getRemainingLockTime() async {
    final prefs = await SharedPreferences.getInstance();
    final attempts = prefs.getInt(_pinAttemptsKey) ?? 0;
    final lastAttempt = prefs.getInt(_lastAttemptKey) ?? 0;
    
    if (attempts < 3) return Duration.zero;
    
    final lockDuration = Duration(seconds: _getLockDuration(attempts));
    final unlockTime = DateTime.fromMillisecondsSinceEpoch(lastAttempt).add(lockDuration);
    final remaining = unlockTime.difference(DateTime.now());
    
    return remaining.isNegative ? Duration.zero : remaining;
  }
  
  int _getLockDuration(int attempts) {
    // Progressive lock duration: 30s, 1min, 5min, 15min, 30min, 1hr
    const durations = [30, 60, 300, 900, 1800, 3600];
    final index = (attempts - 3).clamp(0, durations.length - 1);
    return durations[index];
  }
  
  Future<void> resetAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pinAttemptsKey, 0);
  }

  // Biometric Settings
  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }
  
  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);
  }
  
  // Transaction Authorization
  Future<bool> authorizeTransaction({
    required String pin,
    required String transactionType,
    required double amount,
    String? recipient,
  }) async {
    // Verify PIN first
    if (!await verifyPin(pin)) {
      return false;
    }
    
    // Log the transaction authorization
    await _logTransactionAuth(transactionType, amount, recipient);
    
    return true;
  }
  
  Future<void> _logTransactionAuth(String type, double amount, String? recipient) async {
    // TODO: Implement transaction authorization logging
    print('Transaction authorized: $type, Amount: $amount, To: $recipient');
  }
  
  // Security Settings
  Future<void> clearAllSecurityData() async {
    await _secureStorage.delete(key: _pinKey);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_isSecuritySetupKey);
    await prefs.remove(_pinAttemptsKey);
    await prefs.remove(_lastAttemptKey);
    await prefs.remove(_biometricEnabledKey);
  }
  
  // Helper Methods
  String _hashPin(String pin) {
    // Add salt for better security
    const salt = 'kanari_wallet_salt_2025';
    final bytes = utf8.encode(pin + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  // Security Validation
  bool isValidPin(String pin) {
    return pin.length == 6 && RegExp(r'^\d+$').hasMatch(pin);
  }
  
  bool isWeakPin(String pin) {
    if (!isValidPin(pin)) return true;
    
    // Check for common weak patterns
    final weakPatterns = [
      '000000', '111111', '222222', '333333', '444444', '555555',
      '666666', '777777', '888888', '999999', '123456', '654321',
      '000001', '111111', '121212', '101010'
    ];
    
    if (weakPatterns.contains(pin)) return true;
    
    // Check for sequential numbers
    bool isSequential = true;
    for (int i = 1; i < pin.length; i++) {
      if (int.parse(pin[i]) != int.parse(pin[i-1]) + 1) {
        isSequential = false;
        break;
      }
    }
    
    return isSequential;
  }
  
  String getPinStrengthMessage(String pin) {
    if (!isValidPin(pin)) {
      return 'PIN must be 6 digits';
    }
    
    if (isWeakPin(pin)) {
      return 'PIN is too weak. Avoid sequential or repeated numbers';
    }
    
    return 'PIN strength: Good';
  }
}
