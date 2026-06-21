// lib/models/user_model.dart

class User {
  final String id;
  final String phoneNumber;
  final String name;
  final String email;
  final String nationalId;
  final String carPlate;
  final String role; // 'user', 'admin', 'support'
  final int points;
  final String? photoUrl;
  final bool isVerified;
  final String? pendingReward;
  final DateTime createdAt;

  User({
    required this.id,
    required this.phoneNumber,
    required this.name,
    required this.email,
    required this.nationalId,
    required this.carPlate,
    required this.role,
    required this.points,
    this.photoUrl,
    required this.isVerified,
    this.pendingReward,
    required this.createdAt,
  });

  // Convert JSON from API to User Object
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      nationalId: json['nationalId'] ?? '',
      carPlate: json['carPlate'] ?? '',
      role: json['role'] ?? 'user',
      points: double.tryParse(json['points'].toString())?.toInt() ?? 0,
      photoUrl: json['photoUrl'],
      isVerified: json['isVerified'] ?? false,
      pendingReward: json['pendingReward'],
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
    );
  }

  // Convert User Object to JSON (for API requests)
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'phoneNumber': phoneNumber,
      'name': name,
      'email': email,
      'nationalId': nationalId,
      'carPlate': carPlate,
      'role': role,
      'points': points,
      'photoUrl': photoUrl,
      'pendingReward': pendingReward,
      'isVerified': isVerified,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create a copy of the user with updated fields (useful for Profile edits)
  User copyWith({
    String? id,
    String? phoneNumber,
    String? name,
    String? email,
    String? nationalId,
    String? carPlate,
    String? role,
    int? points,
    String? photoUrl,
    bool? isVerified,
    String? pendingReward,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      name: name ?? this.name,
      email: email ?? this.email,
      nationalId: nationalId ?? this.nationalId,
      carPlate: carPlate ?? this.carPlate,
      role: role ?? this.role,
      points: points ?? this.points,
      photoUrl: photoUrl ?? this.photoUrl,
      isVerified: isVerified ?? this.isVerified,
      pendingReward: pendingReward ?? this.pendingReward,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}