enum AppThemeMode { light, dark, system }

class TwinsUserSettings {
  final String userId;
  final AppThemeMode theme;
  final String? defaultFolderId;
  final String defaultSort;
  final String mediaQuality;
  final bool notificationsEnabled;

  const TwinsUserSettings({
    required this.userId,
    this.theme = AppThemeMode.system,
    this.defaultFolderId,
    this.defaultSort = 'newest',
    this.mediaQuality = 'auto',
    this.notificationsEnabled = true,
  });

  TwinsUserSettings copyWith({
    AppThemeMode? theme,
    String? defaultFolderId,
    String? defaultSort,
    String? mediaQuality,
    bool? notificationsEnabled,
  }) {
    return TwinsUserSettings(
      userId: userId,
      theme: theme ?? this.theme,
      defaultFolderId: defaultFolderId ?? this.defaultFolderId,
      defaultSort: defaultSort ?? this.defaultSort,
      mediaQuality: mediaQuality ?? this.mediaQuality,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }

  factory TwinsUserSettings.fromJson(Map<String, dynamic> json) => TwinsUserSettings(
        userId: json['user_id'] as String,
        theme: AppThemeMode.values.firstWhere(
          (e) => e.name == json['theme'],
          orElse: () => AppThemeMode.system,
        ),
        defaultFolderId: json['default_folder_id'] as String?,
        defaultSort: json['default_sort'] as String? ?? 'newest',
        mediaQuality: json['media_quality'] as String? ?? 'auto',
        notificationsEnabled: json['notifications_enabled'] as bool? ?? true,
      );
}
