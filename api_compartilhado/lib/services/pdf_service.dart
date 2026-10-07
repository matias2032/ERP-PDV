import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:printing/printing.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

// ═══════════════════════════════════════════════════════════════════
// CONSTANTES FISCAIS — fonte única de verdade, NUNCA em base de dados
// ═══════════════════════════════════════════════════════════════════

/// Código atribuído pela Autoridade Tributária de Moçambique.
const String kCodigoAT = 'STECH-MZ-2026-XXXX'; // ← substituir pelo real

/// IVA vigente em Moçambique
const double kTaxaIva = 0.16;

// ═══════════════════════════════════════════════════════════════════
// ENUM — tipos de documento fiscal (para uso local no PDF)
// ═══════════════════════════════════════════════════════════════════

enum TipoDocumentoPdf {
  factura,
  recibo, /*notaDeCompra,*/
  vendaADinheiro,
  notaDeEntrega,
  notaCredito,
  notaDebito,
}

extension TipoDocumentoPdfExt on TipoDocumentoPdf {
  String get titulo => switch (this) {
        TipoDocumentoPdf.factura => 'FACTURA',

        TipoDocumentoPdf.recibo => 'RECIBO',
        // TipoDocumentoPdf.notaDeCompra => 'NOTA DE COMPRA',
          TipoDocumentoPdf.vendaADinheiro => 'VENDA A DINHEIRO',
          TipoDocumentoPdf.notaDeEntrega => 'NOTA DE ENTREGA',
          TipoDocumentoPdf.notaCredito => 'NOTA DE CRÉDITO',
          TipoDocumentoPdf.notaDebito => 'NOTA DE DÉBITO',
      };

  String get prefixo => switch (this) {
        TipoDocumentoPdf.factura => 'FAT',

        TipoDocumentoPdf.recibo => 'REC',
        // TipoDocumentoPdf.notaDeCompra => 'NCO',
        TipoDocumentoPdf.vendaADinheiro => 'VD',
        TipoDocumentoPdf.notaDeEntrega => 'NOTA DE ENTREGA',
        TipoDocumentoPdf.notaCredito => 'NCR',
        TipoDocumentoPdf.notaDebito => 'NDB',
      };

  String get labelReferencia => switch (this) {
        TipoDocumentoPdf.factura => 'Factura Nº',
        TipoDocumentoPdf.recibo => 'Recibo Nº',
        // TipoDocumentoPdf.notaDeCompra => 'N. Compra Nº',
        TipoDocumentoPdf.vendaADinheiro => 'Venda a Dinheiro Nº',
        TipoDocumentoPdf.notaDeEntrega => 'N. Entrega Nº',
        TipoDocumentoPdf.notaCredito => 'Nota de Crédito Nº',
        TipoDocumentoPdf.notaDebito => 'Nota de Débito Nº',
      };

  /// Converte o prefixo da BD para o enum local de PDF.
  static TipoDocumentoPdf dePrefixo(String prefixo) => switch (prefixo.toUpperCase()) {
        'FAT' => TipoDocumentoPdf.factura,
        'REC' => TipoDocumentoPdf.recibo,
        // 'NCO' => TipoDocumentoPdf.notaDeCompra,
        'VD' => TipoDocumentoPdf.vendaADinheiro,
        'NE' => TipoDocumentoPdf.notaDeEntrega,
        'NCR' => TipoDocumentoPdf.notaCredito,
        'NDB' => TipoDocumentoPdf.notaDebito,
        _ => TipoDocumentoPdf.factura,
      };
}
// ═══════════════════════════════════════════════════════════════════
// MODELO LOCAL DO PDF — renomeado de DocumentoFiscalModel
// para evitar conflito com o model da API (DocumentoFiscalModel)
// ═══════════════════════════════════════════════════════════════════

class DocumentoPdfModel {
  final TipoDocumentoPdf tipo;

  /// Referência gerada pelo backend, ex: FAT-0001/2026
  final String referencia;

  /// Código AT — sempre passar kCodigoAT
  final String codigoAT;

  final DateTime dataEmissao;


  final String? salesperson;
  final String prazoPagamento;
  final PedidoModel pedido;
final ClienteModel? cliente;
  final String tipoPagamento;

  /// Fotografia imutável dos itens/total no momento da emissão da FAT/VD,
  /// vinda de DocumentoFiscalModel.snapshotConteudo. Quando presente, o PDF
  /// deve usar SEMPRE este conteúdo em vez de `pedido` (que pode já ter sido
  /// alterado por devoluções/trocas posteriores).
  final SnapshotPedidoFiscal? snapshot;

  const DocumentoPdfModel({
    required this.tipo,
    required this.referencia,
    required this.codigoAT,
    required this.dataEmissao,
    required this.pedido,
     this.cliente,
    required this.tipoPagamento,

    this.salesperson,
    this.prazoPagamento = 'Pronto Pagamento',
    this.snapshot,
  });

  /// Fábrica de conveniência — constrói a partir do DocumentoFiscalModel
  /// (o model da API) + dados complementares.
  factory DocumentoPdfModel.deApiModel({
    required DocumentoFiscalModel apiModel,
    required PedidoModel pedido,
ClienteModel? cliente,
    required String tipoPagamento,
    String? salesperson,
    String prazoPagamento = 'Pronto Pagamento',
  }) {
    return DocumentoPdfModel(
      tipo: TipoDocumentoPdfExt.dePrefixo(apiModel.tipoDocumento.prefixo),
      referencia: apiModel.referencia,
      codigoAT: apiModel.codigoAt,
      dataEmissao: apiModel.emitidoEm,
      pedido: pedido,
      cliente: cliente,
      tipoPagamento: tipoPagamento,
      salesperson: salesperson,
      prazoPagamento: prazoPagamento,
      snapshot: SnapshotPedidoFiscal.tentarParsear(apiModel.snapshotConteudo),
    );
  }

  

  // Adicionar dentro de class DocumentoPdfModel, após o factory deApiModel existente:

factory DocumentoPdfModel.deApiModelMultiplos({
  required DocumentoFiscalModel apiModel,
  required List<PedidoModel> pedidos,
ClienteModel? cliente,
  required String tipoPagamento,
}) {
  // Agrega todos os itens numa lista única
  final todosProdutos = pedidos.expand((p) => p.itensProduto).toList();
  final todosServicos = pedidos.expand((p) => p.itensServico).toList();
  final totalGeral    = pedidos.fold(0.0, (acc, p) => acc + p.total);
  final valorPago     = pedidos.fold(0.0, (acc, p) => acc + p.valorPago);

  // Cria um PedidoModel sintético que agrega todos os dados
  final pedidoAgregado = pedidos.first.copyWith(
    itensProduto: todosProdutos,
    itensServico: todosServicos,
    total:        totalGeral,
    valorPago:    valorPago,
  );

  return DocumentoPdfModel(
    tipo:          TipoDocumentoPdfExt.dePrefixo(apiModel.tipoDocumento.prefixo),
    referencia:    apiModel.referencia,
    codigoAT:      apiModel.codigoAt,
    dataEmissao:   apiModel.emitidoEm,
    pedido:        pedidoAgregado,
    cliente:       cliente,
    tipoPagamento: tipoPagamento,
    // Sem isto, uma FAT/VD que cobre múltiplos pedidos NUNCA lia o
    // snapshot congelado pelo backend — o PDF recaía sempre no caminho
    // "pedido ao vivo" em _docFiscalTabelaItens, fazendo a factura
    // mudar de valor sempre que qualquer um dos pedidos agregados
    // sofresse uma devolução/troca posterior à emissão.
    snapshot: SnapshotPedidoFiscal.tentarParsear(apiModel.snapshotConteudo),
  );
}
}

// ═══════════════════════════════════════════════════════════════════
// SNAPSHOT DO PEDIDO — fotografia imutável gravada pelo backend na
// emissão de FAT/VD (DocumentoFiscal.snapshotConteudo).
// ═══════════════════════════════════════════════════════════════════

class SnapshotItemFiscal {
  final String descricao;
  final int quantidade;
  final double precoUnitario;
  final double subtotal;
  final String? observacoes;

  const SnapshotItemFiscal({
    required this.descricao,
    required this.quantidade,
    required this.precoUnitario,
    required this.subtotal,
    this.observacoes,
  });

  factory SnapshotItemFiscal.fromJson(Map<String, dynamic> json, {
    required String chaveDescricao,
  }) {
    return SnapshotItemFiscal(
      descricao: (json[chaveDescricao] ?? '').toString(),
      quantidade: (json['quantidade'] as num?)?.toInt() ?? 0,
      precoUnitario: (json['precoUnitario'] as num?)?.toDouble() ?? 0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      observacoes: json['observacoes'] as String?,
    );
  }
}

class SnapshotPedidoFiscal {
  final String referenciaPedido;
  final double total;
  final List<SnapshotItemFiscal> itensProduto;
  final List<SnapshotItemFiscal> itensServico;

  const SnapshotPedidoFiscal({
    required this.referenciaPedido,
    required this.total,
    required this.itensProduto,
    required this.itensServico,
  });

