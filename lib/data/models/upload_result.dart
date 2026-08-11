/// Result of uploading a local file into space-scoped Storage.
class UploadResult {
  /// Raw bucket path, e.g. `spaces/{spaceId}/items/{uuid}.jpg` - stored on
  /// the item so it can be re-signed or deleted later.
  final String storagePath;

  /// A URL usable right now to display/play the file (signed, for private
  /// buckets; identical to storagePath-derived URL in mock mode).
  final String url;

  const UploadResult({required this.storagePath, required this.url});
}
