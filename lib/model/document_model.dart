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
  final String fullName;
  final String comment;
  final String email;
  final String createdAt;

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
    required this.comment,
    required this.fullName,
    required this.email,
    required this.createdAt,
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
      comment: json["comment"] ?? "",
      fullName: json["full_name"] ?? "",
      email: json["email"] ?? "",
      createdAt: json["created_at"] ?? "",
     
    );
  }
}
