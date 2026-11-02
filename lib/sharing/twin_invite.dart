import 'package:share_plus/share_plus.dart';

import '../data/supabase/invite_link.dart';
import '../data/supabase/supabase_client_provider.dart';

/// Opens the share sheet with a link that connects the other twin's phone to
/// this project (see SupabaseSetupScreen).
Future<void> shareTwinInvite() async {
  final config = await knownSupabaseConfig;
  final link = buildInviteLink(url: config.url, publishableKey: config.publishableKey);
  await Share.share("Join me on ¡Twins! 💚 Install the app, then tap this link - or paste it on the app's first screen:\n$link");
}
