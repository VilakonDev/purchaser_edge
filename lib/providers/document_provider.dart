import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:purchaser_edge/model/document_model.dart';
import 'package:http/http.dart' as http;
import 'package:purchaser_edge/model/monthly_buy_model.dart';
import 'package:purchaser_edge/services/url_service.dart';

class DocumentProvider extends ChangeNotifier {
  final List<String> _category = [
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
    timer = Timer.periodic(Duration(seconds: 3), (timer) {
      getAllDocuments();

      notifyListeners();
    });
  }

  List<DocumentModel> _documents = [];

  List<DocumentModel> get documents => _documents;

  Future getAllDocuments() async {
    final response = await http.get(
      Uri.parse('${UrlService().baseUrl}/documents/getAllDocument'),
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);

      _documents = data.map((e) => DocumentModel.fromJson(e)).toList();

      notifyListeners();
    }
  }

  List<DocumentModel> get pendingDocument =>
      _documents.where((doc) => doc.status == "PENDING").toList();

  List<DocumentModel> get dmApprovedDocument =>
      _documents.where((doc) => doc.status == "DM_APPROVED").toList();

  List<DocumentModel> get directorApproved =>
      _documents.where((doc) => doc.status == "DIRECTOR_APPROVED").toList();

  List<DocumentModel> showAllDocuments(String category) {
    if (category == "ທັງຫມົດ") {
      return _documents;
    }

    return _documents.where((doc) => doc.documentCategory == category).toList();
  }

  List<DocumentModel> showDocumentByOfficerCategory(String category) {
    return _documents.where((doc) => doc.documentCategory == category).toList();
  }

  List<DocumentModel> showDocumentByOfficerCategoryAndStatus(
    String category,
    String status,
  ) {
    final docs = showDocumentByOfficerCategory(category);

    if (status == "All") {
      return docs;
    }

    return docs.where((doc) => doc.status == status).toList();
  }

  List<MonthlyBuyModel> getMonthlyBuy() {
    List<MonthlyBuyModel> result = [];

    List<String> months = [
      'ມ.ກ',
      'ກ.ພ',
      'ມີ.ນ',
      'ເມ.ສ',
      'ພ.ພ',
      'ມິ.ຖ',
      'ກ.ລ',
      'ສ.ຫ',
      'ກ.ຍ',
      'ຕ.ລ',
      'ພ.ຈ',
      'ທ.ວ',
    ];

    for (int i = 1; i <= 12; i++) {
      int count = _documents.where((doc) {
        final date = DateTime.parse(doc.createdAt); // parse ก่อน
        return date.month == i &&
            doc.status == "DIRECTOR_APPROVED"; // filter status ด้วย
      }).length;

      result.add(MonthlyBuyModel(months[i - 1], count.toDouble()));
    }

    return result;
  }
}
