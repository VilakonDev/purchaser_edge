import 'dart:io';

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
}