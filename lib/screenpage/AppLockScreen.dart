import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/security_service.dart';
import 'dart:async';

class AppLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  
  const AppLockScreen({
    super.key,
    required this.onUnlocked,
  });

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen>
    with TickerProviderStateMixin {
  final SecurityService _securityService = SecurityService();
  final List<TextEditingController> _pinControllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _pinFocusNodes = List.generate(6, (index) => FocusNode());
  
  late AnimationController _fadeController;
  late AnimationController _shakeController;
  late AnimationController _lockController;
  
  late Animation<double> _fadeAnimation;
  late Animation<double> _shakeAnimation;
  late Animation<double> _lockAnimation;
  
  bool _isLoading = false;
  String _errorMessage = '';
  int _attemptCount = 0;
  bool _isLocked = false;
  Timer? _lockTimer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkLockStatus();
    
    // Auto focus first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isLocked) {
        _pinFocusNodes[0].requestFocus();
      }
    });
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _lockController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _shakeAnimation = Tween(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
    
    _lockAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _lockController,
      curve: Curves.bounceOut,
    ));

    _fadeController.forward();
  }

  Future<void> _checkLockStatus() async {
    final isLocked = await _securityService.isTemporarilyLocked();
    if (isLocked) {
      final remainingTime = await _securityService.getRemainingLockTime();
      setState(() {
        _isLocked = true;
        _remainingSeconds = remainingTime.inSeconds;
      });
      _startLockTimer();
      _lockController.forward();
    }
    
    final attempts = await _securityService.getFailedAttempts();
    setState(() {
      _attemptCount = attempts;
    });
  }

  void _startLockTimer() {
    _lockTimer?.cancel();
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingSeconds--;
      });
      
      if (_remainingSeconds <= 0) {
        timer.cancel();
        setState(() {
          _isLocked = false;
        });
        _lockController.reverse();
        _pinFocusNodes[0].requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _shakeController.dispose();
    _lockController.dispose();
    _lockTimer?.cancel();
    
    for (var controller in _pinControllers) {
      controller.dispose();
    }
    for (var focusNode in _pinFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _onPinChanged(int index, String value) {
    if (_isLocked) return;
    
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

  Future<void> _verifyPin(String pin) async {
    if (_isLocked) return;
    
    setState(() => _isLoading = true);
    
    try {
      bool isValid = await _securityService.verifyPin(pin);
      
      if (isValid) {
        // Success - unlock the app
        widget.onUnlocked();
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
      _errorMessage = 'PIN is incorrect. Please try again.';
    });
    
    // Shake animation
    _shakeController.forward().then((_) {
      _shakeController.reverse();
    });
    
    _clearPinFields();
    
    // Check if should be locked
    if (_attemptCount >= 3) {
      _checkLockStatus();
    }
  }

  void _clearPinFields() {
    for (var controller in _pinControllers) {
      controller.clear();
    }
    if (!_isLocked) {
      _pinFocusNodes[0].requestFocus();
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1a1a2e),
              Color(0xFF16213e),
              Color(0xFF0f3460),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  
                  // App Logo with lock animation
                  AnimatedBuilder(
                    animation: _lockAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: _isLocked ? [
                              const Color(0xFFE53E3E),
                              const Color(0xFFC53030),
                            ] : [
                              const Color(0xFF6C63FF),
                              const Color(0xFF5A52E8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: (_isLocked 
                                  ? const Color(0xFFE53E3E) 
                                  : const Color(0xFF6C63FF)).withOpacity(0.3),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Transform.scale(
                          scale: 1.0 + (_lockAnimation.value * 0.1),
                          child: Icon(
                            _isLocked ? Icons.lock_outlined : Icons.security,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // App Name
                  const Text(
                    'Kanari Wallet',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 2),
                          blurRadius: 8,
                          color: Color(0x40000000),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Status message
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _isLocked 
                      //eng
                          ? 'The app is temporarily locked\nPlease wait ${_formatTime(_remainingSeconds)} to try again'
                          : 'Please enter a 6-digit PIN to access the app',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  const Spacer(flex: 1),
                  
                  // PIN input fields with shake animation
                  if (!_isLocked) ...[
                    AnimatedBuilder(
                      animation: _shakeAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(_shakeAnimation.value * 10, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(6, (index) => _buildPinField(index)),
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 24),
                  ],
                  
                  // Error message
                  if (_errorMessage.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53E3E).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFE53E3E).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Color(0xFFE53E3E),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage,
                              style: const TextStyle(
                                color: Color(0xFFE53E3E),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Attempt counter
                  if (_attemptCount > 0 && !_isLocked)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECC94B).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFECC94B).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        //eng
                        'Attempts remaining: ${3 - _attemptCount}',
                        style: const TextStyle(
                          color: Color(0xFFECC94B),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  
                  const Spacer(flex: 2),
                  
                  // Loading indicator
                  if (_isLoading)
                    const SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Security notice
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.white70,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            //eng
                            'Your PIN is used to secure your Wallet',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.7),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinField(int index) {
    bool hasValue = _pinControllers[index].text.isNotEmpty;
    bool hasError = _errorMessage.isNotEmpty;
    
    return Container(
      width: 50,
      height: 60,
      decoration: BoxDecoration(
        border: Border.all(
          color: hasError 
              ? const Color(0xFFE53E3E)
              : hasValue 
                  ? const Color(0xFF6C63FF)
                  : Colors.white.withOpacity(0.3),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
        color: hasValue 
            ? const Color(0xFF6C63FF).withOpacity(0.1) 
            : Colors.white.withOpacity(0.05),
      ),
      child: TextField(
        controller: _pinControllers[index],
        focusNode: _pinFocusNodes[index],
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        keyboardType: TextInputType.number,
        maxLength: 1,
        obscureText: true,
        enabled: !_isLocked && !_isLoading,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
        ),
        onChanged: (value) => _onPinChanged(index, value),
      ),
    );
  }
}
