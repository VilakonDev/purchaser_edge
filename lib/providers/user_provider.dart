import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:purchaser_edge/model/user_model.dart';
import 'package:http/http.dart' as http;
import 'package:purchaser_edge/services/url_service.dart';

class UserProvider extends ChangeNotifier {
  Timer? timer;

  void startAutoFetchUser() {
    timer = Timer.periodic(Duration(seconds: 3), (_) {
      getAllUser();
    });
  }

  //

  List<UserModel> _users = [];

  List<UserModel> get users => _users;

  Future getAllUser() async {
    final response = await http.get(Uri.parse('${UrlService().baseUrl}/user'));

    if (response.statusCode == 200) {
      final List userData = jsonDecode(response.body);

      _users = userData.map((e) => UserModel.fromJson(e)).toList();

      notifyListeners();
    }
  }

  String get dmEmail => _users
      .where((u) => u.role == "DISTRICT_MANAGER")
      .map((u) => u.email)
      .join(", ");

  String get directorsEmail =>
      _users.where((u) => u.role == "DIRECTOR").map((u) => u.email).join(", ");

  File? _signature;

  File? get signature => _signature;

  void setSignature(File? file) {
    _signature = file; // ถ้า null = ลบไฟล์
    notifyListeners();
  }

  Future<http.Response?> addUser(
    String fullName,
    String username,
    String password,
    String email,
    String branch,
    String category,
    String role,
  ) async {
    if (_signature == null) {
      print("No signature file selected");
      return null;
    }

    final url = Uri.parse('${UrlService().baseUrl}/user');

    // ✅ เปลี่ยนจาก AbortableMultipartRequest เป็น MultipartRequest ปกติ
    final request = http.MultipartRequest('POST', url);

    request.fields['full_name'] = fullName;
    request.fields['username'] = username;
    request.fields['password'] = password;
    request.fields['email'] = email;
    request.fields['branch'] = branch;
    request.fields['category'] = category;
    request.fields['role'] = role;

    request.files.add(
      await http.MultipartFile.fromPath('file', _signature!.path),
    );

    final streamedResponse = await request.send();

    // ✅ แปลง StreamedResponse → Response เพื่อให้ใช้ statusCode ได้ตรงๆ
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      setSignature(null);
      notifyListeners();
    } else {
      print('addUser error: ${response.statusCode} ${response.body}');
    }

    return response;
  }

  Future<void> deleteUser(int id) async {
    final response = await http.delete(
      Uri.parse('${UrlService().baseUrl}/user/${id}'),
    );

    if (response.statusCode == 200) {
      print("Delete Success");
    }
  }
}
