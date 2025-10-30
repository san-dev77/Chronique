# 📋 Plan de Refonte - Note Box

## 🎯 Problèmes Identifiés

### 1. **Perte de données**

- ❌ Pas de synchronisation cloud
- ❌ Perte des notes si téléphone perdu/cassé
- ✅ **Solution immédiate** : Export/Import JSON (IMPLÉMENTÉ)

### 2. **Perte d'images**

- ❌ Images stockées par chemin local (peuvent être supprimées par le système)
- ❌ Pas de copie permanente dans l'app
- 🔧 **Solution à venir** : Stockage images en base64 ou copie interne

### 3. **Améliorations UX/Design**

- 🎨 Design modernisé avec palette slate
- 🧠 Fonctionnalités "intelligentes"
- ⚡ Plus d'options et possibilités

---

## 🚀 Phase 1 : Sauvegarde Immédiate (✅ TERMINÉ)

### Actions réalisées

1. ✅ Service `BackupService` créé

   - Export JSON avec images encodées en base64
   - Import avec restauration des images
   - Support export/import dossier complet

2. ✅ UI dans `SettingsScreen`
   - Bouton "Exporter toutes les notes"
   - Bouton "Importer des notes"
   - Statistiques (nombre notes/images)

### 📱 Utilisation immédiate

**Pour sauvegarder tes notes MAINTENANT :**

1. Ouvre l'app
2. Va dans Paramètres (⚙️)
3. Section "💾 Sauvegarde & Données"
4. Clique "Exporter toutes les notes"
5. Copie le fichier JSON généré sur ton PC/cloud

---

## 🔧 Phase 2 : Correction Problème Images (PRIORITÉ)

### Stratégie : Copie Interne + Nettoyage

```dart
// Modifier image_picker pour copier dans dossier app
// Au lieu de : imagePath (temporaire)
// Faire : copier vers appDir/note_images/ (permanent)
```

### Actions à faire

1. Modifier `note_edit_screen.dart` pour copier images
2. Créer service `ImageStorageService`
3. Migration : copier toutes les images existantes
4. Cleanup : supprimer images orphelines

### Architecture proposée

```
lib/
  services/
    image_storage_service.dart  // Nouveau
    - copyImageToAppStorage()
    - getImageFile()
    - cleanupOrphanImages()
```

---

## 🌐 Phase 3 : Synchronisation Cloud (REFONTE MAJEURE)

### Options Cloud

1. **Firebase (recommandé)**

   - Firestore : stockage notes
   - Firebase Storage : stockage images
   - Auth : comptes utilisateurs
   - Gratuit jusqu'à 1GB

2. **Supabase (alternative)**

   - PostgreSQL
   - Storage
   - Auth
   - Open-source

3. **Appwrite (self-hosted)**
   - Full control
   - Pas de limites
   - Plus complexe

### Architecture Cloud Proposée

```
lib/
  services/
    auth_service.dart           // Nouveau
    cloud_sync_service.dart     // Nouveau
    conflict_resolver.dart      // Nouveau
  models/
    sync_state.dart            // Nouveau
  providers/
    sync_provider.dart         // Nouveau (state management)
```

### Fonctionnalités Sync

- ⬆️ Auto-upload notes modifiées
- ⬇️ Auto-download notes depuis cloud
- 🔄 Résolution conflits (last-write-wins / merge)
- 📶 Mode offline-first (fonctionne sans connexion)
- 🔐 Chiffrement end-to-end (optionnel)

---

## 🎨 Phase 4 : Design Sublime + Palette Slate

### Palette Slate (remplace bleu)

```dart
// app_theme.dart - Nouveau
slate50: #f8fafc
slate100: #f1f5f9
slate200: #e2e8f0
slate300: #cbd5e1
slate400: #94a3b8
slate500: #64748b
slate600: #475569
slate700: #334155
slate800: #1e293b
slate900: #0f172a
```

### Améliorations UI

1. **Animations fluides**

   - Transitions page améliorées
   - Micro-interactions
   - Hero animations

2. **Composants modernes**

   - Bottom sheets redessinés
   - Cards avec neumorphisme
   - Glassmorphism pour overlays

