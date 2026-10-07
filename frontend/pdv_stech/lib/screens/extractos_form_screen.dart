import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:api_compartilhado/api_compartilhado.dart';

const _kAzul       = Color(0xFF1B2A6B);
const _kVermelho   = Color(0xFFC8102E);
const _kBranco     = Colors.white;
const _kCinzaClaro = Color(0xFFF4F5F7);
const _kCinzaTexto = Color(0xFF6B7280);

// ── Períodos disponíveis ──────────────────────────────────────────────────────

enum _Periodo {
  hoje,
  ultimoDia,
  ultimaSemana,
  ultimos15Dias,
  ultimoMes,
  ultimos3Meses,
  ultimos6Meses,
  ultimoAno,
}

enum _TipoExtractoPdf {
  geral,
  interno,
}

extension _PeriodoExt on _Periodo {
  String get label => switch (this) {
        _Periodo.hoje          => 'Hoje',
        _Periodo.ultimoDia     => 'Último dia',
        _Periodo.ultimaSemana  => 'Última semana',
        _Periodo.ultimos15Dias => 'Últimos 15 dias',
        _Periodo.ultimoMes     => 'Último mês',
        _Periodo.ultimos3Meses => 'Últimos 3 meses',
        _Periodo.ultimos6Meses => 'Últimos 6 meses',
        _Periodo.ultimoAno     => 'Último ano',
      };

  /// Retorna [dataInicio, dataFim] para o período.
  (DateTime, DateTime) intervalo() {
    final agora = DateTime.now();
    final fim   = DateTime(agora.year, agora.month, agora.day, 23, 59, 59);

    final inicio = switch (this) {
      _Periodo.hoje          => DateTime(agora.year, agora.month, agora.day),
      _Periodo.ultimoDia     => fim.subtract(const Duration(days: 1)),
      _Periodo.ultimaSemana  => fim.subtract(const Duration(days: 7)),
      _Periodo.ultimos15Dias => fim.subtract(const Duration(days: 15)),
      _Periodo.ultimoMes     => fim.subtract(const Duration(days: 30)),
      _Periodo.ultimos3Meses => fim.subtract(const Duration(days: 90)),
      _Periodo.ultimos6Meses => fim.subtract(const Duration(days: 180)),
      _Periodo.ultimoAno     => fim.subtract(const Duration(days: 365)),
    };

    return (inicio, fim);
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class ExtratosFormScreen extends StatefulWidget {
  const ExtratosFormScreen({super.key});

  @override
  State<ExtratosFormScreen> createState() => _ExtratosFormScreenState();
}

class _ExtratosFormScreenState extends State<ExtratosFormScreen> {
  _Periodo _periodoSelecionado = _Periodo.ultimoMes;
  bool     _gerando            = false;
  ExtratoModel? _previa;
  _TipoExtractoPdf? _tipoSelecionado;
final _campo19Ctrl = TextEditingController();
SimulacaoApuramentoIvaModel? _apuramentoIva;

  final _fmtData  = DateFormat('dd/MM/yyyy');
  final _fmtMoeda = NumberFormat.currency(locale: 'pt_PT', symbol: 'MZN');

  // ── Gerar prévia ──────────────────────────────────────────────────────────


@override
void dispose() {
  _campo19Ctrl.dispose();
  super.dispose();
}

Future<void> _gerarPrevia() async {
  final tipo = await _escolherTipoExtracto();

  if (tipo == null) return;

  setState(() {
    _gerando = true;
    _previa = null;
    _apuramentoIva = null;
    _tipoSelecionado = tipo;
  });

  try {
    final (inicio, fim) = _periodoSelecionado.intervalo();

    final extrato = await ExtratoService.instance.gerar(
      dataInicio: inicio,
      dataFim: fim,
      labelPeriodo: _periodoSelecionado.label,
    );

    if (!mounted) return;

    if (tipo == _TipoExtractoPdf.geral) {
      final apuramento = SimulacaoApuramentoIvaModel.fromExtrato(
        extrato,
        campo19: _parseNumero(_campo19Ctrl.text),
      );

      setState(() {
        _apuramentoIva = apuramento;
        _previa = extrato.copyWith(apuramentoIva: apuramento);
      });
    } else {
      setState(() {
        _apuramentoIva = null;
        _previa = extrato;
      });
    }
  } catch (e) {
    if (mounted) {
      _snack('Erro ao gerar extracto: $e', erro: true);
    }
  } finally {
    if (mounted) {
      setState(() => _gerando = false);
    }
  }
}

  Future<_TipoExtractoPdf?> _escolherTipoExtracto() {
  return showDialog<_TipoExtractoPdf>(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text(
        'Tipo de extracto',
        style: TextStyle(
          color: _kAzul,
          fontWeight: FontWeight.w700,
        ),
      ),
   content: const Text(
  'Escolha o tipo de extracto antes de gerar a pré-visualização.\n\n'
  'Extracto Geral: inclui simulação do apuramento do IVA.\n'
  'Extracto Interno: lista documentos fiscais com o estado.',
  style: TextStyle(color: _kCinzaTexto),
),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancelar'),
        ),
        OutlinedButton.icon(
          onPressed: () =>
              Navigator.of(context).pop(_TipoExtractoPdf.geral),
          icon: const Icon(Icons.analytics_outlined),
          label: const Text('Extracto Geral'),
        ),
        ElevatedButton.icon(
          onPressed: () =>
              Navigator.of(context).pop(_TipoExtractoPdf.interno),
          icon: const Icon(Icons.receipt_long_rounded),
          label: const Text('Extracto Interno'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kAzul,
            foregroundColor: _kBranco,
          ),
        ),
      ],
    ),
  );
}

  // ── Exportar PDF ─────────────────────────────────────────────────────────