  /// Retorna null se `raw` for nulo/vazio/inválido — nesse caso o chamador
  /// deve recorrer ao pedido ao vivo (ex: documentos que não são FAT/VD).
  static SnapshotPedidoFiscal? tentarParsear(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return SnapshotPedidoFiscal(
        referenciaPedido: (json['referenciaPedido'] ?? '').toString(),
        total: (json['total'] as num?)?.toDouble() ?? 0,
        itensProduto: (json['itensProduto'] as List<dynamic>? ?? [])
            .map((e) => SnapshotItemFiscal.fromJson(
                e as Map<String, dynamic>, chaveDescricao: 'produto'))
            .toList(),
        itensServico: (json['itensServico'] as List<dynamic>? ?? [])
            .map((e) => SnapshotItemFiscal.fromJson(
                e as Map<String, dynamic>, chaveDescricao: 'servico'))
            .toList(),
      );
    } catch (_) {
      return null;
    }
  }
}



class ReciboCreditoPdfModel {
  /// Documento fiscal REC gerado pelo backend.
  final String referenciaRecibo;

  /// Factura principal da venda a crédito, ex: FAT-0001/2026.
  final String referenciaFactura;

  /// Código AT.
  final String codigoAT;

  final DateTime dataEmissao;
  final PedidoModel pedido;
  final ClienteModel cliente;
  final PagamentoCreditoModel pagamento;
  final String tipoPagamento;

  /// Saldo antes deste pagamento.
  final double saldoAnterior;

  /// Saldo depois deste pagamento.
  final double saldoRemanescente;

  /// Parcela associada, se o pagamento estiver ligado a uma parcela.
  final int? numeroParcela;
  final int? totalParcelas;

  final String? salesperson;
  final String? observacoes;

  const ReciboCreditoPdfModel({
    required this.referenciaRecibo,
    required this.referenciaFactura,
    required this.codigoAT,
    required this.dataEmissao,
    required this.pedido,
    required this.cliente,
    required this.pagamento,
    required this.tipoPagamento,
    required this.saldoAnterior,
    required this.saldoRemanescente,
    this.numeroParcela,
    this.totalParcelas,
    this.salesperson,
    this.observacoes,
  });

  factory ReciboCreditoPdfModel.deApiModel({
    required DocumentoFiscalModel apiModel,
    required String referenciaFactura,
    required PedidoModel pedido,
    required ClienteModel cliente,
    required PagamentoCreditoModel pagamento,
    required String tipoPagamento,
    required double saldoAnterior,
    required double saldoRemanescente,
    int? numeroParcela,
    int? totalParcelas,
    String? salesperson,
    String? observacoes,
  }) {
    return ReciboCreditoPdfModel(
      referenciaRecibo: apiModel.referencia,
      referenciaFactura: referenciaFactura,
      codigoAT: apiModel.codigoAt,
      dataEmissao: apiModel.emitidoEm,
      pedido: pedido,
      cliente: cliente,
      pagamento: pagamento,
      tipoPagamento: tipoPagamento,
      saldoAnterior: saldoAnterior,
      saldoRemanescente: saldoRemanescente,
      numeroParcela: numeroParcela,
      totalParcelas: totalParcelas,
      salesperson: salesperson,
      observacoes: observacoes,
    );
  }

  String get descricaoPagamento {
    if (numeroParcela != null && totalParcelas != null) {
      return 'Pagamento da parcela $numeroParcela/$totalParcelas';
    }

    if (numeroParcela != null) {
      return 'Pagamento da parcela $numeroParcela';
    }

    if ((pagamento.observacoes ?? '').toLowerCase().contains('entrada')) {
      return 'Entrada inicial da venda a crédito';
    }

    return 'Pagamento parcial da venda a crédito';
  }
}

// ═══════════════════════════════════════════════════════════════════
// NOTA DE CRÉDITO / DÉBITO — modelo local do PDF
// ═══════════════════════════════════════════════════════════════════

/// Linha de item efectivamente devolvido/ajustado numa nota retificativa.
/// Montada pelo chamador (screen) a partir dos itens seleccionados,
/// já que o backend não devolve os itens dentro de
/// NotaRetificativaResponseModel / DevolucaoResponseModel.
class ItemNotaRetificativaModel {
  final String descricao;
  final int quantidade;
  final double precoUnitario;

  const ItemNotaRetificativaModel({
    required this.descricao,
    required this.quantidade,
    required this.precoUnitario,
  });

  double get subtotal => precoUnitario * quantidade;
}

class NotaRetificativaPdfModel {
  final TipoDocumentoPdf tipo; // notaCredito | notaDebito

  /// Referência da própria nota, ex: NCR-0001/2026
  final String referencia;

  final String codigoAT;
  final DateTime dataEmissao;

  /// Referência do documento de origem (FAT/VD) sobre o qual a nota incide.
  final String referenciaDocumentoOrigem;

  /// Referência do pedido de origem, se disponível (apenas contexto).
  final String? referenciaPedidoOrigem;

  /// Código do motivo tal como vem do backend:
  /// ERRO_PREENCHIMENTO | TROCA_PRODUTO | DEVOLUCAO | IVA_INCORRETO | OUTRO
  final String motivo;

  final double valor;

  final ClienteModel? cliente;
  final String? nomeClienteSingular;
  final String? apelidoClienteSingular;

  final String? observacoes;
  final String? salesperson;

  /// Itens efectivamente devolvidos — só populado para DEVOLUCAO/TROCA_PRODUTO.
  /// Vazio para ERRO_PREENCHIMENTO (anulação total) e para NDB.
  final List<ItemNotaRetificativaModel> itensDevolvidos;

  const NotaRetificativaPdfModel({
    required this.tipo,
    required this.referencia,
    required this.codigoAT,
    required this.dataEmissao,
    required this.referenciaDocumentoOrigem,
    this.referenciaPedidoOrigem,
    required this.motivo,
    required this.valor,
    this.cliente,
    this.nomeClienteSingular,
    this.apelidoClienteSingular,
    this.observacoes,
    this.salesperson,
    this.itensDevolvidos = const [],
  });

  bool get temClienteSingular =>
      cliente == null &&
      ((nomeClienteSingular != null && nomeClienteSingular!.trim().isNotEmpty) ||
       (apelidoClienteSingular != null && apelidoClienteSingular!.trim().isNotEmpty));

  String get nomeClienteExibicao {
    if (cliente != null) return '${cliente!.nome ?? ''} ${cliente!.apelido ?? ''}'.trim();
    if (temClienteSingular) {
      return [nomeClienteSingular, apelidoClienteSingular]
          .where((v) => v != null && v.trim().isNotEmpty)
          .join(' ')
          .trim();
    }
    return '';
  }

  String get motivoLabel => switch (motivo) {
        'ERRO_PREENCHIMENTO' => 'Erro de preenchimento (anulação total da factura)',
        'TROCA_PRODUTO' => 'Troca de produto',
        'DEVOLUCAO' => 'Devolução',
        'IVA_INCORRETO' => 'IVA incorrecto',
        'OUTRO' => 'Outro',
        _ => motivo,
      };

  /// Fábrica a partir da resposta completa do backend (usada quando a API
  /// devolve NotaRetificativaResponseModel — actualmente é o caso de NDB;
  /// para NCR emitida via processarDevolucaoOuTroca, ver
  /// NotaRetificativaPdfModel.deDevolucaoResponse.
  factory NotaRetificativaPdfModel.deApiModel({
    required NotaRetificativaResponseModel apiModel,
    required String referenciaDocumentoOrigem,
    String? referenciaPedidoOrigem,
    ClienteModel? cliente,
    String? nomeClienteSingular,
    String? apelidoClienteSingular,
    String? observacoes,
    String? salesperson,
    List<ItemNotaRetificativaModel> itensDevolvidos = const [],
  }) {
    return NotaRetificativaPdfModel(
      tipo: TipoDocumentoPdfExt.dePrefixo(apiModel.documento.tipoDocumento.prefixo),
      referencia: apiModel.documento.referencia,
      codigoAT: apiModel.documento.codigoAt,
      dataEmissao: apiModel.documento.emitidoEm,
      referenciaDocumentoOrigem: referenciaDocumentoOrigem,
      referenciaPedidoOrigem: referenciaPedidoOrigem,
      motivo: apiModel.motivoRetificacao,
      valor: apiModel.valor,
      cliente: cliente,
      nomeClienteSingular: nomeClienteSingular,
      apelidoClienteSingular: apelidoClienteSingular,
      observacoes: observacoes,
      salesperson: salesperson,
      itensDevolvidos: itensDevolvidos,
    );
  }

  /// Fábrica a partir de DevolucaoResponseModel (fluxo NCR via
  /// processarDevolucaoOuTroca), que não traz codigoAt/emitidoEm/tipoDocumento
  /// completos. Requer que o chamador tenha buscado o DocumentoFiscalModel
  /// completo à parte (ex: via DocumentoFiscalProvider.buscarPorId) para
  /// preencher codigoAT e dataEmissao correctamente.
  factory NotaRetificativaPdfModel.deDevolucaoResponse({
    required DevolucaoResponseModel devolucao,
    required DocumentoFiscalModel documentoNota,
    required String referenciaDocumentoOrigem,
    String? referenciaPedidoOrigem,
    ClienteModel? cliente,
    String? nomeClienteSingular,
    String? apelidoClienteSingular,
    String? observacoes,
    String? salesperson,
    List<ItemNotaRetificativaModel> itensDevolvidos = const [],
  }) {
    return NotaRetificativaPdfModel(
      tipo: TipoDocumentoPdfExt.dePrefixo(documentoNota.tipoDocumento.prefixo),
      referencia: devolucao.referenciaNotaCredito,
      codigoAT: documentoNota.codigoAt,
      dataEmissao: documentoNota.emitidoEm,
      referenciaDocumentoOrigem: referenciaDocumentoOrigem,
      referenciaPedidoOrigem: referenciaPedidoOrigem,
      motivo: devolucao.motivo,
      valor: devolucao.valorCreditado,
      cliente: cliente,
      nomeClienteSingular: nomeClienteSingular,
      apelidoClienteSingular: apelidoClienteSingular,
      observacoes: observacoes,
      salesperson: salesperson,
      itensDevolvidos: itensDevolvidos,
    );
  }
}


