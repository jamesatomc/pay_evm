import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:kanaripay/screenpage/WelcomeScreen.dart';
import 'package:kanaripay/screenpage/WalletScreen.dart';
import 'package:kanaripay/screenpage/AppLockScreen.dart';
import 'package:kanaripay/utils/app_theme.dart';
import 'package:kanaripay/services/wallet_service.dart';
import 'package:kanaripay/services/security_service.dart';
import 'package:kanaripay/providers/theme_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Enter immersive fullscreen mode (hides status bar)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
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
            themeMode: themeProvider.isDarkMode
                ? ThemeMode.dark
                : ThemeMode.light,
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

class _AppInitializerState extends State<AppInitializer>
    with WidgetsBindingObserver {
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
          final timeDifference = DateTime.now().difference(
            _lastBackgroundTime!,
          );
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
    // Ensure AppTheme dynamic colors are in sync with the active Theme
    AppTheme.updateThemeColors(Theme.of(context).brightness == Brightness.dark);

    if (_isLoading) {
      final bool isDark = Theme.of(context).brightness == Brightness.dark;

      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 1500),
                tween: Tween(begin: 0.86, end: 1.0),
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: isDark ? Theme.of(context).cardColor : Theme.of(context).colorScheme.primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: AppTheme.elevatedShadow,
                      ),
                      child: Icon(Icons.account_balance_wallet, size: 54, color: Theme.of(context).colorScheme.primary),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              Text('Kanari Wallet', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 36),
              SizedBox(width: 44, height: 44, child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary))),
            ],
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
