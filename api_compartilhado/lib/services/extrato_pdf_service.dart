import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:api_compartilhado/api_compartilhado.dart';

import '../models/extrato_model.dart';

const _kAzul = PdfColor.fromInt(0xFF1B2A6B);
const _kVermelho = PdfColor.fromInt(0xFFC8102E);

class ExtratoPdfService {
  static final ExtratoPdfService instance = ExtratoPdfService._();
  ExtratoPdfService._();

  final _fmtData = DateFormat('dd/MM/yyyy');
  final _fmtMoeda = NumberFormat.currency(locale: 'pt_PT', symbol: 'MZN');
  final _fmtNomeArq = DateFormat('yyyyMMdd_HHmm');

  // ══════════════════════════════════════════════════════════════════════
  // EXTRACTO DA EMPRESA
  // Inclui:
  // 1. Prestação de serviços / documentos fiscais emitidos
  // 2. Outros bens e serviços
  // 3. Imobilizado
  // 4. Existências
  // 5. Importação
  // 6. Tabela final de apuramento
  // ══════════════════════════════════════════════════════════════════════

  bool _linhaAnulada(LinhaExtrato linha) {
  return linha.estado.trim().toUpperCase() == 'ANULADO';
}

List<LinhaExtrato> _linhasNaoAnuladas(ExtratoModel extrato) {
  return extrato.linhas.where((linha) => !_linhaAnulada(linha)).toList();
}

ExtratoModel _extratoSemDocumentosAnulados(ExtratoModel extrato) {
  return extrato.copyWith(
    linhas: _linhasNaoAnuladas(extrato),
  );
}

Future<File> gerar(ExtratoModel extrato) async {
  final extratoLimpo = _extratoSemDocumentosAnulados(extrato);

  final pdf = await _build(extratoLimpo);
  return _salvar(pdf, extratoLimpo);
}

  Future<void> abrirPdf(File file) async {
    final result = await OpenFilex.open(file.path);

    if (result.type != ResultType.done) {
      throw Exception('Erro ao abrir PDF: ${result.message}');
    }
  }

