import 'package:flutter/material.dart';
import 'rich_text_controller.dart';
import 'formatting_toolbar.dart';
import '../models/text_span_data.dart';

/// Champ de texte enrichi avec formatage en temps réel et gestion améliorée de la sélection
class RichTextField extends StatefulWidget {
  final RichTextEditingController controller;
  final FocusNode? focusNode;
  final TextStyle? baseStyle;
  final String? placeholder;
  final Color? cursorColor;
  final ValueChanged<String>? onChanged;

  const RichTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.baseStyle,
    this.placeholder,
    this.cursorColor,
    this.onChanged,
  });

  @override
  State<RichTextField> createState() => _RichTextFieldState();
}

class _RichTextFieldState extends State<RichTextField> {
  late FocusNode _focusNode;
  bool _showToolbar = false;
  OverlayEntry? _toolbarOverlay;
  final LayerLink _layerLink = LayerLink();

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _removeToolbar();
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onControllerChanged() {
    final selection = widget.controller.selection;
    final hasSelection = selection.isValid && !selection.isCollapsed;
    
    if (hasSelection && !_showToolbar) {
      _showFormattingToolbar();
    } else if (!hasSelection && _showToolbar) {
      _removeToolbar();
    }
  }

  void _showFormattingToolbar() {
    _removeToolbar();
    _showToolbar = true;

    _toolbarOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: 100,
        left: 0,
        right: 0,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: FormattingToolbar(
              onBold: () {
                widget.controller.toggleBold();
                _updateOverlay();
              },
              onItalic: () {
                widget.controller.toggleItalic();
                _updateOverlay();
              },
              onQuote: () {
                widget.controller.toggleQuote();
                _updateOverlay();
              },
              onTextColor: (color) {
                widget.controller.setTextColor(color);
                _updateOverlay();
              },
              onBackgroundColor: (color) {
                widget.controller.setBackgroundColor(color);
                _updateOverlay();
              },
              isBoldActive: _isBoldActive(),
              isItalicActive: _isItalicActive(),
              isQuoteActive: _isQuoteActive(),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_toolbarOverlay!);
  }

  void _updateOverlay() {
    _toolbarOverlay?.markNeedsBuild();
  }

  void _removeToolbar() {
    _toolbarOverlay?.remove();
    _toolbarOverlay = null;
    _showToolbar = false;
  }

  bool _isBoldActive() {
    final spans = widget.controller.spans;
    final sel = widget.controller.selection;
    if (!sel.isValid || sel.isCollapsed || spans.isEmpty) return false;
    
    int pos = 0;
    for (final span in spans) {
      final spanEnd = pos + span.text.length;
      if (pos < sel.end && spanEnd > sel.start) {
        if (!span.isBold) return false;
      }
      pos = spanEnd;
    }
    return true;
  }

  bool _isItalicActive() {
    final spans = widget.controller.spans;
    final sel = widget.controller.selection;
    if (!sel.isValid || sel.isCollapsed || spans.isEmpty) return false;
    
    int pos = 0;
    for (final span in spans) {
      final spanEnd = pos + span.text.length;
      if (pos < sel.end && spanEnd > sel.start) {
        if (!span.isItalic) return false;
      }
      pos = spanEnd;
    }
    return true;
  }

  bool _isQuoteActive() {
    final spans = widget.controller.spans;
    final sel = widget.controller.selection;
    if (!sel.isValid || sel.isCollapsed || spans.isEmpty) return false;
    
    int pos = 0;
    for (final span in spans) {
      final spanEnd = pos + span.text.length;
      if (pos < sel.end && spanEnd > sel.start) {
        if (!span.isQuote) return false;
      }
      pos = spanEnd;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = widget.baseStyle ?? const TextStyle(fontSize: 16);

    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        style: baseStyle,
        cursorColor: widget.cursorColor,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        // Amélioration : désactiver l'autocorrection agressive qui peut causer des problèmes de sélection
        autocorrect: false,
        enableSuggestions: true,
        // Amélioration : permettre une sélection plus précise
        enableInteractiveSelection: true,
        // Amélioration : configuration du clavier pour une meilleure expérience
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          hintText: (widget.controller.text.isEmpty) ? widget.placeholder : null,
          hintStyle: baseStyle.copyWith(
            color: baseStyle.color?.withValues(alpha: 0.3),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 20),
          isDense: false,
          filled: false,
        ),
        onChanged: (value) {
          widget.onChanged?.call(value);
        },
        // Amélioration : gestion des gestes pour une meilleure sélection
        onTap: () {
          // Forcer le focus pour s'assurer que la sélection fonctionne correctement
          if (!_focusNode.hasFocus) {
            _focusNode.requestFocus();
          }
        },
      ),
    );
  }
}
