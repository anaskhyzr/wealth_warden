import 'dart:math';

/// Utility class for formatting file sizes in a human-readable format
class SizeFormatter {
  /// Formats a file size in bytes to a human-readable string
  /// with appropriate units (B, KB, MB, GB)
  static String formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (log(bytes) / log(1024)).floor();
    
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }
}
