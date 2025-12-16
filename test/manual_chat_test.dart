import 'dart:async';
import 'dart:io';
import 'package:transconnect/core/services/chat_service.dart';

Future<void> main() async {
  print('🚀 Starting Chat Service Test...');
  
  // Initialize the chat service
  final chatService = ChatService();
  
  // Test channel ID - replace with a real channel ID from your backend
  const testChannelId = 'test-channel-123';
  
  try {
    print('🔌 Connecting to WebSocket...');
    
    // Connect to the chat channel
    final messageStream = chatService.connectToChatChannel(testChannelId);
    
    // Listen for messages
    final subscription = messageStream.listen(
      (message) {
        print('📨 Received message: ${message.type}');
        print('   Data: ${message.data}');
        
        if (message.isTyping) {
          final userId = message.data['user_id'];
          final isTyping = message.data['is_typing'];
          print('   👉 User $userId is ${isTyping ? 'typing...' : 'not typing'}');
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

    // Send a test message
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

    // Test typing indicator
    print('\n⌨️ Sending typing indicator...');
    await chatService.sendTypingIndicator(testChannelId, true);
    print('✅ Typing indicator sent!');
    
    // Wait a bit, then stop typing
    await Future.delayed(const Duration(seconds: 2));
    await chatService.sendTypingIndicator(testChannelId, false);
    print('✅ Stopped typing indicator sent!');

    // Keep the connection open for a while to test incoming messages
    print('\n👂 Listening for incoming messages for 30 seconds...');
    print('   (Press Ctrl+C to exit early)');
    
    // Set up a timer to automatically close the connection
    Timer(const Duration(seconds: 30), () {
      print('\n⏱️ Test complete!');
      subscription.cancel();
      chatService.dispose();
      exit(0);
    });
    
    // Handle Ctrl+C
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
