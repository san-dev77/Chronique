import 'package:hive/hive.dart';
import '../models/spark.dart';
import 'auth_service.dart';
import 'cloud_sync_service.dart';

class SparkService {
  static const String _boxPrefix = 'sparks_';
  static SparkService? _instance;
  static Box? _sparkBox;

  SparkService._();

  static SparkService get instance {
    _instance ??= SparkService._();
    return _instance!;
  }

  Future<void> initialize() async {
    final userId = AuthService.instance.userId;
    final boxName = userId != null ? '${_boxPrefix}$userId' : '${_boxPrefix}local';
    
    if (_sparkBox != null && _sparkBox!.isOpen && _sparkBox!.name != boxName) {
      await _sparkBox!.close();
      _sparkBox = null;
    }

    if (_sparkBox == null || !_sparkBox!.isOpen) {
      _sparkBox = await Hive.openBox(boxName);
    }
  }

  List<Spark> getAllSparks() {
    if (_sparkBox == null || !_sparkBox!.isOpen) return [];
    
    final sparksData = _sparkBox!.values.toList();
    final sparks = sparksData
        .map((data) => Spark.fromJson(Map<String, dynamic>.from(data)))
        .toList();

    sparks.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return sparks;
  }

  Future<void> saveSpark(Spark spark, {bool skipCloud = false}) async {
    if (_sparkBox == null || !_sparkBox!.isOpen) return;
    
    // Si ce n'est pas une sync descendante, on met à jour la date
    if (!skipCloud) {
       spark.modifiedAt = DateTime.now();
    }
    
    await _sparkBox!.put(spark.id, spark.toJson());

    // Sync cloud si disponible
    if (!skipCloud && AuthService.instance.isSignedIn) {
      try {
        await CloudSyncService.instance.uploadSpark(spark);
      } catch (e) {
        print('Échec sync auto spark ${spark.id}: $e');
      }
    }
  }

  Future<void> deleteSpark(String id) async {
    if (_sparkBox == null || !_sparkBox!.isOpen) return;
    await _sparkBox!.delete(id);

    // Suppression cloud
    if (AuthService.instance.isSignedIn) {
      try {
        await CloudSyncService.instance.deleteSparkFromCloud(id);
      } catch (e) {
        print('Échec sync auto suppression spark $id: $e');
      }
    }
  }

  Future<void> clearAll() async {
    if (_sparkBox == null || !_sparkBox!.isOpen) return;
    await _sparkBox!.clear();
  }
}
