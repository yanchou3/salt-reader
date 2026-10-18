import 'dart:convert';

import 'package:dio/dio.dart';

/// 极简 WebDAV 客户端（坚果云用 Basic Auth，只需要 GET / PUT / MKCOL）。
///
/// 说明：坚果云只支持明文 Basic 凭据，因此凭据仅存本机、不进日志。
class WebDavClient {
  WebDavClient({
    required String baseUrl,
    required this.username,
    required this.password,
  })  : baseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
        _dio = Dio(
          BaseOptions(
            headers: <String, String>{'Accept': '*/*'},
            receiveTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(seconds: 30),
            validateStatus: (int? status) => status != null && status < 500,
          ),
        );

  final String baseUrl;
  final String username;
  final String password;
  final Dio _dio;

  String get _basicAuth =>
      'Basic ${base64Encode(utf8.encode('$username:$password'))}';

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  /// 读取文本文件；不存在（404 等）返回 null，而不是抛异常。
  Future<String?> readText(String path) async {
    final Response<String> response = await _dio.get<String>(
      _uri(path).toString(),
      options: Options(
        responseType: ResponseType.plain,
        headers: <String, String>{'Authorization': _basicAuth},
      ),
    );
    if (response.statusCode == 200) {
      return response.data;
    }
    return null;
  }

  /// 写入文本文件（覆盖）。
  Future<void> writeText(String path, String content) async {
    final Response<dynamic> response = await _dio.put(
      _uri(path).toString(),
      data: content,
      options: Options(
        contentType: 'application/json; charset=utf-8',
        headers: <String, String>{'Authorization': _basicAuth},
      ),
    );
    final int? status = response.statusCode;
    if (status == null || status < 200 || status >= 300) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: '写入失败（HTTP $status）',
      );
    }
  }

  /// 创建目录；已存在（405/301）时忽略。
  Future<void> ensureDir(String path) async {
    await _dio.request<dynamic>(
      _uri(path).toString(),
      options: Options(
        method: 'MKCOL',
        headers: <String, String>{'Authorization': _basicAuth},
      ),
    );
  }
}
