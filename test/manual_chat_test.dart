// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:npo_community/core/services/chat_service.dart';

void main() {
  test('manual chat runner (skipped)', () {}, skip: true);
}

Future<void> runManualChatTest() async {
  print('🚀 Starting Chat Service Test...');

  final chatService = ChatService();

  const testChannelId = 'test-channel-123';

  try {
    print('🔌 Connecting to WebSocket...');

    final messageStream = chatService.connectToChatChannel(testChannelId);

    final subscription = messageStream.listen(
      (message) {
        print('📨 Received message: ${message.type}');
        print('   Data: ${message.data}');

        if (message.isTyping) {
          final userId = message.data['user_id'];
          final isTyping = message.data['is_typing'];
          print(
            '   👉 User $userId is ${isTyping ? 'typing...' : 'not typing'}',
          );
        } else if (message.isMessage) {
          print('   💬 New message: ${message.data}');
        } else if (message.isReadReceipt) {
          print('   ✅ Message read: ${message.data}');
        }
      },
      onError: (error, stackTrace) {
        print('❌ Error: $error');
        print('Stack trace: $stackTrace');
      },
      onDone: () {
        print('📡 WebSocket connection closed');
      },
    );

    print('\n💬 Sending test message...');
    try {
      final message = await chatService.sendChannelMessage(
        channelId: testChannelId,
        content: 'Hello from test client!',
      );
      print('✅ Message sent successfully! ID: ${message.id}');
    } catch (e) {
      print('❌ Failed to send message: $e');
    }

    print('\n⌨️ Sending typing indicator...');
    await chatService.sendTypingIndicator(testChannelId, true);
    print('✅ Typing indicator sent!');

    await Future.delayed(const Duration(seconds: 2));
    await chatService.sendTypingIndicator(testChannelId, false);
    print('✅ Stopped typing indicator sent!');

    print('\n👂 Listening for incoming messages for 30 seconds...');
    print('   (Press Ctrl+C to exit early)');

    Timer(const Duration(seconds: 30), () {
      print('\n⏱️ Test complete!');
      subscription.cancel();
      chatService.dispose();
      exit(0);
    });

    ProcessSignal.sigint.watch().listen((_) {
      print('\n👋 Exiting...');
      subscription.cancel();
      chatService.dispose();
      exit(0);
    });
  } catch (e, stackTrace) {
    print('❌ Fatal error: $e');
    print('Stack trace: $stackTrace');
    chatService.dispose();
    exit(1);
  }
}
