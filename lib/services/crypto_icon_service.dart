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
      'WLFI': 'world-liberty-financial',
      'TRUMP': 'official-trump',
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
      // Add more as needed
    };
    
    final upper = symbol.toUpperCase();
    return map[upper] ?? symbol.toLowerCase();
  }

  /// Map symbols to CoinGecko numeric IDs (for image URLs)
  static String getCoinGeckoImageId(String symbol) {
    final map = <String, String>{
      'BTC': '1',           // Bitcoin
      'ETH': '279',         // Ethereum
      'BNB': '825',         // Binance Coin
      'SOL': '4128',        // Solana
      'WLFI': '38036',      // World Liberty Financial
      'TRUMP': '38103',     // Official Trump
      'ADA': '975',         // Cardano
      'DOT': '12171',       // Polkadot
      'LINK': '1975',       // Chainlink
      'UNI': '12504',       // Uniswap
      'DOGE': '5',          // Dogecoin
      'SHIB': '11939',      // Shiba Inu
      'PEPE': '29850',      // Pepe
      'MATIC': '4713',      // Polygon
      'AVAX': '12559',      // Avalanche
      'ATOM': '3794',       // Cosmos
      'XRP': '44',          // Ripple
      'LTC': '2',           // Litecoin
      'BCH': '1',           // Bitcoin Cash (uses same as BTC for fallback)
      'USDT': '325',        // Tether
      'USDC': '6319',       // USD Coin
      'DAI': '4943',        // Dai
      // Add more as needed
    };
    
    final upper = symbol.toUpperCase();
    return map[upper] ?? '1'; // Default to Bitcoin ID if unknown
  }

  /// Get logo URL for a coin (small: 64x64, large: 256x256)
  static String getLogoUrl(String symbol, {bool large = false}) {
    final imageId = getCoinGeckoImageId(symbol);
    final coinId = getCoinGeckoId(symbol);
    final size = large ? 'large' : 'small';
    return 'https://assets.coingecko.com/coins/images/$imageId/$size/$coinId.png';
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

