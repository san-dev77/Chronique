import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/note.dart';
import '../models/note_mood.dart';
import '../theme/app_theme.dart';
import 'note_view_screen.dart';
import '../services/note_service.dart';

/// Stories plein écran — style Instagram.
/// Auto-avance, barres de progression segmentées, tap zones, aura + images.
class StoriesScreen extends StatefulWidget {
  final List<Note> notes;
  final String title;
  final Color accentColor;
  final int startIndex;

  const StoriesScreen({
    super.key,
    required this.notes,
    required this.title,
    this.accentColor = const Color(0xFF42A5F5),
    this.startIndex = 0,
  });

  @override
  State<StoriesScreen> createState() => _StoriesScreenState();
}

class _StoriesScreenState extends State<StoriesScreen>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late AnimationController _progressController;
  bool _isPaused = false;

  static const _storyDuration = Duration(seconds: 6);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.startIndex.clamp(0, widget.notes.length - 1);
    _progressController = AnimationController(
      vsync: this,
      duration: _storyDuration,
    );
    _progressController.addStatusListener(_onProgressDone);
    _startStory();

    // Plein écran immersif
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _progressController.removeStatusListener(_onProgressDone);
    _progressController.dispose();
    // Restaurer le mode normal (pas edgeToEdge qui décale la bottom nav)
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  void _onProgressDone(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _nextStory();
    }
  }

  void _startStory() {
    _progressController.reset();
    _progressController.forward();
  }

  void _nextStory() {
    if (_currentIndex < widget.notes.length - 1) {
      setState(() => _currentIndex++);
      _startStory();
    } else {
      Navigator.pop(context);
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _startStory();
    } else {
      _startStory(); // Restart current
    }
  }

  void _pause() {
    if (!_isPaused) {
      _progressController.stop();
      setState(() => _isPaused = true);
    }
  }

  void _resume() {
    if (_isPaused) {
      _progressController.forward();
      setState(() => _isPaused = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.notes[_currentIndex];
    final hasAura = NoteMood.hasGlow(note.mood);
    final auraColor = hasAura
        ? NoteMood.getEffectiveColor(note.mood, note.moodColor)
        : widget.accentColor;
    final hasImage =
        note.imagePaths.isNotEmpty && File(note.imagePaths.first).existsSync();
    final moodData = NoteMood.fromKey(note.mood);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        // Long press = pause
        onLongPressStart: (_) => _pause(),
        onLongPressEnd: (_) => _resume(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // === FOND : image ou gradient ===
            if (hasImage)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: Image.file(
                  File(note.imagePaths.first),
                  key: ValueKey(note.id),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              )
            else
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      auraColor.withOpacity(0.4),
                      Colors.black,
                      auraColor.withOpacity(0.2),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),

            // === OVERLAY GRADIENT (pour texte lisible) ===
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                  ],
                  stops: const [0.0, 0.25, 0.6, 1.0],
                ),
              ),
            ),

            // === AURA GLOW (si active) ===
            if (hasAura)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.2,
                        colors: [
                          auraColor.withOpacity(0.15),
                          auraColor.withOpacity(0.05),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
              ),

            // === CONTENU DE LA STORY ===
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Barres de progression
                    _buildProgressBars(auraColor),
                    const SizedBox(height: 16),

                    // En-tête : titre de la collection + compteur
                    _buildHeader(moodData, auraColor),

                    const Spacer(),

                    // Contenu de la note
                    _buildContent(note, moodData, auraColor),

                    const SizedBox(height: 24),

                    // Bouton pour lire la note complète
                    _buildReadButton(note, auraColor),
                  ],
                ),
              ),
            ),

            // === TAP ZONES (gauche/droite) ===
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    onTap: _previousStory,
                    behavior: HitTestBehavior.translucent,
                    child: const SizedBox.expand(),
                  ),
                ),
                Expanded(
                  flex: 7,
                  child: GestureDetector(
                    onTap: _nextStory,
                    behavior: HitTestBehavior.translucent,
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),

            // === PAUSE INDICATOR ===
            if (_isPaused)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.pause_rounded,
                      color: Colors.white, size: 40),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBars(Color accentColor) {
    return AnimatedBuilder(
      animation: _progressController,
      builder: (context, _) {
        return Row(
          children: List.generate(widget.notes.length, (i) {
            double progress;
            if (i < _currentIndex) {
              progress = 1.0;
            } else if (i == _currentIndex) {
              progress = _progressController.value;
            } else {
              progress = 0.0;
            }

            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                height: 2.5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: Colors.white.withOpacity(0.25),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: Colors.white.withOpacity(0.95),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withOpacity(0.6),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildHeader(dynamic moodData, Color accentColor) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [accentColor, accentColor.withOpacity(0.6)],
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.4),
                blurRadius: 8,
              ),
            ],
          ),
          child: Icon(Icons.auto_stories_rounded,
              size: 18, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${_currentIndex + 1}/${widget.notes.length}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        // Fermer
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close_rounded,
                color: Colors.white, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(Note note, dynamic moodData, Color accentColor) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOut,
      child: Column(
        key: ValueKey(note.id),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _formatDate(note.createdAt),
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Titre
          if (note.title.isNotEmpty)
            Text(
              note.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1.2,
                shadows: [
                  Shadow(
                    color: Colors.black45,
                    blurRadius: 8,
                  ),
                ],
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          if (note.title.isNotEmpty) const SizedBox(height: 10),

          // Séparateur lumineux
          Container(
            height: 2,
            width: 40,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.7),
              borderRadius: BorderRadius.circular(1),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.5),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Contenu (aperçu)
          if (note.content.isNotEmpty)
            Text(
              note.content,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 15,
                height: 1.7,
                shadows: const [
                  Shadow(color: Colors.black38, blurRadius: 6),
                ],
              ),
              maxLines: 6,
              overflow: TextOverflow.fade,
            ),

          // Badge aura
          if (moodData != null && NoteMood.hasGlow(note.mood)) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: accentColor.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(moodData.icon, size: 14, color: accentColor),
                  const SizedBox(width: 6),
                  Text(
                    moodData.label,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReadButton(Note note, Color accentColor) {
    return Center(
      child: GestureDetector(
        onTap: () {
          _pause();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NoteViewScreen(
                note: note,
                onEdit: () => Navigator.pop(context),
                onDelete: () {
                  NoteService.instance.deleteNote(note.id);
                  Navigator.pop(context);
                },
                onToggleFavorite: () {
                  note.isFavorite = !note.isFavorite;
                  NoteService.instance.saveNote(note);
                },
              ),
            ),
          ).then((_) => _resume());
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_stories_rounded,
                  size: 16, color: Colors.white.withOpacity(0.9)),
              const SizedBox(width: 8),
              Text(
                'Lire la chronique',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    const months = [
      '', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
    ];
    return '${days[date.weekday - 1]} ${date.day} ${months[date.month]} ${date.year}';
  }
}
