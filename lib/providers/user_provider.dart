import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:purchaser_edge/model/user_model.dart';
import 'package:http/http.dart' as http;
import 'package:purchaser_edge/services/url_service.dart';

class UserProvider extends ChangeNotifier {
  Timer? timer;

  void startAutoFetchUser() {
    timer = Timer.periodic(Duration(seconds: 10), (_) {
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

  Future addUser(
    String fullName,
    String username,
    String password,
    String branch,
    String role,
  ) async {
    final response = await http.post(
      Uri.parse('http://localhost:5000/user'),
      body: {
        "full_name": fullName,
        "username": username,
        "password": password,
        "branch": branch,
        "role": role,
      },
    );

    if (response.statusCode == 200) {
      notifyListeners();
    }
  }
}
