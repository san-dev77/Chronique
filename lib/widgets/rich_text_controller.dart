import 'package:flutter/material.dart';
import '../models/text_span_data.dart';

/// Controller pour gérer le texte formaté
class RichTextEditingController extends TextEditingController {
  List<TextSpanData> _spans = [];
  
  RichTextEditingController({String? text}) : super(text: text) {
    if (text != null && text.isNotEmpty) {
      _spans = [TextSpanData(text: text)];
    }
  }

  /// Initialise depuis un FormattedContent
  void setFormattedContent(FormattedContent content) {
    _spans = List.from(content.spans);
    text = content.toPlainText();
  }

  /// Récupère le contenu formaté
  FormattedContent getFormattedContent() {
    return FormattedContent(spans: List.from(_spans));
  }

  @override
  set value(TextEditingValue newValue) {
    if (newValue.text != super.value.text) {
      _rebuildSpans(super.value, newValue);
    }
    super.value = newValue;
  }

  void _rebuildSpans(TextEditingValue oldValue, TextEditingValue newValue) {
    if (_spans.isEmpty) {
      _spans = [TextSpanData(text: newValue.text)];
      return;
    }

    final oldText = oldValue.text;
    final newText = newValue.text;
    final oldSel = oldValue.selection;

    if (oldText == newText) return;

    if (newText.isEmpty) {
      _spans = [];
      return;
    }

    if (!oldSel.isValid) {
      _spans = [TextSpanData(text: newText)];
      return;
    }

    // Calculer la zone modifiée
    int start;
    int end;
    String insertion;

    if (!oldSel.isCollapsed) {
      // Remplacement d'une sélection
      start = oldSel.start;
      end = oldSel.end;
      // L'insertion est ce qui se trouve entre start et (start + diff_after_replacement)
      int newEnd = newValue.selection.end;
      int diff = newText.length - (oldText.length - (end - start));
      insertion = newText.substring(start, start + diff.clamp(0, newText.length - start));
    } else {
      // Ajout ou Suppression au curseur
      int diff = newText.length - oldText.length;
      if (diff > 0) {
        // Ajout
        start = newValue.selection.start - diff;
        end = start;
        insertion = newText.substring(start.clamp(0, newText.length), (start + diff).clamp(0, newText.length));
      } else {
        // Suppression (backspace ou delete)
        start = newValue.selection.start;
        end = start - diff; // end est après start
        insertion = "";
      }
    }

    _applyChangeToSpans(start, end, insertion);
  }

  void _applyChangeToSpans(int start, int end, String insertion) {
    List<TextSpanData> newSpans = [];
    int currentPos = 0;

    for (var span in _spans) {
      int spanEnd = currentPos + span.text.length;

      if (spanEnd <= start) {
        // Avant la zone modifiée
        newSpans.add(span);
      } else if (currentPos >= end) {
        // Après la zone modifiée
        newSpans.add(span);
      } else {
        // Le span intersecte la zone modifiée
        String beforeStr = "";
        String afterStr = "";

        if (currentPos < start) {
          beforeStr = span.text.substring(0, start - currentPos);
        }
        if (spanEnd > end) {
          afterStr = span.text.substring(end - currentPos);
        }

        // Si on est dans le span où l'insertion doit se faire
        // On fusionne l'insertion dans ce span pour garder le style
        if (currentPos <= start && spanEnd >= start) {
          newSpans.add(span.copyWith(text: beforeStr + insertion + afterStr));
          insertion = ""; // On a consommé l'insertion
        } else {
          // On réduit simplement le span si une partie est supprimée
          if (beforeStr.isNotEmpty || afterStr.isNotEmpty) {
            newSpans.add(span.copyWith(text: beforeStr + afterStr));
          }
        }
      }
      currentPos = spanEnd;
    }

    // Si l'insertion n'a pas été placée (ex: ajout à la fin ou texte vide au début)
    if (insertion.isNotEmpty) {
      if (newSpans.isNotEmpty) {
        newSpans.last = newSpans.last.copyWith(text: newSpans.last.text + insertion);
      } else {
        newSpans.add(TextSpanData(text: insertion));
      }
    }

    // Nettoyer les spans vides et normaliser
    _normalizeSpans(newSpans);
    
    if (_spans.isEmpty && text.isNotEmpty) {
      _spans = [TextSpanData(text: text)];
    }
  }

  void _normalizeSpans(List<TextSpanData> source) {
    if (source.isEmpty) {
      _spans = [];
      return;
    }

    List<TextSpanData> normalized = [];
    TextSpanData? current;

    for (var span in source) {
      if (span.text.isEmpty) continue;

      if (current == null) {
        current = span;
      } else if (current.hasSameStyleAs(span)) {
        current = current.copyWith(text: current.text + span.text);
      } else {
        normalized.add(current);
        current = span;
      }
    }

    if (current != null) {
      normalized.add(current);
    }

    _spans = normalized;
  }