// ═══════════════════════════════════════════════════════════════════
// DADOS FIXOS DA EMPRESA
// ═══════════════════════════════════════════════════════════════════

abstract final class _Empresa {
  static const nomeCompleto =
      'Segurança Tecnologica SU, LDA (Stech Engenharia)';
  static const bairro = 'Bairro: Chingodzi, Tete';
  static const telefone = 'Número: +258 84 239 0756 ou 87 939 0756';
  static const email = 'Email: info@stech.co.mz';
  static const website = 'Website: www.stecheng.co.mz';
  static const nuit = 'NUIT: 401 684 530';

  static const List<_Banco> bancos = [
    _Banco(
      banco: 'Banco Comercial de Investimentos, SA',
      conta: 'C- 29052431310001',
      nib: 'N- 00080000905243131 0113',
      moeda: 'MT',
    ),
    _Banco(
      banco: 'Moza Banco',
      conta: 'C- 4211626910001',
      nib: 'N- 003400004211626910192',
      moeda: 'MT',
    ),
  ];


}

class _Banco {
  final String banco, conta, nib, moeda;
  const _Banco({
    required this.banco,
    required this.conta,
    required this.nib,
    required this.moeda,
  });
}

// ═══════════════════════════════════════════════════════════════════
// CORES DA MARCA
// ═══════════════════════════════════════════════════════════════════

const _kAzul = PdfColor.fromInt(0xFF1B2A6B);
const _kVermelho = PdfColor.fromInt(0xFFC8102E);

// ═══════════════════════════════════════════════════════════════════
// FORMATOS DE PAPEL
// ═══════════════════════════════════════════════════════════════════

enum PaperFormat { a4, thermal58mm, thermal80mm }

// ═══════════════════════════════════════════════════════════════════
// PDF SERVICE
// ═══════════════════════════════════════════════════════════════════

class PdfService {
  static final PdfService instance = PdfService._internal();
  factory PdfService() => instance;
  PdfService._internal();

  final _fmt = DateFormat('dd/MM/yyyy');

  double _removerIva(double valorComIva) {
  return valorComIva / (1 + kTaxaIva);
}

double _calcularIva(double valorComIva) {
  return valorComIva - _removerIva(valorComIva);
}

  // ─────────────────────────────────────────────────────────────────
  // PÚBLICO: Gerar documento fiscal
  // ─────────────────────────────────────────────────────────────────

Future<File> gerarDocumentoFiscal(
  DocumentoPdfModel doc, {
  DocumentoFiscalModel? documentoFiscal,
}) async {
  final pdf = await _buildDocumentoFiscal(
    doc,
    documentoFiscal: documentoFiscal,
  );

  return _savePdfWithName(pdf, _nomeArquivo(doc));
}

  Future<File> gerarReciboCredito(ReciboCreditoPdfModel doc) async {
  final pdf = await _buildReciboCredito(doc);
  return _savePdfWithName(pdf, _nomeArquivoReciboCredito(doc));
}


  Future<void> imprimirDocumentoFiscalViaSumatra({
    required DocumentoPdfModel doc,
    required String impressoraNome,
  }) async {
    _assertWindows();
    final sumatra = _sumatraPath();
    final pdf = await _buildDocumentoFiscal(doc);
    final file = await _savePdfWithName(pdf, _nomeArquivo(doc));
    final result = await Process.run(sumatra, [
      '-print-to', impressoraNome,
      '-print-settings', 'fit',
      '-silent',
      file.path,
    ]);
    if (result.exitCode != 0) {
      throw Exception('SumatraPDF erro (${result.exitCode}): ${result.stderr}');
    }
  }

  Future<void> imprimirReciboCreditoViaSumatra({
  required ReciboCreditoPdfModel doc,
  required String impressoraNome,
}) async {
  _assertWindows();

  final sumatra = _sumatraPath();
  final pdf = await _buildReciboCredito(doc);
  final file = await _savePdfWithName(pdf, _nomeArquivoReciboCredito(doc));

  final result = await Process.run(sumatra, [
    '-print-to',
    impressoraNome,
    '-print-settings',
    'fit',
    '-silent',
    file.path,
  ]);

  if (result.exitCode != 0) {
    throw Exception('SumatraPDF erro (${result.exitCode}): ${result.stderr}');
  }
}

// ═════════════════════════════════════════════════════════════════
  // PÚBLICO: Gerar Nota de Crédito / Débito
  // ═════════════════════════════════════════════════════════════════

  Future<File> gerarNotaRetificativa(NotaRetificativaPdfModel doc) async {
    final pdf = await _buildNotaRetificativa(doc);
    return _savePdfWithName(pdf, _nomeArquivoNotaRetificativa(doc));
  }

  Future<void> imprimirNotaRetificativaViaSumatra({
    required NotaRetificativaPdfModel doc,
    required String impressoraNome,
  }) async {
    _assertWindows();
    final sumatra = _sumatraPath();
    final pdf = await _buildNotaRetificativa(doc);
    final file = await _savePdfWithName(pdf, _nomeArquivoNotaRetificativa(doc));
    final result = await Process.run(sumatra, [
      '-print-to', impressoraNome,
      '-print-settings', 'fit',
      '-silent',
      file.path,
    ]);
    if (result.exitCode != 0) {
      throw Exception('SumatraPDF erro (${result.exitCode}): ${result.stderr}');
    }
  }

  Future<void> imprimirNotaRetificativaComDialogo({
    required NotaRetificativaPdfModel doc,
  }) async {
    _assertWindows();
    final sumatra = _sumatraPath();
    final pdf = await _buildNotaRetificativa(doc);
    final file = await _savePdfWithName(pdf, _nomeArquivoNotaRetificativa(doc));
    await Process.run(sumatra, ['-print-dialog', file.path]);
  }

  // ═════════════════════════════════════════════════════════════════
  // BUILD — NOTA DE CRÉDITO / DÉBITO
  // ═════════════════════════════════════════════════════════════════

