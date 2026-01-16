import 'dart:math';

class GuidanceService {
  static final GuidanceService instance = GuidanceService._();
  GuidanceService._();

  final Random _random = Random();

  final List<String> _sparkPrompts = [
    "Une idée soudaine ? Capturez-la en une étincelle ! ⚡",
    "N'attendez pas que l'inspiration s'envole, créez une étincelle. ✨",
    "Petit rappel : vos grandes chroniques commencent souvent par une simple étincelle.",
    "Une pensée fugace ? Une ligne suffit pour une étincelle.",
    "Et si vous notiez votre idée du moment ? 💡",
  ];

  final List<String> _chroniquePrompts = [
    "Il est temps de raconter votre histoire... 📖",
    "Vos souvenirs méritent d'être écrits. Commencez une chronique.",
    "Qu'avez-vous appris aujourd'hui ? Partagez-le en chronique.",
    "Un moment précieux ? Gravez-le dans une chronique.",
    "Vos chroniques sont les trésors de demain. 💎",
  ];

  final Map<String, List<String>> _timeBasedMessages = {
    'morning': [
      "Bonjour ! Une nouvelle journée pour de nouvelles chroniques. ☀️",
      "Le matin est parfait pour capturer ses rêves. 💭",
      "Prêt à écrire votre première ligne de la journée ?",
      "Un café et une petite étincelle pour bien commencer ?",
      "Une idée lumineuse avant de commencer la journée ?",
      "Une idée lumineuse avant de commencer la journée ?",
    ],
    'afternoon': [
      "Prenez une pause, écrivez un instant. ☕",
      "L'après-midi regorge de moments à capturer.",
      "Une idée lumineuse sous le soleil de l'après-midi ? ☀️",
      "Continuez votre récit, une ligne à la fois.",
      "Une idée lumineuse avant de commencer la journée ?",
    ],
    'evening': [
      "Une pensée avant la fin de journée ? 🌙",
      "Le calme du soir est propice à la réflexion.",
      "Qu'est-ce qui a marqué votre journée aujourd'hui ?",
      "Capturez la magie du soir en une chronique.",
      "Une idée lumineuse avant de dormir ?",
      "Une idée lumineuse avant de commencer la journée ?",
    ],
    'night': [
      "Une inspiration nocturne ? 🌌",
      "Le silence de la nuit fait parler le cœur.",
      "Notez vos pensées avant de rêver.",
      "La nuit est la muse des plus belles histoires.",
      "Une idée lumineuse avant de rêver ?",
      "Une idée lumineuse avant de dormir ?",
      "Libérez vos pensées avant de dormir ?",
    ],
  };

  String getRandomSparkPrompt() =>
      _sparkPrompts[_random.nextInt(_sparkPrompts.length)];
  String getRandomChroniquePrompt() =>
      _chroniquePrompts[_random.nextInt(_chroniquePrompts.length)];

  String getTimeBasedWelcomeMessage() {
    final hour = DateTime.now().hour;
    List<String> messages;
    if (hour >= 5 && hour < 12) {
      messages = _timeBasedMessages['morning']!;
    } else if (hour >= 12 && hour < 18) {
      messages = _timeBasedMessages['afternoon']!;
    } else if (hour >= 18 && hour < 22) {
      messages = _timeBasedMessages['evening']!;
    } else {
      messages = _timeBasedMessages['night']!;
    }
    return messages[_random.nextInt(messages.length)];
  }

  String getDevelopSparkPrompt(String sparkTitle) {
    final List<String> prompts = [
      "Cette étincelle mérite de briller : '$sparkTitle'. La développer ?",
      "Et si on transformait '$sparkTitle' en une véritable chronique ?",
      "L'idée '$sparkTitle' est excellente. Envie d'en dire plus ?",
      "Pourquoi ne pas approfondir '$sparkTitle' maintenant ? ✨",
    ];
    return prompts[_random.nextInt(prompts.length)];
  }
}
