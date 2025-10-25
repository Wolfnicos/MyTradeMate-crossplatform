import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/theme_provider.dart';
import '../services/binance_service.dart';
import '../services/app_settings_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final BinanceService _binanceService = BinanceService();

  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _apiSecretController = TextEditingController();

  bool _biometricEnabled = false;
  bool _canCheckBiometrics = false;
  bool _isTestingConnection = false;
  bool _obscureSecret = true;
  String _permissionLevel = 'read';
  String _quote = 'USDT';

  @override
  void initState() {
    super.initState();
    // Load settings after frame is rendered (non-blocking)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBiometricSupport();
      _loadSettings();
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _apiSecretController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricSupport() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      setState(() {
        _canCheckBiometrics = canCheck && isDeviceSupported;
      });
    } catch (e) {
      debugPrint('Error checking biometric support: $e');
    }
  }

  Future<void> _loadSettings() async {
    // Load settings and credentials in parallel for faster startup
    final results = await Future.wait([
      SharedPreferences.getInstance(),
      _binanceService.loadCredentials(),
    ]);

    final prefs = results[0] as SharedPreferences;

    // Single setState to avoid multiple rebuilds
    if (mounted) {
      setState(() {
        _biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
        _permissionLevel = AppSettingsService().permissionLevel;
        _quote = AppSettingsService().quoteCurrency;
        _apiKeyController.text = _binanceService.apiKey ?? '';
        _apiSecretController.text = _binanceService.apiSecret ?? '';
      });
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      // Try to authenticate before enabling
      try {
        final authenticated = await _localAuth.authenticate(
          localizedReason: 'Enable biometric authentication',
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
          ),
        );

        if (authenticated) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('biometric_enabled', true);
          setState(() => _biometricEnabled = true);
          _showSnackBar('Biometric authentication enabled', isError: false);
        }
      } catch (e) {
        _showSnackBar('Error enabling authentication: $e', isError: true);
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric_enabled', false);
      setState(() => _biometricEnabled = false);
      _showSnackBar('Biometric authentication disabled', isError: false);
    }
  }

  Future<void> _saveApiCredentials() async {
    final apiKey = _apiKeyController.text.trim();
    final apiSecret = _apiSecretController.text.trim();

    if (apiKey.isEmpty || apiSecret.isEmpty) {
      _showSnackBar('Please fill both fields', isError: true);
      return;
    }

    try {
      await _binanceService.saveCredentials(apiKey, apiSecret);
      _showSnackBar('Credentials saved successfully', isError: false);
      // Keep them in the fields so they persist visually
      setState(() {});
    } catch (e) {
      _showSnackBar('Error saving credentials: $e', isError: true);
    }
  }

  Future<void> _testConnection() async {
    setState(() => _isTestingConnection = true);

    try {
      final success = await _binanceService.testConnection();
      if (success) {
        _showSnackBar('Connection successful! API keys are valid.', isError: false);
      } else {
        _showSnackBar('Connection failed. Please check your API keys.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => _isTestingConnection = false);
    }
  }

  Future<void> _clearCredentials() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Confirm Deletion', style: AppTheme.headingLarge),
        content: Text(
          'Are you sure you want to delete your API credentials?',
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _binanceService.clearCredentials();
      _showSnackBar('Credentials deleted', isError: false);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.error : AppTheme.success,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: Text('Settings', style: AppTheme.headingLarge),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacing20),
        children: [
          // Security Section
          _buildSectionHeader('Security', Icons.security),
          GlassCard(
            child: Column(
              children: [
                if (_canCheckBiometrics)
                  SwitchListTile(
                    title: Text('Biometric Authentication', style: AppTheme.bodyLarge),
                    subtitle: Text(
                      'Lock app with Face ID / Fingerprint',
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.textTertiary),
                    ),
                    value: _biometricEnabled,
                    onChanged: _toggleBiometric,
                    activeThumbColor: AppTheme.primary,
                    secondary: Container(
                      padding: const EdgeInsets.all(AppTheme.spacing8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                      ),
                      child: const Icon(Icons.fingerprint, color: AppTheme.primary),
                    ),
                  )
                else
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(AppTheme.spacing8),
                      decoration: BoxDecoration(
                        color: AppTheme.holdYellow.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                      ),
                      child: const Icon(Icons.warning_amber, color: AppTheme.holdYellow),
                    ),
                    title: Text('Biometric Unavailable', style: AppTheme.bodyLarge),
                    subtitle: Text(
                      'This device does not support biometric authentication',
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.textTertiary),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spacing24),

          // API Permission Level
          _buildSectionHeader('API Permission Level', Icons.vpn_lock),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Control what your AI assistant can do',
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  Wrap(
                    spacing: AppTheme.spacing12,
                    runSpacing: AppTheme.spacing12,
                    children: [
                      // READ ONLY (Free)
                      GestureDetector(
                        onTap: () async {
                          await AppSettingsService().setPermissionLevel('read');
                          setState(() => _permissionLevel = 'read');
                          _showSnackBar('API Permission: Read Only (Free)', isError: false);
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppTheme.spacing16),
                          decoration: BoxDecoration(
                            gradient: _permissionLevel == 'read' ? AppTheme.primaryGradient : null,
                            color: _permissionLevel == 'read' ? null : AppTheme.glassWhite,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                            border: Border.all(
                              color: _permissionLevel == 'read' ? AppTheme.primary : AppTheme.glassBorder,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(AppTheme.spacing8),
                                decoration: BoxDecoration(
                                  color: _permissionLevel == 'read'
                                      ? Colors.white.withOpacity(0.2)
                                      : AppTheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                                ),
                                child: Icon(
                                  Icons.visibility,
                                  color: _permissionLevel == 'read' ? Colors.white : AppTheme.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: AppTheme.spacing12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            'READ ONLY',
                                            style: AppTheme.labelLarge.copyWith(
                                              color: _permissionLevel == 'read' ? Colors.white : AppTheme.textPrimary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: AppTheme.spacing8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppTheme.spacing8,
                                            vertical: AppTheme.spacing4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.success.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                                          ),
                                          child: Text(
                                            'FREE',
                                            style: AppTheme.labelSmall.copyWith(
                                              color: AppTheme.success,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: AppTheme.spacing4),
                                    Text(
                                      'View portfolio & get AI analysis',
                                      style: AppTheme.bodySmall.copyWith(
                                        color: _permissionLevel == 'read'
                                            ? Colors.white.withOpacity(0.8)
                                            : AppTheme.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // TRADING ENABLED (Premium)
                      GestureDetector(
                        onTap: () async {
                          // TODO: Show payment/subscription dialog in future
                          await AppSettingsService().setPermissionLevel('trading');
                          setState(() => _permissionLevel = 'trading');
                          _showSnackBar('API Permission: Trading Enabled (Premium)', isError: false);
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppTheme.spacing16),
                          decoration: BoxDecoration(
                            gradient: _permissionLevel == 'trading' ? AppTheme.buyGradient : null,
                            color: _permissionLevel == 'trading' ? null : AppTheme.glassWhite,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                            border: Border.all(
                              color: _permissionLevel == 'trading' ? AppTheme.buyGreen : AppTheme.glassBorder,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(AppTheme.spacing8),
                                decoration: BoxDecoration(
                                  color: _permissionLevel == 'trading'
                                      ? Colors.white.withOpacity(0.2)
                                      : AppTheme.buyGreen.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                                ),
                                child: Icon(
                                  Icons.swap_horiz,
                                  color: _permissionLevel == 'trading' ? Colors.white : AppTheme.buyGreen,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: AppTheme.spacing12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            'TRADING ENABLED',
                                            style: AppTheme.labelLarge.copyWith(
                                              color: _permissionLevel == 'trading' ? Colors.white : AppTheme.textPrimary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: AppTheme.spacing8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppTheme.spacing8,
                                            vertical: AppTheme.spacing4,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: AppTheme.premiumGoldGradient,
                                            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.12),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            'PRO',
                                            style: AppTheme.labelSmall.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: AppTheme.spacing4),
                                    Text(
                                      'AI can execute trades for you',
                                      style: AppTheme.bodySmall.copyWith(
                                        color: _permissionLevel == 'trading'
                                            ? Colors.white.withOpacity(0.8)
                                            : AppTheme.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppTheme.spacing24),

          // Quote Currency
          _buildSectionHeader('Quote Currency', Icons.currency_exchange),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select the currency for prices and totals (Binance supported)',
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  Wrap(
                    spacing: AppTheme.spacing8,
                    runSpacing: AppTheme.spacing8,
                    children: ['USDT', 'EUR', 'USDC'].map((q) {
                      final isSelected = _quote == q;
                      return GestureDetector(
                        onTap: () async {
                          final svc = AppSettingsService();
                          await svc.setQuoteCurrency(q);
                          setState(() => _quote = q);
                          _showSnackBar('Quote currency set to: $q', isError: false);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacing16,
                            vertical: AppTheme.spacing12,
                          ),
                          decoration: BoxDecoration(
                            gradient: isSelected ? AppTheme.primaryGradient : null,
                            color: isSelected ? null : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                            border: Border.all(
                              color: isSelected ? Colors.transparent : Theme.of(context).colorScheme.outlineVariant.withOpacity(0.6),
                            ),
                          ),
                          child: Text(
                            q,
                            style: AppTheme.bodyMedium.copyWith(
                              color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppTheme.spacing24),

          // API Section
          _buildSectionHeader('Binance API', Icons.vpn_key),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _apiKeyController,
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'API Key',
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        borderSide: BorderSide(color: AppTheme.glassBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        borderSide: BorderSide(color: AppTheme.glassBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                      ),
                      prefixIcon: const Icon(Icons.vpn_key, color: AppTheme.primary),
                      suffixIcon: _binanceService.hasCredentials
                          ? Tooltip(
                              message: 'Loaded from secure storage',
                              child: const Icon(Icons.verified, color: AppTheme.success),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  TextField(
                    controller: _apiSecretController,
                    obscureText: _obscureSecret,
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Secret Key',
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        borderSide: BorderSide(color: AppTheme.glassBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        borderSide: BorderSide(color: AppTheme.glassBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                      ),
                      prefixIcon: const Icon(Icons.lock, color: AppTheme.primary),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureSecret ? Icons.visibility : Icons.visibility_off,
                          color: AppTheme.textSecondary,
                        ),
                        onPressed: () => setState(() => _obscureSecret = !_obscureSecret),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saveApiCredentials,
                          icon: const Icon(Icons.save),
                          label: const Text('Save'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacing12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isTestingConnection ? null : _testConnection,
                          icon: _isTestingConnection
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.wifi),
                          label: const Text('Test'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                            side: const BorderSide(color: AppTheme.primary),
                            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacing12),
                  TextButton.icon(
                    onPressed: _clearCredentials,
                    icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                    label: const Text('Delete Credentials', style: TextStyle(color: AppTheme.error)),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppTheme.spacing24),

          // Appearance Section
          _buildSectionHeader('Appearance', Icons.palette),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Theme Mode', style: AppTheme.headingSmall),
                  const SizedBox(height: AppTheme.spacing16),
                  Wrap(
                    spacing: AppTheme.spacing8,
                    runSpacing: AppTheme.spacing8,
                    children: [
                      {'label': 'Light', 'icon': Icons.light_mode, 'mode': AppThemeMode.light},
                      {'label': 'Dark', 'icon': Icons.dark_mode, 'mode': AppThemeMode.dark},
                      {'label': 'System', 'icon': Icons.settings_brightness, 'mode': AppThemeMode.system},
                    ].map((theme) {
                      final isSelected = themeProvider.themeMode == theme['mode'];
                      return GestureDetector(
                        onTap: () {
                          themeProvider.setThemeMode(theme['mode'] as AppThemeMode);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacing16,
                            vertical: AppTheme.spacing12,
                          ),
                          decoration: BoxDecoration(
                            gradient: isSelected ? AppTheme.primaryGradient : null,
                            color: isSelected ? null : AppTheme.glassWhite,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                            border: Border.all(
                              color: isSelected ? Colors.transparent : AppTheme.glassBorder,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                theme['icon'] as IconData,
                                color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                                size: 20,
                              ),
                              const SizedBox(width: AppTheme.spacing8),
                              Text(
                                theme['label'] as String,
                                style: AppTheme.bodyMedium.copyWith(
                                  color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppTheme.spacing24),

          // Sign Out Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () async {
                // Show confirmation dialog
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: AppTheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                    ),
                    title: Text('Sign Out', style: AppTheme.headingLarge),
                    content: Text(
                      'Are you sure you want to sign out?',
                      style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.error,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Sign Out'),
                      ),
                    ],
                  ),
                );
                
                if (confirmed == true && mounted) {
                  // Sign out
                  await context.read<AuthService>().signOut();
                  if (mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil('/onboarding', (route) => false);
                  }
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppTheme.spacing24),

          // About Section
          _buildSectionHeader('About', Icons.info_outline),
          GlassCard(
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(AppTheme.spacing8),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                    ),
                    child: const Icon(Icons.rocket_launch, color: Colors.white),
                  ),
                  title: Text('MyTradeMate', style: AppTheme.headingMedium),
                  subtitle: Text(
                    'Version 1.0.0 - Premium AI Trading',
                    style: AppTheme.bodySmall.copyWith(color: AppTheme.textTertiary),
                  ),
                ),
                const Divider(color: AppTheme.glassBorder),
                ListTile(
                  leading: const Icon(Icons.privacy_tip, color: AppTheme.primary),
                  title: Text('Privacy Policy', style: AppTheme.bodyMedium),
                  subtitle: Text('How we handle your data', style: AppTheme.bodySmall.copyWith(color: AppTheme.textTertiary)),
                  trailing: const Icon(Icons.open_in_new, color: AppTheme.textTertiary),
                  onTap: () => _openPrivacyPolicy(),
                ),
                ListTile(
                  leading: const Icon(Icons.description, color: AppTheme.primary),
                  title: Text('Terms of Service', style: AppTheme.bodyMedium),
                  subtitle: Text('Legal terms and conditions', style: AppTheme.bodySmall.copyWith(color: AppTheme.textTertiary)),
                  trailing: const Icon(Icons.open_in_new, color: AppTheme.textTertiary),
                  onTap: () => _openTermsOfService(),
                ),
                ListTile(
                  leading: const Icon(Icons.help_outline, color: AppTheme.primary),
                  title: Text('Support & FAQ', style: AppTheme.bodyMedium),
                  subtitle: Text('Get help and answers', style: AppTheme.bodySmall.copyWith(color: AppTheme.textTertiary)),
                  trailing: const Icon(Icons.open_in_new, color: AppTheme.textTertiary),
                  onTap: () => _openSupport(),
                ),
                ListTile(
                  leading: const Icon(Icons.email, color: AppTheme.primary),
                  title: Text('Contact Us', style: AppTheme.bodyMedium),
                  subtitle: Text('Get in touch with support', style: AppTheme.bodySmall.copyWith(color: AppTheme.textTertiary)),
                  trailing: const Icon(Icons.open_in_new, color: AppTheme.textTertiary),
                  onTap: () => _openContact(),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline, color: AppTheme.primary),
                  title: Text('About MyTradeMate', style: AppTheme.bodyMedium),
                  subtitle: Text('Visit our website', style: AppTheme.bodySmall.copyWith(color: AppTheme.textTertiary)),
                  trailing: const Icon(Icons.open_in_new, color: AppTheme.textTertiary),
                  onTap: () => _openWebsite(),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spacing40),
        ],
      ),
    );
  }

  Future<void> _openPrivacyPolicy() async {
    final Uri url = Uri.parse('https://mytrademate.app/privacy.html');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      _showSnackBar('Could not open Privacy Policy', isError: true);
    }
  }

  Future<void> _openTermsOfService() async {
    final Uri url = Uri.parse('https://mytrademate.app/terms.html');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      _showSnackBar('Could not open Terms of Service', isError: true);
    }
  }

  Future<void> _openSupport() async {
    final Uri url = Uri.parse('https://mytrademate.app/support.html');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      _showSnackBar('Could not open Support', isError: true);
    }
  }

  Future<void> _openContact() async {
    final Uri url = Uri.parse('https://mytrademate.app/contact.html');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      _showSnackBar('Could not open Contact page', isError: true);
    }
  }

  Future<void> _openWebsite() async {
    final Uri url = Uri.parse('https://mytrademate.app');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      _showSnackBar('Could not open website', isError: true);
    }
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing8),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
            ),
            const SizedBox(width: AppTheme.spacing12),
            Text('MyTradeMate', style: AppTheme.headingLarge),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'AI-Powered Crypto Trading Assistant',
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppTheme.spacing16),
              _buildAboutRow('Version', '1.0.0+1'),
              _buildAboutRow('Build', 'Production'),
              _buildAboutRow('Platform', 'Flutter 3.9.2'),
              const SizedBox(height: AppTheme.spacing16),
              Text(
                'Features:',
                style: AppTheme.labelLarge.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: AppTheme.spacing8),
              _buildFeatureRow('🤖', 'AI predictions on 6 timeframes'),
              _buildFeatureRow('📊', '4 order types (Market, Limit, Stop)'),
              _buildFeatureRow('💼', 'Real-time portfolio tracking'),
              _buildFeatureRow('🔒', 'Bank-level security'),
              _buildFeatureRow('📈', 'Professional charts'),
              const SizedBox(height: AppTheme.spacing16),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber, color: AppTheme.warning, size: 18),
                        const SizedBox(width: AppTheme.spacing8),
                        Text(
                          'Disclaimer',
                          style: AppTheme.labelMedium.copyWith(
                            color: AppTheme.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    Text(
                      'Cryptocurrency trading involves substantial risk. This app provides tools and information but does NOT constitute financial advice. Trade responsibly.',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacing16),
              Center(
                child: Text(
                  '© 2025 MyTradeMate. All rights reserved.',
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.textTertiary),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              final Uri url = Uri.parse('https://mytrademate.com');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.language),
            label: const Text('Visit Website'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
          ),
          Text(
            value,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: Text(
              text,
              style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 20),
          const SizedBox(width: AppTheme.spacing8),
          Text(
            title,
            style: AppTheme.headingMedium.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