  Future<pw.Document> _buildNotaRetificativa(NotaRetificativaPdfModel doc) async {
    final iconBytes = await rootBundle.load('assets/icon/app_icon.png');
    final iconImage = pw.MemoryImage(iconBytes.buffer.asUint8List());

    final pdf = pw.Document(
      title: doc.referencia,
      author: _Empresa.nomeCompleto,
      creator: 'Sistema de Gestão Stech',
    );

    final corAccent = doc.tipo == TipoDocumentoPdf.notaCredito ? _kAzul : _kVermelho;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(30, 28, 30, 20),
        footer: (ctx) => _docFiscalFooterPagina(ctx),
        build: (ctx) => [
          _notaRetificativaCabecalho(doc, iconImage, corAccent),
          pw.SizedBox(height: 6),
          _notaRetificativaEmissorCliente(doc),
          pw.SizedBox(height: 6),
          pw.Divider(color: PdfColors.grey400, thickness: 0.5),
          pw.SizedBox(height: 4),
          _notaRetificativaMetadados(doc),
          pw.SizedBox(height: 8),
          _notaRetificativaBlocoMotivo(doc, corAccent),
          if (doc.itensDevolvidos.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            _notaRetificativaTabelaItens(doc.itensDevolvidos),
          ],
          pw.SizedBox(height: 12),
          _notaRetificativaResumoValor(doc, corAccent),
          if (doc.observacoes != null && doc.observacoes!.trim().isNotEmpty) ...[
            pw.SizedBox(height: 10),
            _notaRetificativaObservacoes(doc.observacoes!),
          ],
          pw.SizedBox(height: 16),
          _docFiscalCodigoAT(doc.codigoAT),
        ],
      ),
    );

    return pdf;
  }

  pw.Widget _notaRetificativaCabecalho(
    NotaRetificativaPdfModel doc,
    pw.MemoryImage icon,
    PdfColor corAccent,
  ) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Image(icon, width: 135, height: 80, fit: pw.BoxFit.contain),
            pw.SizedBox(width: 20),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    doc.tipo.titulo,
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: corAccent,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Referente à factura ${doc.referenciaDocumentoOrigem}',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                    textAlign: pw.TextAlign.right,
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: corAccent, thickness: 2.5),
      ],
    );
  }

  pw.Widget _notaRetificativaEmissorCliente(NotaRetificativaPdfModel doc) {
    final nomeCliente = doc.nomeClienteExibicao;
    final c = doc.cliente;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _t(_Empresa.nomeCompleto, bold: true, size: 8.5),
              pw.SizedBox(height: 2),
              _t(_Empresa.bairro, size: 8),
              _t(_Empresa.telefone, size: 8),
              _t(_Empresa.email, size: 8),
              _t(_Empresa.website, size: 8),
              _t(_Empresa.nuit, size: 8),
            ],
          ),
        ),
        pw.SizedBox(width: 20),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _t('Exmo. (s) Sr(s)', size: 8, color: PdfColors.grey700),
              pw.SizedBox(height: 2),
              if (nomeCliente.isNotEmpty)
                _t('Nome:  $nomeCliente', bold: true, size: 8.5),
              if (c != null && c.nuit != null && c.nuit!.isNotEmpty)
                _t('NUIT:  ${c.nuit}', size: 8),
              if (c != null && c.morada != null && c.morada!.isNotEmpty)
                _t('Endereço:  ${c.morada}', size: 8),
              if (c != null && c.contacto != null && c.contacto!.isNotEmpty)
                _t('Tel:  ${c.contacto}', size: 8),
              if (doc.temClienteSingular)
                _t('Tipo:  Cliente singular', size: 8, color: PdfColors.grey700),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _notaRetificativaMetadados(NotaRetificativaPdfModel doc) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _metaRow('Data:', _fmt.format(doc.dataEmissao)),
              _metaRow('Gerado em:',
                  DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())),
              _metaRow('Documento de origem:', doc.referenciaDocumentoOrigem),
              if (doc.referenciaPedidoOrigem != null)
                _metaRow('Pedido:', doc.referenciaPedidoOrigem!),
              if (doc.salesperson != null && doc.salesperson!.isNotEmpty)
                _metaRow('Salesperson:', doc.salesperson!),
              _metaRow('Moeda:', 'MT'),
            ],
          ),
        ),
        pw.Text(
          '${doc.tipo.labelReferencia} ${doc.referencia}',
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: _kVermelho,
          ),
        ),
      ],
    );
  }

  pw.Widget _notaRetificativaBlocoMotivo(NotaRetificativaPdfModel doc, PdfColor corAccent) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: corAccent, width: 0.6),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Motivo',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: corAccent),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            doc.motivoLabel,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
          ),
        ],
      ),
    );
  }

  pw.Widget _notaRetificativaTabelaItens(List<ItemNotaRetificativaModel> itens) {
    const pw.TextStyle estiloHeader = pw.TextStyle(fontSize: 8, color: PdfColors.white);
    const pw.TextStyle estiloCell = pw.TextStyle(fontSize: 8);

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(28),
        1: pw.FlexColumnWidth(),
        2: pw.FixedColumnWidth(88),
        3: pw.FixedColumnWidth(88),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _kAzul),
          children: [
            _thCell('Qt', estiloHeader, align: pw.TextAlign.center),
            _thCell('Descrição', estiloHeader),
            _thCell('Preço Unitário', estiloHeader, align: pw.TextAlign.right),
            _thCell('Subtotal', estiloHeader, align: pw.TextAlign.right),
          ],
        ),
        for (final item in itens)
          pw.TableRow(
            children: [
              _tdCell('${item.quantidade}', estiloCell, align: pw.TextAlign.center),
              _tdCell(item.descricao, estiloCell),
              _tdCell('MZN ${item.precoUnitario.toStringAsFixed(2)}', estiloCell,
                  align: pw.TextAlign.right),
              _tdCell('MZN ${item.subtotal.toStringAsFixed(2)}', estiloCell,
                  align: pw.TextAlign.right),
            ],
          ),
      ],
    );
  }

  pw.Widget _notaRetificativaResumoValor(NotaRetificativaPdfModel doc, PdfColor corAccent) {
    final label = doc.tipo == TipoDocumentoPdf.notaCredito
        ? 'Valor creditado'
        : 'Valor debitado';

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 10, color: corAccent)),
          pw.Text(
            'MZN ${doc.valor.toStringAsFixed(2)}',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: corAccent),
          ),
        ],
      ),
    );
  }

  pw.Widget _notaRetificativaObservacoes(String obs) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _t('Observações', bold: true, size: 8, color: _kAzul),
          pw.SizedBox(height: 3),
          _t(obs, size: 8, color: PdfColors.grey800),
        ],
      ),
    );
  }


  Future<void> imprimirDocumentoFiscalComDialogo({
    required DocumentoPdfModel doc,
  }) async {
    _assertWindows();
    final sumatra = _sumatraPath();
    final pdf = await _buildDocumentoFiscal(doc);
    final file = await _savePdfWithName(pdf, _nomeArquivo(doc));
    await Process.run(sumatra, ['-print-dialog', file.path]);
  }

  Future<void> imprimirReciboCreditoComDialogo({
  required ReciboCreditoPdfModel doc,
}) async {
  _assertWindows();

  final sumatra = _sumatraPath();
  final pdf = await _buildReciboCredito(doc);
  final file = await _savePdfWithName(pdf, _nomeArquivoReciboCredito(doc));

  await Process.run(sumatra, ['-print-dialog', file.path]);
}

  // ─────────────────────────────────────────────────────────────────
  // PÚBLICO: Comprovativo térmico (fluxo antigo — mantido intacto)
  // ─────────────────────────────────────────────────────────────────

  Future<File> gerarComprovativo({
    required PedidoModel pedido,
    required String tipoPagamento,
    String? nomeCliente,
    String? telefoneCliente,
    PaperFormat paperFormat = PaperFormat.a4,
  }) async {
    final pdf = await _buildComprovativo(
      pedido: pedido,
      tipoPagamento: tipoPagamento,
      paperFormat: paperFormat,
      nomeCliente: nomeCliente,
      telefoneCliente: telefoneCliente,
    );
    return _savePdf(pdf, pedido.idPedido);
  }

  Future<void> imprimirComprovativo({
    required PedidoModel pedido,
    required String tipoPagamento,
    String? nomeCliente,
    String? telefoneCliente,
    PaperFormat paperFormat = PaperFormat.thermal80mm,
  }) async {
    _assertWindows();
    final sumatra = _sumatraPath();
    final pdf = await _buildComprovativo(
      pedido: pedido,
      tipoPagamento: tipoPagamento,
      paperFormat: paperFormat,
      nomeCliente: nomeCliente,
      telefoneCliente: telefoneCliente,
    );
    final file = await _savePdf(pdf, pedido.idPedido);
    await Process.run(sumatra, ['-print-dialog', file.path]);
  }

  Future<void> imprimirSilencioso({
    required PedidoModel pedido,
    required String tipoPagamento,
    required Printer impressora,
    String? nomeCliente,
    String? telefoneCliente,
    PaperFormat paperFormat = PaperFormat.thermal80mm,
  }) async {
    final pdf = await _buildComprovativo(
      pedido: pedido,
      tipoPagamento: tipoPagamento,
      paperFormat: paperFormat,
      nomeCliente: nomeCliente,
      telefoneCliente: telefoneCliente,
    );
    final file = await _savePdf(pdf, pedido.idPedido);
    final bytes = await file.readAsBytes();
    await Printing.directPrintPdf(
      printer: impressora,
      onLayout: (_) async => bytes,
      name: _nomeAutomaticoComprovativo(pedido.idPedido),
      usePrinterSettings: false,
    );
  }

  Future<void> imprimirViaSumatra({
    required PedidoModel pedido,
    required String tipoPagamento,
    required String impressoraNome,
    String? nomeCliente,
    String? telefoneCliente,
    PaperFormat paperFormat = PaperFormat.thermal80mm,
  }) async {
    _assertWindows();
    final sumatra = _sumatraPath();
    final pdf = await _buildComprovativo(
      pedido: pedido,
      tipoPagamento: tipoPagamento,
      paperFormat: paperFormat,
      nomeCliente: nomeCliente,
      telefoneCliente: telefoneCliente,
    );
    final file = await _savePdf(pdf, pedido.idPedido);
    final result = await Process.run(sumatra, [
      '-print-to', impressoraNome,
      '-print-settings', 'fit',
      '-silent',
      file.path,
    ]);
    if (result.exitCode != 0) {
      throw Exception('SumatraPDF erro (${result.exitCode}): ${result.stderr}');
    }
  }

  Future<void> abrirPdf(File file) async {
    final result = await OpenFilex.open(file.path);
    switch (result.type) {
      case ResultType.done:
        return;
      case ResultType.noAppToOpen:
        throw Exception(
            'Nenhuma app de leitura de PDF encontrada.\nFicheiro em: ${file.path}');
      case ResultType.fileNotFound:
        throw Exception('Ficheiro não encontrado: ${file.path}');
      case ResultType.permissionDenied:
        throw Exception('Permissão negada ao abrir o ficheiro.');
      case ResultType.error:
        throw Exception('Erro ao abrir o PDF: ${result.message}');
    }
  }

  // ═════════════════════════════════════════════════════════════════
  // BUILD — DOCUMENTO FISCAL
  // ═════════════════════════════════════════════════════════════════

Future<pw.Document> _buildDocumentoFiscal(
  DocumentoPdfModel doc, {
  DocumentoFiscalModel? documentoFiscal,
}) async {
    final iconBytes = await rootBundle.load('assets/icon/app_icon.png');
    final iconImage = pw.MemoryImage(iconBytes.buffer.asUint8List());

    final pdf = pw.Document(
      title: doc.referencia,
      author: _Empresa.nomeCompleto,
      creator: 'Sistema de Gestão Stech',
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(30, 28, 30, 20),
        footer: (ctx) => _docFiscalFooterPagina(ctx),
        build: (ctx) => [
          _docFiscalCabecalho(doc, iconImage),
          pw.SizedBox(height: 6),
          _docFiscalEmissorCliente(doc),
          pw.SizedBox(height: 6),
          pw.Divider(color: PdfColors.grey400, thickness: 0.5),
          pw.SizedBox(height: 4),
         _docFiscalMetadados(doc),

if (documentoFiscal?.anulado == true) ...[
  pw.SizedBox(height: 6),
  _docFiscalBlocoAnulacao(documentoFiscal!),
],

pw.SizedBox(height: 6),
_docFiscalTabelaItens(doc),
          pw.SizedBox(height: 10),
          _docFiscalAssinatura(doc),
          pw.SizedBox(height: 8),
          _docFiscalTermos(doc),
          pw.SizedBox(height: 8),
          if (doc.tipo != TipoDocumentoPdf.notaDeEntrega) ...[
            _docFiscalDadosBancarios(),
            pw.SizedBox(height: 6),
          ],
          _docFiscalCodigoAT(doc.codigoAT),
        ],
      ),
    );

    return pdf;
  }

