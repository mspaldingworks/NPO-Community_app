import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';

part 'ws_message.g.dart';

/// Represents a WebSocket message for real-time chat
@JsonEnum()
enum WSMessageType {
  @JsonValue('message')
  message,
  @JsonValue('typing')
  typing,
  @JsonValue('read_receipt')
  readReceipt,
  @JsonValue('error')
  error,
}

@JsonSerializable()
class WSMessage {
  final WSMessageType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final String? error;

  WSMessage({
    required this.type,
    required this.data,
    DateTime? timestamp,
    this.error,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Creates a WSMessage from a JSON map
  factory WSMessage.fromJson(Map<String, dynamic> json) => 
      _$WSMessageFromJson(json);

  /// Converts this message to a JSON map
  Map<String, dynamic> toJson() => _$WSMessageToJson(this);

  /// Creates a WSMessage from a JSON string
  factory WSMessage.fromJsonString(String jsonString) {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return WSMessage.fromJson(json);
    } catch (e) {
      throw FormatException('Failed to parse WSMessage: $e');
    }
  }

  /// Converts this message to a JSON string
  String toJsonString() => jsonEncode(toJson());

  // Getters for common message types
  bool get isMessage => type == WSMessageType.message;
  bool get isTyping => type == WSMessageType.typing;
  bool get isReadReceipt => type == WSMessageType.readReceipt;
  bool get isError => type == WSMessageType.error;
}

/// Extension methods for WSMessage
extension WSMessageExtension on WSMessage {
  bool get isMessage => type == WSMessageType.message;
  bool get isTyping => type == WSMessageType.typing;
  bool get isReadReceipt => type == WSMessageType.readReceipt;
  bool get isError => type == WSMessageType.error;
}
