import 'package:flutter/material.dart';
import '../models/configuracao_model.dart';
import '../services/configuracao_service.dart';

class ConfiguracaoProvider with ChangeNotifier {
  final ConfiguracaoService _service = ConfiguracaoService.instance;

  bool _isLoading = false;
  String? _errorMessage;

  ConfiguracaoModel get configuracao => _service.actual;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> carregar() async {
    _isLoading = true;
    notifyListeners();
    await _service.carregar();
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> guardar(ConfiguracaoModel dto) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _service.actualizar(dto);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}