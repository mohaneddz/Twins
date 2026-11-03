import 'package:flutter/material.dart';

import '../../data/supabase/project_setup.dart';
import '../../data/supabase/supabase_client_provider.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../widgets/buttons.dart';
import '../../widgets/toast.dart';
import '../../widgets/twins_bottom_sheet.dart';
import '../../widgets/twins_input.dart';
import '../../theme/palette.dart';

/// Re-deploys the bundled edge functions (link previews, AI tags, chat
/// naming) to this project - needed after an app update changes them.
/// Neither the access token nor the Groq key is stored.
Future<void> showDeployFunctionsSheet(BuildContext context) async {
  final token = TextEditingController();
  final groq = TextEditingController();
  var deploying = false;
  String? progress;
  String? error;

  await showTwinsBottomSheet(
    context: context,
    title: 'Update server functions',
    child: StatefulBuilder(
      builder: (sheetContext, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Create an access token at supabase.com/dashboard/account/tokens and paste it here. '
            'Leave the Groq key empty to keep the one already set.',
          ),
          const SizedBox(height: TwinsSpacing.md),
          TwinsInput(hint: 'Supabase access token (sbp_…)', controller: token),
          const SizedBox(height: TwinsSpacing.sm),
          TwinsInput(hint: 'Groq API key (optional)', controller: groq),
          if (progress != null || error != null) ...[
            const SizedBox(height: TwinsSpacing.sm),
            Text(error ?? progress!, style: TextStyle(color: error != null ? TwinsColors.danger : context.twins.accent, fontSize: 13)),
          ],
          const SizedBox(height: TwinsSpacing.md),
          PrimaryButton(
            label: 'Deploy',
            loading: deploying,
            onPressed: () async {
              if (token.text.trim().isEmpty) {
                setState(() => error = 'Paste an access token first.');
                return;
              }
              setState(() {
                deploying = true;
                error = null;
              });
              try {
                final versions = await deployEdgeFunctions(
                  projectUrl: (await knownSupabaseConfig).url,
                  accessToken: token.text,
                  groqApiKey: groq.text,
                  onStep: (step) => setState(() => progress = 'Deploying $step…'),
                );
                if (sheetContext.mounted) {
                  Navigator.of(sheetContext).pop();
                  final summary = versions.entries.map((e) => '${e.key} v${e.value ?? '?'}').join(', ');
                  showTwinsToast(context, 'Deployed $summary');
                }
              } on SetupException catch (e) {
                setState(() => error = e.message);
              } catch (e) {
                // Anything else (no network, an unexpected reply) must not
                // look like success.
                setState(() => error = "Couldn't deploy: $e");
              } finally {
                if (sheetContext.mounted) setState(() => deploying = false);
              }
            },
          ),
        ],
      ),
    ),
  );
  token.dispose();
  groq.dispose();
}
