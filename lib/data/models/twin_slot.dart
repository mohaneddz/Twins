/// One of the two accounts a ¡Twins! project can hold, as listed on the
/// "Who's this?" screen before anyone has logged in.
class TwinSlot {
  final int slot;
  final String displayName;
  final String? avatarUrl;
  final String loginEmail;

  const TwinSlot({required this.slot, required this.displayName, this.avatarUrl, required this.loginEmail});

  factory TwinSlot.fromJson(Map<String, dynamic> json) => TwinSlot(
        slot: (json['slot'] as num).toInt(),
        displayName: json['display_name'] as String,
        avatarUrl: json['avatar_path'] as String?,
        loginEmail: json['login_email'] as String,
      );
}
