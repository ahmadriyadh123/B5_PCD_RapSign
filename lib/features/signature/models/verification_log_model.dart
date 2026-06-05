import 'package:hive/hive.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

part 'verification_log_model.g.dart';

/// Status hasil verifikasi tanda tangan
enum VerificationStatus { valid, invalid, error }

@HiveType(typeId: 2)
class VerificationLogModel {
  @HiveField(0)
  final String? id;

  @HiveField(1)
  final String verifiedBy; // username yang melakukan verifikasi

  @HiveField(2)
  final String enrolledLabel; // label pemilik ttd yang diklaim

  @HiveField(3)
  final String predictedLabel; // label prediksi CNN

  @HiveField(4)
  final double similarityScore; // 0.0 - 1.0

  @HiveField(5)
  final String verificationResult; // "valid" | "invalid"

  @HiveField(6)
  final String timestamp;

  @HiveField(7)
  final bool isSynced;

  @HiveField(8)
  final String? notes; // catatan tambahan opsional

  VerificationLogModel({
    this.id,
    required this.verifiedBy,
    required this.enrolledLabel,
    required this.predictedLabel,
    required this.similarityScore,
    required this.verificationResult,
    required this.timestamp,
    this.isSynced = false,
    this.notes,
  });

  VerificationStatus get status {
    if (verificationResult == 'valid') return VerificationStatus.valid;
    if (verificationResult == 'invalid') return VerificationStatus.invalid;
    return VerificationStatus.error;
  }

  VerificationLogModel copyWith({bool? isSynced}) {
    return VerificationLogModel(
      id: id,
      verifiedBy: verifiedBy,
      enrolledLabel: enrolledLabel,
      predictedLabel: predictedLabel,
      similarityScore: similarityScore,
      verificationResult: verificationResult,
      timestamp: timestamp,
      isSynced: isSynced ?? this.isSynced,
      notes: notes,
    );
  }

  Map<String, dynamic> toMap() => {
        '_id': id != null ? ObjectId.fromHexString(id!) : ObjectId(),
        'verifiedBy': verifiedBy,
        'enrolledLabel': enrolledLabel,
        'predictedLabel': predictedLabel,
        'similarityScore': similarityScore,
        'verificationResult': verificationResult,
        'timestamp': timestamp,
        'notes': notes,
      };

  factory VerificationLogModel.fromMap(Map<String, dynamic> map) {
    return VerificationLogModel(
      id: (map['_id'] as ObjectId?)?.oid,
      verifiedBy: map['verifiedBy'] ?? '',
      enrolledLabel: map['enrolledLabel'] ?? '',
      predictedLabel: map['predictedLabel'] ?? '',
      similarityScore: (map['similarityScore'] as num?)?.toDouble() ?? 0.0,
      verificationResult: map['verificationResult'] ?? 'error',
      timestamp: map['timestamp'] ?? '',
      isSynced: true,
      notes: map['notes'],
    );
  }

  factory VerificationLogModel.fromJson(
    Map<String, dynamic> json, {
    required String verifiedBy,
  }) {
    return VerificationLogModel(
      id: ObjectId().oid,
      verifiedBy: verifiedBy,
      enrolledLabel: json['enrolled_label'] ?? '',
      predictedLabel: json['predicted_label'] ?? '',
      similarityScore: (json['similarity_score'] as num?)?.toDouble() ?? 0.0,
      verificationResult: json['verification_result'] ?? 'error',
      timestamp: DateTime.now().toIso8601String(),
      isSynced: false,
      notes: null,
    );
  }
}