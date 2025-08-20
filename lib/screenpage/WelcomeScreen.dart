import 'package:flutter/material.dart';
import 'package:kanaripay/utils/custom_widgets.dart';
import 'package:kanaripay/utils/app_theme.dart';
import 'CreateWalletScreen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    // Start animations
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _slideController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
  final Decoration backgroundDecoration = isDark
    ? const BoxDecoration(gradient: AppTheme.darkBackgroundGradient)
        : BoxDecoration(
            color: AppTheme.lightBackgroundColor,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor.withOpacity(0.06),
                AppTheme.primaryVariant.withOpacity(0.03),
              ],
            ),
          );

    return Scaffold(
      body: Container(
        decoration: backgroundDecoration,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Column(
              children: [
                Expanded(
                  flex: 2,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // App Logo/Icon
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: isDark ? AppTheme.darkBackgroundGradient : null,
                            color: isDark
                                ? null
                                : AppTheme.primaryColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withOpacity(
                                  isDark ? 0.3 : 0.08,
                                ),
                                blurRadius: 30,
                                offset: const Offset(0, 15),
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 60,
                            color: isDark
                                ? Colors.white
                                : AppTheme.primaryColor,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // App Name
                        Text(
                          'Kanari Wallet',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppTheme.textPrimary,
                            letterSpacing: 0.5,
                            shadows: const [
                              Shadow(
                                offset: Offset(0, 2),
                                blurRadius: 8,
                                color: Color(0x40000000),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Subtitle
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.darkCardColor.withOpacity(0.18)
                                : Colors.black.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? AppTheme.darkCardColor.withOpacity(0.28)
                                  : Colors.black.withOpacity(0.06),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Your gateway to the decentralized world',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  flex: 3,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          // Features list
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppTheme.darkCardColor.withOpacity(0.12)
                                    : Colors.black.withOpacity(0.02),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: isDark
                                      ? AppTheme.darkCardColor.withOpacity(0.18)
                                      : Colors.black.withOpacity(0.04),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(
                                      isDark ? 0.08 : 0.04,
                                    ),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildFeatureItem(
                                    isDark,
                                    Icons.security_outlined,
                                    'Secure & Private',
                                    'Your keys, your crypto',
                                  ),
                                  const SizedBox(height: 16),
                                  _buildFeatureItem(
                                    isDark,
                                    Icons.flash_on_outlined,
                                    'Fast Transactions',
                                    'Quick and efficient transfers',
                                  ),
                                  const SizedBox(height: 16),
                                  _buildFeatureItem(
                                    isDark,
                                    Icons.language_outlined,
                                    'Multi-Network',
                                    'Support for multiple blockchains',
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Action Buttons
                          Column(
                            children: [
                              // Create Wallet Button
                              CustomButton(
                                text: 'Get Started',
                                onPressed: () =>
                                    _navigateToCreateWallet(context),
                                icon: Icons.rocket_launch_outlined,
                                backgroundColor: AppTheme.primaryColor,
                              ),

                              const SizedBox(height: 16),

                              // Import Wallet Button
                              CustomButton(
                                text: 'Import Existing Wallet',
                                onPressed: () =>
                                    _navigateToImportWallet(context),
                                icon: Icons.download_outlined,
                                isOutlined: true,
                                backgroundColor: isDark
                                    ? AppTheme.darkCardColor.withOpacity(0.14)
                                    : Colors.black.withOpacity(0.04),
                                textColor: isDark
                                    ? AppTheme.darkTextPrimary
                                    : AppTheme.textPrimary,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(
    bool isDark,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: isDark ? AppTheme.darkBackgroundGradient : AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(isDark ? 0.3 : 0.12),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withOpacity(0.7)
                      : AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _navigateToCreateWallet(BuildContext context) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const CreateWalletScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _navigateToImportWallet(BuildContext context) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const CreateWalletScreen(), // Will show default create tab
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}
