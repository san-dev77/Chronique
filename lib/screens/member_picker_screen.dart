import 'package:flutter/material.dart';
import '../models/note.dart';
import '../services/sharing_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';

/// Écran de sélection Multiple de membres pour partager une story
class MemberPickerScreen extends StatefulWidget {
  final Note note;

  const MemberPickerScreen({super.key, required this.note});

  @override
  State<MemberPickerScreen> createState() => _MemberPickerScreenState();
}

class _MemberPickerScreenState extends State<MemberPickerScreen> {
  final _searchController = TextEditingController();
  List<AppMember> _allMembers = [];
  List<AppMember> _filteredMembers = [];
  final Set<String> _selectedMemberIds = {};
  bool _isLoading = true;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _searchController.addListener(_filterMembers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    try {
      final members = await SharingService.instance.getAllMembers();
      if (mounted) {
        setState(() {
          _allMembers = members;
          _filteredMembers = members;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  void _filterMembers() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredMembers = _allMembers;
      } else {
        _filteredMembers = _allMembers.where((m) => 
          m.displayName.toLowerCase().contains(query) || 
          m.email.toLowerCase().contains(query)).toList();
      }
    });
  }

  void _toggleSelection(String uid) {
    setState(() {
      if (_selectedMemberIds.contains(uid)) {
        _selectedMemberIds.remove(uid);
      } else {
        _selectedMemberIds.add(uid);
      }
    });
  }

  Future<void> _shareWithSelected() async {
    if (_selectedMemberIds.isEmpty) return;

    setState(() => _isSharing = true);
    try {
      int successCount = 0;
      for (final uid in _selectedMemberIds) {
        final member = _allMembers.firstWhere((m) => m.uid == uid);
        await SharingService.instance.shareNoteToMember(widget.note, member);
        successCount++;
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Story partagée avec $successCount membre(s) !'),
            backgroundColor: AppTheme.skyBlue,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppTheme.skyBlue;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Partager avec...',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: (isDark ? Colors.black : Colors.white).withOpacity(0.8),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [Colors.black, const Color(0xFF1A1A1A)]
                : [Colors.white, const Color(0xFFF0F4F8)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildSearchBar(isDark, primaryColor),
              if (_selectedMemberIds.isNotEmpty) _buildSelectionHeader(primaryColor),
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: primaryColor))
                    : _filteredMembers.isEmpty
                        ? _buildEmptyState(isDark)
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            itemCount: _filteredMembers.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) =>
                                _buildMemberCard(_filteredMembers[index], isDark, primaryColor),
                          ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _selectedMemberIds.isEmpty || _isSharing
          ? null
          : Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: FloatingActionButton.extended(
                onPressed: _shareWithSelected,
                backgroundColor: primaryColor,
                elevation: 0,
                icon: const Icon(Icons.send_rounded, color: Colors.white),
                label: Text(
                  'Partager (${_selectedMemberIds.length})',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
    );
  }

  Widget _buildSearchBar(bool isDark, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          style: TextStyle(
              fontSize: 16, color: isDark ? Colors.white : const Color(0xFF2D3436)),
          decoration: InputDecoration(
            hintText: 'Rechercher un membre...',
            hintStyle: TextStyle(
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                fontWeight: FontWeight.w500),
            prefixIcon: Icon(Icons.search_rounded,
                color: isDark ? Colors.grey : primaryColor),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionHeader(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_selectedMemberIds.length} sélectionné(s)',
              style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 14),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _selectedMemberIds.clear()),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey,
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
            child: const Text('Tout effacer'),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(AppMember member, bool isDark, Color primaryColor) {
    final isSelected = _selectedMemberIds.contains(member.uid);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected
            ? primaryColor.withOpacity(isDark ? 0.2 : 0.1)
            : (isDark ? const Color(0xFF2C2C2C) : Colors.white),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isSelected
              ? primaryColor
              : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                    color: primaryColor.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ]
            : [
                BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
      ),
      child: InkWell(
        onTap: () => _toggleSelection(member.uid),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar
              UserAvatar(
                displayName: member.displayName,
                photoUrl: member.photoUrl,
                photoBase64: member.photoBase64,
                profileColor: member.profileColor,
                radius: 28,
              ),
              const SizedBox(width: 16),

              // Infos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.white : const Color(0xFF2D3436),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      member.email,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Checkbox custom
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? primaryColor : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? primaryColor : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.03),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_search_rounded,
                size: 64, color: Colors.grey.withOpacity(0.5)),
          ),
          const SizedBox(height: 24),
          Text(
            _searchController.text.isEmpty
                ? 'Aucun autre membre trouvé'
                : 'Aucun résultat',
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
