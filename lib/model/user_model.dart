class UserModel {
  final int id;
  final String fullName;
  final String username;
  final String password;
  final String role;
  final String branch;
  final String status;

  UserModel({
    required this.id,
    required this.fullName,
    required this.username,
    required this.password,
    required this.role,
    required this.branch,
    required this.status,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      fullName: json['full_name'],
      username: json['username'],
      password: json['password'],
      role: json['role'],
      branch: json['branch'],
      status: json['status'],
    );
  }
}
