/// §3.1, IDEAFORM-2, TASKFORM-3. The name field both forms share.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zen_domain/zen_domain.dart';

/// §3.1. The validated name field.
///
/// IDEAFORM-2: "It is disabled while the name is invalid" — so validity is
/// reported on every keystroke — but "messages appear once the user has typed
/// and then paused or blurred the field", so the *message* waits for
/// [messageDelay] of quiet or for a blur. The two are separate on purpose: a
/// button that flickers between enabled and disabled is honest, a message that
/// accuses the user mid-word is not. A field that opens with text in it already
/// shows its message; see `initState`.
///
/// NAME-4: "On the Add/Edit screens, pressing Enter in the name field submits
/// the form instead of inserting a newline." Both halves are here — the field
/// is single-line, and [onSubmit] fires on Enter.
class NameField extends StatefulWidget {
  /// A field editing [controller], validated by [validate].
  const NameField({
    required this.controller,
    required this.validate,
    required this.onChanged,
    this.onSubmit,
    this.collisionAction,
    this.readOnly = false,
    this.autofocus = false,
    super.key,
  });

  /// IDEAFORM-2. How long the user must pause before a message appears.
  static const Duration messageDelay = Duration(milliseconds: 600);

  /// The text being edited.
  final TextEditingController controller;

  /// Returns the violation for the current text, or `null` when it is valid.
  final RuleViolation? Function(String raw) validate;

  /// Called on every keystroke, so the form can re-evaluate its Save button.
  final VoidCallback onChanged;

  /// NAME-4. What Enter does.
  final VoidCallback? onSubmit;

  /// NAME-8. The `"Open it"` link, shown beside a collision message.
  final Widget? collisionAction;

  /// ARCH-3, SEARCH-3. Read-only screens still show the name.
  final bool readOnly;

  /// HOME-3. "the name field is focused and the on-screen keyboard is raised".
  final bool autofocus;

  @override
  State<NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<NameField> {
  final FocusNode _focusNode = FocusNode();
  Timer? _pause;
  late bool _showMessage;

  @override
  void initState() {
    super.initState();
    // IDEAFORM-2 delays the message until "the user has typed and then paused
    // or blurred the field", so that it does not accuse them mid-word. A name
    // the screen arrived with — Edit mode's stored name, or CONVERT-1's
    // pre-fill — has already settled, and NAME-8 wants its message shown. So
    // the delay applies only to a field that started empty.
    _showMessage = widget.controller.text.isNotEmpty;
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        setState(() => _showMessage = true);
      }
    });
  }

  @override
  void dispose() {
    _pause?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    _pause?.cancel();
    setState(() => _showMessage = false);
    _pause = Timer(
      NameField.messageDelay,
      () => setState(() => _showMessage = true),
    );
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final RuleViolation? violation = widget.validate(widget.controller.text);
    final bool show = _showMessage && violation != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          readOnly: widget.readOnly,
          // NAME-4. One line, so Enter cannot insert a break; the field still
          // wraps visually (IDEAFORM-1).
          maxLines: 1,
          textInputAction: TextInputAction.done,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.deny(RegExp(r'[\r\n]')),
          ],
          decoration: InputDecoration(
            labelText: 'Name',
            errorText: show ? violation.message : null,
          ),
          onChanged: _onChanged,
          onSubmitted: (String _) => widget.onSubmit?.call(),
        ),
        // NAME-8. "The message SHOULD offer an `"Open it"` link that navigates
        // to the colliding Item's Edit screen."
        if (show && widget.collisionAction != null)
          Align(alignment: Alignment.centerLeft, child: widget.collisionAction),
      ],
    );
  }
}
