import 'package:flutter/material.dart';

import '../models/note_mood.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import 'aura_glow_widget.dart';

/// Resultat du choix d'aura.
class AuraChoice {
  /// `null` = aucune aura. `NoteMood.freeKey` = une couleur, sans humeur.
  final String? moodKey;
  final int? color;

  const AuraChoice(this.moodKey, this.color);
}

/// Ouvre le selecteur d'aura : feuille glissante sur telephone, boite centree
/// sur desktop. Renvoie `null` si l'utilisateur annule.
Future<AuraChoice?> showAuraPicker(
  BuildContext context, {
  String? moodKey,
  int? moodColor,
}) {
  final body = _AuraPicker(moodKey: moodKey, moodColor: moodColor);

  if (Responsive.isWide(context)) {
    return showDialog<AuraChoice>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
          child: body,
        ),
      ),
    );
  }

  return showModalBottomSheet<AuraChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      child: body,
    ),
  );
}

class _AuraPicker extends StatefulWidget {
  final String? moodKey;
  final int? moodColor;

  const _AuraPicker({required this.moodKey, required this.moodColor});

  @override
  State<_AuraPicker> createState() => _AuraPickerState();
}

class _AuraPickerState extends State<_AuraPicker> {
  late String? _mood = widget.moodKey;
  late int? _color = widget.moodColor;

