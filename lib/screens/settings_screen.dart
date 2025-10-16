import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';
import '../services/binance_service.dart';
import '../services/app_settings_service.dart';
import '../design_system/screen_backgrounds.dart';
import '../design_system/widgets/glass_card.dart';
import '../design_system/app_colors.dart';

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
      _showSnackBar('Completează ambele câmpuri', isError: true);
      return;
    }

    try {
      await _binanceService.saveCredentials(apiKey, apiSecret);
      _showSnackBar('Credentials saved', isError: false);
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
        _showSnackBar('Connection successful! Keys valid.', isError: false);
      } else {
        _showSnackBar('Connection failed. Check API keys.', isError: true);
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
        title: const Text('Confirmation'),
        content: const Text('Are you sure you want to delete API credentials?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: Container(
        decoration: ScreenBackgrounds.market(context),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Text('Settings', style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold)),
          ),
          // Security Section
          _buildSectionHeader('Security'),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_canCheckBiometrics)
                  SwitchListTile(
                    title: const Text('Lock with Face ID / Fingerprint'),
                    subtitle: Text('Authenticate on each app open', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.muted)),
                    value: _biometricEnabled,
                    onChanged: _toggleBiometric,
                    secondary: const Icon(Icons.fingerprint),
                  )
                else
                  ListTile(
                    leading: const Icon(Icons.warning_amber, color: Colors.orange),
                    title: const Text('Biometric authentication unavailable'),
                    subtitle: Text('This device does not support biometrics', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.muted)),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Quote Currency (placed before Theme)
          _buildSectionHeader('Quote currency'),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Select the quote currency used for prices and totals', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.muted)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      'USDT','USDC','USD','EUR'
                    ].map((q) => ChoiceChip(
                      label: Text(q),
                      selected: _quote == q,
                      onSelected: (_) async {
                        final svc = AppSettingsService();
                        await svc.setQuoteCurrency(q);
                        setState(() => _quote = q);
                        _showSnackBar('Quote set to: ' + q, isError: false);
                      },
                    )).toList(),
                  ),
                ],
              ),
            ),
          ),

          // Trading Mode Section (moved below Security)
          _buildSectionHeader('Trading'),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  title: const Text('Paper Trading'),
                  subtitle: Text('Execute orders in simulation mode', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.muted)),
                  value: _paperTrading,
                  onChanged: (bool v) async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('paper_trading', v);
                    setState(() => _paperTrading = v);
                    _showSnackBar(v ? 'Paper Trading enabled' : 'Paper Trading disabled', isError: false);
                  },
                  secondary: const Icon(Icons.description_outlined),
                ),
                const SizedBox(height: 8),
                Text('Environment', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.muted)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    {'label': 'Live', 'value': 'live'},
                    {'label': 'Testnet', 'value': 'testnet'},
                  ].map((m) {
                    return ChoiceChip(
                      label: Text(m['label'] as String),
                      selected: AppSettingsService().tradingEnvironment == m['value'],
                      onSelected: (_) async {
                        await AppSettingsService().setTradingEnvironment(m['value'] as String);
                        setState(() {});
                        _showSnackBar('Environment: ' + (m['label'] as String), isError: false);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // API Section
          _buildSectionHeader('Binance API'),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _apiKeyController,
                    decoration: const InputDecoration(
                      labelText: 'API Key',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.vpn_key),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _apiSecretController,
                    obscureText: _obscureSecret,
                    decoration: InputDecoration(
                      labelText: 'Secret Key',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureSecret ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscureSecret = !_obscureSecret),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saveApiCredentials,
                          icon: const Icon(Icons.save),
                          label: const Text('Save'),
                        ),
                      ),
                      const SizedBox(width: 8),
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
                          label: const Text('Test connection'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _clearCredentials,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text('Delete credentials', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Appearance Section
          _buildSectionHeader('Appearance'),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.brightness_6),
                  title: const Text('Theme'),
                  subtitle: Text(_getThemeLabel(themeProvider.themeMode), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.muted)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SegmentedButton<AppThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: AppThemeMode.light,
                        label: Text('Light'),
                        icon: Icon(Icons.light_mode),
                      ),
                      ButtonSegment(
                        value: AppThemeMode.dark,
                        label: Text('Dark'),
                        icon: Icon(Icons.dark_mode),
                      ),
                      ButtonSegment(
                        value: AppThemeMode.system,
                        label: Text('System'),
                        icon: Icon(Icons.settings_brightness),
                      ),
                    ],
                    selected: {themeProvider.themeMode},
                    onSelectionChanged: (Set<AppThemeMode> selection) {
                      themeProvider.setThemeMode(selection.first);
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // About Section
          _buildSectionHeader('About'),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('MyTradeMate'),
                  subtitle: Text('Version 1.0.0', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.muted)),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.bug_report),
                  title: const Text('Report a problem'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () {
                    _showSnackBar('Coming soon', isError: false);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () {
                    _showSnackBar('Coming soon', isError: false);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('Strategies Guide'),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'What each strategy does and when to use it:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text('• Hybrid (Strategies): Combines rule-based logic (e.g., RSI, trend filters) with the AI model signal. Use when you want stricter risk filters and fewer false positives.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
                const SizedBox(height: 8),
                Text('• AI Model: Pure model-driven signals from the on-device TFLite model. Use when you want more frequent, model-led entries; pair with tighter position sizing.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
                const SizedBox(height: 8),
                Text('• Market: Immediate execution at the current market price. Use for manual quick entries and testing.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
                const SizedBox(height: 12),
                Text('Tip: Set your preferred mode in Orders. Hybrid suits swing trading; AI Model suits short-term momentum; Market is manual.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.muted),
      ),
    );
  }

  String _getThemeLabel(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
      case AppThemeMode.system:
        return 'System';
    }
  }
}
