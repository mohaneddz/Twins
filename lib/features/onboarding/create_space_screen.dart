import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../state/repository_provider.dart';
import '../../theme/palette.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/buttons.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/twins_input.dart';

class CreateSpaceScreen extends ConsumerStatefulWidget {
  const CreateSpaceScreen({super.key});

  @override
  ConsumerState<CreateSpaceScreen> createState() => _CreateSpaceScreenState();
}

class _CreateSpaceScreenState extends ConsumerState<CreateSpaceScreen> {
  final _name = TextEditingController(text: "We're Twins!");
  bool _loading = false;
  String? _inviteCode;

  Future<void> _create() async {
    setState(() => _loading = true);
    final repo = ref.read(repositoryProvider);
    final space = await repo.createSpace(_name.text.trim());
    final invite = await repo.createInvite(space.id);
    if (mounted) {
      setState(() {
        _inviteCode = invite.code;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ScreenHeader(title: 'Create our space'),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: TwinsSpacing.xl),
          child: _inviteCode == null ? _form() : _inviteView(),
        ),
      ),
    );
  }

  Widget _form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: TwinsSpacing.lg),
        Text('Give your space a name', style: TwinsTypography.body(context.twins.textSecondary)),
        const SizedBox(height: TwinsSpacing.md),
        TwinsInput(hint: 'Space name', controller: _name),
        const SizedBox(height: TwinsSpacing.lg),
        PrimaryButton(label: 'Create space', onPressed: _create, loading: _loading),
      ],
    );
  }

  Widget _inviteView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: TwinsSpacing.xl),
        Text('Your space is ready 🎉', style: TwinsTypography.heading(context.twins.textPrimary, size: 20)),
        const SizedBox(height: TwinsSpacing.xs),
        Text('Send this code to your partner so they can join.', style: TwinsTypography.body(context.twins.textSecondary)),
        const SizedBox(height: TwinsSpacing.xl),
        Container(
          padding: const EdgeInsets.symmetric(vertical: TwinsSpacing.xl),
          decoration: BoxDecoration(color: TwinsColors.mikuMist, borderRadius: BorderRadius.circular(24)),
          alignment: Alignment.center,
          child: Text(
            _inviteCode!,
            style: TwinsTypography.display(TwinsColors.mikuGreen, size: 40),
          ),
        ),
        const SizedBox(height: TwinsSpacing.xl),
        PrimaryButton(label: "Let's go", onPressed: () => context.go('/home')),
      ],
    );
  }
}
