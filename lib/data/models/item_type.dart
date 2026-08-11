enum ItemType {
  reel,
  tiktok,
  youtube,
  short,
  video,
  image,
  gif,
  note,
  document,
  audio,
  link,
  other;

  static ItemType fromString(String value) {
    return ItemType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ItemType.other,
    );
  }
}

enum ItemPlatform {
  instagram,
  tiktok,
  youtube,
  web,
  device;

  static ItemPlatform fromString(String? value) {
    return ItemPlatform.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ItemPlatform.device,
    );
  }
}
