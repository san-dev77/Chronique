import 'package:flutter/material.dart';
import '../models/shared_note.dart';
import '../services/sharing_service.dart';
import '../services/auth_service.dart';
import '../services/image_base64_service.dart';
import '../theme/app_theme.dart';
import '../utils/date_formatter.dart';
import '../widgets/user_avatar.dart';
import 'shared_note_view_screen.dart';

/// Écran listant les stories partagées (reçues et envoyées)
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = AppTheme.skyBlue;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03);

    if (!AuthService.instance.isSignedIn) {
      return Scaffold(
        backgroundColor: bgColor,
        body: _buildLoggedOutState(isDark),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // BACKGROUND DECORATION
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    primaryColor.withOpacity(isDark ? 0.12 : 0.08),
                    primaryColor.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.purple.withOpacity(isDark ? 0.08 : 0.05),
                    Colors.purple.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // CUSTOM HEADER
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Partages',
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            StreamBuilder<int>(
                              stream: SharingService.instance.watchUnreadReceivedNotesCount(),
                              builder: (context, snapshot) {
                                final count = snapshot.data ?? 0;
                                return Text(
                                  count > 0 ? '$count nouvelles stories' : 'Vos échanges cryptés',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: count > 0 ? primaryColor : (isDark ? Colors.white38 : Colors.black38),
                                  ),
                                );
                              }
                            ),
                          ],
                        ),
                      ),
                      if (_isSelectionMode)
                        _isDeleting
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                          : IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                              onPressed: _selectedNoteIds.isEmpty ? null : _deleteSelectedNotes,
                            )
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // GLASSMORPHIC TAB BAR
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  height: 48,
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        if (!isDark)
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                      ],
                    ),
                    labelColor: isDark ? Colors.white : const Color(0xFF1E293B),
                    unselectedLabelColor: isDark ? Colors.white38 : Colors.black45,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    tabs: const [
                      Tab(text: 'Reçues'),
                      Tab(text: 'Envoyées'),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // CONTENT
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
          ),
          
          // Selection Mode Close Button
          if (_isSelectionMode)
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _exitSelectionMode,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Quitter la sélection (${_selectedNoteIds.length})',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
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
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_person_rounded,
                  size: 48,
                  color: isDark ? Colors.white24 : Colors.black12),
            ),
            const SizedBox(height: 32),
            const Text('Espace Privé',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Text(
              'Identifiez-vous pour accéder à vos échanges de stories et partager vos moments.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white38 : Colors.black45,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesList(List<SharedNote> notes,
      {required bool isReceived, required bool isDark}) {
    if (notes.isEmpty) {
      return _buildEmptyState(isReceived, isDark);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      physics: const BouncingScrollPhysics(),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isReceived ? Icons.auto_awesome_rounded : Icons.history_edu_rounded,
            size: 64,
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
          ),
          const SizedBox(height: 16),
          Text(
            isReceived ? 'Aucune story reçue' : 'Partez à l\'aventure',
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(SharedNote note,
      {required bool isReceived, required bool isDark, bool isSelected = false}) {
    final isUnread = isReceived && !note.isRead;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isSelected 
              ? AppTheme.skyBlue 
              : (isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08)),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isSelectionMode
                ? () => _toggleNoteSelection(note.id)
                : () {
                    if (isReceived && !note.isRead) {
                      SharingService.instance.markAsRead(note.id);
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => SharedNoteViewScreen(sharedNote: note)),
                    );
                  },
            onLongPress: () => _enterSelectionMode(note.id),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // ICON/AVATAR
                  Stack(
                    children: [
                      _buildLeadingThumbnail(note, isReceived),
                      if (isUnread)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                              border: Border.all(color: isDark ? const Color(0xFF1E293B) : Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  
                  const SizedBox(width: 16),

                  // CONTENT
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                isReceived ? note.senderName : 'À : ${note.recipientName}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              DateFormatter.formatRelativeDate(note.sharedAt),
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white38 : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          note.title.isNotEmpty ? note.title : 'Sans titre',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: isUnread ? FontWeight.w900 : FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (note.content.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            note.content,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white70 : const Color(0xFF475569),
                              height: 1.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        
                        // Indicators
                        if (note.reactions.isNotEmpty || note.imagesBase64.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              if (note.imagesBase64.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.skyBlue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.image_rounded, size: 10, color: AppTheme.skyBlue),
                                      const SizedBox(width: 4),
                                      Text('${note.imagesBase64.length}', 
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.skyBlue)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              if (note.reactions.isNotEmpty)
                                _buildCompactReactionBadge(note, isDark),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // TRAILER
                  if (_isSelectionMode)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                        color: isSelected ? AppTheme.skyBlue : (isDark ? Colors.white10 : Colors.black12),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeadingThumbnail(SharedNote note, bool isReceived) {
    if (note.imagesBase64.isNotEmpty) {
      return Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Color(note.color).withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ImageBase64Service.instance.decodeBase64ToImage(
            note.imagesBase64.first,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return UserAvatar(
      userId: isReceived ? note.senderId : note.recipientId,
      displayName: isReceived ? note.senderName : (note.recipientName.isNotEmpty ? note.recipientName : 'User'),
      radius: 26,
      heroTag: 'avatar_list_${note.id}',
    );
  }

  Widget _buildCompactReactionBadge(SharedNote note, bool isDark) {
    final reaction = note.reactions.last;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(reaction.emoji, style: const TextStyle(fontSize: 12)),
          if (note.reactions.length > 1) ...[
            const SizedBox(width: 4),
            Text('+${note.reactions.length - 1}', 
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white60 : Colors.black45)),
          ],
        ],
      ),
    );
  }

  void _enterSelectionMode(String noteId) {
    if (_isSelectionMode) return;
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
        if (_selectedNoteIds.isEmpty) _isSelectionMode = false;
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
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer les stories', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('Voulez-vous supprimer les $count stories sélectionnées ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Supprimer', style: TextStyle(fontWeight: FontWeight.bold)),
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
            SnackBar(
              content: Text('$count stories supprimées'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
        }
      } finally {
        if (mounted) setState(() => _isDeleting = false);
      }
    }
  }
}
