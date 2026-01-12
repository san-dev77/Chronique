import 'package:flutter/material.dart';
import '../models/shared_note.dart';
import '../services/sharing_service.dart';
import '../services/auth_service.dart';
import '../services/image_base64_service.dart';
import '../theme/app_theme.dart';
import '../utils/date_formatter.dart';
import 'shared_note_view_screen.dart';

/// Écran listant les notes partagées (reçues et envoyées)
class SharedNotesScreen extends StatefulWidget {
  const SharedNotesScreen({super.key});

  @override
  State<SharedNotesScreen> createState() => _SharedNotesScreenState();
}

class _SharedNotesScreenState extends State<SharedNotesScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late Stream<List<SharedNote>> _receivedNotesStream;
  late Stream<List<SharedNote>> _sentNotesStream;
  
  final Set<String> _selectedNoteIds = {};
  bool _isSelectionMode = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _receivedNotesStream = SharingService.instance.watchReceivedNotes();
    _sentNotesStream = SharingService.instance.watchSentNotes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppTheme.skyBlue;

    if (!AuthService.instance.isSignedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notes partagées')),
        body: _buildLoggedOutState(isDark),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSelectionMode ? '${_selectedNoteIds.length} sélectionnés' : 'Notes partagées',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        elevation: 0,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: _exitSelectionMode,
              )
            : null,
        actions: [
          if (_isSelectionMode)
            _isDeleting
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.only(right: 16),
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
                        onPressed: _selectedNoteIds.isEmpty ? null : _deleteSelectedNotes,
                        tooltip: 'Supprimer la selection',
                      ),
                    ),
                  ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          // CUSTOM PILL TAB SWITCHER
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: isDark ? Colors.white38 : Colors.black45,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(
                  height: 38,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_rounded, size: 16),
                      SizedBox(width: 8),
                      Text('Reçues'),
                    ],
                  ),
                ),
                Tab(
                  height: 38,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send_rounded, size: 16),
                      SizedBox(width: 8),
                      Text('Envoyées'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStreamList(_receivedNotesStream, true, isDark),
                _buildStreamList(_sentNotesStream, false, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamList(
      Stream<List<SharedNote>> stream, bool isReceived, bool isDark) {
    return StreamBuilder<List<SharedNote>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final notes = snapshot.data ?? [];
        return _buildNotesList(notes, isReceived: isReceived, isDark: isDark);
      },
    );
  }

  Widget _buildLoggedOutState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_person_rounded,
              size: 80,
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.1)),
          const SizedBox(height: 24),
          const Text('Accès Restreint',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Connectez-vous pour débloquer le partage',
            style: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesList(List<SharedNote> notes,
      {required bool isReceived, required bool isDark}) {
    if (notes.isEmpty) {
      return _buildEmptyState(isReceived, isDark);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        final isSelected = _selectedNoteIds.contains(note.id);
        return _buildNoteCard(note,
            isReceived: isReceived, isDark: isDark, isSelected: isSelected);
      },
    );
  }

  Widget _buildEmptyState(bool isReceived, bool isDark) {
    return Center(
      child: Opacity(
        opacity: 0.6,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? Colors.white.withOpacity(0.03)
                    : Colors.black.withOpacity(0.02),
              ),
              child: Icon(
                isReceived
                    ? Icons.auto_awesome_rounded
                    : Icons.history_edu_rounded,
                size: 64,
                color: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isReceived
                  ? 'Votre boîte est vide'
                  : 'Aucun envoi pour le moment',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isReceived
                  ? 'Les notes reçues brilleront ici'
                  : 'Partagez votre première idée',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteCard(SharedNote note,
      {required bool isReceived, required bool isDark, bool isSelected = false}) {
    final noteColor = Color(note.color);
    final textColor = _getTextColor(noteColor, isDark);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: noteColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isSelectionMode
                ? () => _toggleNoteSelection(note.id)
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              SharedNoteViewScreen(sharedNote: note)),
                    ),
            onLongPress: () {
              if (!_isSelectionMode) {
                _enterSelectionMode(note.id);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: textColor.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isReceived ? Icons.person_rounded : Icons.alternate_email_rounded,
                          size: 20,
                          color: textColor.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isReceived
                                  ? note.senderName
                                  : 'Pour : ${note.recipientName}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: textColor.withOpacity(0.9),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              DateFormatter.formatRelativeDate(note.sharedAt),
                              style: TextStyle(
                                  fontSize: 11,
                                  color: textColor.withOpacity(0.5)),
                            ),
                          ],
                        ),
                      ),
                      if (note.reactions.isNotEmpty)
                        _buildReactionBadge(note, textColor),
                      if (_isSelectionMode) ...[
                        const SizedBox(width: 8),
                        Icon(
                          isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                          color: isSelected ? textColor : textColor.withOpacity(0.3),
                          size: 24,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 18),
                  
                  // CONTENT AREA WITH OPTIONAL IMAGE PREVIEW
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              note.title.isNotEmpty ? note.title : 'Sans titre',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: note.title.isNotEmpty ? textColor : textColor.withOpacity(0.55),
                                fontStyle: note.title.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              note.content.isNotEmpty 
                                  ? note.content 
                                  : (note.imagesBase64.isNotEmpty ? "[Note avec images]" : "Aucun contenu"),
                              style: TextStyle(
                                fontSize: 14,
                                color: note.content.isNotEmpty ? textColor.withOpacity(0.7) : textColor.withOpacity(0.45),
                                height: 1.5,
                                fontStyle: note.content.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (note.imagesBase64.isNotEmpty) ...[
                        const SizedBox(width: 16),
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: textColor.withOpacity(0.1)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: ImageBase64Service.instance.decodeBase64ToImage(
                              note.imagesBase64.first,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildCardFooter(note, textColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReactionBadge(SharedNote note, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(note.reactions.first.emoji,
              style: const TextStyle(fontSize: 14)),
          if (note.reactions.length > 1) ...[
            const SizedBox(width: 6),
            Text(
              '+${note.reactions.length - 1}',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: textColor.withOpacity(0.6)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCardFooter(SharedNote note, Color textColor) {
    return Row(
      children: [
        if (note.imagesBase64.isNotEmpty)
          _buildPillIndicator(Icons.image_rounded,
              note.imagesBase64.length.toString(), textColor),
        if (note.reactions.any((r) => r.isComment)) ...[
          const SizedBox(width: 12),
          _buildPillIndicator(
              Icons.chat_bubble_rounded,
              note.reactions.where((r) => r.isComment).length.toString(),
              textColor),
        ],
        const Spacer(),
        Icon(Icons.arrow_forward_ios_rounded,
            size: 12, color: textColor.withOpacity(0.3)),
      ],
    );
  }

  Widget _buildPillIndicator(IconData icon, String label, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: textColor.withOpacity(0.4)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: textColor.withOpacity(0.4)),
          ),
        ],
      ),
    );
  }

  void _enterSelectionMode(String noteId) {
    setState(() {
      _isSelectionMode = true;
      _selectedNoteIds.add(noteId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedNoteIds.clear();
    });
  }

  void _toggleNoteSelection(String noteId) {
    setState(() {
      if (_selectedNoteIds.contains(noteId)) {
        _selectedNoteIds.remove(noteId);
        if (_selectedNoteIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedNoteIds.add(noteId);
      }
    });
  }

  Future<void> _deleteSelectedNotes() async {
    final count = _selectedNoteIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer les notes'),
        content: Text('Voulez-vous supprimer les $count notes sélectionnées ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isDeleting = true);
      try {
        for (final id in _selectedNoteIds) {
          await SharingService.instance.deleteSharedNote(id);
        }
        if (mounted) {
          _exitSelectionMode();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$count notes supprimées avec succès')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de la suppression: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isDeleting = false);
      }
    }
  }

  Color _getTextColor(Color bg, bool isDark) {
    // Si la couleur est trop claire, texte noir, sinon texte blanc
    // On ignore isDark car c'est la couleur de la CARTE qui dicte le contraste
    return bg.computeLuminance() > 0.6 ? Colors.black87 : Colors.white;
  }
}
