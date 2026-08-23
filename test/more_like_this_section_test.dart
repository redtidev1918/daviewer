import 'dart:async';

import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:daviewer/features/artwork/artwork_detail_providers.dart';
import 'package:daviewer/features/artwork/more_like_this.dart';
import 'package:daviewer/features/artwork/more_like_this_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a website failure cannot be hidden by an empty official fallback', () {
    expect(
      () => resolveOfficialMoreLikeThisFallback(
        const MoreLikeThisResult(artworks: <Artwork>[]),
        websiteError: const FormatException('partial page'),
      ),
      throwsA(isA<MoreLikeThisFailure>()),
    );
  });

  test('two successful empty sources remain a normal empty result', () {
    final result = resolveOfficialMoreLikeThisFallback(
      const MoreLikeThisResult(artworks: <Artwork>[]),
    );

    expect(result.artworks, isEmpty);
  });

  testWidgets('an empty result explains both sources and checks again', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          moreLikeThisProvider('art-id').overrideWith((ref) async {
            attempts++;
            return const MoreLikeThisResult(artworks: <Artwork>[]);
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MoreLikeThisSection(artworkId: 'art-id'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('网页和备用来源'), findsOneWidget);
    expect(find.text('检查更新'), findsOneWidget);
    expect(find.text('重试'), findsNothing);
    expect(find.text('重新加载'), findsNothing);

    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.textContaining('已重新检查'), findsWidgets);
  });

  testWidgets('a transient failure retries once then explains the cause', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          moreLikeThisProvider('art-id').overrideWith((ref) async {
            attempts++;
            throw DioException(
              requestOptions: RequestOptions(path: '/related'),
              type: DioExceptionType.connectionError,
            );
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MoreLikeThisSection(artworkId: 'art-id'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.textContaining('网络连接失败'), findsOneWidget);
    expect(find.text('重新加载'), findsOneWidget);
    expect(find.text('重试'), findsNothing);
  });

  testWidgets('refresh keeps current cards visible until new items arrive', (
    tester,
  ) async {
    var attempts = 0;
    final refreshed = Completer<MoreLikeThisResult>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          moreLikeThisProvider('art-id').overrideWith((ref) async {
            attempts++;
            if (attempts == 1) {
              return MoreLikeThisResult(
                artworks: <Artwork>[_artwork('old', 'Current suggestion')],
              );
            }
            return refreshed.future;
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MoreLikeThisSection(artworkId: 'art-id'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('检查更新'));
    await tester.pump();

    expect(find.text('Current suggestion'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    refreshed.complete(
      MoreLikeThisResult(
        artworks: <Artwork>[_artwork('new', 'New suggestion')],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New suggestion'), findsOneWidget);
    expect(find.textContaining('已更新'), findsOneWidget);
  });
}

Artwork _artwork(String id, String title) => Artwork(
  id: id,
  title: title,
  author: UserProfile(id: 'user-$id', username: 'artist'),
  pageUri: Uri.parse('https://www.deviantart.com/artist/art/work-$id'),
  media: const <MediaAsset>[],
);
