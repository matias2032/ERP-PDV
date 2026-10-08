import 'package:api_compartilhado/api_compartilhado.dart';

/// Espelho do ServicoResponseDTO / Servico entity Java.
class ServicoModel {
  final int idServico;
  final String nomeServico;
  final String? descricao;
  final double precoUnitario;   // preço FINAL (com IVA) — é o que o PDV vende
  final double precoSemIva;
  final double ivaAplicado;
  final String unidade; // página, folha, unidade…
  final bool ativo;
  final String syncStatus;
final String? localId;

bool get isPending  => syncStatus == 'pending';
bool get isSynced   => syncStatus == 'synced';
bool get isConflict => syncStatus == 'conflict';
bool get isOffline  => isPending;

const ServicoModel({
    required this.idServico,
    required this.nomeServico,
    this.descricao,
    required this.precoUnitario,
    required this.precoSemIva,
    required this.ivaAplicado,
    this.unidade = 'página',
    required this.ativo,
    this.syncStatus = 'synced',
    this.localId,
  });

factory ServicoModel.fromJson(Map<String, dynamic> json) {
    final precoUnit = (json['precoUnitario'] as num).toDouble();
    final iva = (json['ivaAplicado'] as num?)?.toDouble() ??
        ConfiguracaoService.instance.ivaPercentual;
        
    return ServicoModel(
      idServico: json['idServico'] as int,
      nomeServico: json['nomeServico'] as String,
      descricao: json['descricao'] as String?,
      precoUnitario: precoUnit,
      precoSemIva: (json['precoSemIva'] as num?)?.toDouble() ??
          IvaUtil.semIva(precoUnit, iva),
      ivaAplicado: iva,
      unidade: json['unidade'] as String? ?? 'página',
      ativo: json['ativo'] as bool? ?? true,
      syncStatus: json['syncStatus'] as String? ?? 'synced',
      localId: json['localId'] as String?,
    );
  }

Map<String, dynamic> toJson() => {
        'idServico': idServico,
        'nomeServico': nomeServico,
        'descricao': descricao,
        'precoUnitario': precoUnitario,
        'precoSemIva': precoSemIva,
        'ivaAplicado': ivaAplicado,
        'unidade': unidade,
        'ativo': ativo,
        'syncStatus': syncStatus,
        'localId': localId,
      };

ServicoModel copyWith({
    int? idServico,
    String? nomeServico,
    String? descricao,
    double? precoUnitario,
    double? precoSemIva,
    double? ivaAplicado,
    String? unidade,
    bool? ativo,
    String? syncStatus,
    String? localId,
  }) {
    return ServicoModel(
      idServico: idServico ?? this.idServico,
      nomeServico: nomeServico ?? this.nomeServico,
      descricao: descricao ?? this.descricao,
      precoUnitario: precoUnitario ?? this.precoUnitario,
      precoSemIva: precoSemIva ?? this.precoSemIva,
      ivaAplicado: ivaAplicado ?? this.ivaAplicado,
      unidade: unidade ?? this.unidade,
      ativo: ativo ?? this.ativo,
      syncStatus: syncStatus ?? this.syncStatus,
      localId: localId ?? this.localId,
    );
  }
factory ServicoModel.fromLocalDb(Map<String, dynamic> row) {
    final precoUnit = (row['preco_unitario'] as num).toDouble();
    final iva = (row['iva_aplicado'] as num?)?.toDouble() ??
        ConfiguracaoService.instance.ivaPercentual;

    return ServicoModel(
      idServico: row['id'] as int,
      localId: row['local_id'] as String?,
      nomeServico: row['nome_servico'] as String,
      descricao: row['descricao'] as String?,
      precoUnitario: precoUnit,
      precoSemIva: (row['preco_sem_iva'] as num?)?.toDouble() ??
          IvaUtil.semIva(precoUnit, iva),
      ivaAplicado: iva,
      unidade: row['unidade'] as String? ?? 'página',
      ativo: (row['ativo'] as int? ?? 1) == 1,
      syncStatus: row['sync_status'] as String? ?? 'synced',
    );
  }

Map<String, dynamic> toLocalDb() => {
        'id': idServico,
        'local_id': localId,
        'nome_servico': nomeServico,
        'descricao': descricao,
        'preco_unitario': precoUnitario,
        'preco_sem_iva': precoSemIva,
        'iva_aplicado': ivaAplicado,
        'unidade': unidade,
        'ativo': ativo ? 1 : 0,
        'sync_status': syncStatus,
        'updated_at': DateTime.now().toIso8601String(),
      };


  @override
  String toString() =>
      'ServicoModel(id: $idServico, nome: $nomeServico, ativo: $ativo)';
}

// ─── Request DTO ─────────────────────────────────────────────────────────────

/// Espelho do ServicoRequestDTO Java.
class ServicoRequestModel {
  final String nomeServico;
  final String? descricao;
  final double precoUnitario;
  final String unidade;

  const ServicoRequestModel({
    required this.nomeServico,
    this.descricao,
    required this.precoUnitario,
    required this.unidade,
  });

  Map<String, dynamic> toJson() => {
        'nomeServico': nomeServico,
        'descricao': descricao,
        'precoUnitario': precoUnitario,
        'unidade': unidade,
      };
}