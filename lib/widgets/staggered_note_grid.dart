import 'package:flutter/material.dart';
import '../models/note.dart';
import 'note_card.dart';

class StaggeredNoteGrid extends StatefulWidget {
  final List<Note> notes;
  final Function(Note) onTap;
  final Function(Note)? onFavoriteToggle;
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double childAspectRatio;

  const StaggeredNoteGrid({
    super.key,
    required this.notes,
    required this.onTap,
    this.onFavoriteToggle,
    this.crossAxisCount = 2,
    this.crossAxisSpacing = 16,
    this.mainAxisSpacing = 16,
    this.childAspectRatio = 0.8,
  });

  @override
  State<StaggeredNoteGrid> createState() => _StaggeredNoteGridState();
}

class _StaggeredNoteGridState extends State<StaggeredNoteGrid>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _fadeAnimations;
  late List<Animation<Offset>> _slideAnimations;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _controllers = List.generate(
      widget.notes.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      ),
    );

    _fadeAnimations = _controllers.map((controller) {
      return Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOut,
      ));
    }).toList();

    _slideAnimations = _controllers.map((controller) {
      return Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      ));
    }).toList();

    // Démarrer les animations en cascade
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 100), () {
        if (mounted && i < _controllers.length) {
          _controllers[i].forward();
        }
      });
    }
  }

  @override
  void didUpdateWidget(StaggeredNoteGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notes.length != widget.notes.length) {
      // Nettoyer les anciens contrôleurs
      for (var controller in _controllers) {
        controller.dispose();
      }
      // Réinitialiser les animations
      _initializeAnimations();
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.crossAxisCount,
        crossAxisSpacing: widget.crossAxisSpacing,
        mainAxisSpacing: widget.mainAxisSpacing,
        childAspectRatio: widget.childAspectRatio,
      ),
      itemCount: widget.notes.length,
      itemBuilder: (context, index) {
        final note = widget.notes[index];
        if (index >= _controllers.length) return const SizedBox.shrink();

        return AnimatedBuilder(
          animation: _controllers[index],
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimations[index],
              child: SlideTransition(
                position: _slideAnimations[index],
                child: NoteCard(
                  note: note,
                  onTap: () => widget.onTap(note),
                  onFavoriteToggle: widget.onFavoriteToggle != null
                      ? () => widget.onFavoriteToggle!(note)
                      : null,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
