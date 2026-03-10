import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:purchaser_edge/model/user_model.dart';
import 'package:purchaser_edge/services/url_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  CurrentUserModel? currentUser;

 

  Future<String?> getDeviceID() async {
    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isWindows) {
      WindowsDeviceInfo windowsInfo = await deviceInfo.windowsInfo;

      return "${windowsInfo.computerName}_${windowsInfo.deviceId}";
    }

    return null;
  }

  Future<bool> verifyLicense() async {
    try {
      SharedPreferences pref = await SharedPreferences.getInstance();
      final licenseKey = pref.getString('license_key');

      final response = await http.post(
        Uri.parse('${UrlService().baseUrl}/auth/license'),
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
    } catch (e) {
      return false;
    }
  }

  Future<bool> activateLicense(String licenseKey) async {
    final response = await http.post(
      Uri.parse(UrlService().baseUrl + '/auth/activate'),
      body: {"license_key": licenseKey, "device_id": await getDeviceID() ?? ""},
    );

    if (response.statusCode == 200) {
      SharedPreferences pref = await SharedPreferences.getInstance();

      await pref.setString('license_key', licenseKey);
      return true;
    }

    return false;
  }

  Future<bool> login(
    BuildContext context,
    String username,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('${UrlService().baseUrl}/auth/login'),
      body: {"username": username, "password": password},
    );

    if (response.statusCode == 200) {
      final loginData = jsonDecode(response.body);

      if (loginData['success']) {
        currentUser = CurrentUserModel.fromJson(loginData['data'][0]);

        return true;
      }

      return false;
    }

    return false;
  }
}