3. **Typographie**
   - Font custom (Google Fonts)
   - Hiérarchie claire
   - Meilleur contraste

---

## 🧠 Phase 5 : Fonctionnalités Intelligentes

### 1. **Recherche Avancée**

```dart
- Recherche full-text
- Recherche par tag
- Recherche par couleur
- Recherche par date
- Recherche dans images (OCR optionnel)
```

### 2. **Organisation Automatique**

```dart
- Auto-catégorisation par mots-clés
- Suggestions de tags
- Rappels intelligents
- Notes épinglées
```

### 3. **Édition Avancée**

```dart
- Rich text editor (gras, italique, liste)
- Markdown support
- Checkboxes interactives
- Dessin/annotation sur images
- Voice-to-text
```

### 4. **Collaboration (optionnel)**

```dart
- Partage de notes
- Notes partagées en temps réel
- Commentaires
```

### 5. **Widgets & Extensions**

```dart
- Widget Android/iOS
- Extension navigateur
- Raccourcis Siri/Google Assistant
```

---

## 📦 Phase 6 : Nouvelles Dépendances

### À ajouter dans pubspec.yaml

```yaml
dependencies:
  # Cloud & Auth
  firebase_core: ^2.24.0
  firebase_auth: ^4.16.0
  cloud_firestore: ^4.14.0
  firebase_storage: ^11.6.0

  # State Management
  provider: ^6.1.1 # ou riverpod, bloc

  # UI/UX
  google_fonts: ^6.1.0
  flutter_animate: ^4.3.0
  shimmer: ^3.0.0

  # Rich Editor
  flutter_quill: ^9.0.0

  # Search
  algolia: ^1.1.1 # optionnel

  # OCR (optionnel)
  google_ml_kit: ^0.16.0
```

---

## 🗓️ Timeline Proposé

### Sprint 1 (Semaine 1) - CRITIQUE

- [x] Export/Import (FAIT)
- [ ] Fix stockage images (copie interne)
- [ ] Migration images existantes

### Sprint 2 (Semaine 2) - DESIGN

- [ ] Nouvelle palette slate
- [ ] Refonte UI screens
- [ ] Animations

### Sprint 3 (Semaine 3-4) - CLOUD

- [ ] Setup Firebase
- [ ] Auth utilisateur
- [ ] Sync basique notes

### Sprint 4 (Semaine 5) - IMAGES CLOUD

- [ ] Upload images Firebase Storage
- [ ] Download optimisé
- [ ] Cache local

### Sprint 5 (Semaine 6-7) - INTELLIGENCE

- [ ] Recherche avancée
- [ ] Tags auto
- [ ] Rich editor

### Sprint 6 (Semaine 8) - POLISH

- [ ] Tests
- [ ] Optimisation perfs
- [ ] Documentation

---

## 🎯 Action Immédiate pour Toi

### AUJOURD'HUI (URGENT)

1. **Lance l'app**
2. **Va dans Paramètres → Sauvegarde & Données**
3. **Clique "Exporter toutes les notes"**
4. **Copie le fichier JSON sur ton PC ou Google Drive**
5. **TEST : Essaye d'importer pour vérifier que ça marche**

### CETTE SEMAINE

- Confirme les priorités de refonte
- Choix cloud : Firebase ou autre ?
- Budget design : minimaliste ou riche ?

---

## 💡 Recommandations

### Pour Éviter Perte de Données

1. ✅ **Export régulier** (1x/semaine)
2. 🔄 **Sync auto** après refonte
3. ☁️ **Cloud backup** toujours activé

### Pour Design

- Inspiration : Notion, Craft, Bear
- Palette slate + accents colorés
- Mode sombre premium

### Pour Intelligence

- Commencer simple : recherche + tags
- Ajouter progressivement : OCR, voice, etc.

---

## 🤝 Prochaines Étapes

**Dis-moi :**

1. Quelle phase tu veux prioriser ?
2. Firebase ou autre cloud ?
3. Fonctionnalités "must-have" vs "nice-to-have" ?

**Je continue avec :**

- Fix images (Phase 2) ?
- Nouveau design (Phase 4) ?
- Setup cloud (Phase 3) ?
