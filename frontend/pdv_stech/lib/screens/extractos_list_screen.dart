import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import '../widgets/app_sidebar.dart';
import 'extractos_form_screen.dart';

const _kAzul       = Color(0xFF1B2A6B);
const _kVermelho   = Color(0xFFC8102E);
const _kBranco     = Colors.white;
const _kCinzaClaro = Color(0xFFF4F5F7);
const _kCinzaTexto = Color(0xFF6B7280);

class ExtratosListScreen extends StatefulWidget {
  const ExtratosListScreen({super.key});

  @override
  State<ExtratosListScreen> createState() => _ExtratosListScreenState();
}

class _ExtratosListScreenState extends State<ExtratosListScreen> {
  /// Extractos gerados na sessão (em memória — não há tabela de persistência).
  final List<_ExtratoSessao> _historico = [];

  bool _carregandoPrevia = false;

  final _fmtData  = DateFormat('dd/MM/yyyy');
  final _fmtHora  = DateFormat('HH:mm');
  final _fmtMoeda = NumberFormat.currency(locale: 'pt_PT', symbol: 'MZN');

  // ── Navegar para o formulário e receber resultado ─────────────────────────

// DEPOIS
Future<void> _novoExtrato() async {
  final resultado = await Navigator.push<ExtratoModel>(
    context,
    MaterialPageRoute(builder: (_) => const ExtratosFormScreen()),
  );
  if (resultado != null && mounted) {
    setState(() {
      _historico.insert(
        0,
        _ExtratoSessao(extrato: resultado, geradoEm: DateTime.now()),
      );
    });
  }
}

  // ── Regerar PDF de um extracto do histórico ───────────────────────────────

  Future<void> _regerarPdf(_ExtratoSessao sessao) async {
    setState(() => _carregandoPrevia = true);
    try {
      final file = await ExtratoPdfService.instance.gerar(sessao.extrato);
      if (mounted) {
        setState(() => _carregandoPrevia = false);
        await ExtratoPdfService.instance.abrirPdf(file);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _carregandoPrevia = false);
        _snack('Erro ao gerar PDF: $e', erro: true);
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
      drawer: const AppSidebar(currentRoute: '/gerenciar_extractos'),
      appBar: _buildAppBar(),
      body: _historico.isEmpty
          ? _estadoVazio()
          : _listaHistorico(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _novoExtrato,
        backgroundColor: _kVermelho,
        foregroundColor: _kBranco,
        icon:  const Icon(Icons.add_rounded),
        label: const Text('Novo Extracto',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _kAzul,
      foregroundColor: _kBranco,
      elevation:       0,
      title: Row(children: [
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
        const Text('Extractos',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _estadoVazio() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.analytics_outlined,
              size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('Nenhum extracto gerado nesta sessão.',
              style: TextStyle(
                  fontSize: 15, color: _kCinzaTexto)),
          const SizedBox(height: 8),
          const Text(
            'Clique em "Novo Extracto" para gerar.',
            style: TextStyle(fontSize: 12, color: _kCinzaTexto),
          ),
        ],
      ),
    );
  }

  Widget _listaHistorico() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      itemCount: _historico.length,
      itemBuilder: (_, i) {
        final s = _historico[i];
        return _CardHistorico(
          sessao:   s,
          fmtData:  _fmtData,
          fmtHora:  _fmtHora,
          fmtMoeda: _fmtMoeda,
          onExportar: () => _regerarPdf(s),
        );
      },
    );
  }
}

// ── Modelo de sessão (em memória) ─────────────────────────────────────────────

class _ExtratoSessao {
  final ExtratoModel extrato;
  final DateTime     geradoEm;

  const _ExtratoSessao({required this.extrato, required this.geradoEm});
}

// ── Card de histórico ─────────────────────────────────────────────────────────

class _CardHistorico extends StatelessWidget {
  final _ExtratoSessao sessao;
  final DateFormat     fmtData;
  final DateFormat     fmtHora;
  final NumberFormat   fmtMoeda;
  final VoidCallback   onExportar;

  const _CardHistorico({
    required this.sessao,
    required this.fmtData,
    required this.fmtHora,
    required this.fmtMoeda,
    required this.onExportar,
  });

  @override
  Widget build(BuildContext context) {
    final e = sessao.extrato;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ícone
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color:        _kAzul.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.analytics_outlined,
                  color: _kAzul, size: 22),
            ),
            const SizedBox(width: 12),

            // Informações
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.labelPeriodo,
                      style: const TextStyle(
                          fontSize:   15,
                          fontWeight: FontWeight.w700,
                          color:      _kAzul)),
                  const SizedBox(height: 4),
                  Text(
                    '${fmtData.format(e.dataInicio)} → '
                    '${fmtData.format(e.dataFim)}',
                    style: const TextStyle(
                        fontSize: 12, color: _kCinzaTexto),
                  ),
                  const SizedBox(height: 6),
                  Wrap(spacing: 12, children: [
                    _ChipInfo(
                      icon:  Icons.description_outlined,
                      label: '${e.totalDocumentos} docs',
                    ),
                    _ChipInfo(
                      icon:  Icons.attach_money_rounded,
                      label: fmtMoeda.format(e.somaTotal),
                      cor:   _kVermelho,
                    ),
                    _ChipInfo(
                      icon:  Icons.schedule_rounded,
                      label: 'Gerado às '
                          '${fmtHora.format(sessao.geradoEm)}',
                    ),
                  ]),
                ],
              ),
            ),

            // Botão exportar
            Tooltip(
              message: 'Exportar PDF',
              child: IconButton(
                icon:      const Icon(Icons.picture_as_pdf_rounded),
                color:     _kAzul,
                iconSize:  24,
                onPressed: onExportar,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipInfo extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    cor;

  const _ChipInfo({
    required this.icon,
    required this.label,
    this.cor = _kCinzaTexto,
  });

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: cor),
      const SizedBox(width: 3),
      Text(label,
          style: TextStyle(fontSize: 11, color: cor)),
    ]);
  }
}