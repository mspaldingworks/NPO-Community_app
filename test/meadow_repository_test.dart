import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transconnect/features/meadow/data/meadow_repository.dart';

void main() {
  group('InMemoryMeadowRepository Meadow lifecycle', () {
    final repo = InMemoryMeadowRepository.instance;

    setUp(() {
      repo.reset();
    });

    test('createChat joins creator and updates participantCount', () async {
      final chat = await repo.createChat(
        topic: 'Test topic',
        createdBy: 'Creator',
        createdByUserId: 'creator-id',
        position: const Offset(10, 20),
      );

      final flowers = await repo.watchChatFlowers().first;
      expect(flowers.length, 1);
      expect(flowers.first.id, chat.id);
      expect(flowers.first.participantCount, 1);
    });

    test('leaveChat removes flower when last participant leaves', () async {
      final chat = await repo.createChat(
        topic: 'Temporary chat',
        createdBy: 'Creator',
        createdByUserId: 'creator-id',
        position: const Offset(10, 20),
      );

      await repo.joinChat(chatId: chat.id, userId: 'other-id');
      var flowers = await repo.watchChatFlowers().first;
      expect(flowers.singleWhere((f) => f.id == chat.id).participantCount, 2);

      await repo.leaveChat(chatId: chat.id, userId: 'other-id');
      flowers = await repo.watchChatFlowers().first;
      expect(flowers.singleWhere((f) => f.id == chat.id).participantCount, 1);

      await repo.leaveChat(chatId: chat.id, userId: 'creator-id');
      flowers = await repo.watchChatFlowers().first;
      expect(flowers, isEmpty);

      await repo.leaveChat(chatId: chat.id, userId: 'creator-id');
      flowers = await repo.watchChatFlowers().first;
      expect(flowers, isEmpty);
    });
  });
}