  Color get _accent => _mood == null
      ? AppTheme.skyBlue
      : NoteMood.getEffectiveColor(_mood, _color);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.textMutedDark : AppTheme.textMuted;
    final wide = Responsive.isWide(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: wide
            ? BorderRadius.circular(24)
            : const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!wide)
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: muted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
              child: AuraChooser(
                moodKey: _mood,
                color: _color,
                onChanged: (choice) => setState(() {
                  _mood = choice.moodKey;
                  _color = choice.color;
                }),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
            ),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    _mood = null;
                    _color = null;
                  }),
                  child: Text('Aucune aura',
                      style: TextStyle(color: muted, fontSize: 13.5)),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Annuler',
                      style: TextStyle(color: muted, fontSize: 13.5)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.pop(context, AuraChoice(_mood, _color)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 13),
                  ),
                  child: const Text('Valider'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Corps du choix d'aura, sans cadre ni boutons : apercu vivant, teintes
/// toujours accessibles, humeur libre, puis humeurs proposees.
///
/// Composant controle — l'etat vit chez l'appelant, ce qui permet de l'utiliser
/// aussi bien dans la feuille glissante que dans l'assistant de creation.
class AuraChooser extends StatefulWidget {
  final String? moodKey;
  final int? color;
  final ValueChanged<AuraChoice> onChanged;

  /// L'assistant de creation montre deja une carte-temoin avec la vraie image :
  /// inutile d'y ajouter une seconde vignette.
  final bool showPreview;

  const AuraChooser({
    super.key,
    required this.moodKey,
    required this.color,
    required this.onChanged,
    this.showPreview = true,
  });

  @override
  State<AuraChooser> createState() => _AuraChooserState();
}

class _AuraChooserState extends State<AuraChooser> {
  late final TextEditingController _nameController = TextEditingController(
    text: NoteMood.isCustom(widget.moodKey)
        ? widget.moodKey!.substring(7)
        : '',
  );

  @override
  void didUpdateWidget(AuraChooser old) {
    super.didUpdateWidget(old);
    // Si l'humeur change depuis l'exterieur (choix d'une humeur proposee),
    // le champ libre se vide pour ne pas afficher deux verites.
    if (!NoteMood.isCustom(widget.moodKey) && _nameController.text.isNotEmpty) {
      _nameController.clear();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Color get _accent => widget.moodKey == null
      ? AppTheme.skyBlue
      : NoteMood.getEffectiveColor(widget.moodKey, widget.color);

  /// Choisir une teinte suffit : sans humeur retenue, on bascule sur une aura
  /// libre plutot que d'obliger a prendre une etiquette.
  void _pickColor(Color c) {
    widget.onChanged(
      AuraChoice(widget.moodKey ?? NoteMood.freeKey, c.toARGB32()),
    );
  }

  void _pickMood(String key) {
    // Une humeur proposee reprend sa teinte d'origine.
    widget.onChanged(AuraChoice(key, null));
  }

  void _applyCustomName() {
    final name = _nameController.text.trim();
    widget.onChanged(AuraChoice(
      name.isEmpty ? NoteMood.freeKey : NoteMood.customKey(name),
      widget.color,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.textMutedDark : AppTheme.textMuted;
    final textColor = isDark ? Colors.white : AppTheme.textDark;
    final mood = widget.moodKey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showPreview)
        Center(
          child: Column(
            children: [
              SizedBox(
                height: 92,
                child: Center(
                  child: mood == null
                      ? Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: muted.withValues(alpha: 0.35),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(Icons.block_rounded,
                              color: muted, size: 22),
                        )
                      : AuraOrb(
                          moodKey: mood,
                          color: _accent,
                          size: 58,
                          active: true,
                        ),
                ),
              ),
              Text(
                mood == null ? 'Aucune aura' : NoteMood.getDisplayLabel(mood),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                mood == null
                    ? 'La note restera sobre'
                    : AuraSpec.describe(mood),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                  color: muted,
                ),
              ),
            ],
          ),
        ),
        if (widget.showPreview) const SizedBox(height: 22),

        _label('TEINTE', muted),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in NoteMood.palette)
              _Dot(
                color: c,
                selected: mood != null && _accent.toARGB32() == c.toARGB32(),
                onTap: () => _pickColor(c),
              ),
          ],
        ),
        const SizedBox(height: 22),

        _label('VOTRE HUMEUR', muted),
        const SizedBox(height: 10),
        TextField(
          controller: _nameController,
          onChanged: (_) => _applyCustomName(),
          style: TextStyle(fontSize: 14, color: textColor),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Écrivez la vôtre, ou laissez vide',
            hintStyle: TextStyle(
                fontSize: 13.5, color: muted.withValues(alpha: 0.7)),
            prefixIcon:
                Icon(Icons.auto_awesome_rounded, size: 18, color: _accent),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 38, minHeight: 38),
            filled: true,
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.035),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _accent, width: 1.6),
            ),
          ),
        ),
        const SizedBox(height: 22),

        _label('OU UNE HUMEUR PROPOSÉE', muted),
        const SizedBox(height: 10),
        for (final family in NoteMood.families.entries) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Text(
              family.key,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: muted,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in family.value)
                _MoodChip(
                  label: m.label,
                  icon: m.icon,
                  color: NoteMood.getEffectiveColor(
                      m.key, mood == m.key ? widget.color : null),
                  selected: mood == m.key,
                  isDark: isDark,
                  onTap: () => _pickMood(m.key),
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _label(String text, Color muted) => Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.3,
          color: muted,
        ),
      );
}

class _MoodChip extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _MoodChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_MoodChip> createState() => _MoodChipState();
}

class _MoodChipState extends State<_MoodChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: on
                ? widget.color.withValues(alpha: 0.20)
                : (_hover
                    ? widget.color.withValues(alpha: 0.11)
                    : (widget.isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.035))),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: on ? widget.color.withValues(alpha: 0.85) : Colors.transparent,
              width: 1.4,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 17,
                height: 17,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  boxShadow: on
                      ? [
                          BoxShadow(
                            color: widget.color.withValues(alpha: 0.6),
                            blurRadius: 10,
                          )
                        ]
                      : null,
                ),
                child: Icon(widget.icon, size: 10, color: Colors.white),
              ),
              const SizedBox(width: 7),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                  color: widget.isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _Dot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Colors.white
                  : Colors.black.withValues(alpha: 0.10),
              width: selected ? 2.4 : 1,
            ),
            boxShadow: selected
                ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 13)]
                : null,
          ),
          child: selected
              ? Icon(Icons.check_rounded,
                  size: 15,
                  color: color.computeLuminance() > 0.6
                      ? Colors.black87
                      : Colors.white)
              : null,
        ),
      ),
    );
  }
}
