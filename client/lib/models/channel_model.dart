class ChannelRequest {
  final String channelName;
  final String? eventUuid;

  ChannelRequest({
    required this.channelName,
    this.eventUuid,
  });

  Map<String, dynamic> toJson() {
    return {
      'channel_name': channelName,
      'event_uuid': eventUuid,
    };
  }
}

class ChannelResponse {
  final String channelUuid;
  final String channelName;
  final String? eventUuid;

  ChannelResponse({
    required this.channelUuid,
    required this.channelName,
    this.eventUuid,
  });

  factory ChannelResponse.fromJson(Map<String, dynamic> json) {
    return ChannelResponse(
      channelUuid: json['channel_uuid'] ?? '',
      channelName: json['channel_name'] ?? '',
      eventUuid: json['event_uuid'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'channel_uuid': channelUuid,
      'channel_name': channelName,
      'event_uuid': eventUuid,
    };
  }
}
