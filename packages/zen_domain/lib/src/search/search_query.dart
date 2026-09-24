/// §5.10. The matching and filtering behind `SCR-SEARCH`.
///
/// §11.7 keeps rules out of providers: "If a decision needs a test, it belongs
/// in `zen_domain`." What counts as a match is such a decision, so it lives
/// here and the screen only renders what these functions return.
library;

import '../model/enums.dart';
import '../model/idea.dart';
import '../model/normalize.dart';
import '../model/subtask.dart';
import '../model/tag.dart';
import '../model/task.dart';

/// SEARCH-2. Which Tasks a search includes, by state.
///
/// The five values are exactly the filter's checkboxes. `Archived` and
/// `Deleted` are states rather than statuses, and they win: an archived Task is
/// `Done` (INV-3) but shows under `Archived`, never under `Done`.
enum TaskStateFilter {
  /// An active Task whose status is `Todo`.
  todo,

  /// An active Task whose status is `Blocked`.
  blocked,

  /// An active Task whose status is `Done` and which is not yet archived.
  done,

  /// `isArchived == true` and not deleted.
  archived,

  /// `isDeleted == true`, whatever else is true of it.
  deleted;

  /// SEARCH-2. "The default is all except Deleted."
  static const Set<TaskStateFilter> defaults = <TaskStateFilter>{
    todo,
    blocked,
    done,
    archived,
  };

  /// Which of the five [task] is in. Deleted wins over archived, which wins
  /// over the status, so every Task is in exactly one.
  static TaskStateFilter of(Task task) {
    if (task.isDeleted) {
      return deleted;
    }
    if (task.isArchived) {
      return archived;
    }
    return switch (task.status) {
      TaskStatus.todo => todo,
      TaskStatus.blocked => blocked,
      TaskStatus.done => done,
    };
  }
}

/// SEARCH-1, SEARCH-2. One search's text and filters.
///
/// An empty [text] matches everything the filters admit, so the screen can show
/// the filters working before anything is typed.
final class SearchQuery {
  /// Builds a query. The defaults are SEARCH-2's: both kinds, all four
  /// timeframes, and every Task state except `Deleted`.
  SearchQuery({
    String text = '',
    this.kinds = const <ItemKind>{ItemKind.idea, ItemKind.task},
    this.timeframes = const <Timeframe>{
      Timeframe.now,
      Timeframe.soon,
      Timeframe.later,
      Timeframe.distant,
    },
    this.taskStates = TaskStateFilter.defaults,
  }) : needle = normalizeName(text);

  /// SEARCH-1. The typed text, run through §2's normalization so that a
  /// search is case-insensitive and insensitive to accent composition and
  /// runs of whitespace — the same equivalence NAME-5 uses.
  final String needle;

  /// SEARCH-2. `Kind: Ideas / Tasks / Both`, as the set of kinds to include.
  final Set<ItemKind> kinds;

  /// SEARCH-2. Which Idea timeframes to include.
  final Set<Timeframe> timeframes;

  /// SEARCH-2. Which Task states to include.
  final Set<TaskStateFilter> taskStates;

  /// Whether nothing has been typed yet.
  bool get isEmptyText => needle.isEmpty;

  /// SEARCH-1, SEARCH-2. Whether [idea] belongs in the results.
  ///
  /// Matches its name, its tags and its context.
  bool matchesIdea(Idea idea) =>
      kinds.contains(ItemKind.idea) &&
      timeframes.contains(idea.timeframe) &&
      _matchesAny(<String>[
        idea.name.value,
        idea.context.value,
        for (final Tag tag in idea.tags) tag.value,
      ]);

  /// SEARCH-1, SEARCH-2. Whether [task] belongs in the results.
  ///
  /// Matches its name, its tags, its description and its subtask names.
  bool matchesTask(Task task) =>
      kinds.contains(ItemKind.task) &&
      taskStates.contains(TaskStateFilter.of(task)) &&
      _matchesAny(<String>[
        task.name.value,
        task.description.value,
        for (final Tag tag in task.tags) tag.value,
        for (final Subtask subtask in task.subtasks) subtask.name.value,
      ]);

  bool _matchesAny(List<String> haystacks) {
    if (needle.isEmpty) {
      return true;
    }
    return haystacks.any(
      (String field) => normalizeName(field).contains(needle),
    );
  }
}
