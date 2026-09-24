/// §5.3. `SCR-IDEA-FORM`: Add Idea and Edit Idea.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zen_domain/zen_domain.dart';

import '../providers/app_providers.dart';
import '../providers/idea_actions.dart';
import '../router.dart';
import '../widgets/advanced_details.dart';
import '../widgets/confirmations.dart';
import '../widgets/name_field.dart';
import '../widgets/tag_input.dart';

/// §5.3. "The screen has two modes, Add and Edit, with the same layout."
///
/// One widget rather than two, because §11.13 says so in as many words: the Add
/// and Edit screens are the same screen in different modes, and building them
/// separately means re-opening both to add a panel and two actions.
class IdeaFormScreen extends ConsumerStatefulWidget {
  /// §5.3, Add mode. HOME-3 focuses the name field.
  const IdeaFormScreen.add({super.key}) : ideaId = null;

  /// §5.3, Edit mode, for the Idea [ideaId].
  const IdeaFormScreen.edit({required String this.ideaId, super.key});

  /// The Idea being edited, or `null` in Add mode.
  final String? ideaId;

  /// Whether this is Edit mode.
  bool get isEdit => ideaId != null;

  @override
  ConsumerState<IdeaFormScreen> createState() => _IdeaFormScreenState();
}

class _IdeaFormScreenState extends ConsumerState<IdeaFormScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _contextText = TextEditingController();
  List<Tag> _tags = const <Tag>[];
  Timeframe? _timeframe;
  Idea? _loaded;
  bool _dirty = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _contextText.dispose();
    super.dispose();
  }

  /// §3.2. The Add screen's timeframe defaults to
  /// `settings.defaultIdeaTimeframe`.
  Timeframe get _currentTimeframe =>
      _timeframe ??
      _loaded?.timeframe ??
      ref.read(currentSettingsProvider).defaultIdeaTimeframe;

  /// Fills the form from [idea] the first time Edit mode resolves it.
  ///
  /// Guarded by the id so that a later emission of the stream — another
  /// device's edit arriving, or this screen's own save — does not overwrite
  /// what the user is typing (IDEAFORM-3: saving is explicit).
  void _adopt(Idea idea) {
    if (_loaded != null) {
      return;
    }
    _loaded = idea;
    _name.text = idea.name.value;
    _contextText.text = idea.context.value;
    _tags = idea.tags;
    _timeframe = idea.timeframe;
  }

  /// NAME-6, NAME-8. The names this Idea must not collide with.
  ///
  /// Read from the live list rather than the database so the Save button reacts
  /// as the user types. The guarantee is still the unique index (§11.5.2); this
  /// only produces the message.
  Set<String> _otherNames(List<Idea> ideas) => <String>{
    for (final Idea idea in ideas)
      if (idea.id != _loaded?.id) idea.name.normalized,
  };

  /// IDEAFORM-2. The violation blocking Save, or `null`.
  RuleViolation? _nameViolation(List<Idea> ideas, String raw) {
    final Result<ItemName, RuleViolation> parsed = ItemName.parse(raw);
    return switch (parsed) {
      Err<ItemName, RuleViolation>(:final RuleViolation error) => error,
      Ok<ItemName, RuleViolation>(:final ItemName value) =>
        _otherNames(ideas).contains(value.normalized)
            ? const IdeaNameCollision()
            : null,
    };
  }

  Future<void> _save() async {
    final Result<ItemName, RuleViolation> name = ItemName.parse(_name.text);
    final Result<ItemText, RuleViolation> text = ItemText.parseContext(
      _contextText.text,
    );
    if (name case Err<ItemName, RuleViolation>(:final RuleViolation error)) {
      await showViolation(context, error);
      return;
    }
    if (text case Err<ItemText, RuleViolation>(:final RuleViolation error)) {
      await showViolation(context, error);
      return;
    }

    setState(() => _saving = true);
    final IdeaActions actions = ref.read(ideaActionsProvider);
    final Idea? existing = _loaded;
    final Result<Idea, RuleViolation> saved = existing == null
        ? await actions.create(
            name: name.unwrap(),
            timeframe: _currentTimeframe,
            tags: _tags,
            context: text.unwrap(),
          )
        : await actions.save(
            existing,
            name: name.unwrap(),
            timeframe: _currentTimeframe,
            tags: _tags,
            context: text.unwrap(),
          );
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);

    switch (saved) {
      // §11.5.5. "Capture screens report the failure and keep the user's typed
      // text on screen; they never discard input because a write failed."
      case Err<Idea, RuleViolation>(:final RuleViolation error):
        await showViolation(context, error);
      // IDEAFORM-4, IDEAFORM-5. Both modes return to the Ideas tab.
      case Ok<Idea, RuleViolation>(:final Idea value):
        _dirty = false;
        if (mounted) {
          context.go(Routes.reviewTab(ReviewTab.ideas, highlight: value.id));
        }
    }
  }

  Future<void> _delete(Idea idea) async {
    final bool go = await confirmDelete(
      context,
      kind: ItemKind.idea,
      confirmDestructive: ref.read(currentSettingsProvider).confirmDestructive,
    );
    if (!go || !mounted) {
      return;
    }
    await ref.read(ideaActionsProvider).delete(idea);
    _dirty = false;
    if (mounted) {
      context.go(Routes.reviewTab(ReviewTab.ideas));
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Idea> ideas = ref.watch(ideasProvider).value ?? const <Idea>[];
    if (widget.isEdit) {
      final Idea? found = ideas
          .where((Idea idea) => idea.id == widget.ideaId)
          .firstOrNull;
      if (found == null) {
        // DEL-3 removes an Idea outright rather than flagging it (INV-7), so a
        // route to one that is gone can only be stale — after a conversion, a
        // delete, or a merge that applied a peer's tombstone.
        return const _MissingIdea();
      }
      _adopt(found);
    }

    final RuleViolation? violation = _nameViolation(ideas, _name.text);
    final Idea? loaded = _loaded;

    return PopScope<Object?>(
      // NAV-1. Unsaved changes ask before leaving.
      canPop: !_dirty,
      onPopInvokedWithResult: (bool didPop, Object? _) async {
        if (didPop || !_dirty) {
          return;
        }
        final bool discard = await confirmDiscard(context);
        if (discard && context.mounted) {
          _dirty = false;
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.isEdit ? 'Edit Idea' : 'Add Idea')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              // IDEAFORM-1. Name, Timeframe, Tags, Context, top to bottom.
              NameField(
                controller: _name,
                validate: (String raw) => _nameViolation(ideas, raw),
                autofocus: !widget.isEdit,
                onChanged: () => setState(() => _dirty = true),
                onSubmit: violation == null ? _save : null,
                collisionAction: violation is IdeaNameCollision
                    ? TextButton(
                        onPressed: () => _openColliding(ideas),
                        child: const Text('Open it'),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              TimeframePicker(
                value: _currentTimeframe,
                onChanged: (Timeframe next) => setState(() {
                  _timeframe = next;
                  _dirty = true;
                }),
              ),
              const SizedBox(height: 16),
              TagInput(
                tags: _tags,
                onChanged: (List<Tag> next) => setState(() {
                  _tags = next;
                  _dirty = true;
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _contextText,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Context',
                  alignLabelWithHint: true,
                ),
                onChanged: (String _) => setState(() => _dirty = true),
              ),
              const SizedBox(height: 24),
              // IDEAFORM-2. Disabled while the name is invalid.
              FilledButton(
                onPressed: violation == null && !_saving ? _save : null,
                child: Text(widget.isEdit ? 'Save' : 'Add Idea'),
              ),
              if (loaded != null) ...<Widget>[
                const SizedBox(height: 8),
                // IDEAFORM-5, CONVERT-0. The second entry point to conversion.
                OutlinedButton(
                  onPressed: () => context.push(Routes.convertIdea(loaded.id)),
                  child: const Text('Create Task'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _delete(loaded),
                  child: const Text('Delete'),
                ),
                const SizedBox(height: 16),
                // IDEAFORM-6.
                AdvancedDetails(
                  rows: <DetailRow>[
                    DetailRow('id', loaded.id, copyable: true),
                    DetailRow.instant('createdAt', loaded.createdAt),
                    DetailRow.instant('updatedAt', loaded.updatedAt),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// NAME-8. "The message SHOULD offer an `"Open it"` link that navigates to
  /// the colliding Item's Edit screen."
  void _openColliding(List<Idea> ideas) {
    final String? normalized = ItemName.parse(_name.text)
        .valueOrNull
        ?.normalized;
    final Idea? other = ideas
        .where((Idea idea) => idea.name.normalized == normalized)
        .firstOrNull;
    if (other != null) {
      _dirty = false;
      context.pushReplacement(Routes.editIdea(other.id));
    }
  }
}

/// IDEAFORM-1, SET-1. "Timeframe (segmented control: Now / Soon / Later /
/// Distant)", shared with the Settings screen's picker.
class TimeframePicker extends StatelessWidget {
  /// A segmented control over the four timeframes.
  const TimeframePicker({
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// The selected timeframe.
  final Timeframe value;

  /// Called with the new selection.
  final ValueChanged<Timeframe> onChanged;

  /// §3.2. The four, in urgency order, with their user-facing labels.
  static const Map<Timeframe, String> labels = <Timeframe, String>{
    Timeframe.now: 'Now',
    Timeframe.soon: 'Soon',
    Timeframe.later: 'Later',
    Timeframe.distant: 'Distant',
  };

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: SegmentedButton<Timeframe>(
      segments: <ButtonSegment<Timeframe>>[
        for (final MapEntry<Timeframe, String> entry in labels.entries)
          ButtonSegment<Timeframe>(value: entry.key, label: Text(entry.value)),
      ],
      selected: <Timeframe>{value},
      showSelectedIcon: false,
      onSelectionChanged: (Set<Timeframe> next) => onChanged(next.single),
    ),
  );
}

class _MissingIdea extends StatelessWidget {
  const _MissingIdea();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Edit Idea')),
    body: const Center(child: Text('This idea no longer exists.')),
  );
}
