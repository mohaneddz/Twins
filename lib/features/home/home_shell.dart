import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../sharing/share_intent_service.dart';
import '../chat/chat_screen.dart';
import '../folders/all_folders_screen.dart';
import '../profile/profile_screen.dart';
import 'home_dashboard_screen.dart';
import '../../widgets/twins_bottom_nav.dart';

/// Hosts the four bottom-tab pages. The center "+" nav item is not a tab -
/// it always pushes the Add Item flow.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _tabIndex = 0; // 0 home, 1 folders, 2 chat, 3 profile

  @override
  void initState() {
    super.initState();
    // If a share arrived before login (e.g. cold-start via the OS share
    // sheet while logged out), pick it up now that we're in the app.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final pending = await ShareIntentService.instance.consumePendingShare();
      if (pending != null && mounted) {
        context.push('/add', extra: {'sharedText': pending});
      }
    });
  }

  static const _navIndexForTab = [0, 1, 3, 4];

  final _pages = const [
    HomeDashboardScreen(),
    AllFoldersScreen(),
    ChatScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tabIndex, children: _pages),
      bottomNavigationBar: TwinsBottomNav(
        currentIndex: _navIndexForTab[_tabIndex],
        onTap: (navIndex) {
          if (navIndex == 2) {
            context.push('/add');
            return;
          }
          final tab = navIndex < 2 ? navIndex : navIndex - 1;
          setState(() => _tabIndex = tab);
        },
        onAddTap: () => context.push('/add'),
      ),
    );
  }
}