  Future<pw.Document> _build(ExtratoModel extrato) async {
    final extratoValido = _extratoSemDocumentosAnulados(extrato);
    final iconBytes = await rootBundle.load('assets/icon/app_icon.png');
    final iconImage = pw.MemoryImage(iconBytes.buffer.asUint8List());

    final doc = pw.Document(
      title: 'Extracto ${extrato.labelPeriodo}',
      author: 'Stech Engenharia',
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 20),
        footer: (ctx) => _rodapePagina(ctx),
        build: (ctx) => [
          _cabecalho(
            extrato,
            iconImage,
            titulo: 'EXTRACTO DA EMPRESA',
          ),
          pw.SizedBox(height: 8),

          _tabelaPrestacaoServicos(extrato),
          pw.SizedBox(height: 10),

          _tabelaDespesaPorTipo(
            titulo: 'OUTROS BENS E SERVIÇOS',
            despesas: _despesasDoTipo(extrato, 'Bens e Serviços'),
          ),
          pw.SizedBox(height: 10),

          _tabelaDespesaPorTipo(
            titulo: 'IMOBILIZADO',
            despesas: _despesasDoTipo(extrato, 'Imobilizado'),
          ),
          pw.SizedBox(height: 10),

          _tabelaDespesaPorTipo(
            titulo: 'EXISTÊNCIAS',
            despesas: _despesasDoTipo(extrato, 'Existências'),
          ),
          pw.SizedBox(height: 10),

          _tabelaDespesaPorTipo(
            titulo: 'IMPORTAÇÃO',
            despesas: _despesasDoTipo(extrato, 'Importação'),
          ),

          pw.SizedBox(height: 14),
          _tabelaResumoApuramento(extrato),
          pw.SizedBox(height: 8),
          _notaFiscal(),
        ],
      ),
    );

    return doc;
  }

  // ══════════════════════════════════════════════════════════════════════
  // EXTRACTO DOCUMENTAL DO CLIENTE
  // IMPORTANTE:
  // Cliente só vê a primeira tabela: documentos/facturas/VDs.
  // Não lista despesas, nem apuramento interno da empresa.
  // ══════════════════════════════════════════════════════════════════════

  Future<File> gerarExtractoDocumentalCliente({
    required ClienteModel cliente,
    required Map<String, dynamic> extractoDocumental,
  }) async {
    final linhasRaw = (extractoDocumental['linhas'] as List?) ?? const [];

    final linhas = linhasRaw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

final linhasExtrato = <LinhaExtrato>[];

    for (final l in linhas) {
      final emitidoEmStr = l['emitidoEm']?.toString();
      final emitidoEm = emitidoEmStr != null
          ? DateTime.tryParse(emitidoEmStr)
          : DateTime.now();
      final dataLinha = emitidoEm ?? DateTime.now();

      final referenciaFactura = (l['referencia'] ?? '-').toString();
      final valorTotal = (l['valorTotal'] as num?)?.toDouble() ?? 0.0;
      final valorAjuste = (l['valorAjuste'] as num?)?.toDouble() ?? 0.0;

      // 1. Linha da factura — SEMPRE com o valor congelado no momento da
      //    emissão (snapshot), nunca o valor já líquido de NCR/NDB.
      linhasExtrato.add(LinhaExtrato(
        dataEmissao: dataLinha,
        numeroDocumento: referenciaFactura,
        nomeEmpresa: cliente.nomeCompleto,
        nuit: cliente.nuit,
        valorTotal: valorTotal,
      ));

      // 2. Linha de ajuste (Nota de Crédito/Débito) — só aparece quando
      //    existe efectivamente uma NCR/NDB associada a esta factura.
      //    valorAjuste já vem negativo para NCR (a subtrair) e positivo
      //    para NDB (a somar) — basta usá-lo directamente, o que faz o
      //    somaTotal do ExtratoModel já dar o valor líquido automaticamente.
      if (valorAjuste != 0) {
        final ehCredito = valorAjuste < 0;
        linhasExtrato.add(LinhaExtrato(
          dataEmissao: dataLinha,
          numeroDocumento: ehCredito ? 'Nota de Crédito' : 'Nota de Débito',
          nomeEmpresa: 'Ref. $referenciaFactura',
          nuit: null,
          valorTotal: valorAjuste,
          isAjusteNotaRetificativa: true,
        ));
      }
    }

    final dataInicio = linhasExtrato.isNotEmpty
        ? linhasExtrato
            .map((l) => l.dataEmissao)
            .reduce((a, b) => a.isBefore(b) ? a : b)
        : DateTime.now();

    final dataFim = linhasExtrato.isNotEmpty
        ? linhasExtrato
            .map((l) => l.dataEmissao)
            .reduce((a, b) => a.isAfter(b) ? a : b)
        : DateTime.now();

    final extrato = ExtratoModel(
      linhas: linhasExtrato,
      despesas: const [],
      dataInicio: dataInicio,
      dataFim: dataFim,
      labelPeriodo: '${_fmtData.format(dataInicio)} a ${_fmtData.format(dataFim)}',
    );

    final pdf = await _buildExtractoDocumentalCliente(
      extrato,
      cliente,
    );

    final nomeCliente = cliente.nomeCompleto
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(' ', '_');

    final nome =
        'EXTRATO_DOCUMENTAL-$nomeCliente-${_fmtNomeArq.format(DateTime.now())}.pdf';

    final dir = await _resolveDirectory();
    final file = File('${dir.path}/$nome');

    await file.writeAsBytes(await pdf.save());

    return file;
  }

  Future<pw.Document> _buildExtractoDocumentalCliente(
    ExtratoModel extrato,
    ClienteModel cliente,
  ) async {
    final iconBytes = await rootBundle.load('assets/icon/app_icon.png');
    final iconImage = pw.MemoryImage(iconBytes.buffer.asUint8List());

    final doc = pw.Document(
      title: 'Extracto Documental - ${cliente.nomeCompleto}',
      author: 'Stech Engenharia',
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 20),
        footer: (ctx) => _rodapePagina(ctx),
        build: (ctx) => [
          _cabecalhoClienteDocumental(
            extrato,
            cliente,
            iconImage,
          ),
          pw.SizedBox(height: 8),
          _tabelaPrestacaoServicos(
            extrato,
            tituloDescricao: 'DOCUMENTOS FISCAIS',
          ),
          pw.SizedBox(height: 8),
          _notaFiscal(),
        ],
      ),
    );

    return doc;
  }

  // ══════════════════════════════════════════════════════════════════════
  // HISTÓRICO COMERCIAL DO CLIENTE
  // Mantido para não quebrar a funcionalidade existente.
  // ══════════════════════════════════════════════════════════════════════

  Future<File> gerarHistoricoCliente({
    required ClienteModel cliente,
    required Map<String, dynamic> extracto,
  }) async {
    final pdf = await _buildHistoricoCliente(cliente, extracto);
    return _salvarHistoricoCliente(pdf, cliente);
  }

  Future<pw.Document> _buildHistoricoCliente(
    ClienteModel cliente,
    Map<String, dynamic> extracto,
  ) async {
    final iconBytes = await rootBundle.load('assets/icon/app_icon.png');
    final iconImage = pw.MemoryImage(iconBytes.buffer.asUint8List());

    final doc = pw.Document(
      title: 'Historico Comercial - ${cliente.nomeCompleto}',
      author: 'Stech Engenharia',
    );

    final linhasRaw = (extracto['linhas'] as List?) ?? const [];

    final linhas = linhasRaw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final totalDivida = (extracto['totalDivida'] as num?)?.toDouble() ?? 0.0;
    final totalPago = (extracto['totalPago'] as num?)?.toDouble() ?? 0.0;
    final saldo = (extracto['saldo'] as num?)?.toDouble() ?? 0.0;
    final quantidadeRegistos = linhas.length;

    final totalDocumentos = linhas
        .where((l) => l['idDocumentoFacturaCredito'] != null)
        .length;

    final pedidosPagos = linhas.where((l) {
      final status = (l['statusPagamento'] ?? '').toString().toUpperCase();
      return status == 'PAGO';
    }).length;

    final pedidosPendentes = linhas.where((l) {
      final status = (l['statusPagamento'] ?? '').toString().toUpperCase();
      return status == 'PENDENTE' || status == 'PARCIAL';
    }).length;

    final mensagemSituacao = saldo > 0
        ? 'Cliente devedor: possui saldo pendente e requer acompanhamento comercial.'
        : 'Cliente regular: nao possui saldo pendente neste momento.';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(30, 28, 30, 20),
        footer: (ctx) => _rodapePagina(ctx),
        build: (ctx) => [
          _cabecalhoHistoricoCliente(cliente, iconImage),
          pw.SizedBox(height: 10),
          _resumoHistoricoCliente(
            cliente: cliente,
            totalDivida: totalDivida,
            totalPago: totalPago,
            saldo: saldo,
            quantidadeRegistos: quantidadeRegistos,
            pedidosPagos: pedidosPagos,
            pedidosPendentes: pedidosPendentes,
            totalDocumentos: totalDocumentos,
            mensagemSituacao: mensagemSituacao,
          ),
          pw.SizedBox(height: 12),
          _tabelaHistoricoCliente(linhas),
          pw.SizedBox(height: 12),
          _rodapeHistoricoCliente(
            totalDivida: totalDivida,
            totalPago: totalPago,
            saldo: saldo,
            totalDocumentos: totalDocumentos,
            quantidadeRegistos: quantidadeRegistos,
            pedidosPagos: pedidosPagos,
            pedidosPendentes: pedidosPendentes,
          ),
          pw.SizedBox(height: 8),
          _notaFiscal(),
        ],
      ),
    );

    return doc;
  }

  // ══════════════════════════════════════════════════════════════════════
  // CABEÇALHOS
  // ══════════════════════════════════════════════════════════════════════

  pw.Widget _cabecalho(
    ExtratoModel extrato,
    pw.MemoryImage icon, {
    required String titulo,
  }) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Image(
                  icon,
                  width: 135,
                  height: 76,
                  fit: pw.BoxFit.contain,
                ),
                pw.SizedBox(height: 4),
                _t(
                  'Segurança Tecnologica SU, LDA (Stech Engenharia)',
                  bold: true,
                  size: 8.2,
                ),
                _t('Bairro: Chingodzi, Tete', size: 7.5),
                _t('Numero: +258 84 239 0756 ou 87 939 0756', size: 7.5),
                _t('Email: info@stech.co.mz', size: 7.5),
                _t('Website: www.stecheng.co.mz', size: 7.5),
                _t('NUIT: 401 684 530', size: 7.5),
              ],
            ),
            pw.SizedBox(width: 18),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  _t(
                    titulo,
                    size: 15,
                    bold: true,
                    color: _kAzul,
                    align: pw.TextAlign.right,
                  ),
                  pw.SizedBox(height: 4),
                  _t(
                    'Periodo: ${_fmtData.format(extrato.dataInicio)}'
                    ' a ${_fmtData.format(extrato.dataFim)}',
                    size: 8.5,
                    color: PdfColors.grey700,
                    align: pw.TextAlign.right,
                  ),
                  pw.SizedBox(height: 2),
                  _t(
                    'Gerado em: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}',
                    size: 7.5,
                    color: PdfColors.grey600,
                    align: pw.TextAlign.right,
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(color: _kAzul, thickness: 2),
      ],
    );
  }

  pw.Widget _cabecalhoClienteDocumental(
    ExtratoModel extrato,
    ClienteModel cliente,
    pw.MemoryImage icon,
  ) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Image(
                  icon,
                  width: 135,
                  height: 76,
                  fit: pw.BoxFit.contain,
                ),
                pw.SizedBox(height: 4),
                _t(
                  'Segurança Tecnologica SU, LDA (Stech Engenharia)',
                  bold: true,
                  size: 8.2,
                ),
                _t('Bairro: Chingodzi, Tete', size: 7.5),
                _t('Numero: +258 84 239 0756 ou 87 939 0756', size: 7.5),
                _t('Email: info@stech.co.mz', size: 7.5),
                _t('Website: www.stecheng.co.mz', size: 7.5),
                _t('NUIT: 401 684 530', size: 7.5),
              ],
            ),
            pw.SizedBox(width: 18),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  _t(
                    'EXTRACTO DOCUMENTAL DO CLIENTE',
                    size: 14,
                    bold: true,
                    color: _kAzul,
                    align: pw.TextAlign.right,
                  ),
                  pw.SizedBox(height: 4),
                  _t(
                    cliente.nomeCompleto,
                    size: 10.5,
                    bold: true,
                    color: _kVermelho,
                    align: pw.TextAlign.right,
                  ),
                  if (cliente.nuit?.isNotEmpty == true)
                    _t(
                      'NUIT: ${cliente.nuit}',
                      size: 8,
                      color: PdfColors.grey700,
                      align: pw.TextAlign.right,
                    ),
                  pw.SizedBox(height: 4),
                  _t(
                    'Periodo: ${_fmtData.format(extrato.dataInicio)}'
                    ' a ${_fmtData.format(extrato.dataFim)}',
                    size: 8.5,
                    color: PdfColors.grey700,
                    align: pw.TextAlign.right,
                  ),
                  pw.SizedBox(height: 2),
                  _t(
                    'Gerado em: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}',
                    size: 7.5,
                    color: PdfColors.grey600,
                    align: pw.TextAlign.right,
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(color: _kAzul, thickness: 2),
      ],
    );
  }

  pw.Widget _cabecalhoHistoricoCliente(
    ClienteModel cliente,
    pw.MemoryImage icon,
  ) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Image(
                  icon,
                  width: 135,
                  height: 76,
                  fit: pw.BoxFit.contain,
                ),
                pw.SizedBox(height: 4),
                _t(
                  'Segurança Tecnologica SU, LDA (Stech Engenharia)',
                  bold: true,
                  size: 8.2,
                ),
                _t('Bairro: Chingodzi, Tete', size: 7.5),
                _t('Numero: +258 84 239 0756 ou 87 939 0756', size: 7.5),
                _t('Email: info@stech.co.mz', size: 7.5),
                _t('Website: www.stecheng.co.mz', size: 7.5),
                _t('NUIT: 401 684 530', size: 7.5),
              ],
            ),
            pw.SizedBox(width: 18),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  _t(
                    'HISTORICO COMERCIAL DO CLIENTE',
                    size: 15,
                    bold: true,
                    color: _kAzul,
                    align: pw.TextAlign.right,
                  ),
                  pw.SizedBox(height: 5),
                  _t(
                    cliente.nomeCompleto,
                    size: 10.5,
                    bold: true,
                    color: _kVermelho,
                    align: pw.TextAlign.right,
                  ),
                  pw.SizedBox(height: 2),
                  _t(
                    'Gerado em: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}',
                    size: 7.5,
                    color: PdfColors.grey600,
                    align: pw.TextAlign.right,
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(color: _kAzul, thickness: 2),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // TABELA 1 — PRESTAÇÃO DE SERVIÇOS / DOCUMENTOS FISCAIS
  // Usada no extracto da empresa e no extracto documental do cliente.
  // ══════════════════════════════════════════════════════════════════════

  pw.Widget _tabelaPrestacaoServicos(
    ExtratoModel extrato, {
    String tituloDescricao = 'PRESTAÇÃO DE SERVIÇOS',
  }) {
final estiloHeader = pw.TextStyle(
  fontSize: 8,
  color: PdfColors.white,
  fontWeight: pw.FontWeight.bold,
);

    const estiloCell = pw.TextStyle(fontSize: 5.8);
    final estiloBold = pw.TextStyle(
      fontSize: 5.8,
      fontWeight: pw.FontWeight.bold,
    );

    final linhas = extrato.linhas;
    final totalFactura = linhas.fold<double>(0, (acc, l) => acc + l.valorTotal);
    final totalLiquido = _valorSemIva(totalFactura);
    final totalIva = totalFactura - totalLiquido;

    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColors.grey500,
        width: 0.45,
      ),
      columnWidths: const {
        0: pw.FixedColumnWidth(20),
        1: pw.FixedColumnWidth(68),
        2: pw.FixedColumnWidth(48),
        3: pw.FixedColumnWidth(46),
        4: pw.FlexColumnWidth(2.2),
        5: pw.FixedColumnWidth(60),
        6: pw.FixedColumnWidth(58),
        7: pw.FixedColumnWidth(48),
        8: pw.FixedColumnWidth(68),
        9: pw.FixedColumnWidth(42),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _kAzul),
          children: [
            _thCell('Nº DE\nORDEM', estiloHeader),
            _thCell('DOCUMENTO Nº\nFACT Nº', estiloHeader),
            _thCell('NUIT', estiloHeader),
            _thCell('DATA', estiloHeader),
            _thCell('DESCRIÇÃO\n$tituloDescricao', estiloHeader),
            _thCell('VALOR DE\nFACTURA', estiloHeader),
            _thCell('IVA COM DEDUÇÃO\nV. LÍQUIDO', estiloHeader),
            _thCell('IVA', estiloHeader),
            _thCell('COM EXCLUSÃO', estiloHeader),
            _thCell('ISENTAS', estiloHeader),
          ],
        ),
