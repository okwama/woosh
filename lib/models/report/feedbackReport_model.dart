class FeedbackReport {
  final int reportId;
  final String? comment;
  final DateTime createdAt;

  FeedbackReport({
    required this.reportId,
    this.comment,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'reportId': reportId,
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory FeedbackReport.fromJson(Map<String, dynamic> json) {
    return FeedbackReport(
      reportId: json['reportId'],
      comment: json['comment'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
