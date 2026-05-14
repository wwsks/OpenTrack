import 'package:hive/hive.dart';

part 'package.g.dart';

@HiveType(typeId: 0)
class Package extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String trackingNumber;

  @HiveField(2)
  String companyCode;

  @HiveField(3)
  String companyName;

  @HiveField(4)
  String status;

  @HiveField(5)
  String lastContext;

  @HiveField(6)
  DateTime lastTime;

  @HiveField(7)
  DateTime addedTime;

  @HiveField(8)
  bool isSigned;

  @HiveField(9)
  String? phone;

  @HiveField(10)
  String? remark;

  Package({
    required this.id,
    required this.trackingNumber,
    required this.companyCode,
    required this.companyName,
    this.status = 'collected',
    this.lastContext = '',
    DateTime? lastTime,
    DateTime? addedTime,
    this.isSigned = false,
    this.phone,
    this.remark,
  })  : lastTime = lastTime ?? DateTime.now(),
        addedTime = addedTime ?? DateTime.now();
}
