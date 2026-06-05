import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logbook_app_001/features/signature/models/verification_log_model.dart';
import 'package:logbook_app_001/helpers/log_helper.dart';

/// Service MongoDB khusus untuk verification logs (terpisah dari LogService)
class VerificationMongoService {
  static final VerificationMongoService _instance =
      VerificationMongoService._internal();
  Db? _db;
  DbCollection? _collection;
  final String _source = 'verification_mongo_service.dart';

  factory VerificationMongoService() => _instance;
  VerificationMongoService._internal();

  Future<DbCollection> _getSafeCollection() async {
    if (_db == null || !_db!.isConnected || _collection == null) {
      await connect();
    }
    return _collection!;
  }

  Future<void> connect() async {
    try {
      final dbUri = dotenv.env['MONGODB_URI'];
      if (dbUri == null) throw Exception('MONGODB_URI tidak ditemukan di .env');

      _db = await Db.create(dbUri);
      await _db!.open().timeout(
            const Duration(seconds: 15),
            onTimeout: () =>
                throw Exception('Koneksi Timeout saat verifikasi MongoDB.'),
          );

      // Collection terpisah: verification_logs
      _collection = _db!.collection('verification_logs');

      await LogHelper.writeLog(
        'VerificationMongo: Terhubung ke collection verification_logs',
        source: _source,
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        'VerificationMongo: Gagal koneksi - $e',
        source: _source,
        level: 1,
      );
      rethrow;
    }
  }

  /// Simpan hasil verifikasi ke MongoDB
  Future<void> insertLog(VerificationLogModel log) async {
    try {
      final collection = await _getSafeCollection();
      await collection.insertOne(log.toMap());
      await LogHelper.writeLog(
        'VerificationMongo: Log tersimpan - ${log.verificationResult} oleh ${log.verifiedBy}',
        source: _source,
        level: 2,
      );
    } catch (e) {
      await LogHelper.writeLog(
        'VerificationMongo: Gagal insert - $e',
        source: _source,
        level: 1,
      );
      rethrow;
    }
  }

  /// Ambil semua log verifikasi (opsional: filter by verifiedBy)
  Future<List<VerificationLogModel>> getLogs({String? verifiedBy}) async {
    try {
      final collection = await _getSafeCollection();
      final selector = verifiedBy != null
          ? where.eq('verifiedBy', verifiedBy)
          : where.exists('_id');

      final data = await collection
          .find(selector.sortBy('timestamp', descending: true))
          .toList();

      return data.map((m) => VerificationLogModel.fromMap(m)).toList();
    } catch (e) {
      await LogHelper.writeLog(
        'VerificationMongo: Gagal fetch - $e',
        source: _source,
        level: 1,
      );
      return [];
    }
  }

  Future<void> close() async {
    await _db?.close();
  }
}