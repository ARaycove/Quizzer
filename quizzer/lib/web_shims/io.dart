// This is a shim for dart:io functionality that doesn't exist on web platforms
// It provides stub implementations of the needed classes

class Platform {
  static bool get isWindows => false;
  static bool get isLinux => false;
  static bool get isMacOS => false;
  static bool get isIOS => false;
  static bool get isAndroid => false;
}

class Directory {
  final String path;

  Directory(this.path);

  static Directory get current => Directory('');

  void createSync({bool recursive = false}) {
    // No-op for web
  }
}

class File {
  final String path;
  
  File(this.path);
  
  bool existsSync() => false;
} 