Future<pw.Document> _buildReciboCredito(ReciboCreditoPdfModel doc) async {
  final iconBytes = await rootBundle.load('assets/icon/app_icon.png');
  final iconImage = pw.MemoryImage(iconBytes.buffer.asUint8List());

  final pdf = pw.Document(
    title: doc.referenciaRecibo,
    author: _Empresa.nomeCompleto,
    creator: 'Sistema de Gestão Stech',
  );

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(30, 28, 30, 20),
      footer: (ctx) => _docFiscalFooterPagina(ctx),
      build: (ctx) => [
        _reciboCreditoCabecalho(doc, iconImage),
        pw.SizedBox(height: 6),
        _reciboCreditoEmissorCliente(doc),
        pw.SizedBox(height: 6),
        pw.Divider(color: PdfColors.grey400, thickness: 0.5),
        pw.SizedBox(height: 4),
        _reciboCreditoMetadados(doc),
        pw.SizedBox(height: 10),
        _reciboCreditoResumo(doc),
        pw.SizedBox(height: 14),
        _reciboCreditoObservacoes(doc),
        pw.SizedBox(height: 16),
        _reciboCreditoAssinatura(),
        pw.SizedBox(height: 8),
        _docFiscalCodigoAT(doc.codigoAT),
      ],
    ),
  );

  return pdf;
}

pw.Widget _reciboCreditoCabecalho(
  ReciboCreditoPdfModel doc,
  pw.MemoryImage icon,
) {
  return pw.Column(
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Image(
            icon,
            width: 135,
            height: 80,
            fit: pw.BoxFit.contain,
          ),
          pw.SizedBox(width: 20),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'RECIBO',
                  style: pw.TextStyle(
                    fontSize: 26,
                    fontWeight: pw.FontWeight.bold,
                    color: _kAzul,
                  ),
                  textAlign: pw.TextAlign.right,
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Pagamento de venda a crédito',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                  textAlign: pw.TextAlign.right,
                ),
              ],
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 10),
      pw.Divider(color: _kAzul, thickness: 2.5),
    ],
  );
}



  // ─── 1. Cabeçalho ──────────────────────────────────────────────

// ─── 1. Cabeçalho ──────────────────────────────────────────────
pw.Widget _docFiscalCabecalho(DocumentoPdfModel doc, pw.MemoryImage icon) {
  return pw.Column(
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Image(
            icon,
            width: 135,
            height: 80,
            fit: pw.BoxFit.contain,
          ),
          pw.SizedBox(width: 20),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  doc.tipo.titulo,
                  style: pw.TextStyle(
                    fontSize: 26,
                    fontWeight: pw.FontWeight.bold,
                    color: _kAzul,
                  ),
                  textAlign: pw.TextAlign.right,
                ),
                // === REMOVIDO A REFERÊNCIA GRANDE DO CABEÇALHO ===
                // pw.Text(doc.referencia ... ) ← removido
              ],
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 10),
      pw.Divider(color: _kAzul, thickness: 2.5),
    ],
  );
}

  // ─── 2. Emissor | Cliente ──────────────────────────────────────

pw.Widget _docFiscalEmissorCliente(DocumentoPdfModel doc) {
  final c = doc.cliente;

  final nomeSingular = [
    doc.pedido.nomeClienteSingular,
    doc.pedido.apelidoClienteSingular,
  ]
      .where((v) => v != null && v.trim().isNotEmpty)
      .join(' ')
      .trim();

  final nomeClienteModel = c != null
      ? '${c.nome ?? ''} ${c.apelido ?? ''}'.trim()
      : '';

  final ehClienteSingular =
      doc.pedido.idCliente == null && nomeSingular.isNotEmpty;

  final nomeCliente = ehClienteSingular
      ? nomeSingular
      : nomeClienteModel;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _t(_Empresa.nomeCompleto, bold: true, size: 8.5),
              pw.SizedBox(height: 2),
              _t(_Empresa.bairro, size: 8),
              _t(_Empresa.telefone, size: 8),
              _t(_Empresa.email, size: 8),
              _t(_Empresa.website, size: 8),
              _t(_Empresa.nuit, size: 8),
            ],
          ),
        ),
        pw.SizedBox(width: 20),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _t('Exmo. (s) Sr(s)', size: 8, color: PdfColors.grey700),
              pw.SizedBox(height: 2),
              if (nomeCliente.isNotEmpty)
                _t('Nome:  $nomeCliente', bold: true, size: 8.5),
            if (c != null && c.nuit != null && c.nuit!.isNotEmpty)
  _t('NUIT:  ${c.nuit}', size: 8),
if (c != null && c.morada != null && c.morada!.isNotEmpty)
  _t('Endereço:  ${c.morada}', size: 8),
if (c != null && c.contacto != null && c.contacto!.isNotEmpty)
  _t('Tel:  ${c.contacto}', size: 8),
if (ehClienteSingular)
  _t('Tipo:  Cliente singular', size: 8, color: PdfColors.grey700),
            ],
          ),
        ),
      ],
    );
  }


pw.Widget _reciboCreditoEmissorCliente(ReciboCreditoPdfModel doc) {
  final c = doc.cliente;
  final nomeCliente = '${c.nome ?? ''} ${c.apelido ?? ''}'.trim();

  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _t(_Empresa.nomeCompleto, bold: true, size: 8.5),
            pw.SizedBox(height: 2),
            _t(_Empresa.bairro, size: 8),
            _t(_Empresa.telefone, size: 8),
            _t(_Empresa.email, size: 8),
            _t(_Empresa.website, size: 8),
            _t(_Empresa.nuit, size: 8),
          ],
        ),
      ),
      pw.SizedBox(width: 20),
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _t('Exmo. (s) Sr(s)', size: 8, color: PdfColors.grey700),
            pw.SizedBox(height: 2),
            if (nomeCliente.isNotEmpty)
              _t('Nome:  $nomeCliente', bold: true, size: 8.5),
            if (c.nuit != null && c.nuit!.isNotEmpty)
              _t('NUIT:  ${c.nuit}', size: 8),
            if (c.morada != null && c.morada!.isNotEmpty)
              _t('Endereço:  ${c.morada}', size: 8),
            if (c.contacto != null && c.contacto!.isNotEmpty)
              _t('Tel:  ${c.contacto}', size: 8),
          ],
        ),
      ),
    ],
  );
}

pw.Widget _reciboCreditoMetadados(ReciboCreditoPdfModel doc) {
  final parcelaTexto = doc.numeroParcela == null
      ? '-'
      : doc.totalParcelas == null
          ? '${doc.numeroParcela}'
          : '${doc.numeroParcela}/${doc.totalParcelas}';

  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _metaRow('Data:', _fmt.format(doc.dataEmissao)),
            _metaRow(
              'Gerado em:',
              DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
            ),
            _metaRow('Pedido:', doc.pedido.referencia),
            _metaRow('Factura associada:', doc.referenciaFactura),
            _metaRow('Método de pagamento:', doc.tipoPagamento),
            _metaRow('Parcela:', parcelaTexto),
            if (doc.salesperson != null && doc.salesperson!.isNotEmpty)
              _metaRow('Salesperson:', doc.salesperson!),
            _metaRow('Moeda:', 'MT'),
          ],
        ),
      ),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            'Recibo Nº ${doc.referenciaRecibo}',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: _kVermelho,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            'Referente à Factura Nº ${doc.referenciaFactura}',
            style: const pw.TextStyle(
              fontSize: 7,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    ],
  );
}

pw.Widget _reciboCreditoResumo(ReciboCreditoPdfModel doc) {
  final valorPago = doc.pagamento.valorPago;

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _t('Resumo do pagamento', bold: true, size: 9, color: _kAzul),
      pw.SizedBox(height: 6),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        columnWidths: const {
          0: pw.FlexColumnWidth(),
          1: pw.FixedColumnWidth(120),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _kAzul),
            children: [
              _thCell(
                'Descrição',
                const pw.TextStyle(fontSize: 8, color: PdfColors.white),
              ),
              _thCell(
                'Valor',
                const pw.TextStyle(fontSize: 8, color: PdfColors.white),
                align: pw.TextAlign.right,
              ),
            ],
          ),
          _reciboRow('Total da factura', doc.pedido.total),
          _reciboRow('Saldo anterior', doc.saldoAnterior),
          _reciboRow(doc.descricaoPagamento, valorPago),
          _reciboRow('Saldo remanescente', doc.saldoRemanescente, destaque: true),
        ],
      ),
    ],
  );
}

