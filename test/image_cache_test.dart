import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:story_box/services/image_base64_service.dart';

/// Fabrique une chaine base64 d'environ [kilobytes] kilo-octets.
///
/// Le motif depend de [graine] pour que deux appels differents ne produisent
/// pas la meme image : le cache se distinguerait sinon de lui-meme.
String _image(int kilobytes, {int graine = 0}) {
  final bytes = Uint8List(kilobytes * 1024);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = (i * 31 + graine * 7) & 0xFF;
  }
  return 'data:image/jpeg;base64,${base64Encode(bytes)}';
}

void main() {
  final service = ImageBase64Service.instance;

  setUp(service.clearCache);

  group('Cache de decodage base64', () {
    test('une petite image est servie depuis le cache', () {
      final petite = _image(8);

      final premier = service.decodeBase64ToBytes(petite);
      final second = service.decodeBase64ToBytes(petite);

      expect(premier, isNotNull);
      expect(identical(premier, second), isTrue,
          reason: 'le second appel doit rendre exactement le meme tableau');
    });

    test('une grande image est mise en cache elle aussi', () {
      // C'est la regression a tenir. Le cache a d'abord refuse toute entree
      // au-dela de quarante-huit kilo-octets, pour borner la memoire. Les
      // photos des chroniques depassent toutes ce seuil : elles se
      // redecodaient donc depuis le base64 a chaque reconstruction de
      // widget, sur le thread d'interface, ce qui hachait le defilement.
      final grande = _image(400);

      final premier = service.decodeBase64ToBytes(grande);
      final second = service.decodeBase64ToBytes(grande);

      expect(premier, isNotNull);
      expect(premier!.lengthInBytes, 400 * 1024);
      expect(identical(premier, second), isTrue,
          reason: 'une photo de 400 Ko doit rester en cache');
    });

    test('deux images distinctes ne se confondent pas', () {
      // La cle est derivee de la longueur et des extremites de la chaine,
      // pas de son contenu entier. Deux images de meme taille doivent
      // malgre tout rester distinctes.
      final a = service.decodeBase64ToBytes(_image(64, graine: 1));
      final b = service.decodeBase64ToBytes(_image(64, graine: 2));

      expect(a, isNotNull);
      expect(b, isNotNull);
      expect(a, isNot(equals(b)));
    });

    test('le cache reste borne et evince les plus anciennes', () {
      // Vingt-quatre mega-octets de borne : trente images de deux mega-octets
      // n'y tiennent pas, la premiere doit donc etre sortie.
      final premiere = _image(2048, graine: 100);
      final initial = service.decodeBase64ToBytes(premiere);
      expect(initial, isNotNull);

      for (var i = 0; i < 20; i++) {
        service.decodeBase64ToBytes(_image(2048, graine: 200 + i));
      }

      final apres = service.decodeBase64ToBytes(premiere);
      expect(apres, isNotNull, reason: 'elle se redecode sans erreur');
      expect(identical(initial, apres), isFalse,
          reason: 'la plus ancienne doit avoir ete evincee du cache');
    });

    test('une image enorme ne prend pas le cache a elle seule', () {
      // Au-dela de trois mega-octets, on decode sans retenir : sinon une
      // seule photo chasserait tout le reste.
      final enorme = _image(4096);

      final premier = service.decodeBase64ToBytes(enorme);
      final second = service.decodeBase64ToBytes(enorme);

      expect(premier, isNotNull);
      expect(identical(premier, second), isFalse);
    });

    test('clearCache rend la memoire', () {
      final image = _image(16);
      final premier = service.decodeBase64ToBytes(image);

      service.clearCache();

      final second = service.decodeBase64ToBytes(image);
      expect(identical(premier, second), isFalse);
    });
  });
}