Future<void> _exportar() async {
  if (_previa == null || _tipoSelecionado == null) return;

  setState(() => _gerando = true);

  try {
    final extratoFinal = _previa!.copyWith(
      apuramentoIva: _tipoSelecionado == _TipoExtractoPdf.geral
          ? _apuramentoIva
          : null,
    );

    final file = switch (_tipoSelecionado!) {
      _TipoExtractoPdf.geral =>
        await ExtratoPdfService.instance.gerar(extratoFinal),

      _TipoExtractoPdf.interno =>
        await ExtratoPdfInternoService.instance.gerar(extratoFinal),
    };

    if (!mounted) return;

    setState(() => _gerando = false);

    switch (_tipoSelecionado!) {
      case _TipoExtractoPdf.geral:
        await ExtratoPdfService.instance.abrirPdf(file);
        break;

      case _TipoExtractoPdf.interno:
        await ExtratoPdfInternoService.instance.abrirPdf(file);
        break;
    }

    if (mounted) {
      Navigator.pop(context, extratoFinal);
    }
  } catch (e) {
    if (mounted) {
      setState(() => _gerando = false);
      _snack('Erro ao exportar PDF: $e', erro: true);
    }
  }
}
  void _snack(String msg, {bool erro = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: erro ? _kVermelho : _kAzul,
      behavior:        SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kCinzaClaro,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _cardPeriodo(),
            const SizedBox(height: 16),
            _botaoGerar(),
            if (_previa != null) ...[
              const SizedBox(height: 20),
              _cardPrevia(),
              const SizedBox(height: 12),
              _botaoExportar(),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  double _parseNumero(String valor) {
  final normalizado = valor
      .replaceAll(' ', '')
      .replaceAll('.', '')
      .replaceAll(',', '.')
      .trim();

  return double.tryParse(normalizado) ?? 0.0;
}

bool _linhaAnulada(LinhaExtrato linha) {
  return linha.estado.trim().toUpperCase() == 'ANULADO';
}

List<LinhaExtrato> _linhasValidasParaResumo(ExtratoModel extrato) {
  if (_tipoSelecionado != _TipoExtractoPdf.interno) {
    return extrato.linhas;
  }

  return extrato.linhas.where((linha) => !_linhaAnulada(linha)).toList();
}

int _totalDocumentosResumo(ExtratoModel extrato) {
  if (_tipoSelecionado != _TipoExtractoPdf.interno) {
    return extrato.totalDocumentos;
  }

  return _linhasValidasParaResumo(extrato).length;
}

double _somaTotalResumo(ExtratoModel extrato) {
  if (_tipoSelecionado != _TipoExtractoPdf.interno) {
    return extrato.somaTotal;
  }

  return _linhasValidasParaResumo(extrato).fold<double>(
    0.0,
    (soma, linha) => soma + linha.valorTotal,
  );
}



void _recalcularCampo19() {
  if (_apuramentoIva == null) return;

  final campo19 = _parseNumero(_campo19Ctrl.text);

  setState(() {
    _apuramentoIva = _apuramentoIva!.recalcularComCampo19(campo19);
  });
}

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _kAzul,
      foregroundColor: _kBranco,
      elevation:       0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color:        _kVermelho,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.analytics_outlined,
                color: _kBranco, size: 20),
          ),
          const SizedBox(width: 10),
          const Text('Gerar Extracto',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── Card período ──────────────────────────────────────────────────────────

  Widget _cardPeriodo() {
    return _CardSecao(
      icon:   Icons.date_range_rounded,
      titulo: 'Selecione o Período',
      filho: Wrap(
        spacing:    8,
        runSpacing: 8,
        children: _Periodo.values.map((p) {
          final activo = _periodoSelecionado == p;
          return GestureDetector(
         onTap: () => setState(() {
  _periodoSelecionado = p;
  _previa = null;
  _apuramentoIva = null;
  _tipoSelecionado = null;
}),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color:        activo ? _kAzul : _kBranco,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: activo ? _kAzul : Colors.grey.shade300,
                ),
                boxShadow: activo
                    ? [BoxShadow(
                        color:     _kAzul.withOpacity(0.18),
                        blurRadius: 6,
                        offset:    const Offset(0, 2),
                      )]
                    : null,
              ),
              child: Text(
                p.label,
                style: TextStyle(
                  fontSize:   13,
                  fontWeight: activo ? FontWeight.w700 : FontWeight.normal,
                  color:      activo ? _kBranco : _kCinzaTexto,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Botão gerar ───────────────────────────────────────────────────────────

  Widget _botaoGerar() {
    return ElevatedButton.icon(
      onPressed: _gerando ? null : _gerarPrevia,
      icon: _gerando
          ? const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: _kBranco))
          : const Icon(Icons.receipt_long_rounded),
      label: Text(_gerando ? 'A processar...' : 'GERAR EXTRACTO',
          style: const TextStyle(fontSize: 15, letterSpacing: 0.4)),
      style: ElevatedButton.styleFrom(
        backgroundColor: _kAzul,
        foregroundColor: _kBranco,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Card prévia ───────────────────────────────────────────────────────────

Widget _cardPrevia() {
  final e = _previa!;
  final totalDocumentosResumo = _totalDocumentosResumo(e);
final somaTotalResumo = _somaTotalResumo(e);

  return _CardSecao(
    icon: Icons.preview_rounded,
  titulo: _tipoSelecionado == _TipoExtractoPdf.interno
    ? 'Prévia do Extracto Interno'
    : 'Prévia do Extracto Geral',
    subtitulo: '${_fmtData.format(e.dataInicio)} → '
        '${_fmtData.format(e.dataFim)}  ·  '
        '${e.labelPeriodo}',
    filho: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Totais
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _kAzul.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kAzul.withOpacity(0.15)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
            _ResumoItem(
  label: 'Documentos',
  valor: '$totalDocumentosResumo',
  cor: _kAzul,
),
              Container(
                width: 1,
                height: 36,
                color: Colors.grey.shade300,
              ),
           _ResumoItem(
  label: 'Total',
  valor: _fmtMoeda.format(somaTotalResumo),
  cor: _kVermelho,
),
            ],
          ),
        ),

        // Simulação do apuramento do IVA
      if (_tipoSelecionado == _TipoExtractoPdf.geral &&
    _apuramentoIva != null) ...[
  _cardSimulacaoApuramentoIva(),
  const SizedBox(height: 12),
],
        // Cabeçalho da tabela
        if (e.linhas.isNotEmpty)
          _CabecalhoTabela(),

        // Linhas
        if (e.linhas.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    color: _kCinzaTexto,
                    size: 40,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Nenhum documento FAT ou VD no período.',
                    style: TextStyle(
                      color: _kCinzaTexto,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...e.linhas.asMap().entries.map(
                (entry) => _LinhaExtrato(
                  linha: entry.value,
                  isAlternate: entry.key.isOdd,
                  fmtData: _fmtData,
                  fmtMoeda: _fmtMoeda,
                ),
              ),
      ],
    ),
  );
}

Widget _cardSimulacaoApuramentoIva() {
  final a = _apuramentoIva!;
  final fmt = NumberFormat('#,##0.00', 'pt_PT');

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFE8F1FA),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _kAzul.withOpacity(0.25)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          width: double.infinity,
          child: Text(
            'Simulação do Apuramento do IVA',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _kAzul,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 10),

        LayoutBuilder(
          builder: (context, constraints) {
            final largura = constraints.maxWidth;

            final larguraCampo = largura >= 640
                ? (largura - 24) / 4
                : largura >= 460
                    ? (largura - 16) / 3
                    : largura >= 300
                        ? (largura - 8) / 2
                        : largura;

            return Wrap(
              spacing: 8,
              runSpacing: 8,
children: [
  _campoIva('1', 'Base Tributavel', fmt.format(a.campo1), larguraCampo),
  _campoIva('2', 'IVA Apurado', fmt.format(a.campo2), larguraCampo),
  _campoIva('3', 'Base 5', fmt.format(a.campo3), larguraCampo),
  _campoIva('4', 'IVA 5', fmt.format(a.campo4), larguraCampo),
  _campoIva('5', 'Isentas', fmt.format(a.campo5), larguraCampo),
  _campoIva('6', 'Sem deducao', fmt.format(a.campo6), larguraCampo),
  _campoIva('7', 'Outras', fmt.format(a.campo7), larguraCampo),
  _campoIva('8', 'Imobilizado', fmt.format(a.campo8), larguraCampo),
  _campoIva('9', 'Existencias', fmt.format(a.campo9), larguraCampo),
  _campoIva('10', 'Outros bens/servicos', fmt.format(a.campo10), larguraCampo),
  _campoIva('11', 'Importacao', fmt.format(a.campo11), larguraCampo),
  _campoIva('12', 'Regularizacoes SP', fmt.format(a.campo12), larguraCampo),
  _campoIva('13', 'Regularizacoes Estado', fmt.format(a.campo13), larguraCampo),
  _campoIva('14', 'Soma Base', fmt.format(a.campo14), larguraCampo),
  _campoIva('15', 'Soma Dedutivel', fmt.format(a.campo15), larguraCampo),
  _campoIva('16', 'Soma IVA Apurado', fmt.format(a.campo16), larguraCampo),
  _campoIva('17', 'IVA a pagar', fmt.format(a.campo17), larguraCampo),
  _campoIva('18', 'IVA a recuperar', fmt.format(a.campo18), larguraCampo),
  _campoIvaManual19(larguraCampo),
  _campoIva('20', '', fmt.format(a.campo20), larguraCampo),
],
            );
          },
        ),
      ],
    ),
  );
}

Widget _campoIva(
  String numero,
  String label,
  String valor,
  double largura,
) {
  return SizedBox(
    width: largura,
    child: TextFormField(
      initialValue: valor == '0,00' ? '-' : valor,
      readOnly: true,
      enabled: false,
      decoration: InputDecoration(
labelText: label.trim().isEmpty
    ? 'Campo $numero'
    : 'Campo $numero - $label',
        labelStyle: const TextStyle(fontSize: 10),
        filled: true,
        fillColor: Colors.white.withOpacity(0.75),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: _kAzul,
      ),
      textAlign: TextAlign.right,
    ),
  );
}

Widget _campoIvaManual19(double largura) {
  return SizedBox(
    width: largura,
    child: TextField(
      controller: _campo19Ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => _recalcularCampo19(),
decoration: InputDecoration(
  labelText: 'Campo 19 - Excesso anterior',
  labelStyle: const TextStyle(fontSize: 10),
  filled: true,
  fillColor: Colors.white,
  suffixIcon: const Icon(
    Icons.edit_outlined,
    size: 16,
    color: _kVermelho,
  ),
  contentPadding:
      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
  ),
),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: _kVermelho,
      ),
      textAlign: TextAlign.right,
    ),
  );
}

  // ── Botão exportar ────────────────────────────────────────────────────────