pw.TableRow _reciboRow(
  String label,
  double valor, {
  bool destaque = false,
}) {
  final estiloLabel = pw.TextStyle(
    fontSize: destaque ? 9 : 8,
    fontWeight: destaque ? pw.FontWeight.bold : pw.FontWeight.normal,
    color: destaque ? _kAzul : PdfColors.black,
  );

  final estiloValor = pw.TextStyle(
    fontSize: destaque ? 9 : 8,
    fontWeight: pw.FontWeight.bold,
    color: destaque ? _kVermelho : PdfColors.black,
  );

  return pw.TableRow(
    decoration: destaque
        ? const pw.BoxDecoration(color: PdfColors.grey200)
        : null,
    children: [
      _tdCell(label, estiloLabel),
      _tdCell(
        'MZN ${valor.toStringAsFixed(2)}',
        estiloValor,
        align: pw.TextAlign.right,
      ),
    ],
  );
}



pw.Widget _reciboCreditoObservacoes(ReciboCreditoPdfModel doc) {
  final obs = doc.observacoes ?? doc.pagamento.observacoes;

  if (obs == null || obs.trim().isEmpty) {
    return pw.SizedBox.shrink();
  }

  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      color: PdfColors.grey100,
      border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _t('Observações', bold: true, size: 8, color: _kAzul),
        pw.SizedBox(height: 3),
        _t(obs, size: 8, color: PdfColors.grey800),
      ],
    ),
  );
}

pw.Widget _reciboCreditoAssinatura() {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Divider(color: PdfColors.grey400, thickness: 0.5),
      pw.SizedBox(height: 8),
      pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _t('Recebido por: ___________________________', size: 8),
                pw.SizedBox(height: 14),
                _t('Assinatura: _____________________________', size: 8),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: _t('Data: _______ / _______ / ___________', size: 8),
            ),
          ),
        ],
      ),
    ],
  );
}





  // ─── 3. Metadados ─────────────────────────────────────────────

  pw.Widget _docFiscalMetadados(DocumentoPdfModel doc) {

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
_metaRow('Data:', _fmt.format(doc.dataEmissao)),
_metaRow('Gerado em:', DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())),
            
              _metaRow('Prazo de Pagamento:', doc.prazoPagamento),
              if (doc.salesperson != null && doc.salesperson!.isNotEmpty)
                _metaRow('Salesperson:', doc.salesperson!),
              _metaRow('Moeda:', 'MT'),
            ],
          ),
        ),
        pw.Text(
          '${doc.tipo.labelReferencia} ${doc.referencia}',
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: _kVermelho,
          ),
        ),
      ],
    );
  }


  pw.Widget _docFiscalBlocoAnulacao(DocumentoFiscalModel documentoFiscal) {
  final motivo = documentoFiscal.motivoAnulacao?.trim();

  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      color: PdfColors.red50,
      border: pw.Border.all(
        color: _kVermelho,
        width: 0.6,
      ),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'DOCUMENTO ANULADO',
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: _kVermelho,
          ),
        ),
        if (motivo != null && motivo.isNotEmpty) ...[
          pw.SizedBox(height: 3),
          pw.Text(
            'Motivo da anulação: $motivo',
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.red900,
            ),
          ),
        ],
      ],
    ),
  );
}

  pw.Widget _metaRow(String label, String valor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 130,
            child: _t(label, size: 8, color: PdfColors.grey700),
          ),
          _t(valor, size: 8),
        ],
      ),
    );
  }

  // ─── 4. Tabela de itens ───────────────────────────────────────

pw.Widget _docFiscalTabelaItens(DocumentoPdfModel doc) {
    // Se existir snapshot (FAT/VD já emitida), usa-o SEMPRE — é a
    // fotografia imutável do momento da emissão. Só cai para o pedido ao
    // vivo quando não há snapshot (ex: documento antigo emitido antes desta
    // funcionalidade, ou tipos de documento que não geram snapshot).
    final snap = doc.snapshot;

    final double totalComIva;
    final List<SnapshotItemFiscal> produtosSnap;
    final List<SnapshotItemFiscal> servicosSnap;

    if (snap != null) {
      totalComIva = snap.total;
      produtosSnap = snap.itensProduto;
      servicosSnap = snap.itensServico;
    } else {
      final pedido = doc.pedido;
      totalComIva = pedido.total;
      produtosSnap = pedido.itensProduto
          .map((p) => SnapshotItemFiscal(
                descricao: p.nomeProduto.isNotEmpty
                    ? p.nomeProduto
                    : 'Produto #${p.idProduto}',
                quantidade: p.quantidade,
                precoUnitario: p.precoUnitario,
                subtotal: p.subtotal,
              ))
          .toList();
      servicosSnap = pedido.itensServico
          .map((s) => SnapshotItemFiscal(
                descricao: (s.nomeServico != null && s.nomeServico!.isNotEmpty)
                    ? s.nomeServico!
                    : 'Serviço #${s.idServico}',
                quantidade: s.quantidade,
                precoUnitario: s.precoUnitario,
                subtotal: s.subtotal,
                observacoes: s.observacoes,
              ))
          .toList();
    }

final subtotalSemIva = produtosSnap.fold<double>(
      0,
      (soma, item) => soma + _removerIva(item.subtotal),
    ) +
    servicosSnap.fold<double>(
      0,
      (soma, item) => soma + _removerIva(item.subtotal),
    );

final valorIva = totalComIva - subtotalSemIva;

 final List<_LinhaItem> linhas = [
  for (final p in produtosSnap)
    _LinhaItem(
      quantidade: p.quantidade,
      descricao: p.descricao,
      precoUnitario: _removerIva(p.precoUnitario),
      total: _removerIva(p.subtotal),
    ),
for (final s in servicosSnap)
  _LinhaItem(
    quantidade: s.quantidade,
    descricao: s.descricao,
    precoUnitario: _removerIva(s.precoUnitario),
    total: _removerIva(s.subtotal),
    obs: s.observacoes,
  ),
    ];

    const int minLinhas = 12;
    while (linhas.length < minLinhas) {
      linhas.add(_LinhaItem.vazia());
    }

    const pw.TextStyle estiloHeader = pw.TextStyle(fontSize: 8, color: PdfColors.white);
    const pw.TextStyle estiloCell = pw.TextStyle(fontSize: 8);
    final pw.TextStyle estiloCellBold = pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold);

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(28),
        1: pw.FlexColumnWidth(),
        2: pw.FixedColumnWidth(88),
        3: pw.FixedColumnWidth(88),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _kAzul),
          children: [
            _thCell('Qt', estiloHeader, align: pw.TextAlign.center),
            _thCell('Descrição', estiloHeader),
            _thCell('Preço Unitário', estiloHeader, align: pw.TextAlign.right),
            _thCell('Total', estiloHeader, align: pw.TextAlign.right),
          ],
        ),
        for (final l in linhas)
          pw.TableRow(
            children: [
              _tdCell(l.qtStr, estiloCell, align: pw.TextAlign.center),
              _tdCellDescricao(l, estiloCell),
              _tdCell(l.precoStr, estiloCell, align: pw.TextAlign.right),
              _tdCell(l.totalStr, estiloCell, align: pw.TextAlign.right),
            ],
          ),
        pw.TableRow(
          children: [
            _tdCell('', estiloCell),
            _tdCell('', estiloCell),
            _tdCell('Subtotal', estiloCellBold, align: pw.TextAlign.right),
            _tdCell('MZN ${subtotalSemIva.toStringAsFixed(2)}', estiloCellBold, align: pw.TextAlign.right),
          ],
        ),
        pw.TableRow(
          children: [
            _tdCell('', estiloCell),
            _tdCell('', estiloCell),
            _tdCell('IVA ${(kTaxaIva * 100).toStringAsFixed(0)}%', estiloCell, align: pw.TextAlign.right),
            _tdCell(valorIva.toStringAsFixed(2), estiloCell, align: pw.TextAlign.right),
          ],
        ),
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _tdCell('', estiloCell),
            _tdCell('', estiloCell),
            _tdCell('Total', pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _kAzul), align: pw.TextAlign.right),
            _tdCell('MZN ${totalComIva.toStringAsFixed(2)}', pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _kVermelho), align: pw.TextAlign.right),
          ],
        ),
      ],
    );
  }

  // ─── 5. Assinatura ────────────────────────────────────────────

pw.Widget _docFiscalAssinatura(DocumentoPdfModel doc) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: [
      pw.SizedBox(height: 4),
      _t('Assinatura: _____________________________', size: 8),
      pw.SizedBox(height: 6),
      pw.Divider(color: PdfColors.grey400, thickness: 0.5),
    ],
  );
}

  // ─── 6. Termos e condições ────────────────────────────────────

