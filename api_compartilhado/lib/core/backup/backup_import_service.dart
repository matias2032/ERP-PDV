import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show compute;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../database/local_database.dart';

// ── Conversões Postgres(JSON) → SQLite ────────────────────────────────

int? _i(Object? v) =>
    v == null ? null : (v is bool ? (v ? 1 : 0) : (v as num).toInt());
int _b(Object? v) => (v == true || (v is num && v != 0)) ? 1 : 0;
double? _d(Object? v) => v == null ? null : (v as num).toDouble();
String? _s(Object? v) => v?.toString();
DateTime? _dt(Object? v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toUtc();

/// Timestamps do Postgres ("2026-10-01 07:44:23+00") → ISO-8601 UTC.
String? _ts(Object? v) => _dt(v)?.toIso8601String() ?? _s(v);

Map<String, dynamic> _decodificar(String s) =>
    jsonDecode(s) as Map<String, dynamic>;

// ── Resultado ─────────────────────────────────────────────────────────

class BackupImportException implements Exception {
  final String mensagem;
  BackupImportException(this.mensagem);
  @override
  String toString() => mensagem;
}

class EstatTabela {
  int inseridos = 0, atualizados = 0, ignorados = 0, preservados = 0, erros = 0;
}

class ImportResultado {
  ImportResultado(this.simulacao);

  final bool simulacao;
  final Map<String, EstatTabela> tabelas = {};
  final List<String> avisos = [];
  String? copiaSeguranca;

  int _soma(int Function(EstatTabela) f) =>
      tabelas.values.fold(0, (a, e) => a + f(e));

  int get inseridos   => _soma((e) => e.inseridos);
  int get atualizados => _soma((e) => e.atualizados);
  int get ignorados   => _soma((e) => e.ignorados);
  int get preservados => _soma((e) => e.preservados);
  int get erros       => _soma((e) => e.erros);

  String resumo() => '${simulacao ? 'SIMULAÇÃO (nada foi gravado)' : 'Importação concluída'}\n'
      'Novos: $inseridos · Actualizados: $atualizados\n'
      'Já iguais ou mais recentes: $ignorados\n'
      'Preservados (alterações locais por sincronizar): $preservados\n'
      'Erros: $erros';
}

// ── Contexto: resolve nomes denormalizados (nome_perfil, nome_cliente…) ─

/// Tabelas do backup usadas só como consulta (PK no Postgres).
const _pksApoio = {
  'perfil': 'id_perfil',
  'perfil_cliente': 'id_perfil_cliente',
  'tipo_documento_fiscal': 'id_tipo_doc',
  'usuario': 'id_usuario',
  'cliente': 'id_cliente',
  'fornecedor': 'id_fornecedor',
  'tipo_despesa': 'id_tipo_despesa',
  'produto': 'id_produto',
  'servico': 'id_servico',
  'pedido': 'id_pedido',
};

class _Ctx {
  _Ctx(this.db, this.dados);
  final DatabaseExecutor db;
  final Map<String, dynamic> dados;
  final _idx = <String, Map<int, Map<String, dynamic>>>{};

  Object? _doBackup(String tab, Object? id, String campo) {
    final k = _i(id);
    if (k == null) return null;
    final mapa = _idx.putIfAbsent(tab, () {
      final pk = _pksApoio[tab];
      final out = <int, Map<String, dynamic>>{};
      for (final l in (dados[tab] as List? ?? const [])) {
        final row = l as Map<String, dynamic>;
        final chave = pk == null ? null : _i(row[pk]);
        if (chave != null) out[chave] = row;
      }
      return out;
    });
    return mapa[k]?[campo];
  }

  /// Procura primeiro no backup; se não estiver lá, no SQLite local.
  Future<String?> nome(String pgTab, Object? id, String pgCampo,
      String sqTab, String sqIdCol, String sqCampo) async {
    final b = _doBackup(pgTab, id, pgCampo);
    if (b != null) return b.toString();
    if (id == null) return null;
    final rows = await db.query(sqTab,
        columns: [sqCampo],
        where: '$sqIdCol = ? AND $sqCampo IS NOT NULL',
        whereArgs: [id],
        limit: 1);
    return rows.isEmpty ? null : rows.first[sqCampo]?.toString();
  }
}

// ── Mapeamento por tabela ─────────────────────────────────────────────

typedef _Mapeador = Future<Map<String, Object?>?> Function(
    Map<String, dynamic> r, _Ctx c);

class _Tabela {
  _Tabela({
    required this.pg,
    required this.sq,
    required this.mapear,
    this.sync = true,      // a tabela local tem sync_status?
    this.updated = true,   // a tabela local tem updated_at?
    this.pai,              // tabela-pai (Postgres) se for tabela-filha
    this.fk,               // coluna FK para o pai
  });
  final String pg, sq;
  final _Mapeador mapear;
  final bool sync, updated;
  final String? pai, fk;
}

enum _Acao { inserido, atualizado, ignorado, preservado, erro }

final List<_Tabela> _tabelas = [
  _Tabela(
    pg: 'tipo_pagamento', sq: 'tipo_pagamento', sync: false, updated: false,
    mapear: (r, c) async => {
      'id': _i(r['id_tipo_pagamento']),
      'tipo_pagamento': r['tipo_pagamento'],
    },
  ),
  _Tabela(
    pg: 'usuario', sq: 'usuario',
    mapear: (r, c) async {
      if (r['deleted'] == true) return null; // local não tem coluna deleted
      final perfil = _i(r['id_perfil']);
      return {
        'id': _i(r['id_usuario']),
        'nome': r['nome'],
        'apelido': r['apelido'],
        'telefone': r['telefone'],
        'email': r['email'],
        'ativo': _b(r['ativo']),
        'id_perfil': perfil,
        'nome_perfil': await c.nome('perfil', perfil, 'nome_perfil',
                'usuario', 'id_perfil', 'nome_perfil') ?? 'Sem perfil',
        'primeira_senha': _b(r['primeira_senha']),
        'updated_at':
            _ts(r['updated_at'] ?? r['atualizado_em'] ?? r['created_at']),
      };
    },
  ),
  _Tabela(
    pg: 'cliente', sq: 'cliente',
    mapear: (r, c) async {
      if (r['deleted'] == true) return null;
      final perfil = _i(r['id_perfil_cliente']);
      return {
        'id': _i(r['id_cliente']),
        'nome': r['nome'],
        'apelido': r['apelido'],
        'email': r['email'],
        'nuit': r['nuit'],
        'contacto': r['contacto'],
        'morada': r['morada'],
        'id_perfil': perfil,
        'nome_perfil': await c.nome('perfil_cliente', perfil,
                'nome_perfil_cliente', 'cliente', 'id_perfil', 'nome_perfil') ??
            'Sem perfil',
        'updated_at': _ts(r['updated_at']),
      };
    },
  ),
  _Tabela(
    pg: 'fornecedor', sq: 'fornecedor', sync: false,
    mapear: (r, c) async => {
      'id': _i(r['id_fornecedor']),
      'nome': r['nome'],
      'email': r['email'],
      'nuit': r['nuit'],
      'contacto': r['contacto'],
      'morada': r['morada'],
      'deleted': _b(r['deleted']),
      'updated_at': _ts(r['updated_at']),
    },
  ),
  _Tabela(
    pg: 'tipo_despesa', sq: 'tipo_despesa',
    mapear: (r, c) async => {
      'id': _i(r['id_tipo_despesa']),
      'nome_despesa': r['nome_despesa'],
      'descricao': r['descricao'],
      'deleted': _b(r['deleted']),
      'updated_at': _ts(r['updated_at']),
    },
  ),
  _Tabela(
    pg: 'categoria', sq: 'categoria',
    mapear: (r, c) async {
      if (r['deleted'] == true) return null;
      return {
        'id': _i(r['id_categoria']),
        'nome_categoria': r['nome_categoria'] ?? '',
        'descricao': r['descricao'],
        'updated_at': _ts(r['updated_at']),
      };
    },
  ),
  _Tabela(
    pg: 'marca', sq: 'marca',
    mapear: (r, c) async {
      if (r['deleted'] == true) return null;
      return {
        'id': _i(r['id_marca']),
        'nome_marca': r['nome_marca'],
        'updated_at': _ts(r['updated_at']),
      };
    },
  ),
  _Tabela(
    pg: 'produto', sq: 'produto',
    mapear: (r, c) async {
      if (r['deleted'] == true) return null;
      return {
        'id': _i(r['id_produto']),
        'nome_produto': r['nome_produto'],
        'descricao': r['descricao'],
        'preco': _d(r['preco']),
        'preco_promocional': _d(r['preco_promocional']),
        'quantidade_estoque': _i(r['quantidade_estoque']) ?? 0,
        'ativo': _b(r['ativo']),
        'updated_at': _ts(r['updated_at']),
      };
    },
  ),
  _Tabela(
    pg: 'servico', sq: 'servico',
    mapear: (r, c) async {
      if (r['deleted'] == true) return null;
      return {
        'id': _i(r['id_servico']),
        'nome_servico': r['nome_servico'],
        'descricao': r['descricao'],
        'preco_unitario': _d(r['preco_unitario']),
        'unidade': r['unidade'] ?? 'página',
        'ativo': _b(r['ativo']),
        'updated_at': _ts(r['updated_at']),
      };
    },
  ),
  _Tabela(
    pg: 'pedido', sq: 'pedido',
    mapear: (r, c) async => {
      'id': _i(r['id_pedido']),
      'referencia': r['referencia'],
      'status_pedido': r['status_pedido'],
      'total': _d(r['total']) ?? 0,
      'valor_pago': _d(r['valor_pago']),
      'troco': _d(r['troco']),
      'observacoes': r['observacoes'],
      'id_cliente': _i(r['id_cliente']),
      'nome_cliente_singular': r['nome_cliente_singular'],
      'apelido_cliente_singular': r['apelido_cliente_singular'],
      'id_tipo_pagamento': _i(r['id_tipo_pagamento']),
      'id_usuario': _i(r['id_usuario']),
      'data_pedido': _ts(r['data_pedido']),
      'data_finalizacao': _ts(r['data_finalizacao']),
      'tipo_venda': r['tipo_venda'] ?? 'IMEDIATA',
      'modalidade_credito': r['modalidade_credito'],
      'status_pagamento': r['status_pagamento'] ?? 'PENDENTE',
      'id_documento_factura_credito': _i(r['id_documento_factura_credito']),
      'data_abertura_credito': _ts(r['data_abertura_credito']),
      'data_vencimento_credito': _s(r['data_vencimento_credito']), // date
      'data_liquidacao_credito': _ts(r['data_liquidacao_credito']),
      'observacoes_credito': r['observacoes_credito'],
      'saldo_devedor_credito': _d(r['saldo_devedor_credito']),
      'deleted': _b(r['deleted']),
      'updated_at': _ts(r['updated_at']),
    },
  ),
  // item_pedido: id AUTOINCREMENT local → não enviamos id (evita colisões)
  _Tabela(
    pg: 'item_pedido', sq: 'item_pedido', sync: false, updated: false,
    pai: 'pedido', fk: 'id_pedido',
    mapear: (r, c) async => {
      'id_pedido': _i(r['id_pedido']),
      'id_produto': _i(r['id_produto']),
      'preco_unitario': _d(r['preco_unitario']),
      'quantidade': _i(r['quantidade']),
      'subtotal': _d(r['subtotal']) ??
          (_d(r['preco_unitario'])! * _i(r['quantidade'])!),
    },
  ),
  _Tabela(
    pg: 'item_pedido_servico', sq: 'item_pedido_servico',
    sync: false, updated: false, pai: 'pedido', fk: 'id_pedido',
    mapear: (r, c) async => {
      'id': _i(r['id_item_servico']),
      'id_pedido': _i(r['id_pedido']),
      'id_servico': _i(r['id_servico']),
      'preco_unitario': _d(r['preco_unitario']) ?? 0,
      'quantidade': _i(r['quantidade']) ?? 1,
      'subtotal': _d(r['subtotal']) ?? 0,
      'observacoes': r['observacoes'],
    },
  ),
  _Tabela(
    pg: 'pedido_credito_parcela', sq: 'pedido_credito_parcela',
    mapear: (r, c) async => {
      'id': _i(r['id_parcela']),
      'id_pedido': _i(r['id_pedido']),
      'numero_parcela': _i(r['numero_parcela']),
      'valor_parcela': _d(r['valor_parcela']) ?? 0,
      'valor_pago': _d(r['valor_pago']) ?? 0,
      'saldo_parcela': _d(r['saldo_parcela']),
      'data_vencimento': _s(r['data_vencimento']),
      'data_pagamento': _ts(r['data_pagamento']),
      'status_parcela': r['status_parcela'] ?? 'PENDENTE',
      'observacoes': r['observacoes'],
      'deleted': _b(r['deleted']),
      'updated_at': _ts(r['updated_at']),
    },
  ),
  _Tabela(
    pg: 'pedido_credito_pagamento', sq: 'pedido_credito_pagamento',
    mapear: (r, c) async => {
      'id': _i(r['id_pagamento_credito']),
      'referencia': r['referencia'],
      'id_pedido': _i(r['id_pedido']),
      'id_parcela': _i(r['id_parcela']),
      'id_tipo_pagamento': _i(r['id_tipo_pagamento']),
      'id_usuario': _i(r['id_usuario']),
      'id_documento_recibo': _i(r['id_documento_recibo']),
      'valor_pago': _d(r['valor_pago']) ?? 0,
      'data_pagamento': _ts(r['data_pagamento']),
      'observacoes': r['observacoes'],
      'deleted': _b(r['deleted']),
      'updated_at': _ts(r['updated_at']),
    },
  ),
  _Tabela(
    pg: 'documento_fiscal', sq: 'documento_fiscal',
    mapear: (r, c) async {
      if (r['deleted'] == true) return null;
      final tipo = _i(r['id_tipo_doc']);
      final user = _i(r['id_usuario']);
      Future<String> t(String pgCampo, String sqCampo) async =>
          await c.nome('tipo_documento_fiscal', tipo, pgCampo,
              'documento_fiscal', 'id_tipo_doc', sqCampo) ?? '';
      return {
        'id': _i(r['id_documento']),
        'id_tipo_doc': tipo,
        'tipo_codigo': await t('codigo', 'tipo_codigo'),
        'tipo_nome': await t('nome', 'tipo_nome'),
        'tipo_prefixo': await t('prefixo', 'tipo_prefixo'),
        'id_pedido': _i(r['id_pedido']),
        'referencia': r['referencia'],
        'numero_seq': _i(r['numero_seq']),
        'ano': _i(r['ano']),
        'codigo_at': r['codigo_at'],
        'id_usuario': user,
        'nome_usuario':
            await c.nome('usuario', user, 'nome', 'usuario', 'id', 'nome') ?? '',
        'emitido_em': _ts(r['emitido_em']),
        'anulado': _b(r['anulado']),
        'motivo_anulacao': r['motivo_anulacao'],
        'tipo_venda': r['tipo_venda'],
        'snapshot_conteudo': r['snapshot_conteudo'],
        'valor_total_emissao': _d(r['valor_total_emissao']),
        'motivo_retificacao': r['motivo_retificacao'],
        'updated_at': _ts(r['updated_at']),
      };
    },
  ),
  _Tabela(
    pg: 'cotacao', sq: 'cotacao',
    mapear: (r, c) async {
      final cli = _i(r['id_cliente']);
      final user = _i(r['id_usuario']);
      final ped = _i(r['id_pedido_convertido']);
      return {
        'id': _i(r['id_cotacao']),
        'referencia': r['referencia'],
        'id_cliente': cli,
        'nome_cliente':
            await c.nome('cliente', cli, 'nome', 'cliente', 'id', 'nome'),
        'nome_cliente_singular': r['nome_cliente_singular'],
        'apelido_cliente_singular': r['apelido_cliente_singular'],
        'id_usuario': user,
        'nome_usuario':
            await c.nome('usuario', user, 'nome', 'usuario', 'id', 'nome'),
        'status_cotacao': r['status_cotacao'] ?? 'ABERTA',
        'total': _d(r['total']) ?? 0,
        'validade_ate': _s(r['validade_ate']),
        'observacoes': r['observacoes'],
        'id_pedido_convertido': ped,
        'referencia_pedido_convertido': await c.nome(
            'pedido', ped, 'referencia', 'pedido', 'id', 'referencia'),
        'created_at': _ts(r['criado_em'] ?? r['created_at']),
        'deleted': _b(r['deleted']),
        'updated_at': _ts(r['updated_at'] ?? r['atualizado_em']),
      };
    },
  ),
  _Tabela(
    pg: 'cotacao_item_produto', sq: 'cotacao_item_produto',
    sync: false, updated: false, pai: 'cotacao', fk: 'id_cotacao',
    mapear: (r, c) async {
      final prod = _i(r['id_produto']);
      return {
        'id': _i(r['id_item_cotacao_produto']),
        'id_cotacao': _i(r['id_cotacao']),
        'id_produto': prod,
        'nome_produto': await c.nome('produto', prod, 'nome_produto',
            'produto', 'id', 'nome_produto'),
        'preco_unitario': _d(r['preco_unitario']) ?? 0,
        'quantidade': _i(r['quantidade']) ?? 1,
        'subtotal': _d(r['subtotal']) ?? 0,
        'observacoes': r['observacoes'],
      };
    },
  ),
  _Tabela(
    pg: 'cotacao_item_servico', sq: 'cotacao_item_servico',
    sync: false, updated: false, pai: 'cotacao', fk: 'id_cotacao',
    mapear: (r, c) async {
      final srv = _i(r['id_servico']);
      return {
        'id': _i(r['id_item_cotacao_servico']),
        'id_cotacao': _i(r['id_cotacao']),
        'id_servico': srv,
        'nome_servico': await c.nome('servico', srv, 'nome_servico',
            'servico', 'id', 'nome_servico'),
        'preco_unitario': _d(r['preco_unitario']) ?? 0,
        'quantidade': _i(r['quantidade']) ?? 1,
        'subtotal': _d(r['subtotal']) ?? 0,
        'observacoes': r['observacoes'],
      };
    },
  ),
  _Tabela(
    pg: 'despesa', sq: 'despesa',
    mapear: (r, c) async {
      final forn = _i(r['id_fornecedor']);
      final tipo = _i(r['id_tipo_despesa']);
      return {
        'id': _i(r['id_despesa']),
        'id_fornecedor': forn,
        'nome_fornecedor': await c.nome(
            'fornecedor', forn, 'nome', 'fornecedor', 'id', 'nome'),
        'nuit_fornecedor': await c.nome(
            'fornecedor', forn, 'nuit', 'fornecedor', 'id', 'nuit'),
        'descricao': r['descricao'],
        'valor_gasto': _d(r['valor_gasto']) ?? 0,
        'data_despesa': _ts(r['data_despesa']),
        'motivo_exclusao': r['motivo_exclusao'],
        'id_tipo_despesa': tipo,
        'nome_tipo_despesa': await c.nome('tipo_despesa', tipo,
            'nome_despesa', 'tipo_despesa', 'id', 'nome_despesa'),
        'deleted': _b(r['deleted']),
        'updated_at': _ts(r['updated_at']),
      };
    },
  ),
];

class _Simulacao implements Exception {}

// ── Serviço ───────────────────────────────────────────────────────────

class BackupImportService {
  /// [simular]=true → corre tudo, devolve contagens e faz rollback.
  Future<ImportResultado> importar(
    String caminho, {
    bool simular = false,
    void Function(String tabela, int feito, int total)? onProgresso,
  }) async {
    final res = ImportResultado(simular);
    final dados = await _lerEValidar(caminho);
    final db = LocalDatabase.instance.db;

    if (!simular) res.copiaSeguranca = await _copiaSeguranca(db);

    try {
      await db.transaction((txn) async {
        final ctx = _Ctx(txn, dados);
        final aplicados = <String, Set<int>>{}; // pais inseridos/actualizados

        for (final t in _tabelas) {
          final linhas = dados[t.pg];
          if (linhas is! List) continue; // tabela não incluída no backup
          final est = res.tabelas.putIfAbsent(t.pg, EstatTabela.new);

          if (t.pai == null) {
            await _processarPai(txn, ctx, t, linhas, est, aplicados, res, onProgresso);
          } else {
            await _processarFilho(txn, ctx, t, linhas, est, aplicados, dados, res, onProgresso);
          }
        }

        final conhecidas = {..._tabelas.map((t) => t.pg), ..._pksApoio.keys};
        for (final k in dados.keys) {
          if (!conhecidas.contains(k)) {
            res.avisos.add('Tabela "$k" não tem equivalente local, ignorada.');
          }
        }
        if (simular) throw _Simulacao(); // força rollback
      });
    } on _Simulacao {
      // rollback intencional da pré-visualização
    }
    return res;
  }

  // ── Tabelas independentes / pais ────────────────────────────────────

  Future<void> _processarPai(
    Transaction txn, _Ctx ctx, _Tabela t, List linhas, EstatTabela est,
    Map<String, Set<int>> aplicados, ImportResultado res,
    void Function(String, int, int)? onProgresso,
  ) async {
    for (var n = 0; n < linhas.length; n++) {
      final v = await t.mapear(linhas[n] as Map<String, dynamic>, ctx);
      if (v == null) {
        est.ignorados++;
      } else {
        if (t.sync) v['sync_status'] = 'synced';
        final acao = await _upsert(txn, t, v, res);
        switch (acao) {
          case _Acao.inserido:
            est.inseridos++;
          case _Acao.atualizado:
            est.atualizados++;
          case _Acao.ignorado:
            est.ignorados++;
          case _Acao.preservado:
            est.preservados++;
          case _Acao.erro:
            est.erros++;
        }
        if (acao == _Acao.inserido || acao == _Acao.atualizado) {
          aplicados.putIfAbsent(t.pg, () => {}).add(v['id'] as int);
        }
      }
      onProgresso?.call(t.pg, n + 1, linhas.length);
    }
  }

  // ── Tabelas-filhas: substituídas apenas para os pais aplicados ──────

  Future<void> _processarFilho(
    Transaction txn, _Ctx ctx, _Tabela t, List linhas, EstatTabela est,
    Map<String, Set<int>> aplicados, Map<String, dynamic> dados,
    ImportResultado res, void Function(String, int, int)? onProgresso,
  ) async {
    if (!dados.containsKey(t.pai)) {
      res.avisos.add('${t.pg}: ignorada, "${t.pai}" não está neste backup.');
      est.ignorados += linhas.length;
      return;
    }
    final alvo = aplicados[t.pai] ?? <int>{};
    final lista = alvo.toList();

    for (var i = 0; i < lista.length; i += 500) { // limite de 999 variáveis
      final bloco = lista.sublist(i, math.min(i + 500, lista.length));
      await txn.delete(t.sq,
          where: '${t.fk} IN (${List.filled(bloco.length, '?').join(',')})',
          whereArgs: bloco);
    }

    for (var n = 0; n < linhas.length; n++) {
      final r = linhas[n] as Map<String, dynamic>;
      if (!alvo.contains(_i(r[t.fk]))) {
        est.ignorados++;
      } else {
        final v = (await t.mapear(r, ctx))!;
        final id = await txn.insert(t.sq, v,
            conflictAlgorithm: ConflictAlgorithm.ignore);
        if (id > 0) {
          est.inseridos++;
        } else {
          est.ignorados++;
          res.avisos.add('${t.pg}#${v['id']}: id já em uso localmente, ignorado.');
        }
      }
      onProgresso?.call(t.pg, n + 1, linhas.length);
    }
  }

  // ── Upsert com as regras de merge ───────────────────────────────────

  Future<_Acao> _upsert(
      Transaction txn, _Tabela t, Map<String, Object?> v, ImportResultado res) async {
    final id = v['id'];
    final existente = await txn.query(t.sq,
        columns: [
          'id',
          if (t.sync) 'sync_status',
          if (t.updated) 'updated_at',
        ],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1);

    try {
      if (existente.isEmpty) {
        await txn.insert(t.sq, v, conflictAlgorithm: ConflictAlgorithm.abort);
        return _Acao.inserido;
      }
      final local = existente.first;

      // alteração offline ainda por enviar → nunca sobrescrever
      if (t.sync && local['sync_status'] != 'synced') return _Acao.preservado;

      if (t.updated) {
        final remoto = _dt(v['updated_at']);
        final loc = _dt(local['updated_at']);
        if (remoto == null) return _Acao.ignorado;
        if (loc != null && !remoto.isAfter(loc)) return _Acao.ignorado;
      }
      await txn.update(t.sq, v, where: 'id = ?', whereArgs: [id]);
      return _Acao.atualizado;
    } on DatabaseException catch (e) {
      // UNIQUE (ex.: fornecedor.contacto) ou NOT NULL → regista e segue
      if (e.isUniqueConstraintError() || e.isNotNullConstraintError()) {
        if (res.avisos.length < 50) res.avisos.add('${t.pg}#$id: conflito (${e.toString().split('\n').first})');
        return _Acao.erro;
      }
      rethrow; // erro de programação (coluna inexistente, etc.)
    }
  }

  // ── Leitura, validação e cópia de segurança ─────────────────────────

  Future<Map<String, dynamic>> _lerEValidar(String caminho) async {
    final Map<String, dynamic> json;
    try {
      json = await compute(_decodificar, await File(caminho).readAsString());
    } catch (_) {
      throw BackupImportException('O ficheiro não é um backup JSON válido.');
    }
    final meta = json['meta'];
    if (meta is! Map || meta['origem'] != 'stech_pdv_postgres') {
      throw BackupImportException('Ficheiro não reconhecido como backup do STech PDV.');
    }
    if (meta['versaoFormato'] != 1) {
      throw BackupImportException('Versão do formato de backup não suportada.');
    }
    final dados = json['dados'];
    if (dados is! Map<String, dynamic>) {
      throw BackupImportException('Backup sem dados.');
    }
    return dados;
  }

  Future<String> _copiaSeguranca(Database db) async {
    await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    final dir = await getDatabasesPath();
    final destino = join(dir, 'stech_pdv_pre_import_${DateTime.now().millisecondsSinceEpoch}.db');
    await File(join(dir, 'stech_pdv.db')).copy(destino);

    final antigas = Directory(dir)
        .listSync()
        .whereType<File>()
        .where((f) => basename(f.path).startsWith('stech_pdv_pre_import_'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final f in antigas.take(math.max(0, antigas.length - 3))) {
      await f.delete();
    }
    return destino;
  }
}