Widget _botaoExportar() {
  final temDados =
      ((_previa?.totalDocumentos ?? 0) > 0) ||
      ((_previa?.totalDespesasRegistadas ?? 0) > 0);

  final interno = _tipoSelecionado == _TipoExtractoPdf.interno;

  return ElevatedButton.icon(
    onPressed: (_gerando || !temDados) ? null : _exportar,
    icon: _gerando
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _kBranco,
            ),
          )
        : Icon(
            interno
                ? Icons.picture_as_pdf_rounded
                : Icons.upload_file_rounded,
          ),
    label: Text(
      _gerando
          ? 'A exportar...'
          : interno
              ? 'GERAR PDF'
              : 'EXPORTAR PDF',
      style: const TextStyle(fontSize: 15, letterSpacing: 0.4),
    ),
    style: ElevatedButton.styleFrom(
      backgroundColor: interno ? _kAzul : _kVermelho,
      foregroundColor: _kBranco,
      disabledBackgroundColor:
          (interno ? _kAzul : _kVermelho).withOpacity(0.4),
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}
}

// ─── Widgets auxiliares ───────────────────────────────────────────────────────

class _CardSecao extends StatelessWidget {
  final IconData icon;
  final String   titulo;
  final String?  subtitulo;
  final Widget   filho;

