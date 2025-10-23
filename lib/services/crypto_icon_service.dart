/// CoinGecko icon service for crypto logos
/// Maps symbol → CoinGecko ID → Logo URL
/// Supports automatic fallback for unknown coins
class CryptoIconService {
  /// Map common symbols to CoinGecko IDs (slug)
  static String getCoinGeckoId(String symbol) {
    final map = <String, String>{
      'BTC': 'bitcoin',
      'ETH': 'ethereum',
      'BNB': 'binancecoin',
      'SOL': 'solana',
      'WLFI': 'world-liberty-financial-wlfi',  // Updated slug
      'TRUMP': 'maga-trump',                    // Updated slug (MAGA Trump is the main one)
      'ADA': 'cardano',
      'DOT': 'polkadot',
      'LINK': 'chainlink',
      'UNI': 'uniswap',
      'DOGE': 'dogecoin',
      'SHIB': 'shiba-inu',
      'PEPE': 'pepe',
      'MATIC': 'matic-network',
      'AVAX': 'avalanche-2',
      'ATOM': 'cosmos',
      'XRP': 'ripple',
      'LTC': 'litecoin',
      'BCH': 'bitcoin-cash',
      'USDT': 'tether',
      'USDC': 'usd-coin',
      'DAI': 'dai',
      // Add more as needed
    };
    
    final upper = symbol.toUpperCase();
    return map[upper] ?? symbol.toLowerCase();
  }

  /// Get logo URL using GitHub CDN (spothq/cryptocurrency-icons)
  /// This is a free, open-source repository with no authentication required
  /// Works reliably without 403 errors
  static String getLogoUrl(String symbol, {bool large = false}) {
    final sym = symbol.toUpperCase();
    final size = large ? '128' : '64';
    
    // Use cryptocurrency-icons GitHub repo via jsDelivr CDN
    // Format: https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/svg/color/{symbol}.svg
    // Or PNG: https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/{size}x{size}/{symbol}.png
    
    return 'https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/${size}x$size/${sym.toLowerCase()}.png';
  }

  /// Get brand color for fallback letter avatars
  static int getBrandColor(String symbol) {
    final map = <String, int>{
      'BTC': 0xFFF7931A, // Bitcoin orange
      'ETH': 0xFF627EEA, // Ethereum purple
      'BNB': 0xFFF3BA2F, // Binance gold
      'SOL': 0xFF9945FF, // Solana purple
      'WLFI': 0xFF3B82F6, // Blue
      'TRUMP': 0xFFDC2626, // Red
      'ADA': 0xFF0033AD, // Cardano blue
      'DOT': 0xFFE6007A, // Polkadot pink
      'DOGE': 0xFFC2A633, // Doge gold
      'SHIB': 0xFFFFA409, // Shiba orange
      'PEPE': 0xFF4CAF50, // Pepe green
    };
    
    return map[symbol.toUpperCase()] ?? 0xFF3B82F6; // Default blue
  }
}

