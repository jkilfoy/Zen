/// §5.1. The navigation map, as routes.
library;

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'screens/archive_screen.dart';
import 'screens/home_screen.dart';
import 'screens/idea_form_screen.dart';
import 'screens/review_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/task_form_screen.dart';

/// §5.1. Every route's path, in one place so no screen spells one out.
///
/// Review carries its tab in the query string rather than as two routes: §5.5
/// makes the tabs one screen with one top bar, and REVIEW-2's "default tab when
/// entering from Home" is then a default for one parameter rather than a second
/// destination.
abstract final class Routes {
  /// `SCR-HOME`.
  static const String home = '/';

  /// `SCR-REVIEW`.
  static const String review = '/review';

  /// §5.3, Add mode.
  static const String addIdea = '/idea/new';

  /// §5.4, Add mode.
  static const String addTask = '/task/new';

  /// `SCR-ARCHIVE`.
  static const String archive = '/archive';

  /// `SCR-SEARCH`.
  static const String search = '/search';

  /// `SCR-SETTINGS`.
  static const String settings = '/settings';

  /// §5.3, Edit mode, for the Idea [id].
  static String editIdea(String id) => '/idea/$id';

  /// §5.4, Edit mode, for the Task [id].
  static String editTask(String id) => '/task/$id';

  /// §4.4, Convert mode, pre-filled from the Idea [ideaId].
  static String convertIdea(String ideaId) => '/task/new/from/$ideaId';

  /// REVIEW-2, IDEAFORM-4, TASKFORM-8. Review, on one tab or the other.
  /// [highlight] is the id of an Item just added, converted or saved.
  /// IDEAFORM-4 asks for "the group containing the new Idea expanded and the
  /// new Idea scrolled into view … briefly highlighted", and TASKFORM-8 for the
  /// scroll; the list reads this parameter to do both.
  static String reviewTab(ReviewTab tab, {String? highlight}) =>
      highlight == null
      ? '$review?tab=${tab.name}'
      : '$review?tab=${tab.name}&highlight=$highlight';
}

/// §5.5. Which of the two tabs the Review screen opens on.
enum ReviewTab {
  /// REVIEW-2. The default when entering from Home.
  todo,

  /// IDEAFORM-4, CONVERT-5.
  ideas;

  /// Reads the `tab` query parameter, defaulting to [todo] (REVIEW-2).
  static ReviewTab parse(String? raw) => ReviewTab.values.firstWhere(
    (ReviewTab tab) => tab.name == raw,
    orElse: () => ReviewTab.todo,
  );
}

/// The root navigator, so that the desktop shortcuts of HOME-5 can pop a route
/// from above the `Router` (§11.7).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// §5.1. Builds the router.
///
/// NAV-3: the initial location is Home, and nothing is shown before it.
GoRouter buildRouter() => GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: Routes.home,
  routes: <RouteBase>[
    GoRoute(
      path: Routes.home,
      builder: (BuildContext context, GoRouterState state) =>
          const HomeScreen(),
    ),
    GoRoute(
      path: Routes.review,
      builder: (BuildContext context, GoRouterState state) => ReviewScreen(
        tab: ReviewTab.parse(state.uri.queryParameters['tab']),
        highlight: state.uri.queryParameters['highlight'],
      ),
    ),
    GoRoute(
      path: Routes.addIdea,
      builder: (BuildContext context, GoRouterState state) =>
          const IdeaFormScreen.add(),
    ),
    GoRoute(
      path: '/idea/:id',
      builder: (BuildContext context, GoRouterState state) =>
          IdeaFormScreen.edit(ideaId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: Routes.addTask,
      builder: (BuildContext context, GoRouterState state) =>
          const TaskFormScreen.add(),
    ),
    GoRoute(
      path: '/task/new/from/:ideaId',
      builder: (BuildContext context, GoRouterState state) =>
          TaskFormScreen.convert(ideaId: state.pathParameters['ideaId']!),
    ),
    GoRoute(
      path: '/task/:id',
      builder: (BuildContext context, GoRouterState state) =>
          TaskFormScreen.edit(taskId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: Routes.archive,
      builder: (BuildContext context, GoRouterState state) =>
          const ArchiveScreen(),
    ),
    GoRoute(
      path: Routes.search,
      builder: (BuildContext context, GoRouterState state) =>
          const SearchScreen(),
    ),
    GoRoute(
      path: Routes.settings,
      builder: (BuildContext context, GoRouterState state) =>
          const SettingsScreen(),
    ),
  ],
);
