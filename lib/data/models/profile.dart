class Profile {
  final String id;
  final String displayName;
  final String username;
  final String? avatarUrl;
  final String? bio;

  /// Key of the colour this twin picked (see TwinColor); 'miku' by default.
  final String themeColor;
  final DateTime createdAt;

  const Profile({
    required this.id,
    required this.displayName,
    required this.username,
    this.avatarUrl,
    this.bio,
    this.themeColor = 'miku',
    required this.createdAt,
  });

  Profile copyWith({
    String? displayName,
    String? username,
    String? avatarUrl,
    String? bio,
    String? themeColor,
  }) {
    return Profile(
      id: id,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      themeColor: themeColor ?? this.themeColor,
      createdAt: createdAt,
    );
  }

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        displayName: json['display_name'] as String? ?? 'Twin',
        username: json['username'] as String? ?? 'twin',
        avatarUrl: json['avatar_path'] as String?,
        bio: json['bio'] as String?,
        themeColor: json['theme_color'] as String? ?? 'miku',
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'display_name': displayName,
        'username': username,
        'avatar_path': avatarUrl,
        'bio': bio,
        'theme_color': themeColor,
      };
}
