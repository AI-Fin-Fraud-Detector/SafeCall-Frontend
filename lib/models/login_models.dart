class LoginRequest {
  final String email;
  final String password;

  LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
  };
}

class LoginResponse {
  final String accessToken;
  final String uuid;
  final String name;
  final String email;
  final String phoneNumber;

  LoginResponse({
    required this.accessToken,
    required this.uuid,
    required this.name,
    required this.email,
    required this.phoneNumber,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accessToken: json['access_token'] as String,
      uuid:        json['uuid']         as String,
      name:        json['name']         as String? ?? '',
      email:       json['email']        as String,
      phoneNumber: json['phone_number'] as String? ?? '',
    );
  }
}
