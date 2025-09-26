import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:subscription_manager/services/cancellation_links_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const assetPath = 'assets/cancellation_links.json';
  const assetJson =
      '{"Netflix":"https://netflix.com/cancel","Spotify":"https://spotify.com/cancel"}';

  late int assetRequests;
  late TestDefaultBinaryMessenger messenger;

  setUp(() {
    assetRequests = 0;
    messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler(
      'flutter/assets',
      (message) async {
        final encoded = utf8.encoder.convert(assetJson);
        if (utf8.decode(message!.buffer.asUint8List()) == assetPath) {
          assetRequests++;
          return ByteData.view(encoded.buffer);
        }
        return null;
      },
    );
  });

  tearDown(() {
    messenger.setMockMessageHandler('flutter/assets', null);
  });

  test('load reads asset once and normalises keys', () async {
    final service = CancellationLinksService();

    await service.load();

    expect(assetRequests, 1);
    expect(service.getLink('netflix'), 'https://netflix.com/cancel');
    expect(service.getLink('Spotify'), 'https://spotify.com/cancel');
    expect(service.links.length, 2);
  });

  test('subsequent load calls reuse cached data', () async {
    final service = CancellationLinksService();

    await service.load();
    final previousRequests = assetRequests;

    messenger.setMockMessageHandler(
      'flutter/assets',
      (_) async => throw StateError('Should not reload asset'),
    );

    await service.load();

    expect(assetRequests, previousRequests);
    expect(service.getLink('spotify'), 'https://spotify.com/cancel');
  });
}
