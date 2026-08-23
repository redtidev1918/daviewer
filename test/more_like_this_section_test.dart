import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:daviewer/features/artwork/artwork_detail_providers.dart';
import 'package:daviewer/features/artwork/more_like_this.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('an empty related result is normal and offers no retry action', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          moreLikeThisProvider('art-id').overrideWith(
            (ref) async => const MoreLikeThisResult(artworks: <Artwork>[]),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: MoreLikeThisSection(artworkId: 'art-id')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('暂时没有找到类似作品'), findsOneWidget);
    expect(find.text('重试'), findsNothing);
    expect(find.text('重新加载'), findsNothing);
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
          home: Scaffold(body: MoreLikeThisSection(artworkId: 'art-id')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.textContaining('网络连接失败'), findsOneWidget);
    expect(find.text('重新加载'), findsOneWidget);
    expect(find.text('重试'), findsNothing);
  });
}
