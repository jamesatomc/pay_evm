import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/theme_provider.dart';
import '../utils/app_theme.dart';
import '../services/security_service.dart';
import 'ChangePinScreen.dart';
import 'MarkdownPage.dart'; // เพิ่มการนำเข้า

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = 'Loading...';
  final SecurityService _securityService = SecurityService();
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
    _loadBiometricSettings();
  }

  Future<void> _loadPackageInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = '${packageInfo.version}+${packageInfo.buildNumber}';
    });
  }

  Future<void> _loadBiometricSettings() async {
    try {
      final isAvailable = await _securityService.isBiometricAvailable();
      final isEnabled = await _securityService.isBiometricEnabled();
      
      if (mounted) {
        setState(() {
          _biometricAvailable = isAvailable;
          _biometricEnabled = isEnabled;
        });
      }
    } catch (e) {
      print('Error loading biometric settings: $e');
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    try {
      if (value) {
        // Test biometric authentication before enabling
        final isAuthenticated = await _securityService.authenticateWithBiometric();
        if (!isAuthenticated) {
          _showError('Biometric authentication failed');
          return;
        }
      }
      
      await _securityService.setBiometricEnabled(value);
      
      setState(() {
        _biometricEnabled = value;
      });
      
      _showSuccess(
        value 
            ? 'Biometric authentication enabled'
            : 'Biometric authentication disabled',
      );
    } catch (e) {
      _showError('Failed to toggle biometric: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Theme Section
            _buildSectionTitle(context, 'Appearance'),
            const SizedBox(height: AppTheme.spacingM),
            _buildThemeSelector(context),
            
            const SizedBox(height: AppTheme.spacingXL),
            
            // Security Section
            _buildSectionTitle(context, 'Security'),
            const SizedBox(height: AppTheme.spacingM),
            _buildSecurityOptions(context),
            
            const SizedBox(height: AppTheme.spacingXL),
            
            // About Section
            _buildSectionTitle(context, 'About'),
            const SizedBox(height: AppTheme.spacingM),
            _buildAboutSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildThemeSelector(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Container(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: themeProvider.isDarkMode 
                    ? AppTheme.primaryColor.withOpacity(0.2)
                    : AppTheme.lightSurfaceColor,
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
              ),
              child: Icon(
                themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                color: themeProvider.isDarkMode 
                    ? AppTheme.primaryColor 
                    : AppTheme.lightTextSecondary,
              ),
            ),
            title: const Text(
              'Dark Mode',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              themeProvider.isDarkMode 
                  ? 'Easy on the eyes' 
                  : 'Classic bright interface',
            ),
            trailing: Switch(
              value: themeProvider.isDarkMode,
              onChanged: (value) => themeProvider.setDarkMode(value),
              activeColor: AppTheme.primaryColor,
            ),
            contentPadding: EdgeInsets.zero,
          ),
        );
      },
    );
  }

  Widget _buildSecurityOptions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSettingItem(
            context,
            'Change PIN',
            'Update your security PIN',
            Icons.lock_outline,
            () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ChangePinScreen(),
                ),
              );
            },
          ),
          const Divider(height: AppTheme.spacingL),
          // Biometric toggle
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _biometricEnabled 
                    ? AppTheme.primaryColor.withOpacity(0.2)
                    : Theme.of(context).brightness == Brightness.dark
                        ? AppTheme.darkCardColor
                        : AppTheme.lightSurfaceColor,
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
              ),
              child: Icon(
                Icons.fingerprint,
                color: _biometricEnabled 
                    ? AppTheme.primaryColor 
                    : Theme.of(context).brightness == Brightness.dark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
              ),
            ),
            title: const Text(
              'Biometric Authentication',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              _biometricAvailable 
                  ? (_biometricEnabled ? 'Enabled for quick access' : 'Use fingerprint or face unlock')
                  : 'Not available on this device',
            ),
            trailing: _biometricAvailable
                ? Switch(
                    value: _biometricEnabled,
                    onChanged: _toggleBiometric,
                    activeColor: AppTheme.primaryColor,
                  )
                : null,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSettingItem(
            context,
            'Version',
            _version,
            Icons.info_outline,
            null,
          ),
          const Divider(height: AppTheme.spacingL),
          _buildSettingItem(
            context,
            'Privacy Policy',
            'Read our privacy policy',
            Icons.privacy_tip_outlined,
            () {
              // เปิดหน้า markdown
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const MarkdownPage(
                    title: 'Privacy Policy',
                    assetPath: 'assets/privacy_policy.md',
                  ),
                ),
              );
            },
          ),
          const Divider(height: AppTheme.spacingL),
          _buildSettingItem(
            context,
            'Terms of Service',
            'Read our terms of service',
            Icons.description_outlined,
            () {
              // เปิดหน้า markdown
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const MarkdownPage(
                    title: 'Terms of Service',
                    assetPath: 'assets/terms_of_service.md',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback? onTap,
  ) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkCardColor
              : AppTheme.lightSurfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
        ),
        child: Icon(
          icon,
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkTextSecondary
              : AppTheme.lightTextSecondary,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle),
      trailing: onTap != null
          ? Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.darkTextMuted
                  : AppTheme.lightTextMuted,
            )
          : null,
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  // Add simple notification helpers (aligned with CreateWalletScreen style)
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
