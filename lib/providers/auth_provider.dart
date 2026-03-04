import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  String baseURL = "http://localhost:5000";

  Future<String?> getDeviceID() async {
    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isWindows) {
      WindowsDeviceInfo windowsInfo = await deviceInfo.windowsInfo;

      return windowsInfo.deviceId;
    }

    return null;
  }

  Future<bool> verifyLicense() async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    final licenseKey = pref.getString('license_key');

    final response = await http.post(
      Uri.parse('$baseURL/auth/license'),
      body: {
        "license_key": licenseKey ?? '',
        "device_id": await getDeviceID() ?? '',
      },
    );

 
    // สมมติ server คืน {"valid": true} เป็น json
    if (response.statusCode == 200) {
      final state = jsonDecode(response.body);

      if (state['success']) {
        return true;
      }

      return false;
    }

    return false;
  }

  Future<bool> activateLicense(String licenseKey) async {
    final response = await http.post(
      Uri.parse(baseURL + '/auth/activate'),
      body: {"license_key": licenseKey, "device_id": await getDeviceID() ?? ""},
    );

    if (response.statusCode == 200) {
      SharedPreferences pref = await SharedPreferences.getInstance();

      await pref.setString('license_key', licenseKey);
      return true;
    }

    return false;
  }
}
