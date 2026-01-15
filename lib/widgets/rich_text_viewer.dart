import 'dart:async';
import 'package:flutter/material.dart';
import '../models/text_span_data.dart';

/// Un widget capable d'afficher du texte riche (spans) 
/// avec un effet machine à écrire (typewriter).
class RichTextViewer extends StatefulWidget {
  final String content;
  final String? formattedContent;
  final TextStyle baseStyle;
  final Duration speed;
  final Duration startDelay;
  final bool skip;
  final VoidCallback? onComplete;

  const RichTextViewer({
    super.key,
    required this.content,
    this.formattedContent,
    required this.baseStyle,
    this.speed = const Duration(milliseconds: 25),
    this.startDelay = Duration.zero,
    this.skip = false,
    this.onComplete,
  });

  @override
  State<RichTextViewer> createState() => _RichTextViewerState();
}

class _RichTextViewerState extends State<RichTextViewer> with TickerProviderStateMixin {
  late List<TextSpanData> _fullSpans;
  List<TextSpanData> _displayedSpans = [];
  int _totalChars = 0;
  int _currentChars = 0;
  Timer? _timer;
  late AnimationController _cursorController;

  @override
  void initState() {
    super.initState();
    _initSpans();
    
    _cursorController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);

    if (widget.skip) {
      _currentChars = _totalChars;
      _updateDisplayedSpans();
    } else {
      if (widget.startDelay == Duration.zero) {
        _startTyping();
      } else {
        Future.delayed(widget.startDelay, () {
          if (mounted) _startTyping();
        });
      }
    }
  }

  void _initSpans() {
    if (widget.formattedContent != null && widget.formattedContent!.isNotEmpty) {
      try {
        final formatted = FormattedContent.fromJsonString(widget.formattedContent!);
        _fullSpans = formatted.spans;
      } catch (e) {
        _fullSpans = [TextSpanData(text: widget.content)];
      }
    } else {
      _fullSpans = [TextSpanData(text: widget.content)];
    }
    
    _totalChars = _fullSpans.fold(0, (sum, span) => sum + span.text.length);
  }

  void _startTyping() {
    _timer = Timer.periodic(widget.speed, (timer) {
      if (_currentChars < _totalChars) {
        if (mounted) {
          setState(() {
            _currentChars++;
            _updateDisplayedSpans();
          });
        }
      } else {
        timer.cancel();
        if (mounted) widget.onComplete?.call();
      }
    });
  }

  void _updateDisplayedSpans() {
    _displayedSpans = [];
    int remaining = _currentChars;

    for (var span in _fullSpans) {
      if (remaining <= 0) break;

      if (remaining >= span.text.length) {
        _displayedSpans.add(span);
        remaining -= span.text.length;
      } else {
        _displayedSpans.add(span.copyWith(text: span.text.substring(0, remaining)));
        remaining = 0;
      }
    }
  }

  @override
  void didUpdateWidget(RichTextViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.skip && !oldWidget.skip) {
      _timer?.cancel();
      setState(() {
        _currentChars = _totalChars;
        _updateDisplayedSpans();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onComplete?.call();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<InlineSpan> children = [];

    for (var span in _fullSpans) {
      // Calculer si ce span est déjà "découvert" par le typewriter
      int currentTotalSoFar = 0;
      int spanIndex = _fullSpans.indexOf(span);
      for (int i = 0; i < spanIndex; i++) {
        currentTotalSoFar += _fullSpans[i].text.length;
      }

      if (_currentChars <= currentTotalSoFar) break;

      int charsToTake = (_currentChars - currentTotalSoFar).clamp(0, span.text.length);
      String visibleText = span.text.substring(0, charsToTake);

      children.add(TextSpan(
        text: visibleText,
        style: widget.baseStyle.copyWith(
          fontWeight: span.isBold ? FontWeight.bold : null,
          fontStyle: span.isItalic ? FontStyle.italic : null,
          color: span.textColor,
          backgroundColor: span.isQuote 
              ? (span.backgroundColor ?? Colors.grey.withAlpha(25))
              : span.backgroundColor,
          decoration: span.isQuote ? TextDecoration.underline : null,
        ),
      ));
    }

    // Curseur à la fin du texte affiché
    if (_currentChars < _totalChars) {
      children.add(WidgetSpan(
        child: AnimatedBuilder(
          animation: _cursorController,
          builder: (context, child) => Opacity(
            opacity: _cursorController.value,
            child: Container(
              width: 2,
              height: (widget.baseStyle.fontSize ?? 16) * 1.2,
              color: Colors.blue,
            ),
          ),
        ),
      ));
    }

    return RichText(
      text: TextSpan(children: children, style: widget.baseStyle),
    );
  }
}
