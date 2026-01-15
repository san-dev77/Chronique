import 'dart:convert';
import 'package:flutter/material.dart';

/// Représente un segment de texte avec son style
class TextSpanData {
  final String text;
  final bool isBold;
  final bool isItalic;
  final Color? textColor;
  final Color? backgroundColor;
  final bool isQuote;

  const TextSpanData({
    required this.text,
    this.isBold = false,
    this.isItalic = false,
    this.textColor,
    this.backgroundColor,
    this.isQuote = false,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        if (isBold) 'bold': true,
        if (isItalic) 'italic': true,
        if (textColor != null) 'color': textColor!.value,
        if (backgroundColor != null) 'bgColor': backgroundColor!.value,
        if (isQuote) 'quote': true,
      };

  factory TextSpanData.fromJson(Map<String, dynamic> json) => TextSpanData(
        text: json['text'] ?? '',
        isBold: json['bold'] ?? false,
        isItalic: json['italic'] ?? false,
        textColor: json['color'] != null ? Color(json['color']) : null,
        backgroundColor: json['bgColor'] != null ? Color(json['bgColor']) : null,
        isQuote: json['quote'] ?? false,
      );

  TextSpanData copyWith({
    String? text,
    bool? isBold,
    bool? isItalic,
    Color? textColor,
    Color? backgroundColor,
    bool? isQuote,
    bool clearTextColor = false,
    bool clearBgColor = false,
  }) =>
      TextSpanData(
        text: text ?? this.text,
        isBold: isBold ?? this.isBold,
        isItalic: isItalic ?? this.isItalic,
        textColor: clearTextColor ? null : (textColor ?? this.textColor),
        backgroundColor: clearBgColor ? null : (backgroundColor ?? this.backgroundColor),
        isQuote: isQuote ?? this.isQuote,
      );

  bool get hasStyle => isBold || isItalic || textColor != null || backgroundColor != null || isQuote;

  bool hasSameStyleAs(TextSpanData other) {
    return isBold == other.isBold &&
        isItalic == other.isItalic &&
        textColor?.value == other.textColor?.value &&
        backgroundColor?.value == other.backgroundColor?.value &&
        isQuote == other.isQuote;
  }
}

/// Contenu formaté d'une note
class FormattedContent {
  final List<TextSpanData> spans;

  const FormattedContent({this.spans = const []});

  String toJsonString() => jsonEncode({'spans': spans.map((s) => s.toJson()).toList()});

  factory FormattedContent.fromJsonString(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return const FormattedContent();
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final spanList = (map['spans'] as List<dynamic>?)
              ?.map((s) => TextSpanData.fromJson(Map<String, dynamic>.from(s)))
              .toList() ??
          [];
      return FormattedContent(spans: spanList);
    } catch (_) {
      return const FormattedContent();
    }
  }

  /// Crée un FormattedContent à partir de texte brut
  factory FormattedContent.fromPlainText(String text) {
    if (text.isEmpty) return const FormattedContent();
    return FormattedContent(spans: [TextSpanData(text: text)]);
  }

  /// Retourne le texte brut sans formatage
  String toPlainText() => spans.map((s) => s.text).join();

  bool get isEmpty => spans.isEmpty || toPlainText().isEmpty;
}
