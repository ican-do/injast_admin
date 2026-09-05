import 'dart:convert';

import 'package:http/http.dart' as raw;
import 'package:injast_admin/api_http.dart';

export 'package:http/http.dart'
    hide get, post, put, delete, patch, head, read, readBytes;

Future<raw.Response> get(Uri url, {Map<String, String>? headers}) =>
    apiHttp.get(url, headers: headers);

Future<raw.Response> post(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) =>
    apiHttp.post(url, headers: headers, body: body, encoding: encoding);

Future<raw.Response> put(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) =>
    apiHttp.put(url, headers: headers, body: body, encoding: encoding);

Future<raw.Response> delete(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) =>
    apiHttp.delete(url, headers: headers, body: body, encoding: encoding);

Future<raw.Response> patch(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) =>
    apiHttp.patch(url, headers: headers, body: body, encoding: encoding);

Future<raw.Response> head(Uri url, {Map<String, String>? headers}) =>
    apiHttp.head(url, headers: headers);

Future<raw.StreamedResponse> send(raw.BaseRequest request) =>
    apiHttp.send(request);
