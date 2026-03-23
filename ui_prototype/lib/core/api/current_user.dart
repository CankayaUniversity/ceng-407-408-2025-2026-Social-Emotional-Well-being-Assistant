class CurrentUser {
  final int id;
  final String username;

  CurrentUser({
    required this.id,
    required this.username,
  });

  factory CurrentUser.fromJson(Map<String, dynamic> json) {
    return CurrentUser(
      id: json['id'] as int,
      username: (json['username'] ??
          json['name'] ??
          json['email'] ??
          'unknown')
          .toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
    };
  }
}