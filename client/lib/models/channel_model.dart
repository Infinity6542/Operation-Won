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
  final String? inviteCode;
  final bool isCreator;

  ChannelResponse({
    required this.channelUuid,
    required this.channelName,
    this.eventUuid,
    this.inviteCode,
    this.isCreator = false,
  });

  factory ChannelResponse.fromJson(Map<String, dynamic> json) {
    return ChannelResponse(
      channelUuid: json['channel_uuid'] ?? '',
      channelName: json['channel_name'] ?? '',
      eventUuid: json['event_uuid'],
      inviteCode: json['invite_code'],
      isCreator: json['is_creator'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'channel_uuid': channelUuid,
      'channel_name': channelName,
      'event_uuid': eventUuid,
      'invite_code': inviteCode,
      'is_creator': isCreator,
    };
  }
}
