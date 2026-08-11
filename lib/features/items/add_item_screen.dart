import 'dart:async';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../data/ai/tag_suggester.dart';
import '../../data/models/item.dart';
import '../../data/models/item_type.dart';
import '../../data/supabase/link_metadata_service.dart';
import '../../state/auth_providers.dart';
import '../../state/data_providers.dart';
import '../../state/repository_provider.dart';
import '../../theme/palette.dart';
import '../../theme/colors.dart';
import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../utils/link_detector.dart';
import '../../widgets/buttons.dart';
import '../../widgets/toast.dart';
import '../../widgets/twins_input.dart';

enum _AddMode { menu, device, link, note, document }

class AddItemScreen extends ConsumerStatefulWidget {
  final String? sharedText;
  final String? initialFolderId;
  const AddItemScreen({super.key, this.sharedText, this.initialFolderId});

  @override
  ConsumerState<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends ConsumerState<AddItemScreen> {
  _AddMode _mode = _AddMode.menu;
  String? _selectedFolderId;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _urlController = TextEditingController();
  final _noteController = TextEditingController();
  ItemType _detectedType = ItemType.link;
  String? _thumbnailUrl;
  String? _pickedFilePath;
  String? _pickedFileName;
  bool _saving = false;
  bool _resolvingMetadata = false;
  double? _uploadProgress;

  // Tags to attach on save. AI populates these by default; the user can toggle
  // any off/on or add their own (see _TagSelector). Stored as lowercase names.
  final Set<String> _selectedTags = {};
  bool _suggestingTags = false;
  Timer? _tagDebounce;
  Timer? _urlDebounce;

  @override
  void initState() {
    super.initState();
    _selectedFolderId = widget.initialFolderId;
    if (widget.sharedText != null && widget.sharedText!.isNotEmpty) {
      _urlController.text = widget.sharedText!;
      _mode = _AddMode.link;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _detectFromUrl(widget.sharedText!);
      });
    }
  }

  @override
  void dispose() {
    _tagDebounce?.cancel();
    _urlDebounce?.cancel();
    _titleController.dispose();
    _descriptionController.dispose();
    _urlController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// The AI-tagging UI shared by every add mode: a live chip picker over the
  /// space's tag catalog (∪ anything the AI proposed or the user typed), with a
  /// re-run "Suggest" affordance and an "add tag" prompt. Selection is stored in
  /// [_selectedTags]; AI pre-selects, the user overrides.
  Widget _buildTagSelector() {
    final space = ref.watch(currentSpaceProvider).valueOrNull;
    final catalog = space == null
        ? const <String>[]
        : (ref.watch(tagsProvider(space.id)).valueOrNull ?? const []).map((t) => t.name).toList();
    final names = <String>{...catalog, ..._selectedTags}.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(PhosphorIconsFill.sparkle, size: 15, color: TwinsColors.mikuGreen),
            const SizedBox(width: 6),
            Text('Tags', style: TwinsTypography.label(context.twins.textSecondary)),
            const SizedBox(width: 8),
            if (_suggestingTags)
              const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2))
            else
              InkWell(
                onTap: _autoTag,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text('Suggest', style: TwinsTypography.label(TwinsColors.mikuGreen, size: 12)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final name in names)
              FilterChip(
                label: Text('#$name'),
                selected: _selectedTags.contains(name),
                onSelected: (on) => setState(() => on ? _selectedTags.add(name) : _selectedTags.remove(name)),
              ),
            ActionChip(
              avatar: const Icon(PhosphorIconsBold.plus, size: 14),
              label: const Text('Add tag'),
              onPressed: _promptNewTag,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _promptNewTag() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New tag'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. recipes'),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Add')),
        ],
      ),
    );
    final clean = name?.trim().toLowerCase();
    if (clean != null && clean.isNotEmpty) setState(() => _selectedTags.add(clean));
  }

  void _detectFromUrl(String url) {
    final detected = detectLink(url);
    setState(() => _detectedType = detected.type);
    _tryResolveMetadata(url);
  }

  Future<void> _tryResolveMetadata(String url) async {
    setState(() => _resolvingMetadata = true);
    final meta = await resolveLinkMetadata(url);
    if (!mounted) return;
    setState(() {
      _resolvingMetadata = false;
      if (meta != null) {
        if (meta.title != null && _titleController.text.isEmpty) _titleController.text = meta.title!;
        if (meta.description != null) _descriptionController.text = meta.description!;
        if (meta.thumbnailUrl != null) _thumbnailUrl = meta.thumbnailUrl;
      }
    });
    // Auto-tag from the catalog once we have a title/description.
    _autoTag();
  }

  /// Debounced auto-tag, for note/media forms where text is typed by hand.
  void _scheduleAutoTag() {
    _tagDebounce?.cancel();
    _tagDebounce = Timer(const Duration(milliseconds: 900), _autoTag);
  }

  /// Asks the AI to pick tags (preferring our catalog) for whatever the form
  /// currently describes, and merges them into the selected set. Runs by
  /// default; the user can then toggle any off/on. Never clobbers a tag the
  /// user manually added or removed in this session.
  Future<void> _autoTag() async {
    final title = _titleController.text.trim();
    final note = _noteController.text.trim();
    final url = _urlController.text.trim();
    // Links always tag from the URL/domain even when preview enrichment failed
    // and there's no title yet.
    if (title.isEmpty && note.isEmpty && url.isEmpty) return;

    final space = ref.read(currentSpaceProvider).valueOrNull;
    final catalog = space == null
        ? const <String>[]
        : (ref.read(tagsProvider(space.id)).valueOrNull ?? const []).map((t) => t.name).toList();

    final platform = url.isNotEmpty ? detectLink(url).platform.name : null;

    setState(() => _suggestingTags = true);
    final suggested = await suggestTags(
      title: title.isNotEmpty ? title : note,
      description: _descriptionController.text.trim(),
      content: note,
      url: url.isEmpty ? null : url,
      platform: platform,
      catalog: catalog,
    );
    if (!mounted) return;
    setState(() {
      _suggestingTags = false;
      // Only ADD suggestions; respect anything the user already toggled.
      _selectedTags.addAll(suggested);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: context.twins.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text('Add to ¡Twins!', style: TwinsTypography.heading(context.twins.textPrimary, size: 19)),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(TwinsSpacing.lg),
          child: switch (_mode) {
            _AddMode.menu => _buildMenu(),
            _AddMode.device => _buildDeviceForm(),
            _AddMode.link => _buildLinkForm(),
            _AddMode.note => _buildNoteForm(),
            _AddMode.document => _buildDocumentForm(),
          },
        ),
      ),
    );
  }

  Widget _buildMenu() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MenuOption(
          icon: PhosphorIconsFill.imageSquare,
          title: 'From device',
          subtitle: 'Photos, videos, files',
          onTap: () => setState(() => _mode = _AddMode.device),
        ),
        const SizedBox(height: TwinsSpacing.sm),
        _MenuOption(
          icon: PhosphorIconsFill.linkSimple,
          title: 'Paste link',
          subtitle: 'YouTube, TikTok, Reels, etc.',
          onTap: () => setState(() => _mode = _AddMode.link),
        ),
        const SizedBox(height: TwinsSpacing.sm),
        _MenuOption(
          icon: PhosphorIconsFill.notePencil,
          title: 'Quick note',
          subtitle: 'Write a note or list',
          onTap: () => setState(() => _mode = _AddMode.note),
        ),
        const SizedBox(height: TwinsSpacing.sm),
        _MenuOption(
          icon: PhosphorIconsFill.fileText,
          title: 'Upload document',
          subtitle: 'PDF, Doc, etc.',
          onTap: () => setState(() => _mode = _AddMode.document),
        ),
        const Spacer(),
        SecondaryButton(label: 'Cancel', onPressed: () => context.pop()),
      ],
    );
  }

  Widget _buildLinkForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TwinsInput(
            hint: 'Paste a link',
            controller: _urlController,
            onChanged: (v) {
              _urlDebounce?.cancel();
              if (Uri.tryParse(v)?.hasScheme == true) {
                // Debounce so a pasted URL resolves once, and typing doesn't
                // fire a network + AI call on every keystroke.
                _urlDebounce = Timer(const Duration(milliseconds: 500), () {
                  if (mounted) _detectFromUrl(v);
                });
              }
            },
          ),
          if (_resolvingMetadata) ...[
            const SizedBox(height: TwinsSpacing.sm),
            Row(children: [
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 8),
              Text('Fetching preview...', style: TwinsTypography.body(context.twins.textSecondary, size: 13)),
            ]),
          ],
          const SizedBox(height: TwinsSpacing.md),
          TwinsInput(hint: 'Title', controller: _titleController),
          const SizedBox(height: TwinsSpacing.md),
          TwinsInput(hint: 'Caption / note (optional)', controller: _descriptionController),
          const SizedBox(height: TwinsSpacing.lg),
          _buildTagSelector(),
          const SizedBox(height: TwinsSpacing.lg),
          _FolderTagPicker(selectedFolderId: _selectedFolderId, onFolderChanged: (id) => setState(() => _selectedFolderId = id)),
          const SizedBox(height: TwinsSpacing.xl),
          PrimaryButton(label: 'Save to ¡Twins!', loading: _saving, onPressed: _saveLink),
        ],
      ),
    );
  }

  Widget _buildNoteForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TwinsInput(hint: 'Note title', controller: _titleController, onChanged: (_) => _scheduleAutoTag()),
          const SizedBox(height: TwinsSpacing.md),
          TextField(
            controller: _noteController,
            maxLines: 8,
            decoration: const InputDecoration(hintText: 'Write a note, or use - for a list...'),
            onChanged: (_) => _scheduleAutoTag(),
          ),
          const SizedBox(height: TwinsSpacing.lg),
          _buildTagSelector(),
          const SizedBox(height: TwinsSpacing.lg),
          _FolderTagPicker(selectedFolderId: _selectedFolderId, onFolderChanged: (id) => setState(() => _selectedFolderId = id)),
          const SizedBox(height: TwinsSpacing.xl),
          PrimaryButton(label: 'Save note', loading: _saving, onPressed: _saveNote),
        ],
      ),
    );
  }

  Widget _buildDeviceForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_pickedFilePath == null)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Photo'),
                    onPressed: () => _pickMedia(ImageSource.gallery, isVideo: false),
                  ),
                ),
                const SizedBox(width: TwinsSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.videocam_outlined),
                    label: const Text('Video'),
                    onPressed: () => _pickMedia(ImageSource.gallery, isVideo: true),
                  ),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.all(TwinsSpacing.md),
              decoration: BoxDecoration(color: TwinsColors.mikuMist, borderRadius: TwinsRadius.mdRadius),
              child: Row(children: [
                const Icon(PhosphorIconsFill.checkCircle, color: TwinsColors.mikuGreen),
                const SizedBox(width: 8),
                Expanded(child: Text(_pickedFileName ?? 'File selected', overflow: TextOverflow.ellipsis)),
              ]),
            ),
          const SizedBox(height: TwinsSpacing.md),
          TwinsInput(hint: 'Title', controller: _titleController),
          const SizedBox(height: TwinsSpacing.lg),
          _buildTagSelector(),
          const SizedBox(height: TwinsSpacing.lg),
          _FolderTagPicker(selectedFolderId: _selectedFolderId, onFolderChanged: (id) => setState(() => _selectedFolderId = id)),
          const SizedBox(height: TwinsSpacing.lg),
          if (_saving) ...[
            LinearProgressIndicator(
              value: _uploadProgress,
              backgroundColor: TwinsColors.mikuMist,
              color: TwinsColors.mikuGreen,
            ),
            const SizedBox(height: TwinsSpacing.sm),
            Text('Uploading...', style: TwinsTypography.body(context.twins.textSecondary, size: 13)),
            const SizedBox(height: TwinsSpacing.sm),
          ],
          PrimaryButton(label: 'Save to ¡Twins!', loading: _saving, onPressed: _pickedFilePath == null ? null : _saveMedia),
        ],
      ),
    );
  }

  Widget _buildDocumentForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_pickedFilePath == null)
            OutlinedButton.icon(
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Choose a document'),
              onPressed: _pickDocument,
            )
          else
            Container(
              padding: const EdgeInsets.all(TwinsSpacing.md),
              decoration: BoxDecoration(color: TwinsColors.mikuMist, borderRadius: TwinsRadius.mdRadius),
              child: Row(children: [
                const Icon(PhosphorIconsFill.fileText, color: TwinsColors.mikuGreen),
                const SizedBox(width: 8),
                Expanded(child: Text(_pickedFileName ?? 'Document selected', overflow: TextOverflow.ellipsis)),
              ]),
            ),
          const SizedBox(height: TwinsSpacing.md),
          TwinsInput(hint: 'Title', controller: _titleController),
          const SizedBox(height: TwinsSpacing.lg),
          _buildTagSelector(),
          const SizedBox(height: TwinsSpacing.lg),
          _FolderTagPicker(selectedFolderId: _selectedFolderId, onFolderChanged: (id) => setState(() => _selectedFolderId = id)),
          const SizedBox(height: TwinsSpacing.lg),
          if (_saving) ...[
            LinearProgressIndicator(
              value: _uploadProgress,
              backgroundColor: TwinsColors.mikuMist,
              color: TwinsColors.mikuGreen,
            ),
            const SizedBox(height: TwinsSpacing.sm),
            Text('Uploading...', style: TwinsTypography.body(context.twins.textSecondary, size: 13)),
            const SizedBox(height: TwinsSpacing.sm),
          ],
          PrimaryButton(label: 'Save to ¡Twins!', loading: _saving, onPressed: _pickedFilePath == null ? null : _saveMedia),
        ],
      ),
    );
  }

  Future<void> _pickMedia(ImageSource source, {required bool isVideo}) async {
    final picker = ImagePicker();
    final file = isVideo ? await picker.pickVideo(source: source) : await picker.pickImage(source: source);
    if (file == null) return;
    setState(() {
      _pickedFilePath = file.path;
      _pickedFileName = file.name;
      _detectedType = isVideo ? ItemType.video : ItemType.image;
      if (_titleController.text.isEmpty) _titleController.text = file.name;
    });
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx', 'txt']);
    final file = result?.files.single;
    if (file == null) return;
    setState(() {
      _pickedFilePath = file.path;
      _pickedFileName = file.name;
      _detectedType = ItemType.document;
      if (_titleController.text.isEmpty) _titleController.text = file.name;
    });
  }

  Future<void> _saveLink() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      showTwinsToast(context, 'Paste a link first.', isError: true);
      return;
    }
    await _save(TwinsItem(
      id: '',
      spaceId: '',
      folderId: _selectedFolderId,
      createdBy: '',
      type: _detectedType,
      platform: detectLink(url).platform,
      sourceUrl: url,
      thumbnailUrl: _thumbnailUrl,
      title: _titleController.text.trim().isEmpty ? url : _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
  }

  Future<void> _saveNote() async {
    if (_titleController.text.trim().isEmpty && _noteController.text.trim().isEmpty) {
      showTwinsToast(context, 'Write something first.', isError: true);
      return;
    }
    await _save(TwinsItem(
      id: '',
      spaceId: '',
      folderId: _selectedFolderId,
      createdBy: '',
      type: ItemType.note,
      title: _titleController.text.trim().isEmpty ? 'Untitled note' : _titleController.text.trim(),
      content: _noteController.text.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
  }

  Future<void> _saveMedia() async {
    final localPath = _pickedFilePath;
    if (localPath == null) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(repositoryProvider);
      final space = await repo.currentSpace();
      if (space == null) throw Exception('No space');

      final upload = await repo.uploadFile(
        spaceId: space.id,
        localPath: localPath,
        fileName: _pickedFileName ?? 'file',
        onProgress: (p) => setState(() => _uploadProgress = p),
      );

      final title = _titleController.text.trim().isEmpty ? (_pickedFileName ?? 'Untitled') : _titleController.text.trim();
      final isImage = _detectedType == ItemType.image || _detectedType == ItemType.gif;

      final created = await repo.createItem(TwinsItem(
        id: '',
        spaceId: space.id,
        folderId: _selectedFolderId,
        createdBy: '',
        type: _detectedType,
        platform: ItemPlatform.device,
        storagePath: upload.storagePath,
        sourceUrl: isImage ? null : upload.url,
        thumbnailUrl: isImage ? upload.url : null,
        title: title,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      if (_selectedTags.isNotEmpty) {
        await repo.setItemTags(spaceId: space.id, itemId: created.id, tagNames: _selectedTags.toList());
      }

      if (mounted) {
        context.pop();
        showTwinsToast(context, 'Saved ✨');
      }
    } catch (e) {
      if (mounted) showTwinsToast(context, "Couldn't upload that. Try again.", isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _uploadProgress = null;
        });
      }
    }
  }

  Future<void> _save(TwinsItem draft) async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(repositoryProvider);
      final space = await repo.currentSpace();
      if (space == null) throw Exception('No space');
      final created = await repo.createItem(TwinsItem(
            id: '',
            spaceId: space.id,
            folderId: draft.folderId,
            createdBy: '',
            type: draft.type,
            platform: draft.platform,
            sourceUrl: draft.sourceUrl,
            storagePath: draft.storagePath,
            thumbnailUrl: draft.thumbnailUrl,
            title: draft.title,
            description: draft.description,
            content: draft.content,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ));
      if (_selectedTags.isNotEmpty) {
        await repo.setItemTags(spaceId: space.id, itemId: created.id, tagNames: _selectedTags.toList());
      }
      if (mounted) {
        context.pop();
        showTwinsToast(context, 'Saved ✨');
      }
    } catch (e) {
      if (mounted) showTwinsToast(context, "Couldn't save that. Try again.", isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _MenuOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuOption({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: TwinsRadius.lgRadius,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(TwinsSpacing.md),
        decoration: BoxDecoration(
          color: context.twins.surfaceMuted,
          borderRadius: TwinsRadius.lgRadius,
          border: Border.all(color: TwinsColors.lightBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: TwinsColors.mikuGreen, size: 28),
            const SizedBox(width: TwinsSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TwinsTypography.heading(context.twins.textPrimary, size: 16)),
                  Text(subtitle, style: TwinsTypography.body(context.twins.textSecondary, size: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FolderTagPicker extends ConsumerWidget {
  final String? selectedFolderId;
  final ValueChanged<String?> onFolderChanged;

  const _FolderTagPicker({required this.selectedFolderId, required this.onFolderChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spaceAsync = ref.watch(currentSpaceProvider);
    return spaceAsync.when(
      data: (space) {
        if (space == null) return const SizedBox.shrink();
        final foldersAsync = ref.watch(foldersProvider(FolderQuery(space.id, null)));
        return foldersAsync.when(
          data: (folders) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Save to folder', style: TwinsTypography.label(context.twins.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: folders
                      .map((f) => ChoiceChip(
                            label: Text('${f.icon} ${f.name}'),
                            selected: selectedFolderId == f.id,
                            onSelected: (_) => onFolderChanged(selectedFolderId == f.id ? null : f.id),
                          ))
                      .toList(),
                ),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
    );
  }
}
