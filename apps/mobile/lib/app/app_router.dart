// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/about/presentation/about_screen.dart';
import '../features/campusmap/presentation/campus_map_screen.dart';
import '../features/canteen/presentation/canteen_screen.dart';
import '../features/contacts/presentation/contact_area_screen.dart';
import '../features/contacts/presentation/contacts_list_screen.dart';
import '../features/calendar/presentation/calendar_screen.dart';
import '../features/calendar/presentation/manage_calendars_screen.dart';
import '../features/legal/presentation/legal_placeholder_screen.dart';
import '../features/mail/presentation/compose_draft.dart';
import '../features/mail/presentation/mail_compose_screen.dart';
import '../features/mail/presentation/mail_message_screen.dart';
import '../features/mail/presentation/mail_screen.dart';
import '../features/mail/presentation/mail_search_screen.dart';
import '../features/grades/presentation/grades_screen.dart';
import '../features/moodle/presentation/moodle_course_screen.dart';
import '../features/moodle/presentation/moodle_screen.dart';
import '../features/more/presentation/more_screen.dart';
import '../features/news/presentation/news_detail_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/news/presentation/news_list_screen.dart';
import '../features/requests/domain/request_models.dart';
import '../features/requests/presentation/request_draft_screen.dart';
import '../features/requests/presentation/requests_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/settings/presentation/channel_settings_screen.dart';
import '../features/settings/presentation/dashboard_settings_screen.dart';
import '../features/settings/presentation/navigation_settings_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/todos/presentation/todos_screen.dart';
import '../features/today/presentation/today_screen.dart';
import '../core/prefs/settings_controller.dart';
import 'app_routes.dart';
import 'app_shell.dart';

/// The application router.
///
/// One stateful branch per [AppSection], **in enum order**, so the branch
/// index is the section's index and no lookup table can drift out of sync.
///
/// A branch for every section rather than only for the five visible tabs: the
/// bottom bar is user-configurable, and a section that is temporarily not in
/// the bar has to keep its navigation stack anyway. Rebuilding the router when
/// the bar changes would throw that stack away — and would also rebuild the
/// whole widget tree for what is a presentation change.
///
/// The personal services keep their `/more/...` paths even though they are
/// branches of their own: the paths are deep-linked from contacts and tests,
/// and there was no product reason to break them.
GoRouter createAppRouter({
  String initialLocation = AppRoutes.today,
  bool Function()? needsOnboarding,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    // The first launch goes to the setup instead of the dashboard. A redirect
    // rather than a different initialLocation, because the flag is only known
    // once the preference store has been read, which happens after the router
    // is built.
    redirect: (BuildContext context, GoRouterState state) {
      final bool pending = needsOnboarding?.call() ?? false;
      final bool onOnboarding = state.matchedLocation == AppRoutes.onboarding;
      if (pending && !onOnboarding) return AppRoutes.onboarding;
      if (!pending && onOnboarding) return AppRoutes.today;
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (BuildContext _, GoRouterState _) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder:
            (
              BuildContext context,
              GoRouterState state,
              StatefulNavigationShell navigationShell,
            ) => AppShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          // AppSection.today
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.today,
                builder: (BuildContext _, GoRouterState _) =>
                    const TodayScreen(),
              ),
            ],
          ),
          // AppSection.calendar
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.calendar,
                builder: (BuildContext _, GoRouterState _) =>
                    const CalendarScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: AppRoutes.calendarManagePath,
                    builder: (BuildContext _, GoRouterState _) =>
                        const ManageCalendarsScreen(),
                  ),
                ],
              ),
            ],
          ),
          // AppSection.canteen
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.canteen,
                builder: (BuildContext _, GoRouterState _) =>
                    const CanteenScreen(),
              ),
            ],
          ),
          // AppSection.news
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
          // AppSection.moodle
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.moodle,
                builder: (BuildContext _, GoRouterState _) =>
                    const MoodleScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: AppRoutes.moodleCoursePath,
                    name: AppRoutes.moodleCourseName,
                    builder: (BuildContext _, GoRouterState state) =>
                        MoodleCourseScreen(
                          courseId:
                              int.tryParse(state.pathParameters['id'] ?? '') ??
                              0,
                        ),
                  ),
                ],
              ),
            ],
          ),
          // AppSection.mail
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.mail,
                builder: (BuildContext _, GoRouterState _) =>
                    const MailScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'search',
                    builder: (BuildContext _, GoRouterState _) =>
                        const MailSearchScreen(),
                  ),
                  GoRoute(
                    path: 'compose',
                    builder: (BuildContext _, GoRouterState state) =>
                        MailComposeScreen(
                          draft: state.extra is ComposeDraft
                              ? state.extra as ComposeDraft
                              : null,
                        ),
                  ),
                  GoRoute(
                    path: 'message/:id',
                    name: AppRoutes.mailMessageName,
                    builder: (BuildContext _, GoRouterState state) =>
                        MailMessageScreen(id: state.pathParameters['id'] ?? ''),
                  ),
                ],
              ),
            ],
          ),
          // AppSection.todos
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.todos,
                builder: (BuildContext _, GoRouterState _) =>
                    const TodosScreen(),
              ),
            ],
          ),
          // AppSection.campusMap
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.campusMap,
                builder: (BuildContext _, GoRouterState state) =>
                    CampusMapScreen(
                      initialRoomKey: state
                          .uri
                          .queryParameters[AppRoutes.campusMapRoomParam],
                    ),
              ),
            ],
          ),
          // AppSection.contacts
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
          // AppSection.grades
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.grades,
                builder: (BuildContext _, GoRouterState _) =>
                    const GradesScreen(),
              ),
            ],
          ),
          // AppSection.requests
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.requests,
                builder: (BuildContext _, GoRouterState _) =>
                    const RequestsScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: AppRoutes.requestDraftPath,
                    name: AppRoutes.requestDraftName,
                    builder: (BuildContext _, GoRouterState state) =>
                        RequestDraftScreen(
                          draftId: state.pathParameters['id'] ?? 'new',
                          kind:
                              RequestKind.fromStorage(
                                state.uri.queryParameters['kind'],
                              ) ??
                              RequestKind.feedback,
                        ),
                  ),
                ],
              ),
            ],
          ),
          // AppSection.more — settings and the legal pages stay here; every
          // other area is reachable from this screen through its own branch.
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.more,
                builder: (BuildContext _, GoRouterState _) =>
                    const MoreScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: AppRoutes.searchPath,
                    builder: (BuildContext _, GoRouterState _) =>
                        const SearchScreen(),
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
                        path: 'navigation',
                        builder: (BuildContext _, GoRouterState _) =>
                            const NavigationSettingsScreen(),
                      ),
                      GoRoute(
                        path: 'dashboard',
                        builder: (BuildContext _, GoRouterState _) =>
                            const DashboardSettingsScreen(),
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
  final GoRouter router = createAppRouter(
    // Read, not watched: the router is built once, and the redirect asks for
    // the current answer every time it runs.
    needsOnboarding: () => !ref.read(settingsProvider).onboardingCompleted,
  );
  ref.onDispose(router.dispose);
  return router;
});
