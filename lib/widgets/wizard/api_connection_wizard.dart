import 'package:flutter/material.dart';
import '../../design_system/widgets/glass_card.dart';
import '../../design_system/app_colors.dart';
import '../../services/binance_service.dart';

class ApiConnectionWizard extends StatefulWidget {
  const ApiConnectionWizard({super.key});

  @override
  State<ApiConnectionWizard> createState() => _ApiConnectionWizardState();
}

class _ApiConnectionWizardState extends State<ApiConnectionWizard> {
  final _keyCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();
  final _binance = BinanceService();
  int _step = 0; // 0 enter, 1 test, 2 done
  bool _testing = false;
  String _status = '';

  @override
  void dispose() {
    _keyCtrl.dispose();
    _secretCtrl.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    setState(() { _testing = true; _status = ''; });
    try {
      await _binance.saveCredentials(_keyCtrl.text.trim(), _secretCtrl.text.trim());
      final ok = await _binance.testConnection();
      setState(() {
        _testing = false;
        _status = ok ? 'Connected successfully' : 'Connection failed';
        _step = ok ? 2 : 1;
      });
    } catch (e) {
      setState(() { _testing = false; _status = 'Error: ' + e.toString(); _step = 1; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('API connection', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_step == 0) ...[
            Text('Enter your Binance API credentials', style: theme.textTheme.titleMedium?.copyWith(color: AppColors.muted)),
            const SizedBox(height: 12),
            TextField(decoration: const InputDecoration(labelText: 'API Key', prefixIcon: Icon(Icons.vpn_key)), controller: _keyCtrl),
            const SizedBox(height: 12),
            TextField(decoration: const InputDecoration(labelText: 'Secret Key', prefixIcon: Icon(Icons.lock)), controller: _secretCtrl, obscureText: true),
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerRight, child: ElevatedButton(onPressed: () => setState(() => _step = 1), child: const Text('Next'))),
          ] else if (_step == 1) ...[
            Text('Test connection', style: theme.textTheme.titleMedium?.copyWith(color: AppColors.muted)),
            const SizedBox(height: 8),
            _testing ? const CircularProgressIndicator() : ElevatedButton.icon(onPressed: _test, icon: const Icon(Icons.wifi), label: const Text('Test now')),
            const SizedBox(height: 8),
            if (_status.isNotEmpty) Text(_status),
          ] else ...[
            Row(children:[const Icon(Icons.check_circle, color: Colors.green), const SizedBox(width: 8), Text('Connected successfully')]),
          ],
        ],
      ),
    );
  }
}


