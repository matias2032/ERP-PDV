import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../api_config.dart';
import '../models/configuracao_model.dart';

/// GET/PUT /api/configuracoes — com cache local para funcionar offline.
class ConfiguracaoService {
  ConfiguracaoService._();
  static final ConfiguracaoService instance = ConfiguracaoService._();

  static const _chaveCache = 'configuracao_sistema';

  ConfiguracaoModel _actual = ConfiguracaoModel.padrao;

  /// Leitura síncrona (cache em memória) — para formulários e cálculos.
  ConfiguracaoModel get actual => _actual;
  double get ivaPercentual => _actual.ivaPercentual;

  /// Chamar no main() depois do ConnectivityService.init().
  Future<ConfiguracaoModel> carregar() async {
    try {
      final url = Uri.parse(ApiConfig.configuracoesUrl);
      final response = await http
          .get(url, headers: ApiConfig.defaultHeaders)
          .timeout(ApiConfig.timeout);
      if (response.statusCode == 200) {
        _actual = ConfiguracaoModel.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
        await _guardarCache(_actual);
        return _actual;
      }
    } catch (e) {
      debugPrint('⚠️ ConfiguracaoService.carregar HTTP falhou — usando cache: $e');
    }
    _actual = await _lerCache() ?? ConfiguracaoModel.padrao;
    return _actual;
  }

  Future<ConfiguracaoModel> actualizar(ConfiguracaoModel dto) async {
    final url = Uri.parse(ApiConfig.configuracoesUrl);
    final response = await http
        .put(url, headers: ApiConfig.defaultHeaders, body: jsonEncode(dto.toJson()))
        .timeout(ApiConfig.timeout);
    if (response.statusCode != 200) {
      throw HttpException(
          'Erro em "actualizar configurações": HTTP ${response.statusCode} — ${response.body}');
    }
    _actual = ConfiguracaoModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
    await _guardarCache(_actual);
    return _actual;
  }

  Future<void> _guardarCache(ConfiguracaoModel c) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chaveCache, jsonEncode(c.toJson()));
    } catch (_) {}
  }

  Future<ConfiguracaoModel?> _lerCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_chaveCache);
      if (s == null) return null;
      return ConfiguracaoModel.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}