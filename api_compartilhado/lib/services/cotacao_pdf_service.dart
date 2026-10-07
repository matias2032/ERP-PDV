import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:api_compartilhado/api_compartilhado.dart';

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

  static const List<String> termos = [
    'Validade: Cotação válida pelo prazo indicado no documento.',
    'Preços: Incluem apenas os itens descritos; extras serão cobrados à parte.',
    'Pagamento: Pode exigir adiantamento. Atrasos podem suspender os serviços.',
    'Prazos: Contam após confirmação e pagamento. Podem variar por factores externos.',
    'Garantia: Serviços com padrão técnico; equipamentos conforme fabricante. Não cobre mau uso.',
    'Alterações/Cancelamentos: Podem gerar custos adicionais.',
    'Responsabilidade do Cliente: Fornecer dados correctos e garantir acesso/condições ao local.',
    'Responsabilidade: A Stech Engenharia não responde por danos indirectos ou externos ao serviço.',
    'Aceitação: Aprovar o documento significa aceitar estes termos.',
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
// COTACAO PDF SERVICE
// ═══════════════════════════════════════════════════════════════════

class CotacaoPdfService {
  static final CotacaoPdfService instance = CotacaoPdfService._internal();
  factory CotacaoPdfService() => instance;
  CotacaoPdfService._internal();

  final _fmt = DateFormat('dd/MM/yyyy');

  // ─────────────────────────────────────────────────────────────────
  // PÚBLICO: Gerar PDF da cotação
  // ─────────────────────────────────────────────────────────────────

Future<File> gerarCotacao(CotacaoModel cotacao, {ClienteModel? cliente}) async {
  final pdf = await _buildCotacao(cotacao, cliente: cliente);
  return _savePdfWithName(pdf, _nomeArquivo(cotacao));
}

Future<void> imprimirCotacaoViaSumatra({
  required CotacaoModel cotacao,
  required String impressoraNome,
  ClienteModel? cliente,
}) async {
  _assertWindows();
  final sumatra = _sumatraPath();
  final pdf = await _buildCotacao(cotacao, cliente: cliente);
    final file = await _savePdfWithName(pdf, _nomeArquivo(cotacao));
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

Future<void> imprimirCotacaoComDialogo({
  required CotacaoModel cotacao,
  ClienteModel? cliente,
}) async {
  _assertWindows();
  final sumatra = _sumatraPath();
  final pdf = await _buildCotacao(cotacao, cliente: cliente);
    final file = await _savePdfWithName(pdf, _nomeArquivo(cotacao));
    await Process.run(sumatra, ['-print-dialog', file.path]);
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
  // BUILD — COTAÇÃO
  // ═════════════════════════════════════════════════════════════════

Future<pw.Document> _buildCotacao(CotacaoModel cotacao, {ClienteModel? cliente}) async {
    final iconBytes = await rootBundle.load('assets/icon/app_icon.png');
    final iconImage = pw.MemoryImage(iconBytes.buffer.asUint8List());

    final pdf = pw.Document(
      title: cotacao.referencia,
      author: _Empresa.nomeCompleto,
      creator: 'Sistema de Gestão Stech',
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(30, 28, 30, 20),
        footer: (ctx) => _footerPagina(ctx),
        build: (ctx) => [
          _cabecalho(cotacao, iconImage),
          pw.SizedBox(height: 6),
_emissorCliente(cotacao, cliente: cliente),
          pw.SizedBox(height: 6),
          pw.Divider(color: PdfColors.grey400, thickness: 0.5),
          pw.SizedBox(height: 4),
          _metadados(cotacao),
          pw.SizedBox(height: 6),
          _tabelaItens(cotacao),
          pw.SizedBox(height: 10),
          _assinatura(),
          pw.SizedBox(height: 8),
          _termos(),
          pw.SizedBox(height: 8),
          _dadosBancarios(),
          pw.SizedBox(height: 6),
          _rodapeDocumento(),
        ],
      ),
    );

    return pdf;
  }

  // ─── 1. Cabeçalho ──────────────────────────────────────────────

  pw.Widget _cabecalho(CotacaoModel cotacao, pw.MemoryImage icon) {
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
  'FACT-PROFORMA',
  style: pw.TextStyle(
    fontSize: 22,
    fontWeight: pw.FontWeight.bold,
    color: _kAzul,
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

  // ─── 2. Emissor | Cliente ──────────────────────────────────────

pw.Widget _emissorCliente(CotacaoModel cotacao, {ClienteModel? cliente}) {
  final nomeCliente = _nomeClienteCotacao(cotacao);
  final ehSingular = _cotacaoEhSingular(cotacao);
  final temCliente = nomeCliente != 'Sem cliente associado';

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

            if (temCliente)
              _t('Nome:  $nomeCliente', bold: true, size: 8.5),

            if (cliente != null && cliente.nuit != null && cliente.nuit!.isNotEmpty)
              _t('NUIT:  ${cliente.nuit}', size: 8),

            if (cliente != null && cliente.morada != null && cliente.morada!.isNotEmpty)
              _t('Endereço:  ${cliente.morada}', size: 8),

            if (cliente != null && cliente.contacto != null && cliente.contacto!.isNotEmpty)
              _t('Tel:  ${cliente.contacto}', size: 8),

            if (ehSingular)
              _t('Tipo:  Cliente singular', size: 8, color: PdfColors.grey700),

            if (cotacao.nomeUsuario != null &&
                cotacao.nomeUsuario!.trim().isNotEmpty)
              _t('Atendido por:  ${cotacao.nomeUsuario!.trim()}', size: 8),
          ],
        ),
      ),
    ],
  );
}

  // ─── 3. Metadados ─────────────────────────────────────────────

  pw.Widget _metadados(CotacaoModel cotacao) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _metaRow(
                'Data:',
                _fmt.format(cotacao.createdAt ?? DateTime.now()),
              ),
              _metaRow(
                'Gerado em:',
                DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
              ),
              if (cotacao.validadeAte != null)
                _metaRow('Válida até:', _fmt.format(cotacao.validadeAte!)),
              _metaRow('Estado:', cotacao.statusCotacao),
              _metaRow('Moeda:', 'MT'),
            ],
          ),
        ),
