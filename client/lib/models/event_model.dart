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

  EventResponse({
    required this.eventUuid,
    required this.eventName,
    required this.eventDescription,
    required this.isOrganiser,
  });

  factory EventResponse.fromJson(Map<String, dynamic> json) {
    return EventResponse(
      eventUuid: json['event_uuid'] ?? '',
      eventName: json['event_name'] ?? '',
      eventDescription: json['event_description'] ?? '',
      isOrganiser: json['is_organiser'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event_uuid': eventUuid,
      'event_name': eventName,
      'event_description': eventDescription,
      'is_organiser': isOrganiser,
    };
  }
}
