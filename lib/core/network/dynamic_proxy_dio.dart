import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

Dio createDynamicProxyDio(
  String Function() proxyDirective, {
  BaseOptions? options,
}) {
  final dio = Dio(options);
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      client.findProxy = (uri) => proxyDirective();
      return client;
    },
  );
  return dio;
}
