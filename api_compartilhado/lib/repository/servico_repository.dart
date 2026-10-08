// lib/features/servico/repository/servico_repository.dart

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:api_compartilhado/api_compartilhado.dart';
import '../../../core/database/daos/servico_dao.dart';
import '../../../core/database/daos/sync_queue_dao.dart';
import '../../../core/connectivity/connectivity_service.dart';

class ServicoRepository {
  ServicoRepository({
    required ServicoService      service,
    required ServicoDao          dao,
    required SyncQueueDao        syncQueueDao,
    required ConnectivityService connectivity,
  })  : _service      = service,
        _dao          = dao,
        _syncQueueDao = syncQueueDao,
        _connectivity = connectivity;

  final ServicoService      _service;
  final ServicoDao          _dao;
  final SyncQueueDao        _syncQueueDao;
  final ConnectivityService _connectivity;

  static const _uuid = Uuid();

  // ── Leitura ───────────────────────────────────────────────────────

  Future<List<ServicoModel>> listarTodos() async {
    if (_connectivity.isOnline) {
      try {
        final lista = await _service.listarTodos();
        await _dao.upsertAll(lista.map((s) => s.toLocalDb()).toList());
        return lista;
      } catch (e) {
        debugPrint('⚠️ ServicoRepository.listarTodos HTTP falhou — usando cache: $e');
      }
    }
    final rows = await _dao.getAll();
    return rows.map(ServicoModel.fromLocalDb).toList();
  }

  Future<List<ServicoModel>> listarAtivos() async {
    if (_connectivity.isOnline) {
      try {
        final lista = await _service.listarAtivos();
        await _dao.upsertAll(lista.map((s) => s.toLocalDb()).toList());
        return lista;
      } catch (e) {
        debugPrint('⚠️ ServicoRepository.listarAtivos HTTP falhou — usando cache: $e');
      }
    }
    final rows = await _dao.getAtivos();
    return rows.map(ServicoModel.fromLocalDb).toList();
  }

  Future<ServicoModel?> buscarPorId(int id) async {
    if (_connectivity.isOnline) {
      try {
        final s = await _service.buscarPorId(id);
        await _dao.upsert(s.toLocalDb());
        return s;
      } catch (e) {
        debugPrint('⚠️ ServicoRepository.buscarPorId HTTP falhou — usando cache: $e');
      }
    }
    final row = await _dao.getById(id);
    return row == null ? null : ServicoModel.fromLocalDb(row);
  }

  // ── Escrita ───────────────────────────────────────────────────────

  Future<ServicoModel> criar(ServicoRequestModel dto) async {
    if (_connectivity.isOnline) {
      try {
        final s = await _service.criar(dto);
        await _dao.upsert(s.toLocalDb());
        return s;
      } catch (e) {
        debugPrint('⚠️ ServicoRepository.criar HTTP falhou: $e');
        rethrow;
      }
    }

    final localId = _uuid.v4();
    final tempId  = -(DateTime.now().millisecondsSinceEpoch);
    final local   = ServicoModel(
      idServico:     tempId,
      nomeServico:   dto.nomeServico,
      descricao:     dto.descricao,
      precoUnitario: IvaUtil.comIva(
          dto.precoUnitario, ConfiguracaoService.instance.ivaPercentual),
      precoSemIva:   dto.precoUnitario,
      ivaAplicado:   ConfiguracaoService.instance.ivaPercentual,
      unidade:       dto.unidade,
      ativo:         true,
      syncStatus:    'pending',
      localId:       localId,
    );
    await _dao.upsert({
      ...local.toLocalDb(),
      'local_id':    localId,
      'sync_status': 'pending',
    });
    await _syncQueueDao.enqueue(
      'servico', 'CREATE', {'localId': localId, ...dto.toJson()},
    );
    debugPrint('📥 ServicoRepository — serviço criado offline (localId: $localId)');
    return local;
  }

  Future<ServicoModel> actualizar(int id, ServicoRequestModel dto) async {
    if (_connectivity.isOnline) {
      try {
        final s = await _service.actualizar(id, dto);
        await _dao.upsert(s.toLocalDb());
        return s;
      } catch (e) {
        debugPrint('⚠️ ServicoRepository.actualizar HTTP falhou: $e');
        rethrow;
      }
    }

    final existente = await _dao.getById(id);
    final local = ServicoModel(
      idServico:     id,
      nomeServico:   dto.nomeServico,
      descricao:     dto.descricao,
      precoUnitario: IvaUtil.comIva(
          dto.precoUnitario, ConfiguracaoService.instance.ivaPercentual),
      precoSemIva:   dto.precoUnitario,
      ivaAplicado:   ConfiguracaoService.instance.ivaPercentual,
      unidade:       dto.unidade,
      ativo:         (existente?['ativo'] as int? ?? 1) == 1,
      syncStatus:    'pending',
      localId:       existente?['local_id'] as String?,
    );
    await _dao.upsert({
      ...local.toLocalDb(),
      'local_id':    existente?['local_id'],
      'sync_status': 'pending',
    });
    await _syncQueueDao.enqueue(
      'servico', 'UPDATE', {'id': id, ...dto.toJson()},
    );
    debugPrint('📥 ServicoRepository — serviço $id actualizado offline');
    return local;
  }

  /// toggleAtivo requer ligação — afecta visibilidade nos pedidos.
  Future<ServicoModel> toggleAtivo(int id) async {
    if (_connectivity.isOffline) {
      throw Exception('Sem ligação — toggleAtivo requer internet.');
    }
    final s = await _service.toggleAtivo(id);
    await _dao.upsert(s.toLocalDb());
    return s;
  }
}