pw.Widget _docFiscalTermos(DocumentoPdfModel doc) {
  return pw.SizedBox.shrink();
}

  // ─── 7. Dados bancários ───────────────────────────────────────

  pw.Widget _docFiscalDadosBancarios() {
    const pw.TextStyle estiloHeader = pw.TextStyle(fontSize: 7, color: PdfColors.white);
    const pw.TextStyle estiloCell = pw.TextStyle(fontSize: 7);

    return pw.Column(
      children: [
        pw.Container(
          width: double.infinity,
          color: PdfColors.grey300,
          padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
          child: pw.Text(
            'O pagamento pode ser feito por Cheque, Depósito ou Transferência Bancária'
            ' — Titular: Stech Engenharia SU, Lda',
            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(2.5),
            1: pw.FlexColumnWidth(2),
            2: pw.FlexColumnWidth(3),
            3: pw.FixedColumnWidth(28),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _kAzul),
              children: [
                _thCell('Banco', estiloHeader),
                _thCell('Conta', estiloHeader),
                _thCell('NIB', estiloHeader),
                _thCell('Moeda', estiloHeader, align: pw.TextAlign.center),
              ],
            ),
            ..._Empresa.bancos.map(
              (b) => pw.TableRow(
                children: [
                  _tdCell(b.banco, estiloCell),
                  _tdCell(b.conta, estiloCell),
                  _tdCell(b.nib, estiloCell),
                  _tdCell(b.moeda, estiloCell, align: pw.TextAlign.center),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── 8. Código AT ────────────────────────────────────────────

pw.Widget _docFiscalCodigoAT(String codigoAT) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.only(top: 4),
    alignment: pw.Alignment.center,
    child: pw.Text(
      'Documento processado por computador através do Sistema de Facturação Stech ERP.',
      // devidamente autorizado pela Administração Tributária de Moçambique – Área Fiscal de Tete
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(
        fontSize: 7,
        fontStyle: pw.FontStyle.italic,
        color: PdfColors.grey700,
      ),
    ),
  );
}

  // ─── Rodapé de página ─────────────────────────────────────────

  pw.Widget _docFiscalFooterPagina(pw.Context ctx) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _t('Stech Engenharia (c) ${DateTime.now().year}', size: 7, color: PdfColors.grey600),
        _t('Página ${ctx.pageNumber} de ${ctx.pagesCount}', size: 7, color: PdfColors.grey600),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════
  // BUILD — COMPROVATIVO TÉRMICO (fluxo antigo — mantido intacto)
  // ═════════════════════════════════════════════════════════════════

  Future<pw.Document> _buildComprovativo({
    required PedidoModel pedido,
    required String tipoPagamento,
    required PaperFormat paperFormat,
    String? nomeCliente,
    String? telefoneCliente,
  }) async {
    final iconBytes = await rootBundle.load('assets/icon/app_icon.png');
    final iconImage = pw.MemoryImage(iconBytes.buffer.asUint8List());

    final bool isSmall = paperFormat != PaperFormat.a4;
final nomeSingular = [
  pedido.nomeClienteSingular,
  pedido.apelidoClienteSingular,
]
    .where((v) => v != null && v.trim().isNotEmpty)
    .join(' ')
    .trim();

final nomeClienteFinal =
    (nomeCliente != null && nomeCliente.trim().isNotEmpty)
        ? nomeCliente.trim()
        : nomeSingular;

final bool temCliente =
    nomeClienteFinal.isNotEmpty || telefoneCliente != null;
    final double alturaDinamica =
        _estimarAlturaComprovativo(pedido, isSmall, temCliente);
    final pageFormat = _pageFormatFor(paperFormat, alturaDinamica);

    final pdf = pw.Document(
      title: _nomeAutomaticoComprovativo(pedido.idPedido),
      author: 'Stech Engenharia',
      creator: 'Sistema de Gestão',
    );

    final double margin = isSmall ? 10 : 40;
    final double baseFontSize = isSmall ? 9 : 12;
    final dataRef = pedido.dataFinalizacao ?? pedido.dataPedido;
    final dataFormatada = DateFormat('dd/MM/yyyy HH:mm').format(dataRef);

    pdf.addPage(
      pw.Page(
        pageTheme: pw.PageTheme(
          pageFormat: pageFormat,
          orientation: pw.PageOrientation.portrait,
          margin: pw.EdgeInsets.all(margin),
          clip: true,
        ),
        build: (context) => pw.Column(
          crossAxisAlignment: isSmall
              ? pw.CrossAxisAlignment.center
              : pw.CrossAxisAlignment.start,
          children: [
            _comprovativoCabecalho(
              pedido: pedido,
              dataFormatada: dataFormatada,
              isSmall: isSmall,
              baseFontSize: baseFontSize,
              iconImage: isSmall ? null : iconImage,
            ),
            pw.SizedBox(height: isSmall ? 6 : 16),
            _divider(isSmall),
            pw.SizedBox(height: isSmall ? 4 : 12),
            if (temCliente) ...[
           _comprovativoCliente(
  nome: nomeClienteFinal,
  telefone: telefoneCliente,
  isSmall: isSmall,
  baseFontSize: baseFontSize,
),
              pw.SizedBox(height: isSmall ? 4 : 12),
              _divider(isSmall),
              pw.SizedBox(height: isSmall ? 4 : 12),
            ],
            _comprovativoItens(
              pedido: pedido,
              isSmall: isSmall,
              baseFontSize: baseFontSize,
            ),
            pw.SizedBox(height: isSmall ? 4 : 12),
            _divider(isSmall),
            pw.SizedBox(height: isSmall ? 4 : 12),
            _comprovativoPagamento(
              pedido: pedido,
              tipoPagamento: tipoPagamento,
              isSmall: isSmall,
              baseFontSize: baseFontSize,
            ),
            pw.SizedBox(height: isSmall ? 4 : 12),
            _divider(isSmall),
            pw.SizedBox(height: isSmall ? 4 : 8),
            _comprovativoRodape(isSmall: isSmall, baseFontSize: baseFontSize),
          ],
        ),
      ),
    );

    return pdf;
  }

  double _estimarAlturaComprovativo(
      PedidoModel pedido, bool isSmall, bool temCliente) {
    double h = isSmall ? 15.0 : 30.0;
    h += isSmall ? 25.0 : 45.0;
    if (temCliente) h += isSmall ? 15.0 : 35.0;
    final int totalItens =
        pedido.itensProduto.length + pedido.itensServico.length;
    h += totalItens * (isSmall ? 12.0 : 18.0);
    h += isSmall ? 20.0 : 40.0;
    h += isSmall ? 15.0 : 25.0;
    h += 10.0;
    return h;
  }

  static PdfPageFormat _pageFormatFor(PaperFormat format, double altura) {
    switch (format) {
      case PaperFormat.thermal58mm:
        return PdfPageFormat(58 * PdfPageFormat.mm, altura * PdfPageFormat.mm,
            marginAll: 2 * PdfPageFormat.mm);
      case PaperFormat.thermal80mm:
        return PdfPageFormat(80 * PdfPageFormat.mm, altura * PdfPageFormat.mm,
            marginAll: 4 * PdfPageFormat.mm);
      case PaperFormat.a4:
        return PdfPageFormat.a4;
    }
  }

  pw.Widget _comprovativoCabecalho({
    required PedidoModel pedido,
    required String dataFormatada,
    required bool isSmall,
    required double baseFontSize,
    pw.MemoryImage? iconImage,
  }) {
    if (isSmall) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          iconImage != null
              ? pw.Image(iconImage, width: 48, height: 48)
              : _t('Stech Engenharia', bold: true, size: 14, color: PdfColors.deepOrange),
          pw.SizedBox(height: 2),
          _t('COMPROVATIVO DE VENDA', bold: true, size: 11, color: _kAzul),
          pw.SizedBox(height: 2),
          _t('Pedido #${pedido.idPedido}', bold: true, size: baseFontSize, color: _kVermelho),
          _t(dataFormatada, size: baseFontSize - 1),
        ],
      );
    }
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _kVermelho, width: 3)),
      ),
      padding: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            iconImage != null
                ? pw.Image(iconImage, width: 90, height: 90)
                : _t('Stech Engenharia', bold: true, size: 28, color: PdfColors.red),
            pw.SizedBox(height: 8),
            _t('Sistema de Gestão de Pedidos', size: 12, color: PdfColors.grey700),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            _t('COMPROVATIVO DE VENDA', bold: true, size: 20),
            pw.SizedBox(height: 4),
            _t('Pedido #${pedido.idPedido}', bold: true, size: 14, color: _kAzul),
            _t(dataFormatada, size: 10, color: PdfColors.grey700),
          ]),
        ],
      ),
    );
  }

  pw.Widget _comprovativoCliente({
    String? nome,
    String? telefone,
    required bool isSmall,
    required double baseFontSize,
  }) {
    if (isSmall) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          _t('CLIENTE', bold: true, size: baseFontSize),
          if (nome != null) _t(nome, size: baseFontSize),
          if (telefone != null) _t(telefone, size: baseFontSize),
        ],
      );
    }
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        _t('CLIENTE', bold: true, size: 12, color: PdfColors.grey800),
        pw.SizedBox(height: 8),
        if (nome != null) _t('Nome: $nome', size: 11),
        if (telefone != null) _t('Telefone: $telefone', size: 11),
      ]),
    );
  }

  pw.Widget _comprovativoItens({
    required PedidoModel pedido,
    required bool isSmall,
    required double baseFontSize,
  }) {
    final widgets = <pw.Widget>[
      _t('ITENS',
          bold: true,
          size: baseFontSize + (isSmall ? 0 : 2),
          color: isSmall ? PdfColors.black : _kAzul),
      pw.SizedBox(height: isSmall ? 4 : 8),
    ];

    for (final item in pedido.itensProduto) {
      widgets.add(_linhaItemComprovativo(
        isSmall: isSmall,
        baseFontSize: baseFontSize,
        nome: item.nomeProduto.isNotEmpty
            ? item.nomeProduto
            : 'Produto #${item.idProduto}',
        quantidade: item.quantidade,
        precoUnit: item.precoUnitario,
        subtotal: item.subtotal,
      ));
    }

    for (final item in pedido.itensServico) {
      widgets.add(_linhaItemComprovativo(
        isSmall: isSmall,
        baseFontSize: baseFontSize,
        nome: (item.nomeServico != null && item.nomeServico!.isNotEmpty)
            ? item.nomeServico!
            : 'Serviço #${item.idServico}',
        quantidade: item.quantidade,
        precoUnit: item.precoUnitario,
        subtotal: item.subtotal,
        obs: item.observacoes,
      ));
    }

    if (pedido.itensProduto.isEmpty && pedido.itensServico.isEmpty) {
      widgets.add(_t('Sem itens', size: baseFontSize, color: PdfColors.grey600));
    }

    return pw.Column(
      crossAxisAlignment: isSmall
          ? pw.CrossAxisAlignment.stretch
          : pw.CrossAxisAlignment.start,
      children: widgets,
    );
  }

  pw.Widget _linhaItemComprovativo({
    required bool isSmall,
    required double baseFontSize,
    required String nome,
    required int quantidade,
    required double precoUnit,
    required double subtotal,
    String? obs,
  }) {
    if (isSmall) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _t(nome, bold: true, size: baseFontSize),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _t('${quantidade}x  MZN ${precoUnit.toStringAsFixed(2)}', size: baseFontSize - 1),
              _t('MZN ${subtotal.toStringAsFixed(2)}', bold: true, size: baseFontSize - 1),
            ],
          ),
          if (obs != null && obs.isNotEmpty)
            _t(obs, size: baseFontSize - 2, color: PdfColors.grey600),
          pw.SizedBox(height: 3),
        ],
      );
    }
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _t(nome, bold: true, size: baseFontSize),
          pw.SizedBox(height: 2),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _t('Qtd: $quantidade', size: baseFontSize - 1, color: PdfColors.grey700),
              _t('Un.: MZN ${precoUnit.toStringAsFixed(2)}', size: baseFontSize - 1, color: PdfColors.grey700),
              _t('Sub: MZN ${subtotal.toStringAsFixed(2)}', bold: true, size: baseFontSize - 1),
            ],
          ),
          if (obs != null && obs.isNotEmpty)
            _t(obs, size: baseFontSize - 2, color: PdfColors.grey600),
        ],
      ),
    );
  }

  pw.Widget _comprovativoPagamento({
    required PedidoModel pedido,
    required String tipoPagamento,
    required bool isSmall,
    required double baseFontSize,
  }) {
    final isDinheiro = tipoPagamento.toLowerCase().contains('dinheiro');
    final totalStr = 'MZN ${pedido.total.toStringAsFixed(2)}';
    final valorPagoStr = 'MZN ${pedido.valorPago.toStringAsFixed(2)}';
    final trocoStr = 'MZN ${(pedido.troco ?? 0.0).toStringAsFixed(2)}';

    pw.Widget row(String label, String val, {bool bold = false, PdfColor? color}) {
      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _t(label, bold: bold, size: baseFontSize),
          _t(val, bold: true, size: baseFontSize, color: color),
        ],
      );
    }

    final rows = <pw.Widget>[
      row('TOTAL', totalStr, bold: true, color: isSmall ? PdfColors.black : _kAzul),
      pw.SizedBox(height: isSmall ? 3 : 8),
      row('Pagamento:', tipoPagamento),
      if (isDinheiro) ...[
        pw.SizedBox(height: isSmall ? 2 : 6),
        row('Valor Pago:', valorPagoStr),
        pw.SizedBox(height: isSmall ? 2 : 6),
        row('Troco:', trocoStr, color: _kVermelho),
      ],
    ];

    if (isSmall) {
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: rows);
    }
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(children: rows),
    );
  }

  pw.Widget _comprovativoRodape({
    required bool isSmall,
    required double baseFontSize,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        _t('Documento somente para controlo interno.',
            size: baseFontSize - (isSmall ? 1 : 2), color: PdfColors.grey700),
        pw.SizedBox(height: isSmall ? 3 : 6),
        _t('Obrigado pela sua preferência!',
            bold: true, size: baseFontSize + (isSmall ? 0 : 2),
            color: isSmall ? PdfColors.black : _kAzul),
        pw.SizedBox(height: isSmall ? 2 : 4),
        _t('Stech Engenharia (c) ${DateTime.now().year}',
            size: baseFontSize - 1, color: PdfColors.grey600),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════
  // HELPERS GERAIS
  // ═════════════════════════════════════════════════════════════════

  pw.Widget _t(String text, {double size = 10, bool bold = false, PdfColor? color}) {
    return pw.Text(text,
        style: pw.TextStyle(
          fontSize: size,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ));
  }

  pw.Widget _thCell(String text, pw.TextStyle style, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(text, style: style, textAlign: align),
    );
  }

  pw.Widget _tdCell(String text, pw.TextStyle style, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: pw.Text(text, style: style, textAlign: align),
    );
  }

  pw.Widget _tdCellDescricao(_LinhaItem l, pw.TextStyle style) {
    if (l.obs != null && l.obs!.isNotEmpty) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(l.descricao, style: style),
            pw.Text(l.obs!, style: pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600)),
          ],
        ),
      );
    }
    return _tdCell(l.descricao, style);
  }

  pw.Widget _divider(bool isSmall) {
    if (isSmall) {
      return pw.Text('-' * 32,
          style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center);
    }
    return pw.Divider(color: PdfColors.grey400, thickness: 1);
  }

  // ═════════════════════════════════════════════════════════════════
  // NOMENCLATURA DE FICHEIROS
  // ═════════════════════════════════════════════════════════════════

  String _nomeArquivo(DocumentoPdfModel doc) {
    final safeRef = doc.referencia.replaceAll('/', '-');
    return '${doc.tipo.prefixo}-$safeRef';
  }

  String _nomeArquivoReciboCredito(ReciboCreditoPdfModel doc) {
  final safeRef = doc.referenciaRecibo.replaceAll('/', '-');
  final safeFat = doc.referenciaFactura.replaceAll('/', '-');

  return 'REC-$safeRef-FAT-$safeFat';
}
  String _nomeArquivoNotaRetificativa(NotaRetificativaPdfModel doc) {
    final safeRef = doc.referencia.replaceAll('/', '-');
    final safeOrigem = doc.referenciaDocumentoOrigem.replaceAll('/', '-');
    return '${doc.tipo.prefixo}-$safeRef-REF-$safeOrigem';
  }
  String _nomeAutomaticoComprovativo(int pedidoId) {
    final agora = DateTime.now();
    final id = pedidoId.toString().padLeft(5, '0');
    final data = DateFormat('yyyyMMdd').format(agora);
    final hora = DateFormat('HHmm').format(agora);
    return 'COMP-$id-$data-$hora';
  }

  // ═════════════════════════════════════════════════════════════════
  // GUARDAR PDF EM DISCO
  // ═════════════════════════════════════════════════════════════════

  Future<File> _savePdfWithName(pw.Document pdf, String nome) async {
    final safeNome = nome.replaceAll(RegExp(r'[/\\:*?"<>|]'), '-');
    final fileName = '$safeNome.pdf';
    final dir = await _resolveDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  Future<File> _savePdf(pw.Document pdf, int pedidoId) async {
    return _savePdfWithName(pdf, _nomeAutomaticoComprovativo(pedidoId));
  }

  Future<Directory> _resolveDirectory() async {
    try {
      if (Platform.isAndroid) {
        final d = Directory('/storage/emulated/0/Download/');
        if (await d.exists()) {
          final test = File('${d.path}/.write_test');
          await test.writeAsString('test');
          await test.delete();
          return d;
        }
        final ext = await getExternalStorageDirectory();
        if (ext != null) {
          final d2 = Directory('${ext.path}/Downloads');
          if (!await d2.exists()) await d2.create(recursive: true);
          return d2;
        }
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final dl = await getDownloadsDirectory();
        if (dl != null) return dl;
      }
    } catch (_) {}
    return getApplicationDocumentsDirectory();
  }

  // ═════════════════════════════════════════════════════════════════
  // UTILITÁRIOS WINDOWS / SUMATRA
  // ═════════════════════════════════════════════════════════════════

  void _assertWindows() {
    if (!Platform.isWindows) {
      throw UnsupportedError('SumatraPDF só está disponível no Windows.');
    }
  }

  String _sumatraPath() {
    final path =
        '${Directory(Platform.resolvedExecutable).parent.path}\\SumatraPDF.exe';
    if (!File(path).existsSync()) {
      throw Exception('SumatraPDF.exe não encontrado.\nCaminho esperado: $path');
    }
    return path;
  }
}

// ═══════════════════════════════════════════════════════════════════
// DATA CLASS — linha de item na tabela fiscal
// ═══════════════════════════════════════════════════════════════════

class _LinhaItem {
  final int quantidade;
  final String descricao;
  final double precoUnitario;
  final double total;
  final String? obs;

  const _LinhaItem({
    required this.quantidade,
    required this.descricao,
    required this.precoUnitario,
    required this.total,
    this.obs,
  });

  factory _LinhaItem.vazia() => const _LinhaItem(
        quantidade: 0,
        descricao: '',
        precoUnitario: 0,
        total: 0,
      );

  bool get isEmpty => descricao.isEmpty;

  String get qtStr => isEmpty ? '' : quantidade.toString();
  String get precoStr => isEmpty ? '0,00 MZN' : 'MZN ${precoUnitario.toStringAsFixed(2)}';
  String get totalStr => isEmpty ? '0,00 MZN' : 'MZN ${total.toStringAsFixed(2)}';
}


