import 'dart:async';
import 'dart:io';

import '../api/client.dart';

/// Short Chinese messages for offline / timeout / server failures.
String friendlyNetworkError(Object e) {
  if (e is ApiException) return e.message;
  if (e is TimeoutException) return '网络超时，请稍后再试';
  if (e is SocketException) return '网络不可用，已显示本地缓存';
  final s = e.toString();
  if (s.contains('SocketException') ||
      s.contains('Failed host lookup') ||
      s.contains('Network is unreachable') ||
      s.contains('Connection refused')) {
    return '网络不可用，已显示本地缓存';
  }
  if (s.contains('TimeoutException') || s.contains('timed out')) {
    return '网络超时，请稍后再试';
  }
  if (s.length > 120) return '${s.substring(0, 120)}…';
  return s;
}

bool looksLikeOffline(Object e) {
  if (e is SocketException) return true;
  if (e is TimeoutException) return false;
  final s = e.toString();
  return s.contains('SocketException') ||
      s.contains('Failed host lookup') ||
      s.contains('Network is unreachable') ||
      s.contains('Connection refused');
}
