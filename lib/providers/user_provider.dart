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

  List<File> _signature = [];

  List<File> get signature => _signature;

  void addSignature(List<File> newFiles) {
    _signature.addAll(newFiles);
    notifyListeners();
  }

  Future addUser(
    String fullName,
    String username,
    String password,
    String branch,
    String category,
    String role,
  ) async {
    final url = Uri.parse(UrlService().baseUrl + '/user');
    final request = http.AbortableMultipartRequest('POST', url);

    request.fields['full_name'] = fullName;
    request.fields['username'] = username;
    request.fields['password'] = password;
    request.fields['branch'] = branch;
    request.fields['category'] = category;
    request.fields['role'] = role;
    request.files.add(
      await http.MultipartFile.fromPath(
        'file', // ต้องตรงกับ .single("file")
        _signature.first.path,
      ),
    );

    final response = await request.send();

    return response;
  }

  Future<void> deleteUser(int id) async {
    final response = await http.delete(
      Uri.parse(UrlService().baseUrl + '/user/${id}'),
    );

    if (response.statusCode == 200) {
      print("Delete Success");
    }
  }
}
