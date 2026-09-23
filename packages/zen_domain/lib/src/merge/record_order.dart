/// §9.3, "Record order". The deterministic order over records that the merge's
/// tie-breaks rest on.
///
/// Several rules in §9.3 need to pick "the first" of a set of records —
/// step 4's third primary-record tie-break, its `tags` and `sourceIdea` rows,
/// and step 5's subtask ordering. An earlier draft of the specification said
/// "sorted by `id`" in those places. That was wrong: a conflict component
/// normally holds one record per replica, **all carrying the same `id`**, so
/// `id` is not a key here and sorting by it leaves the choice open. An open
/// choice is a non-deterministic merge, which breaks MERGE-2.
///
/// The comparators below close it. They are **not** total orders: two records
/// equal in every field compare equal. That is harmless, because such records
/// are interchangeable — any choice between them yields the same output — so
/// they are total *up to field-for-field equality*, which is all determinism
/// requires and a far easier property to defend than true totality.
library;

import '../model/idea.dart';
import '../model/subtask.dart';
import '../model/tag.dart';
import '../model/task.dart';
import '../model/tombstone.dart';

/// §9.3. Record order over Ideas.
///
/// Compares in the sequence §9.3 lays down: `id`, `updatedAt`, normalized name,
/// raw name, `createdAt`, then §3.2's remaining fields in declaration order —
/// `tags`, `context`, `timeframe`.
int compareIdeaRecords(Idea a, Idea b) {
  int result = a.id.compareTo(b.id);
  if (result != 0) return result;

  result = a.updatedAt.compareTo(b.updatedAt);
  if (result != 0) return result;

  result = a.name.normalized.compareTo(b.name.normalized);
  if (result != 0) return result;

  result = a.name.value.compareTo(b.name.value);
  if (result != 0) return result;

  result = a.createdAt.compareTo(b.createdAt);
  if (result != 0) return result;

  // §3.2 declaration order for what is left.
  result = compareTagLists(a.tags, b.tags);
  if (result != 0) return result;

  result = a.context.value.compareTo(b.context.value);
  if (result != 0) return result;

  return a.timeframe.index.compareTo(b.timeframe.index);
}

/// §9.3. Record order over Tasks.
///
/// Compares in the sequence §9.3 lays down: `id`, `updatedAt`, normalized name,
/// raw name, `createdAt`, then §3.3's remaining scalar fields in declaration
/// order, then the subtask list by length and element-wise.
int compareTaskRecords(Task a, Task b) {
  int result = a.id.compareTo(b.id);
  if (result != 0) return result;

  result = a.updatedAt.compareTo(b.updatedAt);
  if (result != 0) return result;

  result = a.name.normalized.compareTo(b.name.normalized);
  if (result != 0) return result;

  result = a.name.value.compareTo(b.name.value);
  if (result != 0) return result;

  result = a.createdAt.compareTo(b.createdAt);
  if (result != 0) return result;

  // §3.3 declaration order for the remaining scalar fields. `subtasks` is
  // deliberately left to the end, as §9.3 specifies.
  result = compareTagLists(a.tags, b.tags);
  if (result != 0) return result;

  result = a.description.value.compareTo(b.description.value);
  if (result != 0) return result;

  result = a.status.index.compareTo(b.status.index);
  if (result != 0) return result;

  result = compareNullableInstants(a.completedAt, b.completedAt);
  if (result != 0) return result;

  result = compareFlags(a.isArchived, b.isArchived);
  if (result != 0) return result;

  result = compareNullableInstants(a.archivedAt, b.archivedAt);
  if (result != 0) return result;

  result = compareFlags(a.isDeleted, b.isDeleted);
  if (result != 0) return result;

  result = compareNullableInstants(a.deletedAt, b.deletedAt);
  if (result != 0) return result;

  result = compareNullableStrings(a.sourceIdeaId, b.sourceIdeaId);
  if (result != 0) return result;

  result = compareNullableInstants(
    a.sourceIdeaCreatedAt,
    b.sourceIdeaCreatedAt,
  );
  if (result != 0) return result;

  return _compareSubtaskLists(a.subtasks, b.subtasks);
}

/// §9.3 step 8, MERGE-3A. Orders Idea tombstones by `id`.
///
/// Step 1 reduces tombstones to one per `id`, so this is a strict total order
/// over the output set.
int compareTombstonesById(IdeaTombstone a, IdeaTombstone b) =>
    a.id.compareTo(b.id);

/// §3.5. Compares two tag sequences: by length, then element-wise by
/// normalized form and then by the case the user typed.
///
/// Tags are a sequence, not a set (MERGE-3A), so order is part of the value.
int compareTagLists(List<Tag> a, List<Tag> b) {
  final int byLength = a.length.compareTo(b.length);
  if (byLength != 0) return byLength;

  for (int i = 0; i < a.length; i++) {
    int result = a[i].normalized.compareTo(b[i].normalized);
    if (result != 0) return result;
    result = a[i].value.compareTo(b[i].value);
    if (result != 0) return result;
  }
  return 0;
}

/// §9.3. Compares two subtask lists by length, then element-wise by `id`,
/// `name`, `status` and `updatedAt`, as the record-order definition specifies.
int _compareSubtaskLists(List<Subtask> a, List<Subtask> b) {
  final int byLength = a.length.compareTo(b.length);
  if (byLength != 0) return byLength;

  for (int i = 0; i < a.length; i++) {
    int result = a[i].id.compareTo(b[i].id);
    if (result != 0) return result;
    result = a[i].name.value.compareTo(b[i].name.value);
    if (result != 0) return result;
    result = a[i].status.index.compareTo(b[i].status.index);
    if (result != 0) return result;
    result = a[i].updatedAt.compareTo(b[i].updatedAt);
    if (result != 0) return result;
  }
  return 0;
}

/// Orders two nullable instants, null first.
///
/// Null sorts first so that a record which has never been completed, archived
/// or deleted precedes one that has, which matches how the flags sort.
int compareNullableInstants(DateTime? a, DateTime? b) {
  if (a == null) return b == null ? 0 : -1;
  if (b == null) return 1;
  return a.compareTo(b);
}

/// Orders two nullable strings, null first.
int compareNullableStrings(String? a, String? b) {
  if (a == null) return b == null ? 0 : -1;
  if (b == null) return 1;
  return a.compareTo(b);
}

/// Orders two flags, `false` first.
int compareFlags(bool a, bool b) {
  if (a == b) return 0;
  return a ? 1 : -1;
}
