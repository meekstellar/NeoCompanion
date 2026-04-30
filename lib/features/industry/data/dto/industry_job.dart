/// One row from `/characters/{id}/industry/jobs/`.
class IndustryJob {
  const IndustryJob({
    required this.jobId,
    required this.installerId,
    required this.facilityId,
    required this.stationId,
    required this.activityId,
    required this.blueprintId,
    required this.blueprintTypeId,
    required this.blueprintLocationId,
    required this.outputLocationId,
    required this.runs,
    required this.cost,
    required this.licensedRuns,
    required this.probability,
    required this.productTypeId,
    required this.status,
    required this.duration,
    required this.startDate,
    required this.endDate,
    required this.pauseDate,
    required this.completedDate,
    required this.completedCharacterId,
    required this.successfulRuns,
  });

  final int jobId;
  final int installerId;
  final int facilityId;
  final int stationId;

  /// 1=manufacturing, 3=TE research, 4=ME research, 5=copying,
  /// 7=reverse engineering, 8=invention, 9=reactions.
  final int activityId;
  final int blueprintId;
  final int blueprintTypeId;
  final int blueprintLocationId;
  final int outputLocationId;
  final int runs;
  final double? cost;
  final int? licensedRuns;
  final double? probability;
  final int? productTypeId;

  /// active | cancelled | delivered | paused | ready | reverted
  final String status;

  /// Total scheduled duration in seconds.
  final int duration;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime? pauseDate;
  final DateTime? completedDate;
  final int? completedCharacterId;
  final int? successfulRuns;

  bool get isActive => status == 'active';
  bool get isReady => status == 'ready' ||
      (isActive && DateTime.now().toUtc().isAfter(endDate));

  /// Where the job is *displayed* to live: facility for citadels,
  /// station for NPC stations. ESI fills both, so picking either
  /// works for resolution; we prefer facility because it's the more
  /// modern field.
  int get locationId => facilityId != 0 ? facilityId : stationId;

  factory IndustryJob.fromJson(Map<String, dynamic> json) {
    DateTime parse(String key) => DateTime.parse(json[key] as String);
    DateTime? parseOpt(String key) {
      final v = json[key];
      return v is String && v.isNotEmpty ? DateTime.parse(v) : null;
    }

    return IndustryJob(
      jobId: (json['job_id'] as num).toInt(),
      installerId: (json['installer_id'] as num).toInt(),
      facilityId: (json['facility_id'] as num?)?.toInt() ?? 0,
      stationId: (json['station_id'] as num?)?.toInt() ?? 0,
      activityId: (json['activity_id'] as num).toInt(),
      blueprintId: (json['blueprint_id'] as num).toInt(),
      blueprintTypeId: (json['blueprint_type_id'] as num).toInt(),
      blueprintLocationId:
          (json['blueprint_location_id'] as num?)?.toInt() ?? 0,
      outputLocationId: (json['output_location_id'] as num?)?.toInt() ?? 0,
      runs: (json['runs'] as num).toInt(),
      cost: (json['cost'] as num?)?.toDouble(),
      licensedRuns: (json['licensed_runs'] as num?)?.toInt(),
      probability: (json['probability'] as num?)?.toDouble(),
      productTypeId: (json['product_type_id'] as num?)?.toInt(),
      status: json['status'] as String? ?? 'unknown',
      duration: (json['duration'] as num).toInt(),
      startDate: parse('start_date'),
      endDate: parse('end_date'),
      pauseDate: parseOpt('pause_date'),
      completedDate: parseOpt('completed_date'),
      completedCharacterId:
          (json['completed_character_id'] as num?)?.toInt(),
      successfulRuns: (json['successful_runs'] as num?)?.toInt(),
    );
  }
}
