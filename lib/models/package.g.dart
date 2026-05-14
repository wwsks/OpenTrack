// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'package.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PackageAdapter extends TypeAdapter<Package> {
  @override
  final int typeId = 0;

  @override
  Package read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Package(
      id: fields[0] as String,
      trackingNumber: fields[1] as String,
      companyCode: fields[2] as String,
      companyName: fields[3] as String,
      status: fields[4] as String,
      lastContext: fields[5] as String,
      lastTime: fields[6] as DateTime?,
      addedTime: fields[7] as DateTime?,
      isSigned: fields[8] as bool,
      phone: fields[9] as String?,
      remark: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Package obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.trackingNumber)
      ..writeByte(2)
      ..write(obj.companyCode)
      ..writeByte(3)
      ..write(obj.companyName)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.lastContext)
      ..writeByte(6)
      ..write(obj.lastTime)
      ..writeByte(7)
      ..write(obj.addedTime)
      ..writeByte(8)
      ..write(obj.isSigned)
      ..writeByte(9)
      ..write(obj.phone)
      ..writeByte(10)
      ..write(obj.remark);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PackageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
