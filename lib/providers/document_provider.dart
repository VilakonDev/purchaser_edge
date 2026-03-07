import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:purchaser_edge/model/document_model.dart';
import 'package:http/http.dart' as http;

class DocumentProvider extends ChangeNotifier {
  List<String> _category = [
    'MA.SA.AU',
    'HT.PT.PB.GD',
    'FT.BD.HO.FD',
    'FC.BR',
    'ET.LT.KC',
    'DH.DW.HW.PA',
    'BM',
  ];

  List<String> get category => _category;

  String? _documentNumber;
  String? _documentTitle;
  String? _documentCategory;
  String? _branch;
  String? _createdBy;

  String? get documentNumber => _documentNumber;
  String? get documentTitle => _documentTitle;
  String? get documentCategory => _documentCategory;
  String? get branch => _branch;
  String? get createBy => _createdBy;

  void setDocumentInfo(
    String documentNumber,
    String documentTitle,
    String documentCategory,
    String branch,
    String createdBy,
  ) {
    _documentNumber = documentNumber;
    _documentTitle = documentTitle;
    _documentCategory = documentCategory;
    _branch = branch;
    _createdBy = createdBy;

    notifyListeners();
  }

  void resetDocumentInfo() {
    _documentNumber = "";
    _documentTitle = "";
    _documentCategory = "";
    _branch = "";
    _createdBy = "";
  }

  //GetDocument

  Timer? timer;

  void startAutoFetchDocument() {
    timer = Timer.periodic(Duration(seconds: 10), (timer) {
      getAllDocument();

      notifyListeners();
    });
  }

  List<DocumentModel> _documents = [];

  List<DocumentModel> get documents => _documents;

  Future getAllDocument() async {
    final response = await http.get(
      Uri.parse('http://localhost:5000/documents/getAllDocument'),
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);

      _documents = data.map((e) => DocumentModel.fromJson(e)).toList();

      notifyListeners();
    }
  }
}
