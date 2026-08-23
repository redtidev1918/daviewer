import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:daviewer/features/artwork/more_like_this_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('classifies network, session, service and page-format failures', () {
    expect(
      classifyMoreLikeThisFailure(<Object?>[
        DioException(
          requestOptions: RequestOptions(path: '/related'),
          type: DioExceptionType.connectionError,
        ),
      ]),
      MoreLikeThisFailureKind.network,
    );
    expect(
      classifyMoreLikeThisFailure(<Object?>[
        const DAKitException(
          kind: DAKitFailureKind.authentication,
          code: 'auth.expired',
          message: 'expired',
        ),
      ]),
      MoreLikeThisFailureKind.session,
    );
    expect(
      classifyMoreLikeThisFailure(<Object?>[
        const DAKitException(
          kind: DAKitFailureKind.rateLimit,
          code: 'api.rate_limit',
          message: 'limited',
        ),
      ]),
      MoreLikeThisFailureKind.service,
    );
    expect(
      classifyMoreLikeThisFailure(<Object?>[const FormatException('changed')]),
      MoreLikeThisFailureKind.pageFormat,
    );
    expect(
      classifyMoreLikeThisFailure(<Object?>[
        DioException(
          requestOptions: RequestOptions(path: '/artwork'),
          response: Response<void>(
            requestOptions: RequestOptions(path: '/artwork'),
            statusCode: 403,
          ),
          type: DioExceptionType.badResponse,
        ),
      ]),
      MoreLikeThisFailureKind.service,
    );
  });

  test(
    'typed failure preserves both source errors and prioritizes session',
    () {
      const failure = MoreLikeThisFailure(
        websiteError: FormatException('website changed'),
        officialError: DAKitException(
          kind: DAKitFailureKind.authorization,
          code: 'api.forbidden',
          message: 'forbidden',
        ),
      );

      expect(failure.kind, MoreLikeThisFailureKind.session);
      expect('$failure', contains('website changed'));
      expect('$failure', contains('forbidden'));
    },
  );
}
