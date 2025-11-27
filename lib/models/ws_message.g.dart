// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WSMessage _$WSMessageFromJson(Map<String, dynamic> json) => WSMessage(
  type: $enumDecode(_$WSMessageTypeEnumMap, json['type']),
  data: json['data'] as Map<String, dynamic>,
  timestamp: json['timestamp'] == null
      ? null
      : DateTime.parse(json['timestamp'] as String),
  error: json['error'] as String?,
);

Map<String, dynamic> _$WSMessageToJson(WSMessage instance) => <String, dynamic>{
  'type': _$WSMessageTypeEnumMap[instance.type]!,
  'data': instance.data,
  'timestamp': instance.timestamp.toIso8601String(),
  'error': instance.error,
};

const _$WSMessageTypeEnumMap = {
  WSMessageType.message: 'message',
  WSMessageType.typing: 'typing',
  WSMessageType.readReceipt: 'read_receipt',
  WSMessageType.error: 'error',
};
