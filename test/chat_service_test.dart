import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:npo_community/core/services/chat_service.dart';
import 'package:npo_community/core/services/shared_preferences_service.dart';
import 'package:npo_community/models/ws_message.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class MockWebSocketChannel extends Mock implements WebSocketChannel {}

void main() {
  // Skipped: these open a real WebSocket to the configured API origin, so they
  // fail asynchronously after the test completes whenever no server is
  // listening — which is always, in CI. They also assert almost nothing
  // (`expect(true, isTrue)` inside a catch). Unskip once ChatService takes an
  // injectable channel factory the way ApiClient takes debugHttpClientOverride.
  group('ChatService Tests', skip: 'needs an injectable WebSocket channel', () {
    late ChatService chatService;
    const testChannelId = 'test-channel-123';

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({'user_token': 'test-token'});
      await SharedPreferencesService().init();
    });

    setUp(() {
      chatService = ChatService();
    });

    tearDown(() {
      chatService.dispose();
    });

    test('connectToChatChannel returns a stream', () {
      try {
        final stream = chatService.connectToChatChannel(testChannelId);
        expect(stream, isA<Stream<WSMessage>>());
        chatService.disconnectFromChatChannel(testChannelId);
      } catch (e) {
        expect(e, anyOf(isA<Exception>(), isA<StateError>()));
      }
    });

    test('sendMessage adds message to the sink', () async {
      // Arrange
      const messageContent = 'Hello, test message!';

      // Act & Assert
      try {
        await chatService.sendChannelMessage(
          channelId: testChannelId,
          content: messageContent,
        );
        // If we get here, the message was sent successfully
        expect(true, isTrue);
      } catch (e) {
        // We expect this to fail in test environment, but we're testing the API contract
        expect(e, anyOf(isA<Exception>(), isA<StateError>()));
      }
    });

    test('disconnectFromChatChannel closes the connection', () {
      // Arrange
      try {
        chatService.connectToChatChannel(testChannelId);
      } catch (e) {
        expect(e, anyOf(isA<Exception>(), isA<StateError>()));
        return;
      }

      // Act
      chatService.disconnectFromChatChannel(testChannelId);

      // Assert
      expect(chatService.isConnected(testChannelId), isFalse);
    });

    test('typing indicator is sent', () async {
      // Act & Assert
      try {
        await chatService.sendTypingIndicator(testChannelId, true);
        // If we get here, the typing indicator was sent
        expect(true, isTrue);
      } catch (e) {
        // We expect this to fail in test environment, but we're testing the API contract
        expect(e, isA<Exception>());
      }
    });
  });
}
