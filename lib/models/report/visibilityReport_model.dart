class VisibilityReport {
  final int reportId;
  final String? comment;
  final String? imageUrl;
  final DateTime createdAt;

  VisibilityReport({
    required this.reportId,
    this.comment,
    this.imageUrl,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'reportId': reportId,
      'comment': comment,
      'imageUrl': imageUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory VisibilityReport.fromJson(Map<String, dynamic> json) {
    return VisibilityReport(
      reportId: json['reportId'],
      comment: json['comment'],
      imageUrl: json['imageUrl'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
