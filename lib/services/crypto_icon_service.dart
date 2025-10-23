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

  /// Get logo URL for a coin using CoinGecko CDN
  /// Uses both numeric ID and slug for maximum compatibility
  static String getLogoUrl(String symbol, {bool large = false}) {
    final coinId = getCoinGeckoId(symbol);
    final size = large ? 'large' : 'small';
    
    // Map of coin slug to image ID (from CoinGecko)
    final imageIds = <String, String>{
      'bitcoin': '1',
      'ethereum': '279',
      'binancecoin': '825',
      'solana': '4128',
      'cardano': '975',
      'polkadot': '12171',
      'chainlink': '1975',
      'uniswap': '12504',
      'dogecoin': '5',
      'shiba-inu': '11939',
      'pepe': '29850',
      'matic-network': '4713',
      'avalanche-2': '12559',
      'cosmos': '3794',
      'ripple': '44',
      'litecoin': '2',
      'tether': '325',
      'usd-coin': '6319',
      'dai': '4943',
      'world-liberty-financial-wlfi': '38036',
      'maga-trump': '37967',  // MAGA Trump token
    };
    
    final imageId = imageIds[coinId];
    
    if (imageId != null) {
      // Use standard CoinGecko CDN URL
      return 'https://assets.coingecko.com/coins/images/$imageId/$size/$coinId.png';
    } else {
      // Fallback: try to construct URL with coin ID as image ID
      // This works for some newer coins
      return 'https://coin-images.coingecko.com/coins/images/1/$size/$coinId.png';
    }
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

