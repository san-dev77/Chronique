import 'package:flutter/material.dart';
import '../models/note.dart';
import '../services/sharing_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Écran de sélection Multiple de membres pour partager une note
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
            content: Text('Note partagee avec $successCount membre(s) !'),
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
      appBar: AppBar(
        title: const Text('Partager avec...', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          _buildSearchBar(isDark, primaryColor),
          if (_selectedMemberIds.isNotEmpty) _buildSelectionHeader(primaryColor),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _filteredMembers.isEmpty 
                ? _buildEmptyState(isDark)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredMembers.length,
                    itemBuilder: (context, index) => _buildMemberCard(_filteredMembers[index], isDark, primaryColor),
                  ),
          ),
        ],
      ),
      floatingActionButton: _selectedMemberIds.isEmpty || _isSharing
          ? null
          : FloatingActionButton.extended(
              onPressed: _shareWithSelected,
              backgroundColor: primaryColor,
              icon: const Icon(Icons.send_rounded, color: Colors.white),
              label: Text('Partager (${_selectedMemberIds.length})', 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
    );
  }

  Widget _buildSearchBar(bool isDark, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Rechercher un membre ou un email...',
            prefixIcon: Icon(Icons.search, color: primaryColor),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionHeader(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text('${_selectedMemberIds.length} sélectionné(s)', 
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
          const Spacer(),
          TextButton(
            onPressed: () => setState(() => _selectedMemberIds.clear()),
            child: const Text('Tout désélectionner'),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(AppMember member, bool isDark, Color primaryColor) {
    final isSelected = _selectedMemberIds.contains(member.uid);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected 
          ? primaryColor.withOpacity(0.1) 
          : (isDark ? Colors.white.withOpacity(0.05) : Colors.white),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? primaryColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: primaryColor.withOpacity(0.1),
              backgroundImage: member.photoUrl != null ? NetworkImage(member.photoUrl!) : null,
              child: member.photoUrl == null 
                ? Text(member.displayName.isNotEmpty ? member.displayName[0].toUpperCase() : '?',
                    style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 20))
                : null,
            ),
            if (isSelected)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: Icon(Icons.check_circle, color: primaryColor, size: 20),
                ),
              ),
          ],
        ),
        title: Text(member.displayName, 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, 
            color: isDark ? Colors.white : Colors.black87)),
        subtitle: Text(member.email, 
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.grey)),
        onTap: () => _toggleSelection(member.uid),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_rounded, size: 80, color: Colors.grey.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(_searchController.text.isEmpty ? 'Aucun membre' : 'Aucun résultat', 
            style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
