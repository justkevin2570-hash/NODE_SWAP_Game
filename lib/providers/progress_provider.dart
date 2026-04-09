import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/player_progress.dart';

const _kProgressKey = 'player_progress';

class ProgressNotifier extends StateNotifier<PlayerProgress> {
  ProgressNotifier() : super(PlayerProgress.initial()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kProgressKey);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      state = PlayerProgress.fromJson(json);
    } catch (_) {
      // 손상된 데이터는 초기값 유지
    }
  }

  Future<void> saveResult({
    required int ep,
    required int lv,
    required int stars,
    required int score,
    required int moves,
  }) async {
    state = state.withResult(
      ep: ep,
      lv: lv,
      stars: stars,
      score: score,
      moves: moves,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProgressKey, jsonEncode(state.toJson()));
  }

  /// 개발/테스트용 전체 초기화
  Future<void> reset() async {
    state = PlayerProgress.initial();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kProgressKey);
  }
}

final progressProvider =
    StateNotifierProvider<ProgressNotifier, PlayerProgress>(
  (ref) => ProgressNotifier(),
);
