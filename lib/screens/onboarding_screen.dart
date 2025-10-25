import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Premium Onboarding Flow (3 pages)
/// Page 1: Welcome + All Features
/// Page 2: FREE vs PREMIUM
/// Page 3: Disclaimer + Face ID/PIN setup
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final LocalAuthentication _localAuth = LocalAuthentication();

  int _currentPage = 0;
  bool _agreedToRisks = false;
  bool _canCheckBiometrics = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricSupport();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricSupport() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (mounted) {
        setState(() {
          _canCheckBiometrics = canCheck && isDeviceSupported;
        });
      }
    } catch (e) {
      debugPrint('Error checking biometric support: $e');
    }
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: AppTheme.animationNormal,
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: AppTheme.animationNormal,
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _setupBiometric() async {
    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      final success = await authService.authenticateWithBiometrics();

      if (!mounted) return;

      if (success) {
        await authService.signInAsGuest();
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        _showError('Biometric authentication failed');
      }
    } catch (e) {
      if (mounted) {
        _showError('Biometric authentication unavailable');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _setupPIN() async {
    // For now, skip PIN setup and go to app
    setState(() => _isLoading = true);
    await context.read<AuthService>().signInAsGuest();
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.of(context).pushReplacementNamed('/home');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: List.generate(3, (index) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: _currentPage >= index
                            ? AppTheme.primary
                            : AppTheme.glassBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // PageView
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  _buildPage1Welcome(),
                  _buildPage2FreePremium(),
                  _buildPage3Security(),
                ],
              ),
            ),

            // Bottom buttons
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: _buildBottomButtons(),
            ),
          ],
        ),
      ),
    );
  }

  // PAGE 1: Welcome + All Features
  Widget _buildPage1Welcome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // Logo with glow
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFFC837), Color(0xFFFF8008)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFC837).withOpacity(0.5),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 60,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 20),

          // Title
          Text(
            'MyTradeMate',
            style: AppTheme.displayLarge.copyWith(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFFFC837),
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'AI-Powered Crypto Trading',
            style: AppTheme.headingMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          Text(
            'Your intelligent trading assistant with advanced AI predictions',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          // Feature 1
          _buildFeatureCard(
            icon: Icons.psychology_outlined,
            iconColor: const Color(0xFF0A84FF),
            title: 'Advanced AI Predictions',
            description: '5 timeframes • 76 indicators • Ensemble models',
          ),

          const SizedBox(height: 12),

          // Feature 2
          _buildFeatureCard(
            icon: Icons.show_chart_rounded,
            iconColor: const Color(0xFF34C759),
            title: '4 Order Types',
            description: 'Market, Limit, Stop-Limit, Stop-Market',
          ),

          const SizedBox(height: 12),

          // Feature 3
          _buildFeatureCard(
            icon: Icons.account_balance_wallet_outlined,
            iconColor: const Color(0xFFAF52DE),
            title: 'Portfolio Tracking',
            description: 'Real-time balances • P&L • Performance analytics',
          ),

          const SizedBox(height: 12),

          // Feature 4
          _buildFeatureCard(
            icon: Icons.shield_outlined,
            iconColor: const Color(0xFF34C759),
            title: 'Secure & Private',
            description: 'Biometric auth • Encrypted storage • Your keys stay on your device',
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // PAGE 2: FREE vs PREMIUM
  Widget _buildPage2FreePremium() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28.0),
      child: Column(
        children: [
          const SizedBox(height: 32),

          Text(
            'Choose Your Plan',
            style: AppTheme.displayLarge.copyWith(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          Text(
            'Start with FREE, upgrade anytime',
            style: AppTheme.bodyLarge.copyWith(
              fontSize: 17,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 40),

          // FREE Plan
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppTheme.glassGradient,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.glassBorder,
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: AppTheme.success, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'FREE Plan',
                      style: AppTheme.headingLarge.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildFeature('✓ AI predictions on 1D timeframe only', fontSize: 15),
                _buildFeature('✓ READ-only Binance API access', fontSize: 15),
                _buildFeature('✓ View portfolio & balances', fontSize: 15),
                _buildFeature('✓ Basic market data', fontSize: 15),
                _buildFeature('✗ Cannot place trades', isDisabled: true, fontSize: 15),
                _buildFeature('✗ Limited AI timeframes', isDisabled: true, fontSize: 15),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // PREMIUM Plan
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withOpacity(0.2),
                  AppTheme.secondary.withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.primary.withOpacity(0.6),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.star, color: AppTheme.primary, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'PREMIUM',
                      style: AppTheme.headingLarge.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildFeature('✓ AI predictions on ALL timeframes (5m, 15m, 1h, 4h, 1d)', fontSize: 15),
                _buildFeature('✓ TRADING Binance API (place real orders)', fontSize: 15),
                _buildFeature('✓ 4 order types (Market, Limit, Stop-Loss, OCO)', fontSize: 15),
                _buildFeature('✓ Full portfolio management', fontSize: 15),
                const SizedBox(height: 16),
                Text(
                  'Requires: TRADING API key from Binance',
                  style: AppTheme.labelMedium.copyWith(
                    fontSize: 13,
                    color: AppTheme.textTertiary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // PAGE 3: Disclaimer + Security Setup
  Widget _buildPage3Security() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // Disclaimer box
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFFC837),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFFFC837),
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Important Risk Disclaimer',
                        style: AppTheme.headingMedium.copyWith(
                          color: const Color(0xFFFFC837),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _buildDisclaimerItem(
                  icon: Icons.warning_rounded,
                  text: 'Crypto trading involves substantial risk of loss',
                ),
                _buildDisclaimerItem(
                  icon: Icons.bar_chart_rounded,
                  text: 'Not financial advice - AI predictions may be inaccurate',
                ),
                _buildDisclaimerItem(
                  icon: Icons.block_rounded,
                  text: 'You must be 18+ to use this app',
                ),
                _buildDisclaimerItem(
                  icon: Icons.school_outlined,
                  text: 'Always do your own research (DYOR)',
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Checkbox
          GestureDetector(
            onTap: () {
              setState(() => _agreedToRisks = !_agreedToRisks);
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _agreedToRisks
                      ? AppTheme.primary
                      : AppTheme.glassBorder,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _agreedToRisks
                          ? AppTheme.primary
                          : Colors.transparent,
                      border: Border.all(
                        color: _agreedToRisks
                            ? AppTheme.primary
                            : AppTheme.textTertiary,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _agreedToRisks
                        ? const Icon(
                            Icons.check,
                            size: 20,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'I understand and accept the risks',
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Security setup section
          if (_agreedToRisks) ...[
            Divider(color: AppTheme.glassBorder, height: 40),

            Text(
              'Secure Your Account',
              style: AppTheme.headingLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            Text(
              'Choose how to protect your trading account',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // Face ID button
            if (_canCheckBiometrics)
              _buildSecurityButton(
                icon: Icons.fingerprint_rounded,
                title: 'Use Face ID / Touch ID',
                description: 'Quick and secure biometric authentication',
                onTap: _isLoading ? null : _setupBiometric,
                isPrimary: true,
              ),

            if (_canCheckBiometrics) const SizedBox(height: 12),

            // PIN button
            _buildSecurityButton(
              icon: Icons.lock_outline_rounded,
              title: 'Use PIN Code',
              description: '4-digit security code',
              onTap: _isLoading ? null : _setupPIN,
              isPrimary: !_canCheckBiometrics,
            ),

            const SizedBox(height: 12),

            // Skip button
            TextButton(
              onPressed: _isLoading ? null : _setupPIN,
              child: Text(
                'Skip for now',
                style: AppTheme.labelMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.glassGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.glassBorder,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeature(String text, {bool isDisabled = false, double fontSize = 14}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Text(
        text,
        style: AppTheme.bodyMedium.copyWith(
          fontSize: fontSize,
          color: isDisabled ? AppTheme.textTertiary : AppTheme.textSecondary,
          decoration: isDisabled ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }

  Widget _buildDisclaimerItem({
    required IconData icon,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: AppTheme.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityButton({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback? onTap,
    required bool isPrimary,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? LinearGradient(
                  colors: [
                    AppTheme.primary.withOpacity(0.15),
                    AppTheme.secondary.withOpacity(0.15),
                  ],
                )
              : AppTheme.glassGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPrimary
                ? AppTheme.primary.withOpacity(0.5)
                : AppTheme.glassBorder,
            width: isPrimary ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isPrimary
                    ? AppTheme.primary.withOpacity(0.2)
                    : AppTheme.glassBorder.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppTheme.primary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppTheme.textTertiary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButtons() {
    if (_currentPage == 0 || _currentPage == 1) {
      return Row(
        children: [
          // Back button (only on page 2)
          if (_currentPage == 1)
            Expanded(
              flex: 1,
              child: SizedBox(
                height: 56,
                child: OutlinedButton(
                  onPressed: _previousPage,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: BorderSide(
                      color: AppTheme.glassBorder,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Back'),
                ),
              ),
            ),
          if (_currentPage == 1) const SizedBox(width: 12),
          // Next button
          Expanded(
            flex: _currentPage == 0 ? 1 : 2,
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _nextPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continue',
                      style: AppTheme.bodyLarge.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Page 3 - Back button (Face ID/PIN appear only after accepting risks)
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: _previousPage,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.textPrimary,
          side: BorderSide(
            color: AppTheme.glassBorder,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text('Back'),
      ),
    );
  }
}
