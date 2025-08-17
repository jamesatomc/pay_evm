import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pay_evm/screenpage/WelcomeScreen.dart';
import 'package:pay_evm/screenpage/WalletScreen.dart';
import 'package:pay_evm/screenpage/AppLockScreen.dart';
import 'package:pay_evm/utils/app_theme.dart';
import 'package:pay_evm/services/wallet_service.dart';
import 'package:pay_evm/services/security_service.dart';
import 'package:pay_evm/providers/theme_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Kanari Wallet',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const AppInitializer(),
          );
        },
      ),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> with WidgetsBindingObserver {
  final WalletService _walletService = WalletService();
  final SecurityService _securityService = SecurityService();
  bool _isLoading = true;
  bool _hasWallet = false;
  bool _hasSecuritySetup = false;
  bool _isAuthenticated = false;
  DateTime? _lastBackgroundTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAppState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _walletService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // Record time when app goes to background
        _lastBackgroundTime = DateTime.now();
        break;
      case AppLifecycleState.resumed:
        // Check when returning to app
        if (_lastBackgroundTime != null && _isAuthenticated) {
          final timeDifference = DateTime.now().difference(_lastBackgroundTime!);
          // If away from app for more than 30 seconds, lock app again
          if (timeDifference.inSeconds > 30) {
            setState(() {
              _isAuthenticated = false;
            });
          }
        }
        break;
      default:
        break;
    }
  }

  Future<void> _checkAppState() async {
    try {
      // Add minimum loading time for better UX
      await Future.delayed(const Duration(milliseconds: 1500));
      
      final wallet = await _walletService.getActiveWallet();
      final isPinSetup = await _securityService.isPinSetup();

      setState(() {
        _hasWallet = wallet != null;
        _hasSecuritySetup = isPinSetup;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasWallet = false;
        _hasSecuritySetup = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF667eea),
                Color(0xFF764ba2),
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo with pulse animation
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 1500),
                  tween: Tween(begin: 0.8, end: 1.0),
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
                const Text(
                  'Kanari Wallet',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _getHomeScreen();
  }

  Widget _getHomeScreen() {
    if (!_hasWallet) {
      return const WelcomeScreen();
    } else if (!_hasSecuritySetup) {
      return AppLockScreen(
        onSuccess: () {
          setState(() {
            _hasSecuritySetup = true;
          });
        },
      );
    } else if (!_isAuthenticated) {
      // แสดงหน้าจอ PIN ทุกครั้งที่เปิดแอพ (เมื่อมี wallet และ security setup แล้ว)
      return AppLockScreen(
        onUnlocked: () {
          setState(() {
            _isAuthenticated = true;
          });
        },
      );
    } else {
      return const WalletScreen();
    }
  }
}
