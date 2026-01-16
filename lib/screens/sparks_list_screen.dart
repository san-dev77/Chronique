import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../models/spark.dart';
import '../services/spark_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/auth_service.dart';
import '../services/guidance_service.dart';
import '../theme/app_theme.dart';
import 'spark_edit_screen.dart';
import '../utils/page_transitions.dart';

class SparksListScreen extends StatefulWidget {
  const SparksListScreen({super.key});

  @override
  State<SparksListScreen> createState() => _SparksListScreenState();
}

class _SparksListScreenState extends State<SparksListScreen> {
  List<Spark> _sparks = [];
  bool _isLoading = true;
  String _pagePrompt = '';

  @override
  void initState() {
    super.initState();
    _pagePrompt = GuidanceService.instance.getRandomSparkPrompt();
    _loadSparks();
  }

  Future<void> _loadSparks() async {
    setState(() => _isLoading = true);
    final sparks = SparkService.instance.getAllSparks();
    setState(() {
      _sparks = sparks;
      _isLoading = false;
    });
  }

  Future<void> _saveSpark(Spark spark) async {
    await SparkService.instance.saveSpark(spark);
    _loadSparks();
  }

  void _editSpark(Spark spark) {
    Navigator.push(
      context,
      PageTransitions.scaleTransition(
        SparkEditScreen(spark: spark, onSave: _saveSpark),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = AppTheme.skyBlue;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, 
                color: isDark ? AppTheme.textLight : AppTheme.textDark),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
              title: Text(
                'Mes Étincelles',
                style: TextStyle(
                  color: isDark ? AppTheme.textLight : AppTheme.textDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
              background: Container(
                color: isDark ? AppTheme.bgDark : AppTheme.bgLight,
              ),
            ),
          ),
          
          if (_sparks.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accentColor.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: accentColor, size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _pagePrompt,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          _isLoading
              ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              : _sparks.isEmpty
                  ? SliverFillRemaining(child: _buildEmptyState(isDark))
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      sliver: SliverMasonryGrid.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        itemBuilder: (context, index) {
                          final spark = _sparks[index];
                          return _buildSparkCard(spark, isDark, accentColor);
                        },
                        childCount: _sparks.length,
                      ),
                    ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          PageTransitions.scaleTransition(
            SparkEditScreen(onSave: _saveSpark),
          ),
        ),
        backgroundColor: AppTheme.skyBlue,
        elevation: 4,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildSparkCard(Spark spark, bool isDark, Color accentColor) {
    return GestureDetector(
      onTap: () => _editSpark(spark),
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showOptions(spark);
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (spark.imagePath != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Hero(
                  tag: 'spark_img_${spark.id}',
                  child: Image.file(
                    File(spark.imagePath!),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 120,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spark.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppTheme.textLight : AppTheme.textDark,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (spark.description != null && spark.description!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      spark.description!,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: isDark ? AppTheme.textLight.withOpacity(0.5) : Colors.grey.shade600,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptions(Spark spark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_rounded, color: Colors.blue),
              ),
              title: const Text('Modifier', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                _editSpark(spark);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              ),
              title: const Text('Supprimer', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () async {
                Navigator.pop(context);
                await SparkService.instance.deleteSpark(spark.id);
                _loadSparks();
              },
            ),
            const SizedBox(height: 20),
          ],
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
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bolt_rounded, size: 64, color: Colors.orangeAccent),
          ),
          const SizedBox(height: 24),
          Text(
            'Aucune étincelle...',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Une idée peut surgir à tout moment.\nCapturez-la ici !',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, height: 1.5),
          ),
        ],
      ),
    );
  }
}
