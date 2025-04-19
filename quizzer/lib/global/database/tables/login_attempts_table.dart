import 'package:sqflite/sqflite.dart';
import 'package:quizzer/global/functionality/quizzer_logging.dart';
import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

Future<String> getDeviceInfo() async {
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  String deviceData = "";
  
  if (Platform.isAndroid) {
    final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    deviceData = '${androidInfo.brand} ${androidInfo.model}, Android ${androidInfo.version.release}';
  } else if (Platform.isIOS) {
    final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
    deviceData = '${iosInfo.name}, iOS ${iosInfo.systemVersion}';
  } else if (Platform.isWindows) {
    final WindowsDeviceInfo windowsInfo = await deviceInfo.windowsInfo;
    deviceData = 'Windows ${windowsInfo.computerName}, ${windowsInfo.majorVersion}.${windowsInfo.minorVersion}';
  } else if (Platform.isMacOS) {
    final MacOsDeviceInfo macOsInfo = await deviceInfo.macOsInfo;
    deviceData = 'macOS ${macOsInfo.computerName}, ${macOsInfo.osRelease}';
  } else if (Platform.isLinux) {
    final LinuxDeviceInfo linuxInfo = await deviceInfo.linuxInfo;
    deviceData = 'Linux ${linuxInfo.name}, ${linuxInfo.version}';
  } else {
    deviceData = 'Unknown device';
  }
  
  return deviceData;
}

Future<String> getUserIpAddress() async {
  try {
    QuizzerLogger.logMessage('Attempting to get IP address');
    
    // Create a custom HttpClient that skips certificate verification
    final httpClient = HttpClient()
      ..badCertificateCallback = (cert, host, port) => true;
    
    final request = await httpClient.getUrl(Uri.parse('https://www.dnsleaktest.com/'));
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    
    if (response.statusCode == 200) {
      // Extract IP from the welcome message
      final ipRegex = RegExp(r'Hello (\d+\.\d+\.\d+\.\d+)');
      final match = ipRegex.firstMatch(responseBody);
      
      if (match != null) {
        final ip = match.group(1)!;
        QuizzerLogger.logSuccess('Successfully retrieved IP address: $ip');
        return ip;
      } else {
        QuizzerLogger.logWarning('Could not find IP address in response');
        return "offline_login";
      }
    } else {
      QuizzerLogger.logWarning('Failed to get IP address, status code: ${response.statusCode}');
      return "offline_login";
    }
  } catch (e) {
    QuizzerLogger.logError('Error getting IP address: $e');
    return "offline_login";
  }
}


Future<bool> doesLoginAttemptsTableExist(Database db) async {
  final List<Map<String, dynamic>> tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='login_attempts'"
  );
  return tables.isNotEmpty;
}

Future<void> createLoginAttemptsTable(Database db) async {
  await db.execute('''
  CREATE TABLE login_attempts(
    login_attempt_id TEXT PRIMARY KEY,
    user_id TEXT,
    email TEXT NOT NULL,
    timestamp TEXT NOT NULL,
    status_code TEXT NOT NULL,
    ip_address TEXT,
    device_info TEXT,
    FOREIGN KEY (user_id) REFERENCES user_profile(uuid)
  )
  ''');
}

Future<bool> addLoginAttemptRecord({
  required String userId,
  required String email,
  required String statusCode,
  required Database db
}) async {
  
  // Check if table exists and create if needed
  bool checkTable = await doesLoginAttemptsTableExist(db);
  if (checkTable == false) {
    await createLoginAttemptsTable(db);
  }
  
  String ipAddress = await getUserIpAddress();
  String deviceInfo = await getDeviceInfo();
  
  // Current timestamp in ISO 8601 format
  final String timestamp = DateTime.now().toIso8601String();
  final String loginAttemptId = timestamp + userId;
  
  // Insert the record - if this fails, it will throw an error and crash
    await db.insert(
      'login_attempts',
      {
        'login_attempt_id': loginAttemptId,
        'user_id': userId,
        'email': email,
        'timestamp': timestamp,
        'status_code': statusCode,
        'ip_address': ipAddress,
        'device_info': deviceInfo,
      },
    );
    QuizzerLogger.logMessage('Login attempt recorded successfully: $loginAttemptId');
  return true;
}