  const _CardSecao({
    required this.icon,
    required this.titulo,
    required this.filho,
    this.subtitulo,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: _kAzul, size: 20),
              const SizedBox(width: 8),
              Text(titulo,
                  style: const TextStyle(
                      fontSize:   15,
                      fontWeight: FontWeight.w700,
                      color:      _kAzul)),
            ]),
            if (subtitulo != null) ...[
              const SizedBox(height: 4),
              Text(subtitulo!,
                  style: const TextStyle(
                      fontSize: 12, color: _kCinzaTexto)),
            ],
            const SizedBox(height: 12),
            filho,
          ],
        ),
      ),
    );
  }
}

class _ResumoItem extends StatelessWidget {
  final String label;
  final String valor;
  final Color  cor;

  const _ResumoItem({
    required this.label,
    required this.valor,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(label,
          style: const TextStyle(
              fontSize: 11, color: _kCinzaTexto)),
      const SizedBox(height: 4),
      Text(valor,
          style: TextStyle(
              fontSize:   16,
              fontWeight: FontWeight.w700,
              color:      cor)),
    ]);
  }
}

class _CabecalhoTabela extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color:        _kAzul,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: const Row(children: [
        SizedBox(width: 76,
            child: Text('Data',
                style: TextStyle(
                    color: Colors.white, fontSize: 11,
                    fontWeight: FontWeight.w600))),
        SizedBox(width: 110,
            child: Text('Documento',
                style: TextStyle(
                    color: Colors.white, fontSize: 11,
                    fontWeight: FontWeight.w600))),
        Expanded(
            child: Text('Empresa',
                style: TextStyle(
                    color: Colors.white, fontSize: 11,
                    fontWeight: FontWeight.w600))),
        SizedBox(width: 90,
            child: Text('NUIT',
                style: TextStyle(
                    color: Colors.white, fontSize: 11,
                    fontWeight: FontWeight.w600))),
        SizedBox(width: 100,
            child: Text('Valor',
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: Colors.white, fontSize: 11,
                    fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

class _LinhaExtrato extends StatelessWidget {
  final LinhaExtrato linha;
  final bool         isAlternate;
  final DateFormat   fmtData;
  final NumberFormat fmtMoeda;

  const _LinhaExtrato({
    required this.linha,
    required this.isAlternate,
    required this.fmtData,
    required this.fmtMoeda,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: isAlternate
            ? const Color(0xFFF0F2FA)
            : Colors.white,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE8EAF0)),
        ),
      ),
      child: Row(children: [
        SizedBox(
          width: 76,
          child: Text(fmtData.format(linha.dataEmissao),
              style: const TextStyle(
                  fontSize: 12, color: _kCinzaTexto)),
        ),
        SizedBox(
          width: 110,
          child: Text(linha.numeroDocumento,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _kAzul)),
        ),
        Expanded(
          child: Text(linha.nomeEmpresa,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12)),
        ),
        SizedBox(
          width: 90,
          child: Text(linha.nuit ?? '—',
              style: const TextStyle(
                  fontSize: 11, color: _kCinzaTexto)),
        ),
        SizedBox(
          width: 100,
          child: Text(
            fmtMoeda.format(linha.valorTotal),
            textAlign: TextAlign.right,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _kVermelho),
          ),
        ),
      ]),
    );
  }
}