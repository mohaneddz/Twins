import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/forgot_password_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/auth/welcome_screen.dart';
import '../features/folders/all_folders_screen.dart';
import '../features/home/activity_screen.dart';
import '../features/home/home_shell.dart';
import '../features/items/add_item_screen.dart';
import '../features/items/item_detail_screen.dart';
import '../features/folders/folder_view_screen.dart';
import '../features/onboarding/create_space_screen.dart';
import '../features/onboarding/join_space_screen.dart';
import '../features/onboarding/pairing_choice_screen.dart';
import '../features/profile/edit_profile_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/help_center_screen.dart';
import '../features/settings/invite_partner_screen.dart';
import '../features/settings/manage_folders_screen.dart';
import '../features/settings/manage_tags_screen.dart';
import '../features/settings/notifications_settings_screen.dart';
import '../features/settings/privacy_screen.dart';
import '../features/settings/settings_screen.dart';
import '../splash_gate.dart';
import '../state/auth_providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authAsync = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: _RiverpodRefreshStream(ref),
    redirect: (context, state) {
      final loggingIn = state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup' ||
          state.matchedLocation == '/forgot-password' ||
          state.matchedLocation == '/welcome';
      final onboarding = state.matchedLocation.startsWith('/onboarding');

      return authAsync.when(
        data: (profile) {
          if (profile == null) {
            // Logged out: only auth screens are allowed. Anywhere else
            // (including the initial splash at '/') goes to welcome.
            return loggingIn ? null : '/welcome';
          }
          // Logged in: leave the splash/auth screens for home; the onboarding
          // (pairing) flow is allowed to stay.
          if (state.matchedLocation == '/' || loggingIn) {
            return onboarding ? null : '/home';
          }
          return null;
        },
        loading: () => null,
        error: (_, __) => null,
      );
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashGate()),
      GoRoute(path: '/welcome', builder: (context, state) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const PairingChoiceScreen(),
      ),
      GoRoute(path: '/onboarding/create', builder: (context, state) => const CreateSpaceScreen()),
      GoRoute(path: '/onboarding/join', builder: (context, state) => const JoinSpaceScreen()),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeShell(),
      ),
      GoRoute(path: '/folders', builder: (context, state) => const AllFoldersScreen()),
      GoRoute(path: '/search', builder: (context, state) => SearchScreen(initialQuery: state.uri.queryParameters['q'])),
      GoRoute(path: '/activity', builder: (context, state) => const ActivityScreen()),
      GoRoute(
        path: '/folder/:id',
        builder: (context, state) => FolderViewScreen(folderId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/item/:id',
        builder: (context, state) => ItemDetailScreen(itemId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/add',
        builder: (context, state) {
          final extra = state.extra;
          final map = extra is Map ? extra : const {};
          return AddItemScreen(
            sharedText: map['sharedText'] as String?,
            initialFolderId: map['folderId'] as String?,
          );
        },
      ),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      GoRoute(path: '/settings/edit-profile', builder: (context, state) => const EditProfileScreen()),
      GoRoute(path: '/settings/manage-folders', builder: (context, state) => const ManageFoldersScreen()),
      GoRoute(path: '/settings/manage-tags', builder: (context, state) => const ManageTagsScreen()),
      GoRoute(path: '/settings/invite', builder: (context, state) => const InvitePartnerScreen()),
      GoRoute(path: '/settings/privacy', builder: (context, state) => const PrivacyScreen()),
      GoRoute(path: '/settings/notifications', builder: (context, state) => const NotificationsSettingsScreen()),
      GoRoute(path: '/settings/help', builder: (context, state) => const HelpCenterScreen()),
    ],
  );
});

/// Bridges a Riverpod stream into a [Listenable] so GoRouter can react to
/// auth changes without a StatefulWidget.
class _RiverpodRefreshStream extends ChangeNotifier {
  _RiverpodRefreshStream(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
}
