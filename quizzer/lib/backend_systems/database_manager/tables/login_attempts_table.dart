import 'package:quizzer/backend_systems/database_manager/tables/user_profile_table.dart';
import 'package:sqflite/sqflite.dart';
import 'package:quizzer/backend_systems/logger/quizzer_logging.dart';
import 'dart:convert';
import 'dart:io';

Future<String> getDeviceInfo() async {
  String deviceData = "";
  
  try {
    // Use Dart's built-in Platform class to get basic platform info
    // without relying on Flutter-specific packages
    if (Platform.isAndroid) {
      deviceData = 'Android ${Platform.operatingSystemVersion}';
    } else if (Platform.isIOS) {
      deviceData = 'iOS ${Platform.operatingSystemVersion}';
    } else if (Platform.isWindows) {
      deviceData = 'Windows ${Platform.operatingSystemVersion}';
    } else if (Platform.isMacOS) {
      deviceData = 'macOS ${Platform.operatingSystemVersion}';
    } else if (Platform.isLinux) {
      deviceData = 'Linux ${Platform.operatingSystemVersion}';
    } else {
      deviceData = 'Unknown device';
    }
    
    // Add some additional system info that's available from dart:io
    deviceData += ' (${Platform.localHostname})';
  } catch (e) {
    // Fallback if any error occurs
    QuizzerLogger.logWarning('Error getting device info: $e');
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
  required String email,
  required String statusCode,
  required Database db
}) async {
  // First get the userId by email
  String? userId = await getUserIdByEmail(email, db);
  
  // Ensure the userId is not null before proceeding
  if (userId == null) {
    QuizzerLogger.logWarning('Cannot record login attempt: No user found with email $email');
    return false;
  }

  
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