pw.Text(
  'Factura Proforma Nº-${_referenciaExibicao(cotacao.referencia)}',
  style: pw.TextStyle(
    fontSize: 8,
    fontWeight: pw.FontWeight.bold,
    color: _kVermelho,
  ),
),
      ],
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

  pw.Widget _tabelaItens(CotacaoModel cotacao) {
    final totalComIva = cotacao.total;

    final subtotalSemIva =
        cotacao.itensProduto.fold<double>(
              0,
              (soma, item) => soma + _removerIva(item.subtotal),
            ) +
        cotacao.itensServico.fold<double>(
          0,
          (soma, item) => soma + _removerIva(item.subtotal),
        );

    final valorIva = totalComIva - subtotalSemIva;

    final List<_LinhaItem> linhas = [
      for (final p in cotacao.itensProduto)
        _LinhaItem(
          quantidade: p.quantidade,
          descricao: (p.nomeProduto != null && p.nomeProduto!.isNotEmpty)
              ? p.nomeProduto!
              : 'Produto #${p.idProduto}',
          precoUnitario: _removerIva(p.precoUnitario),
          total: _removerIva(p.subtotal),
          obs: p.observacoes,
        ),
      for (final s in cotacao.itensServico)
        _LinhaItem(
          quantidade: s.quantidade,
          descricao: (s.nomeServico != null && s.nomeServico!.isNotEmpty)
              ? s.nomeServico!
              : 'Serviço #${s.idServico}',
          precoUnitario: _removerIva(s.precoUnitario),
          total: _removerIva(s.subtotal),
          obs: s.observacoes,
        ),
    ];

    const int minLinhas = 12;
    while (linhas.length < minLinhas) {
      linhas.add(_LinhaItem.vazia());
    }

    const pw.TextStyle estiloHeader =
        pw.TextStyle(fontSize: 8, color: PdfColors.white);
    const pw.TextStyle estiloCell = pw.TextStyle(fontSize: 8);
    final pw.TextStyle estiloCellBold =
        pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold);

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
            _thCell('Preço Unitário', estiloHeader,
                align: pw.TextAlign.right),
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
            _tdCell('Subtotal', estiloCellBold,
                align: pw.TextAlign.right),
            _tdCell(
                'MZN ${subtotalSemIva.toStringAsFixed(2)}', estiloCellBold,
                align: pw.TextAlign.right),
          ],
        ),
        pw.TableRow(
          children: [
            _tdCell('', estiloCell),
            _tdCell('', estiloCell),
            _tdCell('IVA 16%', estiloCell, align: pw.TextAlign.right),
            _tdCell(valorIva.toStringAsFixed(2), estiloCell,
                align: pw.TextAlign.right),
          ],
        ),
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _tdCell('', estiloCell),
            _tdCell('', estiloCell),
            _tdCell(
              'Total',
              pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: _kAzul),
              align: pw.TextAlign.right,
            ),
            _tdCell(
              'MZN ${totalComIva.toStringAsFixed(2)}',
              pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: _kVermelho),
              align: pw.TextAlign.right,
            ),
          ],
        ),
      ],
    );
  }

  // ─── 5. Assinatura ────────────────────────────────────────────

  pw.Widget _assinatura() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 4),
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _t('Aprovado por: ___________________________', size: 8),
                  pw.SizedBox(height: 12),
                  _t('Assinatura: _____________________________', size: 8),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Align(
                alignment: pw.Alignment.centerRight,
                child:
                    _t('Data: _______ / _______ / ___________', size: 8),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Divider(color: PdfColors.grey400, thickness: 0.5),
      ],
    );
  }

  // ─── 6. Termos e condições ────────────────────────────────────

  pw.Widget _termos() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _t('Termos e Condições', bold: true, size: 8),
        pw.SizedBox(height: 3),
        ..._Empresa.termos.asMap().entries.map(
          (e) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 1.5),
            child: pw.Text(
              '${e.key + 1}. ${e.value}',
              style: const pw.TextStyle(fontSize: 7),
            ),
          ),
        ),
      ],
    );
  }

  // ─── 7. Dados bancários ───────────────────────────────────────

  pw.Widget _dadosBancarios() {
    const pw.TextStyle estiloHeader =
        pw.TextStyle(fontSize: 7, color: PdfColors.white);
    const pw.TextStyle estiloCell = pw.TextStyle(fontSize: 7);

    return pw.Column(
      children: [
        pw.Container(
          width: double.infinity,
          color: PdfColors.grey300,
          padding:
              const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
          child: pw.Text(
            'O pagamento pode ser feito por Cheque, Depósito ou Transferência Bancária'
            ' — Titular: Stech Engenharia SU, Lda',
            style:
                pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
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
                _thCell('Moeda', estiloHeader,
                    align: pw.TextAlign.center),
              ],
            ),
            ..._Empresa.bancos.map(
              (b) => pw.TableRow(
                children: [
                  _tdCell(b.banco, estiloCell),
                  _tdCell(b.conta, estiloCell),
                  _tdCell(b.nib, estiloCell),
                  _tdCell(b.moeda, estiloCell,
                      align: pw.TextAlign.center),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }


String _referenciaExibicao(String referencia) {
  return referencia.replaceFirst('COT-', '');
}

String _nomeClienteCotacao(CotacaoModel c) {
  if (c.nomeCliente != null && c.nomeCliente!.trim().isNotEmpty) {
    return c.nomeCliente!.trim();
  }

  final nomeSingular = [
    c.nomeClienteSingular,
    c.apelidoClienteSingular,
  ]
      .where((v) => v != null && v.trim().isNotEmpty)
      .join(' ')
      .trim();

  if (nomeSingular.isNotEmpty) {
    return nomeSingular;
  }

  return 'Sem cliente associado';
}

bool _cotacaoEhSingular(CotacaoModel c) {
  return (c.nomeCliente == null || c.nomeCliente!.trim().isEmpty) &&
      ((c.nomeClienteSingular != null &&
              c.nomeClienteSingular!.trim().isNotEmpty) ||
          (c.apelidoClienteSingular != null &&
              c.apelidoClienteSingular!.trim().isNotEmpty));
}

  // ─── 8. Rodapé do documento ───────────────────────────────────

  pw.Widget _rodapeDocumento() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.only(top: 4),
      alignment: pw.Alignment.center,
      child: pw.Text(
        'Documento processado por computador através do Sistema de Gestão Stech ERP.',
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

  pw.Widget _footerPagina(pw.Context ctx) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _t('Stech Engenharia (c) ${DateTime.now().year}',
            size: 7, color: PdfColors.grey600),
        _t('Página ${ctx.pageNumber} de ${ctx.pagesCount}',
            size: 7, color: PdfColors.grey600),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════
  // HELPERS GERAIS
  // ═════════════════════════════════════════════════════════════════

  double _removerIva(double valorComIva) => valorComIva / (1 + 0.16);

  pw.Widget _t(String text,
      {double size = 10, bool bold = false, PdfColor? color}) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: size,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color,
      ),
    );
  }

  pw.Widget _thCell(String text, pw.TextStyle style,
      {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(text, style: style, textAlign: align),
    );
  }

  pw.Widget _tdCell(String text, pw.TextStyle style,
      {pw.TextAlign align = pw.TextAlign.left}) {
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
            pw.Text(
              l.obs!,
              style: pw.TextStyle(
                  fontSize: 6.5, color: PdfColors.grey600),
            ),
          ],
        ),
      );
    }
    return _tdCell(l.descricao, style);
  }

  // ═════════════════════════════════════════════════════════════════
  // NOMENCLATURA DE FICHEIROS
  // ═════════════════════════════════════════════════════════════════

String _nomeArquivo(CotacaoModel cotacao) {
  final safeRef = cotacao.referencia.replaceAll('/', '-');
  return 'FACT-PROFORMA-$safeRef';
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
      throw Exception(
          'SumatraPDF.exe não encontrado.\nCaminho esperado: $path');
    }
    return path;
  }
}

// ═══════════════════════════════════════════════════════════════════
// DATA CLASS — linha de item na tabela da cotação
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
  String get precoStr =>
      isEmpty ? '0,00 MZN' : 'MZN ${precoUnitario.toStringAsFixed(2)}';
  String get totalStr =>
      isEmpty ? '0,00 MZN' : 'MZN ${total.toStringAsFixed(2)}';
}