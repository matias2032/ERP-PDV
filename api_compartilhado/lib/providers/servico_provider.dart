// lib/features/servico/provider/servico_provider.dart

import 'package:flutter/material.dart';
import '../repository/servico_repository.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
class ServicoProvider with ChangeNotifier {
  final ServicoRepository _repository;

ServicoProvider({required ServicoRepository repository})
    : _repository = repository;

  // ── Estado ────────────────────────────────────────────────────────

  List<ServicoModel> _servicos    = [];
  bool               _isLoading   = false;
  String?            _errorMessage;

  // ── Getters ───────────────────────────────────────────────────────

  List<ServicoModel> get servicos      => List.unmodifiable(_servicos);
  bool               get isLoading     => _isLoading;
  String?            get errorMessage  => _errorMessage;

  // ── Leitura ───────────────────────────────────────────────────────

  /// Carrega todos os serviços (activos + inactivos) — painel de gestão.
  Future<void> carregarTodosOsServicos() async {
    _setLoading(true);
    _clearError();
    try {
      _servicos = await _repository.listarTodos();
      notifyListeners();
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// Carrega apenas os serviços activos — ecrã de pedidos.
  Future<void> carregarServicosAtivos() async {
    _setLoading(true);
    _clearError();
    try {
      _servicos = await _repository.listarAtivos();
      notifyListeners();
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // ── Escrita ───────────────────────────────────────────────────────

  /// Cria um novo serviço. Funciona offline (optimistic UI).
  Future<bool> criarServico(ServicoRequestModel dto) async {
    _setLoading(true);
    _clearError();
    try {
      final novo = await _repository.criar(dto);
      _servicos.add(novo);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Actualiza um serviço existente. Funciona offline (optimistic UI).
  Future<bool> actualizarServico(int id, ServicoRequestModel dto) async {
    _setLoading(true);
    _clearError();
    try {
      final actualizado = await _repository.actualizar(id, dto);
      final idx = _servicos.indexWhere((s) => s.idServico == id);
      if (idx != -1) {
        _servicos[idx] = actualizado;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Inverte o estado activo/inactivo. Requer ligação à internet.
  Future<bool> toggleEstadoServico(int id) async {
    _clearError();
    try {
      final modificado = await _repository.toggleAtivo(id);
      final idx = _servicos.indexWhere((s) => s.idServico == id);
      if (idx != -1) {
        _servicos[idx] = modificado;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  // ── Utilitários ───────────────────────────────────────────────────

  void limparErro() {
    _errorMessage = null;
    notifyListeners();
  }

  // ── Privados ──────────────────────────────────────────────────────

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  String _parseError(Object error) =>
      error.toString().replaceAll('Exception: ', '');
}