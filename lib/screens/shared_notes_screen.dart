import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../models/shared_note.dart';
import '../services/sharing_service.dart';
import '../services/auth_service.dart';
import '../services/image_base64_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../utils/date_formatter.dart';
import '../widgets/user_avatar.dart';
import '../widgets/screen_header.dart';
import 'shared_note_view_screen.dart';

/// Écran listant les chroniques partagées (reçues et envoyées)
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
    final bgColor = isDark ? AppTheme.bgDark : AppTheme.bgLight;

    if (!AuthService.instance.isSignedIn) {
      return Scaffold(
        backgroundColor: bgColor,
        body: _buildLoggedOutState(isDark),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final wide = Responsive.useSidebar(width);

      return Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // En mode selection, l'en-tete cede la place a une barre
              // d'action : le nombre d'elements et le bouton Supprimer sont
              // alors cote a cote, au lieu d'etre separes par tout l'ecran.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _isSelectionMode
                    ? _buildSelectionBar(isDark, width)
                    : _buildHeader(isDark, width),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildStreamList(_receivedNotesStream, true, isDark, width),
                    _buildStreamList(_sentNotesStream, false, isDark, width),
                  ],
                ),
              ),
              if (!wide) const SizedBox(height: 8),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildHeader(bool isDark, double width) {
    return StreamBuilder<int>(
      key: const ValueKey('header'),
      stream: SharingService.instance.watchUnreadReceivedNotesCount(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return ScreenHeader(
          width: width,
          icon: Icons.people_rounded,
          title: 'Partage',
          subtitle: count > 0
              ? '$count chronique${count > 1 ? 's' : ''} non lue${count > 1 ? 's' : ''}'
              : 'Vos échanges avec vos proches',
          bottom: _buildTabs(isDark),
        );
      },
    );
  }

  /// Bascule Reçues / Envoyées, bornee pour ne pas s'etirer sur desktop.
  Widget _buildTabs(bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            splashBorderRadius: BorderRadius.circular(10),
            indicator: BoxDecoration(
              color: AppTheme.skyBlue,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.skyBlue.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            labelColor: Colors.white,
            unselectedLabelColor:
                isDark ? AppTheme.textMutedDark : AppTheme.textMuted,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            tabs: const [
              Tab(text: 'Reçues'),
              Tab(text: 'Envoyées'),
            ],
          ),
        ),
      ),
    );
  }

  /// Barre contextuelle du mode selection.
  Widget _buildSelectionBar(bool isDark, double width) {
    final insets = Responsive.contentInsets(width);
    final n = _selectedNoteIds.length;

    return Container(
      key: const ValueKey('selection'),
      padding: EdgeInsets.fromLTRB(insets.left, 14, insets.right, 14),
      decoration: BoxDecoration(
        color: AppTheme.skyBlue.withValues(alpha: isDark ? 0.18 : 0.10),
        border: Border(
          bottom: BorderSide(color: AppTheme.skyBlue.withValues(alpha: 0.35)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _exitSelectionMode,
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Quitter la sélection',
            color: isDark ? Colors.white : AppTheme.textDark,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              n == 0
                  ? 'Sélectionnez des chroniques'
                  : '$n sélectionnée${n > 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppTheme.textDark,
              ),
            ),
          ),
          if (_isDeleting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            _DangerButton(
              enabled: n > 0,
              onTap: _deleteSelectedNotes,
            ),
        ],
      ),
    );
  }

  Widget _buildStreamList(Stream<List<SharedNote>> stream, bool isReceived,
      bool isDark, double width) {
    return StreamBuilder<List<SharedNote>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final notes = snapshot.data ?? [];
        return _buildNotesList(notes,
            isReceived: isReceived, isDark: isDark, width: width);
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
              'Identifiez-vous pour accéder à vos échanges de chroniques et partager vos moments.',
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
      {required bool isReceived,
      required bool isDark,
      required double width}) {
    if (notes.isEmpty) {
      return _buildEmptyState(isReceived, isDark);
    }

    final insets = Responsive.contentInsets(width);
    final avail = width - insets.horizontal;
    // Deux colonnes des qu'il y a la place : une liste d'une seule colonne
    // laissait les deux tiers de l'ecran vides sur desktop.
    final columns = avail >= 980 ? 2 : 1;
    final padding = EdgeInsets.fromLTRB(insets.left, 16, insets.right, 90);

    if (columns == 1) {
      return ListView.builder(
        padding: padding,
        physics: const BouncingScrollPhysics(),
        itemCount: notes.length,
        itemBuilder: (context, index) => _card(notes[index], isReceived, isDark),
      );
    }

    // Grille a hauteurs naturelles : une carte avec reactions et images est
    // plus haute qu'une autre, une hauteur fixe la ferait deborder.
    return MasonryGridView.count(
      padding: padding,
      physics: const BouncingScrollPhysics(),
      crossAxisCount: columns,
      crossAxisSpacing: 16,
      mainAxisSpacing: 0,
      itemCount: notes.length,
      itemBuilder: (context, index) => _card(notes[index], isReceived, isDark),
    );
  }

  Widget _card(SharedNote note, bool isReceived, bool isDark) {
    return _HoverCard(
      key: ValueKey(note.id),
      accent: AppTheme.skyBlue,
      child: _buildNoteCard(
        note,
        isReceived: isReceived,
        isDark: isDark,
        isSelected: _selectedNoteIds.contains(note.id),
      ),
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
            isReceived ? 'Aucune chronique reçue' : 'Partez à l\'aventure',
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
        title: const Text('Supprimer les chroniques', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('Voulez-vous supprimer les $count chroniques sélectionnées ?'),
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
              content: Text('$count chroniques supprimées'),
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

/// Bouton de suppression de la barre de selection.
class _DangerButton extends StatefulWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _DangerButton({required this.enabled, required this.onTap});

  @override
  State<_DangerButton> createState() => _DangerButtonState();
}

class _DangerButtonState extends State<_DangerButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    const danger = Color(0xFFD1544B);
    final on = widget.enabled;

    return MouseRegion(
      cursor: on ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: on ? widget.onTap : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 140),
          opacity: on ? 1 : 0.4,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: on && _hover
                  ? danger
                  : danger.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: danger.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete_outline_rounded,
                    size: 17,
                    color: on && _hover ? Colors.white : danger),
                const SizedBox(width: 7),
                Text(
                  'Supprimer',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: on && _hover ? Colors.white : danger,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Souleve une carte de partage au survol.
class _HoverCard extends StatefulWidget {
  final Widget child;
  final Color accent;

  const _HoverCard({super.key, required this.child, required this.accent});

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..translate(0.0, _hover ? -3.0 : 0.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: _hover
              ? [
                  BoxShadow(
                    color: widget.accent.withValues(alpha: 0.24),
                    blurRadius: 24,
                    spreadRadius: -2,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}
