import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../state/auth_providers.dart';
import '../../state/repository_provider.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../widgets/avatars.dart';
import '../../widgets/buttons.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/toast.dart';
import '../../widgets/twins_input.dart';

/// Users can only edit their own display name/username/bio - never their
/// twin's fields, per spec section 20.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _username;
  late final TextEditingController _bio;
  bool _saving = false;
  bool _uploadingAvatar = false;
  String? _pendingAvatarPath;

  @override
  void initState() {
    super.initState();
    final me = ref.read(authStateProvider).valueOrNull;
    _name = TextEditingController(text: me?.displayName ?? '');
    _username = TextEditingController(text: me?.username ?? '');
    _bio = TextEditingController(text: me?.bio ?? '');
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800);
    if (file == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final me = ref.read(authStateProvider).valueOrNull;
      if (me == null) return;
      final repo = ref.read(repositoryProvider);
      final url = await repo.uploadAvatar(userId: me.id, localPath: file.path);
      await repo.updateProfile(avatarUrl: url);
      if (mounted) setState(() => _pendingAvatarPath = url);
    } catch (e) {
      if (mounted) showTwinsToast(context, "Couldn't update your photo.", isError: true);
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authStateProvider).valueOrNull;
    final displayProfile = me?.copyWith(avatarUrl: _pendingAvatarPath ?? me.avatarUrl);
    return Scaffold(
      appBar: const ScreenHeader(title: 'Edit profile'),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(TwinsSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (displayProfile != null)
                Center(
                  child: GestureDetector(
                    onTap: _uploadingAvatar ? null : _pickAvatar,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        UserAvatar(profile: displayProfile, size: 84),
                        if (_uploadingAvatar)
                          const CircularProgressIndicator(color: TwinsColors.white)
                        else
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: TwinsColors.mikuGreen, shape: BoxShape.circle),
                              child: const Icon(Icons.edit, size: 16, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: TwinsSpacing.lg),
              TwinsInput(hint: 'Display name', controller: _name),
              const SizedBox(height: TwinsSpacing.md),
              TwinsInput(hint: 'Username', controller: _username),
              const SizedBox(height: TwinsSpacing.md),
              TwinsInput(hint: 'Bio', controller: _bio),
              const SizedBox(height: TwinsSpacing.xl),
              PrimaryButton(
                label: 'Save changes',
                loading: _saving,
                onPressed: () async {
                  setState(() => _saving = true);
                  try {
                    await ref.read(repositoryProvider).updateProfile(
                          displayName: _name.text.trim(),
                          username: _username.text.trim(),
                          bio: _bio.text.trim(),
                        );
                    if (mounted) {
                      showTwinsToast(context, 'Profile updated ✨');
                      context.pop();
                    }
                  } catch (e) {
                    if (mounted) showTwinsToast(context, "Couldn't save changes.", isError: true);
                  } finally {
                    if (mounted) setState(() => _saving = false);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
