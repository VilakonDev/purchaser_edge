import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

class FileProvider extends ChangeNotifier {
  List<File> _files = [];

  List<File> get files => _files;

  void addFile(List<File> newFile) {
    _files.addAll(newFile);
    notifyListeners();
  }


  void deleteFile(int index) {
    _files.removeAt(index);
    notifyListeners();
  }

  void clearFile() {
    _files.clear();

    notifyListeners();
  }

  void openFile(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri);
  }
}
