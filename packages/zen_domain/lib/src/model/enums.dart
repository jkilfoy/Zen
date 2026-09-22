/// §2, §3.2, §3.3. The three closed vocabularies of the data model.
library;

/// §2, §3.2, IDEAS-1. An Idea's urgency class.
///
/// Declared in urgency order, most urgent first, so [index] *is* the urgency
/// rank and the merge's "most urgent wins" rule (§9.3 step 4) is a minimum over
/// indices. IDEAS-1's fixed display order `Now, Soon, Later, Distant` is the
/// same order, so [values] serves both.
enum Timeframe {
  /// The most urgent class, and the factory default for
  /// `settings.defaultIdeaTimeframe` (§3.6).
  now,

  /// Less urgent than [now].
  soon,

  /// Less urgent than [soon].
  later,

  /// The least urgent class. An ordinary group, merely collapsed by default
  /// (IDEAS-1, Q2).
  distant;

  /// §9.3 step 4. Whether this timeframe is more urgent than [other].
  bool isMoreUrgentThan(Timeframe other) => index < other.index;

  /// §9.3 step 4. The more urgent of `this` and [other].
  Timeframe mostUrgent(Timeframe other) => index <= other.index ? this : other;
}

/// §2, §3.3, §3.4. A Task's or Subtask's state.
///
/// Declared in merge-precedence order, highest first, so [index] is the
/// precedence rank and §9.3 step 4's `Done > Blocked > Todo` is a minimum over
/// indices.
enum TaskStatus {
  /// Complete. Requires a non-null `completedAt` (INV-1) and, for a Task, that
  /// every subtask is also [done] (INV-2).
  done,

  /// Cannot proceed. Reachable only from the Edit Task screen in the MVP; the
  /// completion circle never produces it (STATUS-1).
  blocked,

  /// Open. The default for a new Task (§3.3) and Subtask (§3.4).
  todo;

  /// §9.3 step 4. Whether this status outranks [other] in merge precedence.
  bool takesPrecedenceOver(TaskStatus other) => index < other.index;

  /// §9.3 step 4, step 5(d). The higher-precedence of `this` and [other].
  TaskStatus highestPrecedence(TaskStatus other) =>
      index <= other.index ? this : other;
}

/// §2. Which of the two kinds of Item something is.
///
/// Ideas and Tasks are independent namespaces (NAME-6) and never conflict with
/// each other during a merge (MERGE-5), so most rules that span both kinds take
/// this as a parameter.
enum ItemKind {
  /// Something the user might do (§3.2).
  idea,

  /// Something the user intends to complete (§3.3).
  task,
}

/// DEL-3, §9.3 step 1. Why an Idea was tombstoned.
enum TombstoneReason {
  /// The user deleted the Idea outright (DEL-3).
  deleted,

  /// The Idea was consumed by a conversion into a Task (CONVERT-4).
  converted,
}
