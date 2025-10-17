import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';
import '../services/binance_service.dart';
import '../services/app_settings_service.dart';
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
  bool _paperTrading = false;
  String _quote = 'USDT';

  @override
  void initState() {
    super.initState();
    _checkBiometricSupport();
    _loadSettings();
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
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
      _paperTrading = prefs.getBool('paper_trading') ?? false;
      _quote = prefs.getString('quote_currency') ?? 'USDT';
    });

    // Load API credentials
    await _binanceService.loadCredentials();
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
      _apiKeyController.clear();
      _apiSecretController.clear();
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
      backgroundColor: AppTheme.background,
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
                    activeColor: AppTheme.primary,
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

          // Trading Section
          _buildSectionHeader('Trading', Icons.trending_up),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  title: Text('Paper Trading', style: AppTheme.bodyLarge),
                  subtitle: Text(
                    'Simulate orders without real money',
                    style: AppTheme.bodySmall.copyWith(color: AppTheme.textTertiary),
                  ),
                  value: _paperTrading,
                  onChanged: (bool v) async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('paper_trading', v);
                    setState(() => _paperTrading = v);
                    _showSnackBar(v ? 'Paper Trading enabled' : 'Paper Trading disabled', isError: false);
                  },
                  activeColor: AppTheme.primary,
                  secondary: Container(
                    padding: const EdgeInsets.all(AppTheme.spacing8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                    ),
                    child: const Icon(Icons.description_outlined, color: AppTheme.primary),
                  ),
                ),
                const Divider(color: AppTheme.glassBorder),
                Padding(
                  padding: const EdgeInsets.all(AppTheme.spacing16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Environment', style: AppTheme.headingSmall),
                      const SizedBox(height: AppTheme.spacing12),
                      Wrap(
                        spacing: AppTheme.spacing8,
                        children: [
                          {'label': 'Live', 'value': 'live'},
                          {'label': 'Testnet', 'value': 'testnet'},
                        ].map((m) {
                          final isSelected = AppSettingsService().tradingEnvironment == m['value'];
                          return GestureDetector(
                            onTap: () async {
                              await AppSettingsService().setTradingEnvironment(m['value'] as String);
                              setState(() {});
                              _showSnackBar('Environment: ${m['label']}', isError: false);
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
                              child: Text(
                                m['label'] as String,
                                style: AppTheme.bodyMedium.copyWith(
                                  color: isSelected ? Colors.white : AppTheme.textPrimary,
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
              ],
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
                    'Select the currency for prices and totals',
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  Wrap(
                    spacing: AppTheme.spacing8,
                    runSpacing: AppTheme.spacing8,
                    children: ['USDT', 'USDC', 'USD', 'EUR'].map((q) {
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
                            color: isSelected ? null : AppTheme.glassWhite,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                            border: Border.all(
                              color: isSelected ? Colors.transparent : AppTheme.glassBorder,
                            ),
                          ),
                          child: Text(
                            q,
                            style: AppTheme.bodyMedium.copyWith(
                              color: isSelected ? Colors.white : AppTheme.textPrimary,
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
                                color: isSelected ? Colors.white : AppTheme.textPrimary,
                                size: 20,
                              ),
                              const SizedBox(width: AppTheme.spacing8),
                              Text(
                                theme['label'] as String,
                                style: AppTheme.bodyMedium.copyWith(
                                  color: isSelected ? Colors.white : AppTheme.textPrimary,
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
                  leading: const Icon(Icons.bug_report, color: AppTheme.primary),
                  title: Text('Report a Problem', style: AppTheme.bodyMedium),
                  trailing: const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                  onTap: () {
                    _showSnackBar('Coming soon', isError: false);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip, color: AppTheme.primary),
                  title: Text('Privacy Policy', style: AppTheme.bodyMedium),
                  trailing: const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                  onTap: () {
                    _showSnackBar('Coming soon', isError: false);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spacing40),
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
