// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/about/presentation/about_screen.dart';
import '../features/canteen/presentation/canteen_screen.dart';
import '../features/contacts/presentation/contact_area_screen.dart';
import '../features/contacts/presentation/contacts_list_screen.dart';
import '../features/legal/presentation/legal_placeholder_screen.dart';
import '../features/mail/presentation/mail_compose_screen.dart';
import '../features/mail/presentation/mail_message_screen.dart';
import '../features/mail/presentation/mail_screen.dart';
import '../features/more/presentation/more_screen.dart';
import '../features/news/presentation/news_detail_screen.dart';
import '../features/news/presentation/news_list_screen.dart';
import '../features/settings/presentation/channel_settings_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/timetable/presentation/timetable_screen.dart';
import 'app_routes.dart';
import 'app_shell.dart';

/// The application router.
///
/// Five stateful branches — one per bottom navigation destination — so each
/// section keeps its own navigation stack. The branch order is the order of
/// the destinations in [AppShell].
GoRouter createAppRouter({String initialLocation = AppRoutes.news}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder:
            (
              BuildContext context,
              GoRouterState state,
              StatefulNavigationShell navigationShell,
            ) => AppShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.news,
                builder: (BuildContext _, GoRouterState _) =>
                    const NewsListScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: AppRoutes.newsDetailPath,
                    name: AppRoutes.newsDetailName,
                    builder: (BuildContext _, GoRouterState state) =>
                        NewsDetailScreen(
                          slug: state.pathParameters['slug'] ?? '',
                        ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.timetable,
                builder: (BuildContext _, GoRouterState _) =>
                    const TimetableScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.canteen,
                builder: (BuildContext _, GoRouterState _) =>
                    const CanteenScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.contacts,
                builder: (BuildContext _, GoRouterState _) =>
                    const ContactsListScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: AppRoutes.contactAreaPath,
                    name: AppRoutes.contactAreaName,
                    builder: (BuildContext _, GoRouterState state) =>
                        ContactAreaScreen(
                          slug: state.pathParameters['slug'] ?? '',
                        ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.more,
                builder: (BuildContext _, GoRouterState _) =>
                    const MoreScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'mail',
                    builder: (BuildContext _, GoRouterState _) =>
                        const MailScreen(),
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'compose',
                        builder: (BuildContext _, GoRouterState _) =>
                            const MailComposeScreen(),
                      ),
                      GoRoute(
                        path: 'message/:id',
                        name: AppRoutes.mailMessageName,
                        builder: (BuildContext _, GoRouterState state) =>
                            MailMessageScreen(
                              id: state.pathParameters['id'] ?? '',
                            ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (BuildContext _, GoRouterState _) =>
                        const SettingsScreen(),
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'about',
                        builder: (BuildContext _, GoRouterState _) =>
                            const AboutScreen(),
                      ),
                      GoRoute(
                        path: 'channels',
                        builder: (BuildContext _, GoRouterState _) =>
                            const ChannelSettingsScreen(),
                      ),
                      GoRoute(
                        path: 'imprint',
                        builder: (BuildContext _, GoRouterState _) =>
                            const LegalPlaceholderScreen(
                              page: LegalPage.imprint,
                            ),
                      ),
                      GoRoute(
                        path: 'privacy',
                        builder: (BuildContext _, GoRouterState _) =>
                            const LegalPlaceholderScreen(
                              page: LegalPage.privacy,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// The router instance used by the running app.
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final GoRouter router = createAppRouter();
  ref.onDispose(router.dispose);
  return router;
});
