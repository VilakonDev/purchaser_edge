class DocumentModel {
  final int id;
  final String documentNumber;
  final String documentTitle;
  final String branch;
  final String documentCategory;
  final String filePending;
  final String fileDm;
  final String fileDirector;
  final String status;
  final String approvedByDm;
  final String approvedByDirector;
  final String createdBy;
  final String createdAt;
  final String updatedAt;

  DocumentModel({
    required this.id,
    required this.documentNumber,
    required this.documentTitle,
    required this.branch,
    required this.documentCategory,
    required this.filePending,
    required this.fileDm,
    required this.fileDirector,
    required this.status,
    required this.approvedByDm,
    required this.approvedByDirector,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'],
      documentNumber: json['document_number'],
      documentTitle: json["document_title"],
      branch: json["branch"],
      documentCategory: json["category"],
      filePending: json["file_pending"],
      fileDm: json["file_dm"] ?? "",
      fileDirector: json["file_director"] ?? "",
      status: json["status"],
      approvedByDm: json["approved_by_dm"] ?? "",
      approvedByDirector: json["approved_by_director"] ?? "",
      createdBy: json["created_by"] ?? "",
      createdAt: json["created_at"] ?? "",
      updatedAt: json["updated_at"] ?? "",
    );
  }
}
