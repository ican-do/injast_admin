import 'dart:convert';

import 'package:injast_admin/import_sync/asnaf_jwt_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AsnafRecoveryState {
  AsnafRecoveryState({
    required this.mode,
    required this.startPage,
    required this.endPage,
    required this.currentPage,
    required this.currentIndexInPage,
    required this.processedCount,
    required this.failedCount,
    required this.totalPlanned,
    required this.running,
  });

  final String mode;
  final int startPage;
  final int endPage;
  final int currentPage;
  final int currentIndexInPage;
  final int processedCount;
  final int failedCount;
  final int totalPlanned;
  final bool running;

  Map<String, dynamic> toJson() => {
        'mode': mode,
        'start_page': startPage,
        'end_page': endPage,
        'current_page': currentPage,
        'current_index_in_page': currentIndexInPage,
        'processed_count': processedCount,
        'failed_count': failedCount,
        'total_planned': totalPlanned,
        'running': running,
      };

  factory AsnafRecoveryState.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
    return AsnafRecoveryState(
      mode: json['mode']?.toString() ?? 'full',
      startPage: toInt(json['start_page']),
      endPage: toInt(json['end_page']),
      currentPage: toInt(json['current_page']),
      currentIndexInPage: toInt(json['current_index_in_page']),
      processedCount: toInt(json['processed_count']),
      failedCount: toInt(json['failed_count']),
      totalPlanned: toInt(json['total_planned']),
      running: json['running'] == true,
    );
  }
}

class AsnafRecoveryStore {
  static const _kJwtKey = 'asnaf_jwt_hidden_v1';
  static const _kStateKey = 'asnaf_recovery_state_v1';

  Future<void> saveJwt(String token) async {
    final t = token.trim();
    if (t.isEmpty) return;
    if (AsnafJwtPolicy.isExpired(t)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kJwtKey, t);
  }

  Future<String> readJwt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kJwtKey)?.trim() ?? '';
  }

  Future<void> clearJwt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kJwtKey);
  }

  Future<void> saveState(AsnafRecoveryState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStateKey, jsonEncode(state.toJson()));
  }

  Future<AsnafRecoveryState?> readState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kStateKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return AsnafRecoveryState.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kStateKey);
  }
}
