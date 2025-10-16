import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';
import '../services/binance_service.dart';
import '../services/app_settings_service.dart';

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
          localizedReason: 'Activează autentificarea biometrică',
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
          ),
        );

        if (authenticated) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('biometric_enabled', true);
          setState(() => _biometricEnabled = true);
          _showSnackBar('Autentificare biometrică activată', isError: false);
        }
      } catch (e) {
        _showSnackBar('Eroare la activarea autentificării: $e', isError: true);
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric_enabled', false);
      setState(() => _biometricEnabled = false);
      _showSnackBar('Autentificare biometrică dezactivată', isError: false);
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
      _showSnackBar('Credențiale salvate cu succes', isError: false);
      _apiKeyController.clear();
      _apiSecretController.clear();
    } catch (e) {
      _showSnackBar('Eroare la salvarea credențialelor: $e', isError: true);
    }
  }

  Future<void> _testConnection() async {
    setState(() => _isTestingConnection = true);

    try {
      final success = await _binanceService.testConnection();
      if (success) {
        _showSnackBar('Conexiune reușită! Chei valide.', isError: false);
      } else {
        _showSnackBar('Conexiune eșuată. Verifică cheile API.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Eroare: $e', isError: true);
    } finally {
      setState(() => _isTestingConnection = false);
    }
  }

  Future<void> _clearCredentials() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmare'),
        content: const Text('Sigur vrei să ștergi credențialele API?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anulează'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Șterge'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _binanceService.clearCredentials();
      _showSnackBar('Credențiale șterse', isError: false);
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
        title: const Text('Setări'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Security Section
          _buildSectionHeader('Securitate'),
          Card(
            child: Column(
              children: [
                if (_canCheckBiometrics)
                  SwitchListTile(
                    title: const Text('Blocare cu Face ID / Amprentă'),
                    subtitle: const Text('Autentifică-te la fiecare deschidere'),
                    value: _biometricEnabled,
                    onChanged: _toggleBiometric,
                    secondary: const Icon(Icons.fingerprint),
                  )
                else
                  const ListTile(
                    leading: Icon(Icons.warning_amber, color: Colors.orange),
                    title: Text('Autentificare biometrică indisponibilă'),
                    subtitle: Text('Dispozitivul nu suportă această funcție'),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Quote Currency (placed before Theme)
          _buildSectionHeader('Monedă de referință'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Selectează moneda de referință pentru prețuri și totaluri'),
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
                        _showSnackBar('Monedă setată: ' + q, isError: false);
                      },
                    )).toList(),
                  ),
                ],
              ),
            ),
          ),

          // Trading Mode Section (moved below Security)
          _buildSectionHeader('Trading'),
          Card(
            child: SwitchListTile(
              title: const Text('Paper Trading'),
              subtitle: const Text('Rulează ordinele în modul simulare'),
              value: _paperTrading,
              onChanged: (bool v) async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('paper_trading', v);
                setState(() => _paperTrading = v);
                _showSnackBar(v ? 'Paper Trading activat' : 'Paper Trading dezactivat', isError: false);
              },
              secondary: const Icon(Icons.description_outlined),
            ),
          ),

          const SizedBox(height: 24),

          // API Section
          _buildSectionHeader('API Binance'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                          label: const Text('Salvează'),
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
                          label: const Text('Testează'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _clearCredentials,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text('Șterge Credențiale', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Appearance Section
          _buildSectionHeader('Aspect'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.brightness_6),
                  title: const Text('Temă'),
                  subtitle: Text(_getThemeLabel(themeProvider.themeMode)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SegmentedButton<AppThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: AppThemeMode.light,
                        label: Text('Luminos'),
                        icon: Icon(Icons.light_mode),
                      ),
                      ButtonSegment(
                        value: AppThemeMode.dark,
                        label: Text('Întunecat'),
                        icon: Icon(Icons.dark_mode),
                      ),
                      ButtonSegment(
                        value: AppThemeMode.system,
                        label: Text('Sistem'),
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
          _buildSectionHeader('Despre'),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('MyTradeMate'),
                  subtitle: Text('Versiunea 1.0.0'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.bug_report),
                  title: const Text('Raportează o problemă'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () {
                    _showSnackBar('Funcție în curs de implementare', isError: false);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip),
                  title: const Text('Politica de confidențialitate'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () {
                    _showSnackBar('Funcție în curs de implementare', isError: false);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  String _getThemeLabel(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return 'Luminos';
      case AppThemeMode.dark:
        return 'Întunecat';
      case AppThemeMode.system:
        return 'Sistem';
    }
  }
}