for (int i = 0; i < _linhasMinimas(linhas.length); i++)
          if (i < linhas.length)
            _linhaTabelaPrestacaoServicos(linhas[i], i, estiloCell, estiloBold)
          else
            _linhaVaziaTabelaPrincipal(estiloCell),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _tdCell('', estiloBold),
            _tdCell('', estiloBold),
            _tdCell('', estiloBold),
            _tdCell('', estiloBold),
            _tdCell('TOTAL', estiloBold, align: pw.TextAlign.center),
            _tdCell(
              _fmtNumero(totalFactura),
              estiloBold,
              align: pw.TextAlign.right,
            ),
            _tdCell(
              _fmtNumero(totalLiquido),
              estiloBold,
              align: pw.TextAlign.right,
            ),
            _tdCell(
              _fmtNumero(totalIva),
              estiloBold,
              align: pw.TextAlign.right,
            ),
            _tdCell('-', estiloBold, align: pw.TextAlign.center),
            _tdCell('-', estiloBold, align: pw.TextAlign.center),
          ],
        ),
      ],
    );
  }

  /// Cor de destaque para a linha de ajuste (Nota de Crédito/Débito) no
  /// extracto documental do cliente.
  static const _kAjusteCor = PdfColor.fromInt(0xFFB45309); // laranja escuro

  pw.TableRow _linhaTabelaPrestacaoServicos(
    LinhaExtrato linha,
    int indice,
    pw.TextStyle estiloCell,
    pw.TextStyle estiloBold,
  ) {
    if (linha.isAjusteNotaRetificativa) {
      final estiloAjuste = pw.TextStyle(
        fontSize: 5.8,
        fontWeight: pw.FontWeight.bold,
        color: _kAjusteCor,
        fontStyle: pw.FontStyle.italic,
      );

return pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.orange50),
        children: [
          _tdCell('', estiloAjuste),
          _tdCell(linha.numeroDocumento, estiloAjuste),
          _tdCell('-', estiloAjuste, align: pw.TextAlign.center),
          _tdCell(_fmtData.format(linha.dataEmissao), estiloAjuste),
          _tdCell(_sanitizar(linha.nomeEmpresa), estiloAjuste),
          _tdCell(
            _fmtNumero(linha.valorTotal),
            estiloAjuste,
            align: pw.TextAlign.right,
          ),
          _tdCell('-', estiloAjuste, align: pw.TextAlign.center),
          _tdCell('-', estiloAjuste, align: pw.TextAlign.center),
          _tdCell('-', estiloAjuste, align: pw.TextAlign.center),
          _tdCell('-', estiloAjuste, align: pw.TextAlign.center),
        ],
      );
    }

    return pw.TableRow(
      children: [
        _tdCell('${indice + 1}', estiloCell, align: pw.TextAlign.center),
        _tdCell(linha.numeroDocumento, estiloBold),
        _tdCell(_sanitizar(linha.nuit), estiloCell),
        _tdCell(_fmtData.format(linha.dataEmissao), estiloCell),
        _tdCell(_sanitizar(linha.nomeEmpresa), estiloCell),
        _tdCell(
          _fmtNumero(linha.valorTotal),
          estiloCell,
          align: pw.TextAlign.right,
        ),
        _tdCell(
          _fmtNumero(_valorSemIva(linha.valorTotal)),
          estiloCell,
          align: pw.TextAlign.right,
        ),
        _tdCell(
          _fmtNumero(linha.valorTotal - _valorSemIva(linha.valorTotal)),
          estiloCell,
          align: pw.TextAlign.right,
        ),
        _tdCell('-', estiloCell, align: pw.TextAlign.center),
        _tdCell('-', estiloCell, align: pw.TextAlign.center),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // TABELAS DE DESPESAS POR TIPO
  // Sempre aparecem no extracto da empresa, mesmo vazias.
  // ══════════════════════════════════════════════════════════════════════

  pw.Widget _tabelaDespesaPorTipo({
    required String titulo,
    required List<LinhaDespesaExtrato> despesas,
  }) {
final estiloHeader = pw.TextStyle(
  fontSize: 5.7,
  fontWeight: pw.FontWeight.bold,
  color: PdfColors.white,
);

    const estiloCell = pw.TextStyle(fontSize: 5.8);
    final estiloBold = pw.TextStyle(
      fontSize: 5.8,
      fontWeight: pw.FontWeight.bold,
    );

    final totalFactura = despesas.fold<double>(0, (acc, d) => acc + d.valorGasto);
    final totalLiquido = _valorSemIva(totalFactura);
    final totalIva = totalFactura - totalLiquido;

    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColors.grey500,
        width: 0.45,
      ),
      columnWidths: const {
        0: pw.FixedColumnWidth(20),
        1: pw.FixedColumnWidth(68),
        2: pw.FixedColumnWidth(48),
        3: pw.FixedColumnWidth(46),
        4: pw.FlexColumnWidth(2.2),
        5: pw.FixedColumnWidth(60),
        6: pw.FixedColumnWidth(58),
        7: pw.FixedColumnWidth(48),
        8: pw.FixedColumnWidth(68),
        9: pw.FixedColumnWidth(42),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _kAzul),
          children: [
            _thCell('Nº DE\nORDEM', estiloHeader),
            _thCell('DOCUMENTO Nº\nFACT Nº', estiloHeader),
            _thCell('NUIT', estiloHeader),
            _thCell('DATA', estiloHeader),
            _thCell('DESCRIÇÃO\n$titulo', estiloHeader),
            _thCell('VALOR DE\nFACTURA', estiloHeader),
            _thCell('IVA COM DEDUÇÃO\nV. LÍQUIDO', estiloHeader),
            _thCell('IVA', estiloHeader),
            _thCell('Com exclusão do direito a dedução', estiloHeader),
            _thCell('Isentas', estiloHeader),
          ],
        ),
        for (int i = 0; i < _linhasMinimas(despesas.length); i++)
          if (i < despesas.length)
            pw.TableRow(
              children: [
                _tdCell('${i + 1}', estiloCell, align: pw.TextAlign.center),
                _tdCell('-', estiloCell, align: pw.TextAlign.center),
                _tdCell(_sanitizar(despesas[i].nuitFornecedor), estiloCell),
                _tdCell(_fmtData.format(despesas[i].dataDespesa), estiloCell),
                _tdCell(_sanitizar(despesas[i].descricao), estiloCell),
                _tdCell(
                  _fmtNumero(despesas[i].valorGasto),
                  estiloCell,
                  align: pw.TextAlign.right,
                ),
                _tdCell(
                  _fmtNumero(_valorSemIva(despesas[i].valorGasto)),
                  estiloCell,
                  align: pw.TextAlign.right,
                ),
                _tdCell(
                  _fmtNumero(
                    despesas[i].valorGasto -
                        _valorSemIva(despesas[i].valorGasto),
                  ),
                  estiloCell,
                  align: pw.TextAlign.right,
                ),
                _tdCell('-', estiloCell, align: pw.TextAlign.center),
                _tdCell('-', estiloCell, align: pw.TextAlign.center),
              ],
            )
          else
            _linhaVaziaTabelaPrincipal(estiloCell),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _tdCell('', estiloBold),
            _tdCell('', estiloBold),
            _tdCell('', estiloBold),
            _tdCell('', estiloBold),
            _tdCell('TOTAL', estiloBold, align: pw.TextAlign.center),
            _tdCell(
              _fmtNumero(totalFactura),
              estiloBold,
              align: pw.TextAlign.right,
            ),
            _tdCell(
              _fmtNumero(totalLiquido),
              estiloBold,
              align: pw.TextAlign.right,
            ),
            _tdCell(
              _fmtNumero(totalIva),
              estiloBold,
              align: pw.TextAlign.right,
            ),
            _tdCell('-', estiloBold, align: pw.TextAlign.center),
            _tdCell('-', estiloBold, align: pw.TextAlign.center),
          ],
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // TABELA FINAL — SIMULAÇÃO DO APURAMENTO DO IVA
  // ══════════════════════════════════════════════════════════════════════

  pw.Widget _tabelaResumoApuramento(ExtratoModel extrato) {
    const estilo = pw.TextStyle(fontSize: 6.7);
    final estiloBold = pw.TextStyle(
      fontSize: 6.7,
      fontWeight: pw.FontWeight.bold,
    );

    final prestacaoFactura = extrato.somaTotal;
    final prestacaoLiquido = _valorSemIva(prestacaoFactura);
final apuramento = extrato.apuramentoIva ??
    SimulacaoApuramentoIvaModel.fromExtrato(extrato);

    return pw.Align(
      alignment: pw.Alignment.center,
      child: pw.Container(
        width: 370,
        padding: const pw.EdgeInsets.all(6),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(
            color: PdfColors.grey600,
            width: 0.6,
          ),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 3),
              color: _kAzul,
              child: _t(
                'Simulação do Apuramento do IVA',
                size: 7.5,
                bold: true,
                color: PdfColors.white,
                align: pw.TextAlign.center,
              ),
            ),
            pw.SizedBox(height: 6),

_linhaResumo('Campo 1 - Base Tributavel', _fmtNumero(apuramento.campo1), estilo, estiloBold),
_linhaResumo('Campo 2 - IVA Apurado', _fmtNumero(apuramento.campo2), estilo, estiloBold),
_linhaResumo('Campo 3 - Base', _fmtNumero(apuramento.campo3), estilo, estiloBold),
_linhaResumo('Campo 4 - IVA', _fmtNumero(apuramento.campo4), estilo, estiloBold),
_linhaResumo('Campo 5 - Isentas', _fmtNumero(apuramento.campo5), estilo, estiloBold),
_linhaResumo('Campo 6 - Sem deducao', _fmtNumero(apuramento.campo6), estilo, estiloBold),
_linhaResumo('Campo 7 - Outras Operações', _fmtNumero(apuramento.campo7), estilo, estiloBold),

pw.Divider(color: PdfColors.grey400, thickness: 0.4),

_linhaResumo('Campo 8 - Imobilizado', _fmtNumero(apuramento.campo8), estilo, estiloBold),
_linhaResumo('Campo 9 - Existencias', _fmtNumero(apuramento.campo9), estilo, estiloBold),
_linhaResumo('Campo 10 - Outros bens/servicos', _fmtNumero(apuramento.campo10), estilo, estiloBold),
_linhaResumo('Campo 11 - Importacao', _fmtNumero(apuramento.campo11), estilo, estiloBold),
_linhaResumo('Campo 12 - Regularizacoes SP', _fmtNumero(apuramento.campo12), estilo, estiloBold),
_linhaResumo('Campo 13 - Regularizacoes Estado', _fmtNumero(apuramento.campo13), estilo, estiloBold),

pw.Divider(color: PdfColors.grey400, thickness: 0.4),

_linhaResumo('Campo 14 - Soma Base', _fmtNumero(apuramento.campo14), estilo, estiloBold),
_linhaResumo('Campo 15 - Soma Dedutivel', _fmtNumero(apuramento.campo15), estilo, estiloBold),
_linhaResumo('Campo 16 - Soma IVA Apurado', _fmtNumero(apuramento.campo16), estilo, estiloBold),
_linhaResumo('Campo 17 - IVA a pagar', _fmtNumero(apuramento.campo17), estilo, estiloBold),
_linhaResumo('Campo 18 - IVA a recuperar', _fmtNumero(apuramento.campo18), estilo, estiloBold),
_linhaResumo('Campo 19 - Excesso anterior', _fmtNumero(apuramento.campo19), estilo, estiloBold),
_linhaResumo('Campo 20', _fmtNumero(apuramento.campo20), estilo, estiloBold),
          ],
        ),
      ),
    );
  }

  pw.Widget _linhaResumo(
    String label,
    String valor,
    pw.TextStyle estilo,
    pw.TextStyle estiloBold,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: estilo,
            ),
          ),
          pw.Container(
            width: 100,
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 2,
            ),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(
                color: PdfColors.grey500,
                width: 0.4,
              ),
            ),
            child: pw.Text(
              valor,
              textAlign: pw.TextAlign.right,
              style: estiloBold,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // HISTÓRICO COMERCIAL — Widgets
  // ══════════════════════════════════════════════════════════════════════

  pw.Widget _resumoHistoricoCliente({
    required ClienteModel cliente,
    required double totalDivida,
    required double totalPago,
    required double saldo,
    required int quantidadeRegistos,
    required int pedidosPagos,
    required int pedidosPendentes,
    required int totalDocumentos,
    required String mensagemSituacao,
  }) {
    final situacao = saldo > 0 ? 'EM DIVIDA' : 'REGULAR';
    final situacaoCor = saldo > 0 ? _kVermelho : PdfColors.green700;

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(
          color: PdfColors.grey400,
          width: 0.5,
        ),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _t(
            'Dados do Cliente',
            size: 10,
            bold: true,
            color: _kAzul,
          ),
          pw.SizedBox(height: 8),
          pw.Wrap(
            spacing: 20,
            runSpacing: 6,
            children: [
              _t('Empresa: ${cliente.nomeCompleto}', size: 8),
              _t(
                'NUIT: ${cliente.nuit?.isNotEmpty == true ? cliente.nuit! : '-'}',
                size: 8,
              ),
              _t(
                'Contacto: ${cliente.contacto?.isNotEmpty == true ? cliente.contacto! : '-'}',
                size: 8,
              ),
              _t(
                'Email: ${cliente.email?.isNotEmpty == true ? cliente.email! : '-'}',
                size: 8,
              ),
              _t(
                'Morada: ${cliente.morada?.isNotEmpty == true ? cliente.morada! : '-'}',
                size: 8,
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _t(
                'Situacao: $situacao',
                size: 10,
                bold: true,
                color: situacaoCor,
              ),
              _t(
                'Registos: $quantidadeRegistos',
                size: 9,
                bold: true,
                color: _kAzul,
              ),
              _t(
                'Documentos: $totalDocumentos',
                size: 9,
                bold: true,
                color: _kAzul,
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _t(
                'Total em credito: ${_fmtMoeda.format(totalDivida)}',
                size: 9,
                bold: true,
                color: _kAzul,
              ),
              _t(
                'Total pago: ${_fmtMoeda.format(totalPago)}',
                size: 9,
                bold: true,
                color: PdfColors.green700,
              ),
              _t(
                'Saldo actual: ${_fmtMoeda.format(saldo)}',
                size: 9,
                bold: true,
                color: _kVermelho,
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _t(
                'Pedidos pagos: $pedidosPagos',
                size: 9,
                bold: true,
                color: PdfColors.green700,
              ),
              _t(
                'Pendentes / parciais: $pedidosPendentes',
                size: 9,
                bold: true,
                color: PdfColors.orange700,
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: situacaoCor == _kVermelho
                  ? PdfColors.red50
                  : PdfColors.green50,
              border: pw.Border.all(
                color: situacaoCor,
                width: 0.7,
              ),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: _t(
              mensagemSituacao,
              size: 8.5,
              bold: true,
              color: situacaoCor,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _tabelaHistoricoCliente(List<Map<String, dynamic>> linhas) {
final estiloHeader = pw.TextStyle(
  fontSize: 5.7,
  fontWeight: pw.FontWeight.bold,
  color: PdfColors.white,
);

    const estiloCell = pw.TextStyle(fontSize: 8);

    final estiloCellBold = pw.TextStyle(
      fontSize: 8,
      fontWeight: pw.FontWeight.bold,
    );

    if (linhas.isEmpty) {
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          border: pw.Border.all(
            color: PdfColors.grey400,
            width: 0.5,
          ),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Center(
          child: _t(
            'Nenhum historico comercial encontrado para este cliente.',
            size: 9,
            color: PdfColors.grey700,
          ),
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColors.grey400,
        width: 0.5,
      ),
      columnWidths: const {
        0: pw.FixedColumnWidth(100),
        1: pw.FixedColumnWidth(72),
        2: pw.FixedColumnWidth(68),
        3: pw.FixedColumnWidth(68),
        4: pw.FixedColumnWidth(68),
        5: pw.FixedColumnWidth(72),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _kAzul),
          children: [
            _thCell('Pedido', estiloHeader),
            _thCell('Documento', estiloHeader),
            _thCell(
              'Total',
              estiloHeader,
              align: pw.TextAlign.right,
            ),
            _thCell(
              'Pago',
              estiloHeader,
              align: pw.TextAlign.right,
            ),
            _thCell(
              'Saldo',
              estiloHeader,
              align: pw.TextAlign.right,
            ),
            _thCell('Estado', estiloHeader),
          ],
        ),
        for (int i = 0; i < linhas.length; i++)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: i.isOdd ? PdfColors.grey100 : PdfColors.white,
            ),
            children: [
              _tdCell(
                '${(linhas[i]['referencia'] ?? '-').toString()}\n'
                'Pedido #${(linhas[i]['idPedido'] ?? '-').toString()}',
                estiloCellBold,
              ),
              _tdCell(
                linhas[i]['idDocumentoFacturaCredito'] != null
                    ? 'Doc. #${linhas[i]['idDocumentoFacturaCredito']}'
                    : 'Pendente',
                estiloCell,
              ),
              _tdCell(
                _fmtMoeda.format(
                  ((linhas[i]['total'] as num?) ?? 0).toDouble(),
                ),
                estiloCell,
                align: pw.TextAlign.right,
              ),
              _tdCell(
                _fmtMoeda.format(
                  ((linhas[i]['valorPago'] as num?) ?? 0).toDouble(),
                ),
                estiloCell,
                align: pw.TextAlign.right,
              ),
              _tdCell(
                _fmtMoeda.format(
                  ((linhas[i]['saldo'] as num?) ?? 0).toDouble(),
                ),
                estiloCell,
                align: pw.TextAlign.right,
              ),
              _tdCell(
                _statusLabelPdf(
                  (linhas[i]['statusPagamento'] ?? '-').toString(),
                ),
                estiloCell,
              ),
            ],
          ),
      ],
    );
  }

  pw.Widget _rodapeHistoricoCliente({
    required double totalDivida,
    required double totalPago,
    required double saldo,
    required int totalDocumentos,
    required int quantidadeRegistos,
    required int pedidosPagos,
    required int pedidosPendentes,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(
          color: PdfColors.grey400,
          width: 0.5,
        ),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _blocoResumo(
                titulo: 'Total de registos:',
                valor: '$quantidadeRegistos',
                cor: _kAzul,
              ),
              _blocoResumo(
                titulo: 'Total de documentos:',
                valor: '$totalDocumentos',
                cor: _kAzul,
              ),
              _blocoResumo(
                titulo: 'Pedidos pagos:',
                valor: '$pedidosPagos',
                cor: PdfColors.green700,
              ),
              _blocoResumo(
                titulo: 'Pend./Parciais:',
                valor: '$pedidosPendentes',
                cor: PdfColors.orange700,
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              _blocoFinanceiro(
                titulo: 'Total em credito:',
                valor: _fmtMoeda.format(totalDivida),
                cor: _kAzul,
              ),
              pw.SizedBox(width: 24),
              _blocoFinanceiro(
                titulo: 'Total pago:',
                valor: _fmtMoeda.format(totalPago),
                cor: PdfColors.green700,
              ),
              pw.SizedBox(width: 24),
              _blocoFinanceiro(
                titulo: 'Saldo actual:',
                valor: _fmtMoeda.format(saldo),
                cor: _kVermelho,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // WIDGETS PEQUENOS
  // ══════════════════════════════════════════════════════════════════════

  pw.Widget _blocoResumo({
    required String titulo,
    required String valor,
    required PdfColor cor,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _t(
          titulo,
          size: 8,
          color: PdfColors.grey700,
        ),
        pw.SizedBox(height: 2),
        _t(
          valor,
          size: 12,
          bold: true,
          color: cor,
        ),
      ],
    );
  }

  pw.Widget _blocoFinanceiro({
    required String titulo,
    required String valor,
    required PdfColor cor,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        _t(
          titulo,
          size: 8,
          color: PdfColors.grey700,
        ),
        pw.SizedBox(height: 2),
        _t(
          valor,
          size: 12,
          bold: true,
          color: cor,
        ),
      ],
    );
  }

  pw.Widget _notaFiscal() {
    return pw.Center(
      child: _t(
        'Documento processado por computador atraves do Sistema de Facturacao Stech ERP.',
        size: 7,
        color: PdfColors.grey600,
      ),
    );
  }

  pw.Widget _rodapePagina(pw.Context ctx) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _t(
          'Stech Engenharia (c) ${DateTime.now().year}',
          size: 7,
          color: PdfColors.grey600,
        ),
        _t(
          'Pagina ${ctx.pageNumber} de ${ctx.pagesCount}',
          size: 7,
          color: PdfColors.grey600,
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // SALVAR
  // ══════════════════════════════════════════════════════════════════════

  Future<File> _salvar(
    pw.Document pdf,
    ExtratoModel extrato,
  ) async {
    final periodoSeguro = extrato.labelPeriodo
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(' ', '_');

    final nome =
        'EXTRATO_EMPRESA-$periodoSeguro-${_fmtNomeArq.format(DateTime.now())}.pdf';

    final dir = await _resolveDirectory();
    final file = File('${dir.path}/$nome');

    await file.writeAsBytes(await pdf.save());

    return file;
  }

  Future<File> _salvarHistoricoCliente(
    pw.Document pdf,
    ClienteModel cliente,
  ) async {
    final nomeCliente = cliente.nomeCompleto
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(' ', '_');

    final nome =
        'HISTORICO_CLIENTE-$nomeCliente-${_fmtNomeArq.format(DateTime.now())}.pdf';

    final dir = await _resolveDirectory();
    final file = File('${dir.path}/$nome');

    await file.writeAsBytes(await pdf.save());

    return file;
  }

  Future<Directory> _resolveDirectory() async {
    try {
      if (Platform.isAndroid) {
        final d = Directory('/storage/emulated/0/Download/');

        if (await d.exists()) {
          return d;
        }

        final ext = await getExternalStorageDirectory();

        if (ext != null) {
          final d2 = Directory('${ext.path}/Downloads');

          if (!await d2.exists()) {
            await d2.create(recursive: true);
          }

          return d2;
        }
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final dl = await getDownloadsDirectory();

        if (dl != null) {
          return dl;
        }
      }
    } catch (_) {}

    return getApplicationDocumentsDirectory();
  }

  // ══════════════════════════════════════════════════════════════════════
  // HELPERS DE TABELAS E CÁLCULOS
  // ══════════════════════════════════════════════════════════════════════

  List<LinhaDespesaExtrato> _despesasDoTipo(
    ExtratoModel extrato,
    String tipo,
  ) {
    final tipoNormalizado = tipo.trim().toLowerCase();

    return extrato.despesas.where((d) {
      final nome = (d.nomeTipoDespesa ?? '').trim().toLowerCase();
      return nome == tipoNormalizado;
    }).toList();
  }

  double _totalTipo(
    ExtratoModel extrato,
    String tipo,
  ) {
    return _despesasDoTipo(extrato, tipo).fold<double>(
      0,
      (acc, d) => acc + d.valorGasto,
    );
  }

  int _linhasMinimas(int quantidade) {
    if (quantidade <= 0) return 2;
    if (quantidade < 3) return 3;
    return quantidade;
  }

  pw.TableRow _linhaVaziaTabelaPrincipal(pw.TextStyle estiloCell) {
    return pw.TableRow(
      children: [
        _tdCell('', estiloCell),
        _tdCell('', estiloCell),
        _tdCell('', estiloCell),
        _tdCell('', estiloCell),
        _tdCell('', estiloCell),
        _tdCell('-', estiloCell, align: pw.TextAlign.right),
        _tdCell('-', estiloCell, align: pw.TextAlign.right),
        _tdCell('-', estiloCell, align: pw.TextAlign.right),
        _tdCell('-', estiloCell, align: pw.TextAlign.center),
        _tdCell('-', estiloCell, align: pw.TextAlign.center),
      ],
    );
  }

  double _valorSemIva(double valorComIva) {
    if (valorComIva <= 0) return 0;
    return valorComIva / 1.16;
  }

  String _fmtNumero(double valor) {
    if (valor == 0) return '-';

    return NumberFormat('#,##0.00', 'pt_PT').format(valor);
  }

  String _statusLabelPdf(String status) {
    switch (status.toUpperCase()) {
      case 'PAGO':
        return 'Pago';
      case 'PARCIAL':
        return 'Parcial';
      case 'PENDENTE':
        return 'Pendente';
      default:
        return status;
    }
  }

  String _sanitizar(String? texto) {
    if (texto == null || texto.trim().isEmpty) {
      return '-';
    }

    return texto
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('\u2014', '-')
        .replaceAll('\u2013', '-')
        .replaceAll('\u00A0', ' ')
        .trim();
  }

  // ══════════════════════════════════════════════════════════════════════
  // HELPERS DE TEXTO
  // Sem Roboto, sem assets/fonts, sem ThemeData.withFont.
  // ══════════════════════════════════════════════════════════════════════

  pw.Widget _t(
    String text, {
    double size = 10,
    bool bold = false,
    PdfColor? color,
    pw.TextAlign? align,
  }) {
    return pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(
        fontSize: size,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color,
      ),
    );
  }

  pw.Widget _thCell(
    String text,
    pw.TextStyle style, {
    pw.TextAlign align = pw.TextAlign.center,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(
        horizontal: 2,
        vertical: 3,
      ),
      child: pw.Text(
        text,
        style: style,
        textAlign: align,
        maxLines: 3,
      ),
    );
  }

  pw.Widget _tdCell(
    String text,
    pw.TextStyle style, {
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(
        horizontal: 2,
        vertical: 2.5,
      ),
      child: pw.Text(
        text,
        style: style,
        textAlign: align,
        maxLines: 2,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }
}