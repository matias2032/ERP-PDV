// lib/features/produto/repository/produto_repository.dart

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:api_compartilhado/api_compartilhado.dart';
import '../../../core/database/daos/produto_dao.dart';
import '../../../core/database/daos/sync_queue_dao.dart';
import '../../../core/connectivity/connectivity_service.dart';

class ProdutoRepository {
  ProdutoRepository({
    required ProdutoService      service,
    required ProdutoDao          dao,
    required SyncQueueDao        syncQueueDao,
    required ConnectivityService connectivity,
  })  : _service      = service,
        _dao          = dao,
        _syncQueueDao = syncQueueDao,
        _connectivity = connectivity;

  final ProdutoService      _service;
  final ProdutoDao          _dao;
  final SyncQueueDao        _syncQueueDao;
  final ConnectivityService _connectivity;

  static const _uuid = Uuid();

  // ── Leitura ───────────────────────────────────────────────────────

  Future<List<ProdutoModel>> listarTodos() async {
    if (_connectivity.isOnline) {
      try {
        final lista = await _service.listar();
        await _dao.upsertAll(lista.map((p) => p.toLocalDb()).toList());
        return lista;
      } catch (e) {
        debugPrint('⚠️ ProdutoRepository.listarTodos HTTP falhou — usando cache: $e');
      }
    }
    final rows = await _dao.getAll();
    return rows.map(ProdutoModel.fromLocalDb).toList();
  }

  Future<List<ProdutoModel>> listarAtivos() async {
    if (_connectivity.isOnline) {
      try {
        final lista = await _service.listarAtivos();
        await _dao.upsertAll(lista.map((p) => p.toLocalDb()).toList());
        return lista;
      } catch (e) {
        debugPrint('⚠️ ProdutoRepository.listarAtivos HTTP falhou — usando cache: $e');
      }
    }
    final rows = await _dao.getAtivos();
    return rows.map(ProdutoModel.fromLocalDb).toList();
  }

  Future<ProdutoModel?> buscarPorId(int id) async {
    if (_connectivity.isOnline) {
      try {
        final p = await _service.buscarPorId(id);
        await _dao.upsert(p.toLocalDb());
        return p;
      } catch (e) {
        debugPrint('⚠️ ProdutoRepository.buscarPorId HTTP falhou — usando cache: $e');
      }
    }
    final row = await _dao.getById(id);
    return row == null ? null : ProdutoModel.fromLocalDb(row);
  }

  // ── Escrita ───────────────────────────────────────────────────────

  Future<ProdutoModel> criar(ProdutoRequestModel dto) async {
    if (_connectivity.isOnline) {
      try {
        final p = await _service.criar(dto);
        await _dao.upsert(p.toLocalDb());
        return p;
      } catch (e) {
        debugPrint('⚠️ ProdutoRepository.criar HTTP falhou: $e');
        rethrow;
      }
    }

    final localId = _uuid.v4();
    final tempId  = -(DateTime.now().millisecondsSinceEpoch);
    final iva     = ConfiguracaoService.instance.ivaPercentual;
    final local   = ProdutoModel(
      idProduto:         tempId,
      nomeProduto:       dto.nomeProduto,
      descricao:         dto.descricao,
      preco:             IvaUtil.comIva(dto.precoSemIva, iva),
      precoSemIva:       dto.precoSemIva,
      ivaAplicado:       iva,
      quantidadeEstoque: dto.quantidadeEstoque,
      precoPromocional:  dto.precoPromocional,
      ativo:             1,
      categorias:        dto.categorias,
      marcas:            dto.marcas,
    );
    final localRow = {...local.toLocalDb(), 'local_id': localId, 'sync_status': 'pending'};
    await _dao.upsert(localRow);
    final payloadSemRelacoes = {
  ...dto.toJson(),
  'localId':   localId,
  'categorias': <int>[],
  'marcas':     <int>[],
};
await _syncQueueDao.enqueue('produto', 'CREATE', payloadSemRelacoes);
    debugPrint('📥 ProdutoRepository — produto criado offline (localId: $localId)');
    return local;
  }

  Future<ProdutoModel> atualizar(int id, ProdutoRequestModel dto) async {
    if (_connectivity.isOnline) {
      try {
        final p = await _service.atualizar(id, dto);
        await _dao.upsert(p.toLocalDb());
        return p;
      } catch (e) {
        debugPrint('⚠️ ProdutoRepository.atualizar HTTP falhou: $e');
        rethrow;
      }
    }

    final existente = await _dao.getById(id);
    final iva       = ConfiguracaoService.instance.ivaPercentual;
    final local = ProdutoModel(
      idProduto:         id,
      nomeProduto:       dto.nomeProduto,
      descricao:         dto.descricao,
      preco:             IvaUtil.comIva(dto.precoSemIva, iva),
      precoSemIva:       dto.precoSemIva,
      ivaAplicado:       iva,
      quantidadeEstoque: dto.quantidadeEstoque,
      precoPromocional:  dto.precoPromocional,
      ativo:             existente?['ativo'] as int? ?? 1,
      categorias:        dto.categorias,
      marcas:            dto.marcas,
    );
    final localRow = {
      ...local.toLocalDb(),
      'local_id':    existente?['local_id'],
      'sync_status': 'pending',
    };
    await _dao.upsert(localRow);
    await _syncQueueDao.enqueue('produto', 'UPDATE', {'id': id, ...dto.toJson()});
    debugPrint('📥 ProdutoRepository — produto $id actualizado offline');
    return local;
  }

  /// toggleAtivo requer ligação — afecta stock e visibilidade no PDV.
  Future<void> toggleAtivo(int id) async {
    if (_connectivity.isOffline) {
      throw Exception('Sem ligação — toggleAtivo requer internet.');
    }
    await _service.toggleAtivo(id);
    // Actualiza cache local reflectindo o novo estado
    final row = await _dao.getById(id);
    if (row != null) {
      final novoAtivo = (row['ativo'] as int) == 1 ? 0 : 1;
      await _dao.toggleAtivo(id, ativo: novoAtivo);
    }
  }

  /// Operações de relação — requerem ligação.
  Future<void> associarCategoria(int idProduto, int idCategoria) async {
    if (_connectivity.isOffline) {
      throw Exception('Sem ligação — associação de categoria requer internet.');
    }
    await _service.associarCategoria(idProduto, idCategoria);
  }

  Future<void> desassociarCategoria(int idProduto, int idCategoria) async {
    if (_connectivity.isOffline) {
      throw Exception('Sem ligação — remoção de categoria requer internet.');
    }
    await _service.desassociarCategoria(idProduto, idCategoria);
  }

  Future<void> associarMarca(int idProduto, int idMarca) async {
    if (_connectivity.isOffline) {
      throw Exception('Sem ligação — associação de marca requer internet.');
    }
    await _service.associarMarca(idProduto, idMarca);
  }

  Future<void> desassociarMarca(int idProduto, int idMarca) async {
    if (_connectivity.isOffline) {
      throw Exception('Sem ligação — remoção de marca requer internet.');
    }
    await _service.desassociarMarca(idProduto, idMarca);
  }
}