  /// Applique un style à la sélection courante
  void applyStyle({
    bool? bold,
    bool? italic,
    Color? textColor,
    Color? backgroundColor,
    bool? quote,
  }) {
    final sel = selection;
    if (!sel.isValid || sel.isCollapsed) return;
    
    final start = sel.start;
    final end = sel.end;
    
    // Trouver et découper les spans affectés
    List<TextSpanData> newSpans = [];
    int currentPos = 0;

    for (final span in _spans) {
      final spanEnd = currentPos + span.text.length;

      if (spanEnd <= start || currentPos >= end) {
        // Span non affecté
        newSpans.add(span);
      } else {
        // Span partiellement ou totalement affecté
        
        // Partie avant la sélection
        if (currentPos < start) {
          newSpans.add(span.copyWith(
            text: span.text.substring(0, start - currentPos),
          ));
        }

        // Partie sélectionnée (avec nouveau style)
        final selStart = (start - currentPos).clamp(0, span.text.length);
        final selEnd = (end - currentPos).clamp(0, span.text.length);
        
        if (selEnd > selStart) {
          newSpans.add(TextSpanData(
            text: span.text.substring(selStart, selEnd),
            isBold: bold ?? span.isBold,
            isItalic: italic ?? span.isItalic,
            textColor: textColor ?? span.textColor,
            backgroundColor: backgroundColor ?? span.backgroundColor,
            isQuote: quote ?? span.isQuote,
          ));
        }

        // Partie après la sélection
        if (spanEnd > end) {
          newSpans.add(span.copyWith(
            text: span.text.substring(end - currentPos),
          ));
        }
      }

      currentPos = spanEnd;
    }

    _normalizeSpans(newSpans);
    notifyListeners();
  }

  /// Toggle bold sur la sélection
  void toggleBold() {
    final sel = selection;
    if (!sel.isValid || sel.isCollapsed) return;
    
    final isBold = _isSelectionBold();
    applyStyle(bold: !isBold);
  }

  /// Toggle italic sur la sélection
  void toggleItalic() {
    final sel = selection;
    if (!sel.isValid || sel.isCollapsed) return;
    
    final isItalic = _isSelectionItalic();
    applyStyle(italic: !isItalic);
  }

  /// Toggle quote sur la sélection
  void toggleQuote() {
    final sel = selection;
    if (!sel.isValid || sel.isCollapsed) return;
    
    final isQuote = _isSelectionQuote();
    applyStyle(quote: !isQuote);
  }

  /// Définit la couleur du texte
  void setTextColor(Color color) {
    applyStyle(textColor: color);
  }

  /// Définit la couleur de fond
  void setBackgroundColor(Color color) {
    applyStyle(backgroundColor: color);
  }

  bool _isSelectionBold() => _getSpansInSelection().every((s) => s.isBold);
  bool _isSelectionItalic() => _getSpansInSelection().every((s) => s.isItalic);
  bool _isSelectionQuote() => _getSpansInSelection().every((s) => s.isQuote);

  List<TextSpanData> _getSpansInSelection() {
    final sel = selection;
    if (!sel.isValid || sel.isCollapsed) return [];

    List<TextSpanData> result = [];
    int currentPos = 0;

    for (final span in _spans) {
      final spanEnd = currentPos + span.text.length;
      if (currentPos < sel.end && spanEnd > sel.start) {
        result.add(span);
      }
      currentPos = spanEnd;
    }

    return result;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (_spans.isEmpty) {
      return TextSpan(text: text, style: style);
    }

    final List<TextSpan> children = [];
    final defaultStyle = style ?? const TextStyle();

    for (final span in _spans) {
      children.add(TextSpan(
        text: span.text,
        style: defaultStyle.copyWith(
          fontWeight: span.isBold ? FontWeight.bold : null,
          fontStyle: span.isItalic ? FontStyle.italic : null,
          color: span.textColor,
          backgroundColor: span.isQuote 
              ? (span.backgroundColor ?? Colors.grey.withOpacity(0.1))
              : span.backgroundColor,
          decoration: span.isQuote ? TextDecoration.underline : null,
          decorationStyle: TextDecorationStyle.solid,
          decorationColor: defaultStyle.color?.withOpacity(0.3),
        ),
      ));
    }

    return TextSpan(style: style, children: children);
  }

  List<TextSpanData> get spans => List.unmodifiable(_spans);
}
