import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

class FileEntry {
  final File file;
  final String id; // unique เช่น timestamp หรือ uuid

  FileEntry(this.file) : id = DateTime.now().millisecondsSinceEpoch.toString();
}

class FileProvider extends ChangeNotifier {
  List<FileEntry> _files = [];

  List<FileEntry> get files => _files;

  void addFile(List<File> newFiles) {
    _files.addAll(newFiles.map((f) => FileEntry(f)));
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
