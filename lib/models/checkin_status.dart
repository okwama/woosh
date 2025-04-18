class CheckInStatus {
  final bool isCheckedIn;
  final DateTime? checkInTime;
  final int? officeId;
  final String? officeName;

  CheckInStatus({
    required this.isCheckedIn,
    this.checkInTime,
    this.officeId,
    this.officeName,
  });

  factory CheckInStatus.fromJson(Map<String, dynamic> json) {
    // Debug the incoming JSON
    print('⚠️ CheckInStatus.fromJson received: $json');

    // Safe parsing of isCheckedIn field
    bool parseIsCheckedIn() {
      try {
        final value = json['isCheckedIn'];
        print('⚠️ isCheckedIn value: $value (${value?.runtimeType})');

        if (value == null) return false;
        if (value is bool) return value;
        if (value is int) return value != 0;
        if (value is String) {
          if (value.toLowerCase() == 'true') return true;
          if (value.toLowerCase() == 'false') return false;
          // Try to parse as int
          try {
            return int.parse(value) != 0;
          } catch (_) {
            return false;
          }
        }
        // For any other type, try to convert to boolean
        return value != null;
      } catch (e) {
        print('❌ Error parsing isCheckedIn: $e');
        return false;
      }
    }

    // Safe parsing of DateTime
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      try {
        if (value is String) {
          return DateTime.parse(value);
        }
        return null;
      } catch (e) {
        print('❌ Error parsing DateTime: $e');
        return null;
      }
    }

    // Safe parsing of int
    int? parseInt(dynamic value) {
      if (value == null) return null;
      try {
        if (value is int) return value;
        if (value is String) {
          return int.tryParse(value);
        }
        return null;
      } catch (e) {
        print('❌ Error parsing int: $e');
        return null;
      }
    }

    // Create object with safely parsed values
    final result = CheckInStatus(
      isCheckedIn: parseIsCheckedIn(),
      checkInTime: parseDateTime(json['checkInTime']),
      officeId: parseInt(json['officeId']),
      officeName: json['officeName']?.toString(),
    );

    print('✅ CheckInStatus created: $result');
    return result;
  }

  Map<String, dynamic> toJson() => {
        'isCheckedIn': isCheckedIn,
        'checkInTime': checkInTime?.toIso8601String(),
        'officeId': officeId,
        'officeName': officeName,
      };

  @override
  String toString() {
    return 'CheckInStatus(isCheckedIn: $isCheckedIn, checkInTime: $checkInTime, officeId: $officeId, officeName: $officeName)';
  }
}
