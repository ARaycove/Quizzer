import 'package:sqflite/sqflite.dart';
import 'package:quizzer/global/database/quizzer_database.dart';
import 'package:http/http.dart' as http;
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
    // Using a public API service that returns the client's IP address
    final response = await http.get(
      Uri.parse('https://api.ipify.org?format=json'),
      // Add a short timeout to avoid long waits when offline
      headers: {'Connection': 'keep-alive'},
    ).timeout(const Duration(seconds: 3));
    
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return data['ip'] as String;
    } else {
      return "offline_login";
    }
  } catch (e) {
    return "offline_login";
  }
}


Future<bool> doesLoginAttemptsTableExist() async {
  final Database db = await getDatabase();
  final List<Map<String, dynamic>> tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='login_attempts'"
  );
  return tables.isNotEmpty;
}

Future<void> createLoginAttemptsTable() async {
  final Database db = await getDatabase();
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
}) async {
  final Database db = await getDatabase();
  
  // Check if table exists and create if needed
  bool checkTable = await doesLoginAttemptsTableExist();
  if (checkTable == false) {
    await createLoginAttemptsTable();
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
    print('Login attempt recorded successfully: $loginAttemptId');
  return true;
}