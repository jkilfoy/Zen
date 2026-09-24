/// §11.7. The Idea commands the screens invoke.
///
/// Each method reads what a rule in `zen_domain` needs, calls it, and persists
/// what it returns. No decision is taken here: every refusal is a
/// [RuleViolation] a rule produced.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zen_domain/zen_domain.dart';

import 'app_providers.dart';

/// §11.7. The Idea half of the composition root's command surface.
final class IdeaActions {
  /// Wraps the repository, the clock and the id generator the rules need.
  const IdeaActions({
    required IdeaRepository ideas,
    required Clock clock,
    required IdGenerator ids,
    // A named parameter may not begin with an underscore, so
    // `prefer_initializing_formals` is not available here or below.
    // ignore: prefer_initializing_formals
  }) : _ideas = ideas,
       // ignore: prefer_initializing_formals
       _clock = clock,
       // ignore: prefer_initializing_formals
       _ids = ids;

  final IdeaRepository _ideas;
  final Clock _clock;
  final IdGenerator _ids;

  /// CREATE-1, CREATE-3, CREATE-4, IDEAFORM-2.
  Future<Result<Idea, RuleViolation>> create({
    required ItemName name,
    required Timeframe timeframe,
    required List<Tag> tags,
    required ItemText context,
  }) async {
    final Result<Idea, RuleViolation> drafted = createIdea(
      name: name,
      timeframe: timeframe,
      now: _clock.nowUtc(),
      ids: _ids,
      tags: tags,
      context: context,
      activeIdeaNormalizedNames: await _ideas.activeNormalizedNames(),
    );
    return switch (drafted) {
      Err<Idea, RuleViolation>() => drafted,
      Ok<Idea, RuleViolation>(:final Idea value) => _ideas.create(value),
    };
  }

  /// IDEAFORM-2, IDEAFORM-3, NAME-8. Saves an edit.
  Future<Result<Idea, RuleViolation>> save(
    Idea idea, {
    required ItemName name,
    required Timeframe timeframe,
    required List<Tag> tags,
    required ItemText context,
  }) async {
    final Result<Idea, RuleViolation> edited = updateIdea(
      idea,
      now: _clock.nowUtc(),
      name: name,
      timeframe: timeframe,
      tags: tags,
      context: context,
      activeIdeaNormalizedNames: await _ideas.activeNormalizedNames(),
    );
    return switch (edited) {
      Err<Idea, RuleViolation>() => edited,
      Ok<Idea, RuleViolation>(:final Idea value) => _ideas.update(value),
    };
  }

  /// DEL-3, IDEAFORM-5. Removes the Idea and writes its tombstone.
  Future<void> delete(Idea idea) => _ideas.delete(idea.id, _clock.nowUtc());

  /// NAME-8's `"Open it"` link: the active Idea holding [name], if any.
  Future<Idea?> findColliding(ItemName name) =>
      _ideas.findActiveByNormalizedName(name.normalized);
}

/// §11.7. The Idea commands, wired to the repositories.
final Provider<IdeaActions> ideaActionsProvider = Provider<IdeaActions>(
  (Ref ref) => IdeaActions(
    ideas: ref.watch(ideaRepositoryProvider),
    clock: ref.watch(clockProvider),
    ids: ref.watch(idGeneratorProvider),
  ),
);
