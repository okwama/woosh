// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProductHiveModelAdapter extends TypeAdapter<ProductHiveModel> {
  @override
  final int typeId = 21;

  @override
  ProductHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProductHiveModel(
      id: fields[0] as int,
      productCode: fields[1] as String,
      productName: fields[2] as String,
      category_id: fields[3] as int,
      category: fields[4] as String?,
      description: fields[5] as String?,
      unitOfMeasure: fields[6] as String?,
      costPrice: fields[7] as double?,
      sellingPrice: fields[8] as double?,
      reorderLevel: fields[9] as int?,
      currentStock: fields[10] as int?,
      isActive: fields[11] as bool?,
      createdAt: fields[12] as String,
      updatedAt: fields[13] as String,
      imageUrl: fields[14] as String?,
      defaultPriceOptionId: fields[15] as int?,
      defaultPriceOptionLabel: fields[16] as String?,
      defaultPriceValue: fields[17] as double?,
      defaultPriceValueTzs: fields[18] as double?,
      defaultPriceValueNgn: fields[19] as double?,
      defaultPriceCategoryId: fields[20] as int?,
      storeInventoryData: (fields[21] as List)
          .map((dynamic e) => (e as Map).cast<String, dynamic>())
          .toList(),
    );
  }

  @override
  void write(BinaryWriter writer, ProductHiveModel obj) {
    writer
      ..writeByte(22)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.productCode)
      ..writeByte(2)
      ..write(obj.productName)
      ..writeByte(3)
      ..write(obj.category_id)
      ..writeByte(4)
      ..write(obj.category)
      ..writeByte(5)
      ..write(obj.description)
      ..writeByte(6)
      ..write(obj.unitOfMeasure)
      ..writeByte(7)
      ..write(obj.costPrice)
      ..writeByte(8)
      ..write(obj.sellingPrice)
      ..writeByte(9)
      ..write(obj.reorderLevel)
      ..writeByte(10)
      ..write(obj.currentStock)
      ..writeByte(11)
      ..write(obj.isActive)
      ..writeByte(12)
      ..write(obj.createdAt)
      ..writeByte(13)
      ..write(obj.updatedAt)
      ..writeByte(14)
      ..write(obj.imageUrl)
      ..writeByte(15)
      ..write(obj.defaultPriceOptionId)
      ..writeByte(16)
      ..write(obj.defaultPriceOptionLabel)
      ..writeByte(17)
      ..write(obj.defaultPriceValue)
      ..writeByte(18)
      ..write(obj.defaultPriceValueTzs)
      ..writeByte(19)
      ..write(obj.defaultPriceValueNgn)
      ..writeByte(20)
      ..write(obj.defaultPriceCategoryId)
      ..writeByte(21)
      ..write(obj.storeInventoryData);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
