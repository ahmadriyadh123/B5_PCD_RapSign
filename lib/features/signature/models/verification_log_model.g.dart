// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'verification_log_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class VerificationLogModelAdapter extends TypeAdapter<VerificationLogModel> {
  @override
  final int typeId = 2;

  @override
  VerificationLogModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return VerificationLogModel(
      id: fields[0] as String?,
      verifiedBy: fields[1] as String,
      enrolledLabel: fields[2] as String,
      predictedLabel: fields[3] as String,
      similarityScore: fields[4] as double,
      verificationResult: fields[5] as String,
      timestamp: fields[6] as String,
      isSynced: fields[7] is bool ? fields[7] as bool : false,
      notes: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, VerificationLogModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.verifiedBy)
      ..writeByte(2)
      ..write(obj.enrolledLabel)
      ..writeByte(3)
      ..write(obj.predictedLabel)
      ..writeByte(4)
      ..write(obj.similarityScore)
      ..writeByte(5)
      ..write(obj.verificationResult)
      ..writeByte(6)
      ..write(obj.timestamp)
      ..writeByte(7)
      ..write(obj.isSynced)
      ..writeByte(8)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VerificationLogModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}