extension StringColorExtension on String {
  String get toRed {
    return '\x1B[31m$this\x1B[0m';
  }

  String get toGreen {
    return '\x1B[32m$this\x1B[0m';
  }

  String get toYellow {
    return '\x1B[33m$this\x1B[0m';
  }

  String get toBlue {
    return '\x1B[34m$this\x1B[0m';
  }

  String get toMagenta {
    return '\x1B[35m$this\x1B[0m';
  }

  String get toCyan {
    return '\x1B[36m$this\x1B[0m';
  }
}
