/// §3.5, IDEAFORM-1, TASKFORM-1. The chip input for an item's tags.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zen_domain/zen_domain.dart';

import '../providers/app_providers.dart';

/// §3.5. A chip input: the current tags as removable chips, plus a field that
/// turns typed text into another one.
///
/// TAG-1 strips a leading `@`, TAG-2 forbids whitespace, TAG-3 caps the length
/// and TAG-4 makes a duplicate a no-op — all of which are [Tag.parse]'s and
/// `dedupeTags`', not this widget's. A refusal that [RuleViolation.hasMessage]
/// calls silent (an empty tag) simply adds no chip, which is what D-M1-4
/// chose.
///
/// TAG-6: the suggestions come from [activeTagsProvider].
class TagInput extends ConsumerStatefulWidget {
  /// Edits [tags], reporting every change through [onChanged].
  const TagInput({required this.tags, required this.onChanged, super.key});

  /// The tags as they currently stand.
  final List<Tag> tags;

  /// Called with the new list whenever a tag is added or removed.
  final ValueChanged<List<Tag>> onChanged;

  @override
  ConsumerState<TagInput> createState() => _TagInputState();
}

class _TagInputState extends ConsumerState<TagInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _commit(String raw) {
    if (raw.trim().isEmpty) {
      return;
    }
    final Result<Tag, RuleViolation> parsed = Tag.parse(raw);
    switch (parsed) {
      case Err<Tag, RuleViolation>(:final RuleViolation error):
        setState(() => _error = error.hasMessage ? error.message : null);
      case Ok<Tag, RuleViolation>(:final Tag value):
        setState(() => _error = null);
        _controller.clear();
        // TAG-4. `dedupeTags` makes re-adding an existing tag a no-op.
        widget.onChanged(dedupeTags(<Tag>[...widget.tags, value]));
    }
  }

  void _remove(Tag tag) =>
      widget.onChanged(widget.tags.where((Tag other) => other != tag).toList());

  @override
  Widget build(BuildContext context) {
    final List<Tag> suggestions = ref
        .watch(activeTagsProvider)
        .where((Tag tag) => !widget.tags.contains(tag))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (widget.tags.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: <Widget>[
              for (final Tag tag in widget.tags)
                InputChip(
                  label: Text(tag.display),
                  onDeleted: () => _remove(tag),
                  deleteButtonTooltipMessage: 'Remove ${tag.display}',
                ),
            ],
          ),
        // TAG-6. `RawAutocomplete` over the field, so the suggestions appear
        // without replacing the field's own behaviour.
        RawAutocomplete<Tag>(
          textEditingController: _controller,
          focusNode: _focusNode,
          optionsBuilder: (TextEditingValue value) {
            final String typed = normalizeTag(value.text.trim());
            if (typed.isEmpty) {
              return const Iterable<Tag>.empty();
            }
            return suggestions.where(
              (Tag tag) => tag.normalized.startsWith(typed),
            );
          },
          displayStringForOption: (Tag tag) => tag.value,
          onSelected: (Tag tag) => _commit(tag.value),
          fieldViewBuilder:
              (
                BuildContext context,
                TextEditingController controller,
                FocusNode node,
                VoidCallback onSubmit,
              ) => TextField(
                controller: controller,
                focusNode: node,
                decoration: InputDecoration(
                  labelText: 'Tags',
                  hintText: 'Type a tag and press Enter',
                  errorText: _error,
                  prefixText: '@',
                ),
                onSubmitted: _commit,
              ),
          optionsViewBuilder:
              (
                BuildContext context,
                void Function(Tag) onSelected,
                Iterable<Tag> options,
              ) => Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView(
                      shrinkWrap: true,
                      children: <Widget>[
                        for (final Tag tag in options)
                          ListTile(
                            dense: true,
                            title: Text(tag.display),
                            onTap: () => onSelected(tag),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
        ),
      ],
    );
  }
}
