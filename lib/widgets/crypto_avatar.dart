import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/crypto_icon_service.dart';
import '../theme/app_theme.dart';

/// Crypto coin avatar with CoinGecko logo + fallback letter avatar
class CryptoAvatar extends StatelessWidget {
  final String symbol;
  final double size;
  final bool showBorder;

  const CryptoAvatar({
    super.key,
    required this.symbol,
    this.size = 40,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final brandColor = Color(CryptoIconService.getBrandColor(symbol));
    final logoUrl = CryptoIconService.getLogoUrl(symbol);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            brandColor.withOpacity(0.3),
            brandColor.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: showBorder
            ? Border.all(
                color: brandColor.withOpacity(0.3),
                width: 1.5,
              )
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        child: CachedNetworkImage(
          imageUrl: logoUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildLetterFallback(brandColor),
          errorWidget: (context, url, error) {
            // Debug: print error to see what's wrong
            debugPrint('CryptoAvatar: Failed to load $symbol from $logoUrl - Error: $error');
            return _buildLetterFallback(brandColor);
          },
          // Add cache key to force refresh when URL changes
          cacheKey: logoUrl,
          // Retry failed images
          errorListener: (error) {
            debugPrint('CryptoAvatar: Error loading $symbol: $error');
          },
        ),
      ),
    );
  }

  Widget _buildLetterFallback(Color color) {
    return Center(
      child: Text(
        symbol.substring(0, 1).toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: size * 0.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

