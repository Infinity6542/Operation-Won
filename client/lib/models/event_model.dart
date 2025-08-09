class EventRequest {
  final String eventName;
  final String eventDescription;

  EventRequest({
    required this.eventName,
    this.eventDescription = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'event_name': eventName,
      'event_description': eventDescription,
    };
  }
}

class EventResponse {
  final String eventUuid;
  final String eventName;
  final String eventDescription;
  final bool isOrganiser;
  final String? eventLink;
  final String? inviteCode;
  final int? maxParticipants;
  final bool isPublic;
  final DateTime? startTime;
  final DateTime? endTime;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int participantCount;
  final int channelCount;

  EventResponse({
    required this.eventUuid,
    required this.eventName,
    required this.eventDescription,
    required this.isOrganiser,
    this.eventLink,
    this.inviteCode,
    this.maxParticipants,
    this.isPublic = false,
    this.startTime,
    this.endTime,
    required this.createdAt,
    required this.updatedAt,
    this.participantCount = 0,
    this.channelCount = 0,
  });

  factory EventResponse.fromJson(Map<String, dynamic> json) {
    return EventResponse(
      eventUuid: json['event_uuid'] ?? '',
      eventName: json['event_name'] ?? '',
      eventDescription: json['event_description'] ?? '',
      isOrganiser: json['is_organiser'] ?? false,
      eventLink: json['event_link'],
      inviteCode: json['invite_code'],
      maxParticipants: json['max_participants'],
      isPublic: json['is_public'] ?? false,
      startTime: json['start_time'] != null
          ? DateTime.parse(json['start_time'])
          : null,
      endTime:
          json['end_time'] != null ? DateTime.parse(json['end_time']) : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      participantCount: json['participant_count'] ?? 0,
      channelCount: json['channel_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event_uuid': eventUuid,
      'event_name': eventName,
      'event_description': eventDescription,
      'is_organiser': isOrganiser,
      'event_link': eventLink,
      'invite_code': inviteCode,
      'max_participants': maxParticipants,
      'is_public': isPublic,
      'start_time': startTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'participant_count': participantCount,
      'channel_count': channelCount,
    };
  }

  // Helper getters for UI
  bool get hasScheduledTime => startTime != null;
  bool get isLive =>
      startTime != null &&
      endTime != null &&
      DateTime.now().isAfter(startTime!) &&
      DateTime.now().isBefore(endTime!);
  bool get hasEnded => endTime != null && DateTime.now().isAfter(endTime!);
  bool get isUpcoming =>
      startTime != null && DateTime.now().isBefore(startTime!);

  String get timeStatus {
    if (hasEnded) return 'Ended';
    if (isLive) return 'Live';
    if (isUpcoming) return 'Upcoming';
    return 'Scheduled';
  }
}
