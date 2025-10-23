import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class RiskDisclaimerDialog {
  static const String _kDisclaimerAcceptedKey = 'risk_disclaimer_accepted';
  
  static Future<bool> hasAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kDisclaimerAcceptedKey) ?? false;
  }
  
  static Future<void> markAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDisclaimerAcceptedKey, true);
  }
  
  static Future<bool> showIfNeeded(BuildContext context) async {
    final accepted = await hasAccepted();
    if (accepted) return true;
    
    if (!context.mounted) return false;
    
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 28),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Text(
                'Risk Disclaimer',
                style: AppTheme.headingLarge,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Important Information',
                style: AppTheme.headingMedium.copyWith(color: AppTheme.warning),
              ),
              const SizedBox(height: AppTheme.spacing16),
              _buildDisclaimerPoint(
                '⚠️',
                'Cryptocurrency trading involves substantial risk of loss and is not suitable for every investor.',
              ),
              _buildDisclaimerPoint(
                '📊',
                'This app provides information and tools but does NOT constitute financial, investment, or trading advice.',
              ),
              _buildDisclaimerPoint(
                '🔞',
                'You must be 18 years or older to use this application.',
              ),
              _buildDisclaimerPoint(
                '📉',
                'Past performance does not guarantee future results. You may lose all invested capital.',
              ),
              _buildDisclaimerPoint(
                '🤖',
                'AI predictions are based on historical data and may not accurately predict future market movements.',
              ),
              _buildDisclaimerPoint(
                '💼',
                'Always conduct your own research and consult with a qualified financial advisor before making investment decisions.',
              ),
              const SizedBox(height: AppTheme.spacing16),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing16),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  border: Border.all(color: AppTheme.error.withOpacity(0.3), width: 1.5),
                ),
                child: Text(
                  'By continuing, you acknowledge that you understand and accept these risks.',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.error,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Decline',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await markAccepted();
              if (context.mounted) {
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing24,
                vertical: AppTheme.spacing12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
            ),
            child: const Text(
              'I Understand & Accept',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ) ?? false;
  }
  
  static Widget _buildDisclaimerPoint(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Text(
              text,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
