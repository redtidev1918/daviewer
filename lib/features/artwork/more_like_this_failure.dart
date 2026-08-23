import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:dio/dio.dart';

import '../../core/data/web_session.dart';

enum MoreLikeThisFailureKind { network, session, service, pageFormat, unknown }

/// Preserves failures from both related-artwork sources so the UI can explain
/// whether recovery depends on the network, account session, DeviantArt, or a
/// website format change. Raw details stay in diagnostics, not user copy.
final class MoreLikeThisFailure implements Exception {
  const MoreLikeThisFailure({this.websiteError, this.officialError});

  final Object? websiteError;
  final Object? officialError;

  MoreLikeThisFailureKind get kind =>
      classifyMoreLikeThisFailure(<Object?>[websiteError, officialError]);

  @override
  String toString() =>
      'MoreLikeThisFailure(website: $websiteError, official: $officialError)';
}

MoreLikeThisFailureKind classifyMoreLikeThisFailure(Iterable<Object?> errors) {
  final flattened = errors.expand(_errorChain).toList(growable: false);
  if (flattened.any(_isSessionFailure)) {
    return MoreLikeThisFailureKind.session;
  }
  if (flattened.any(_isNetworkFailure)) {
    return MoreLikeThisFailureKind.network;
  }
  if (flattened.any(_isServiceFailure)) {
    return MoreLikeThisFailureKind.service;
  }
  if (flattened.any((error) => error is FormatException)) {
    return MoreLikeThisFailureKind.pageFormat;
  }
  return MoreLikeThisFailureKind.unknown;
}

Iterable<Object> _errorChain(Object? error) sync* {
  if (error == null) return;
  yield error;
  if (error is DAKitException && error.cause != null) {
    yield* _errorChain(error.cause);
  }
  if (error is DioException && error.error != null) {
    yield* _errorChain(error.error);
  }
}

bool _isSessionFailure(Object error) {
  if (error is WebLoginRequired) return true;
  if (error is DAKitException) {
    return error.kind == DAKitFailureKind.authentication ||
        error.kind == DAKitFailureKind.authorization;
  }
  return false;
}

bool _isNetworkFailure(Object error) {
  if (error is DAKitException) {
    return error.kind == DAKitFailureKind.network;
  }
  if (error is DioException) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => true,
      _ => false,
    };
  }
  return false;
}

bool _isServiceFailure(Object error) {
  if (error is DAKitException) {
    return error.kind == DAKitFailureKind.rateLimit ||
        error.kind == DAKitFailureKind.upstream;
  }
  if (error is DioException) {
    final status = error.response?.statusCode;
    // Artwork pages are public. A raw website 403 normally means edge/bot
    // protection rather than an expired account session; DAKit's official API
    // errors remain authoritative for authentication/authorization failures.
    return status == 403 || status == 429 || (status != null && status >= 500);
  }
  return false;
}
