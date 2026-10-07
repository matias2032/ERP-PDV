// lib/screens/cotacao_list_screen.dart

import 'package:flutter/material.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:provider/provider.dart';
import '../widgets/app_sidebar.dart';
import 'cotacao_catalogo_screen.dart';
import 'cotacoes_abertas_screen.dart';
import 'cotacao_detalhes_screen.dart';

// ── Cores STech Engenharia ────────────────────────────────────────────────────
const _kVermelho   = Color(0xFFC8102E);
const _kAzul       = Color(0xFF1B2A6B);
const _kBranco     = Colors.white;
const _kCinzaClaro = Color(0xFFF4F5F7);
const _kCinzaTexto = Color(0xFF6B7280);
const _kVerde      = Color(0xFF1B8A4C);
const _kLaranja    = Color(0xFFE08A00);

// ─────────────────────────────────────────────────────────────────────────────
//  Status — labels e cores
// ─────────────────────────────────────────────────────────────────────────────

const List<String> _kStatusFiltros = [
  'TODAS',
  'ABERTA',
  'ENVIADA',
  'APROVADA',
  'CONVERTIDA',
  'CANCELADA',
  'EXPIRADA',
];

String _labelStatus(String status) {
  switch (status) {
    case 'ABERTA':     return 'Aberta';
    case 'ENVIADA':    return 'Enviada';
    case 'APROVADA':   return 'Aprovada';
    case 'CONVERTIDA': return 'Convertida';
    case 'CANCELADA':  return 'Cancelada';
    case 'EXPIRADA':   return 'Expirada';
    default:           return 'Todas';
  }
}

Color _corStatus(String status) {
  switch (status) {
    case 'ABERTA':     return _kAzul;
    case 'ENVIADA':    return _kLaranja;
    case 'APROVADA':   return _kVerde;
    case 'CONVERTIDA': return _kCinzaTexto;
    case 'CANCELADA':  return _kVermelho;
    case 'EXPIRADA':   return _kCinzaTexto;
    default:           return _kCinzaTexto;
  }
}

String _formatarData(DateTime? data) {
  if (data == null) return '—';
  return '${data.day.toString().padLeft(2, '0')}/'
      '${data.month.toString().padLeft(2, '0')}/${data.year}';
}

String _formatarTotal(double total) {
  return 'MZN ${total.toStringAsFixed(2)}';
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

// ─────────────────────────────────────────────────────────────────────────────

class CotacaoListScreen extends StatefulWidget {
  const CotacaoListScreen({super.key});

  @override
  State<CotacaoListScreen> createState() => _CotacaoListScreenState();
}

class _CotacaoListScreenState extends State<CotacaoListScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _statusSelecionado = 'TODAS';
  String _termoPesquisa = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
context.read<CotacaoProvider>().listarProntas();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Pesquisa / filtro ───────────────────────────────────────────────────

  void _onPesquisar(String termo) {
    setState(() => _termoPesquisa = termo.trim().toLowerCase());
  }

  void _limparPesquisa() {
    _searchController.clear();
    setState(() => _termoPesquisa = '');
  }

  // void _onSelecionarStatus(String status) {
  //   setState(() => _statusSelecionado = status);
  //   final provider = context.read<CotacaoProvider>();
  //   if (status == 'TODAS') {
  //     provider.listarTodas();
  //   } else {
  //     provider.listarPorStatus(status);
  //   }
  // }

Future<void> _recarregar() async {
  await context.read<CotacaoProvider>().listarProntas();
}

  List<CotacaoModel> _aplicarFiltroLocal(List<CotacaoModel> lista) {
    if (_termoPesquisa.isEmpty) return lista;
    return lista.where((c) {
      final referencia  = c.referencia.toLowerCase();
 final nomeCliente = _nomeClienteCotacao(c).toLowerCase();

return referencia.contains(_termoPesquisa) ||
    nomeCliente.contains(_termoPesquisa);
    }).toList();
  }

  // ── Diálogo de exclusão ───────────────────────────────────────────────────

Future<void> _confirmarCancelamento(BuildContext ctx, CotacaoModel cotacao) async {
  final confirma = await showDialog<bool>(
    context: ctx,
    builder: (_) => _DialogoConfirmacao(
      titulo: 'Cancelar cotação',
      mensagem:
          'Deseja cancelar a cotação "${cotacao.referencia}"? Ela ficará marcada como CANCELADA e não poderá ser convertida.',
      corBotao: _kVermelho,
      labelBotao: 'Cancelar Cotação',
    ),
  );

  if (confirma != true || !ctx.mounted) return;

  final provider = ctx.read<CotacaoProvider>();

  final sucesso = await provider.atualizarCotacao(
    cotacao.idCotacao,
    AtualizarCotacaoRequestModel(
      statusCotacao: 'CANCELADA',
    ),
  );

  if (!ctx.mounted) return;

  if (sucesso != null) {
    _mostrarSnack(
      ctx,
      'Cotação ${cotacao.referencia} cancelada com sucesso.',
    );

    await _recarregar();
  } else {
    _mostrarSnack(
      ctx,
      provider.errorMessage ?? 'Erro ao cancelar cotação.',
      erro: true,
    );
    provider.limparErro();
  }
}

  void _mostrarSnack(BuildContext ctx, String mensagem, {bool erro = false}) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: erro ? _kVermelho : _kAzul,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ── Navegação ────────────────────────────────────────────────────────────

void _abrirFormulario({CotacaoModel? cotacao}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const CotacaoCatalogoScreen(),
    ),
  ).then((_) => _recarregar());
}

void _abrirDetalhe(CotacaoModel cotacao) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => CotacaoDetalhesScreen(cotacao: cotacao),
    ),
  ).then((_) => _recarregar());
}

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kCinzaClaro,
      appBar: _buildAppBar(),
      drawer: const AppSidebar(currentRoute: '/cotacoes_prontas'),
      body: Column(
        children: [
          _BarraPesquisa(
            controller: _searchController,
            onChanged: _onPesquisar,
            onLimpar: _limparPesquisa,
          ),
     
          const Divider(height: 1),
       Expanded(
  child: _Listagem(
    aplicarFiltroLocal: _aplicarFiltroLocal,
    onRecarregar: _recarregar,
    onAbrirDetalhe: _abrirDetalhe,
    onCancelar: (c) => _confirmarCancelamento(context, c),
  ),
),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _kAzul,
      foregroundColor: _kBranco,
      elevation: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _kVermelho,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.request_quote_rounded,
                color: _kBranco, size: 20),
          ),
          const SizedBox(width: 10),
          const Text(
            'Cotações',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0.3),
          ),
        ],
      ),
      actions: [
        // IconButton(
        //   icon: const Icon(Icons.add_rounded),
        //   tooltip: 'Nova Cotação',
        //   onPressed: () => _abrirFormulario(),
        // ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Recarregar',
          onPressed: _recarregar,
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Barra de Pesquisa
// ─────────────────────────────────────────────────────────────────────────────

class _BarraPesquisa extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onLimpar;

  const _BarraPesquisa({
    required this.controller,
    required this.onChanged,
    required this.onLimpar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBranco,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: 'Pesquisar por referência ou cliente...',
                hintStyle: const TextStyle(fontSize: 13, color: _kCinzaTexto),
                prefixIcon: const Icon(Icons.search_rounded, color: _kAzul),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: _kCinzaTexto, size: 18),
                        onPressed: onLimpar,
                      )
                    : null,
                filled: true,
                fillColor: _kCinzaClaro,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Contador de resultados
          Consumer<CotacaoProvider>(
            builder: (_, p, __) => Text(
              '${p.cotacoes.length} cotação(ões)',
              style: const TextStyle(fontSize: 13, color: _kCinzaTexto),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Barra de filtro por status
// ─────────────────────────────────────────────────────────────────────────────

class _BarraFiltroStatus extends StatelessWidget {
  final String selecionado;
  final ValueChanged<String> onSelecionar;

  const _BarraFiltroStatus({
    required this.selecionado,
    required this.onSelecionar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBranco,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _kStatusFiltros.map((status) {
            final ativo = status == selecionado;
            final cor = status == 'TODAS' ? _kAzul : _corStatus(status);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(_labelStatus(status)),
                selected: ativo,
                onSelected: (_) => onSelecionar(status),
                selectedColor: cor.withOpacity(0.15),
                backgroundColor: _kCinzaClaro,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: ativo ? FontWeight.w700 : FontWeight.normal,
                  color: ativo ? cor : _kCinzaTexto,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: ativo ? cor.withOpacity(0.4) : Colors.transparent,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Listagem
// ─────────────────────────────────────────────────────────────────────────────

class _Listagem extends StatelessWidget {
  final List<CotacaoModel> Function(List<CotacaoModel>) aplicarFiltroLocal;
  final Future<void> Function() onRecarregar;
  final void Function(CotacaoModel) onAbrirDetalhe;
  final Future<void> Function(CotacaoModel) onCancelar;

  const _Listagem({
    required this.aplicarFiltroLocal,
    required this.onRecarregar,
    required this.onAbrirDetalhe,
    required this.onCancelar,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CotacaoProvider>();

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator(color: _kAzul));
    }

    if (provider.status == CotacaoStatus.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: _kVermelho, size: 48),
            const SizedBox(height: 12),
            Text(provider.errorMessage ?? 'Erro ao carregar cotações.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _kVermelho)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRecarregar,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
              style: ElevatedButton.styleFrom(backgroundColor: _kAzul),
            ),
          ],
        ),
      );
    }

    final lista = aplicarFiltroLocal(provider.cotacoes);

    if (lista.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.request_quote_outlined, color: _kCinzaTexto, size: 48),
            SizedBox(height: 12),
            Text('Nenhuma cotação encontrada.',
                style: TextStyle(color: _kCinzaTexto)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _kAzul,
      onRefresh: onRecarregar,
      child: Column(
        children: [
          // Cabeçalho da tabela
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: _kAzul,
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: const Row(
              children: [
                SizedBox(width: 44), // espaço do avatar
                SizedBox(width: 14),
                Expanded(
                    flex: 3,
                    child: Text('Referência / Cliente',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700))),
                Expanded(
                    flex: 2,
                    child: Text('Status',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700))),
                Expanded(
                    flex: 2,
                    child: Text('Total',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700))),
                Expanded(
                    flex: 2,
                    child: Text('Validade',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700))),
                SizedBox(width: 120),

              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
              itemCount: lista.length,
              itemBuilder: (_, i) => _LinhaCotacao(
  cotacao: lista[i],
  isAlternate: i.isOdd,
  onAbrirDetalhe: onAbrirDetalhe,
  onCancelar: onCancelar,
),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Badge de Status
// ─────────────────────────────────────────────────────────────────────────────

class _BadgeStatus extends StatelessWidget {
  final String status;
  const _BadgeStatus({required this.status});

  @override
  Widget build(BuildContext context) {
    final cor = _corStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _labelStatus(status),
        style: TextStyle(
          fontSize: 11,
          color: cor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Diálogo de Confirmação reutilizável
// ─────────────────────────────────────────────────────────────────────────────

class _DialogoConfirmacao extends StatelessWidget {
  final String titulo;
  final String mensagem;
  final Color corBotao;
  final String labelBotao;

  const _DialogoConfirmacao({
    required this.titulo,
    required this.mensagem,
    required this.corBotao,
    required this.labelBotao,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(titulo,
          style: const TextStyle(
              fontWeight: FontWeight.w700, color: _kAzul, fontSize: 17)),
      content: Text(mensagem,
          style: const TextStyle(fontSize: 14, color: _kCinzaTexto)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child:
              const Text('Cancelar', style: TextStyle(color: _kCinzaTexto)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: corBotao,
            foregroundColor: _kBranco,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(labelBotao),
        ),
      ],
    );
  }
}

  bool _cotacaoEhSingular(CotacaoModel c) {
  return (c.nomeCliente == null || c.nomeCliente!.trim().isEmpty) &&
      ((c.nomeClienteSingular != null &&
              c.nomeClienteSingular!.trim().isNotEmpty) ||
          (c.apelidoClienteSingular != null &&
              c.apelidoClienteSingular!.trim().isNotEmpty));
}

// ─────────────────────────────────────────────────────────────────────────────
//  Linha de Cotação
// ─────────────────────────────────────────────────────────────────────────────

class _LinhaCotacao extends StatelessWidget {
  const _LinhaCotacao({
    required this.cotacao,
    required this.isAlternate,
    required this.onAbrirDetalhe,
    required this.onCancelar,
  });

  final CotacaoModel cotacao;
  final bool isAlternate;
  final void Function(CotacaoModel) onAbrirDetalhe;
  final Future<void> Function(CotacaoModel) onCancelar;

  @override
  Widget build(BuildContext context) {
final nomeCliente = _nomeClienteCotacao(cotacao);

    return InkWell(
      onTap: () => onAbrirDetalhe(cotacao),
      child: Container(
        decoration: BoxDecoration(
          color: isAlternate ? const Color(0xFFF0F2FA) : Colors.white,
          border: const Border(
            bottom: BorderSide(color: Color(0xFFE8EAF0)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 18,
                backgroundColor: _kAzul.withOpacity(0.12),
                child: const Icon(Icons.check_circle_outline,
                    size: 18, color: _kAzul),
              ),
              const SizedBox(width: 14),

              // Referência + cliente
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cotacao.referencia,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _kAzul,
                      ),
                    ),
                    const SizedBox(height: 2),
               Row(
  children: [
    Expanded(
      child: Text(
        nomeCliente,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          color: _kCinzaTexto,
        ),
      ),
    ),
    if (_cotacaoEhSingular(cotacao)) ...[
      const SizedBox(width: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: _kCinzaTexto.withOpacity(0.10),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'Singular',
          style: TextStyle(
            fontSize: 9,
            color: _kCinzaTexto,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  ],
),
                  ],
                ),
              ),

              // Status
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _BadgeStatus(status: cotacao.statusCotacao),
                ),
              ),

              // Total
              Expanded(
                flex: 2,
                child: Text(
                  _formatarTotal(cotacao.total),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kAzul,
                  ),
                ),
              ),

              // Validade
              Expanded(
                flex: 2,
                child: Row(children: [
                  const Icon(Icons.event_outlined,
                      size: 13, color: _kCinzaTexto),
                  const SizedBox(width: 4),
                  Text(
                    _formatarData(cotacao.validadeAte),
                    style: const TextStyle(
                        fontSize: 12, color: _kCinzaTexto),
                  ),
                ]),
              ),

              // Ações
              // Ações
SizedBox(
  width: 128,
  child: Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      // ── PDF ──
      Tooltip(
        message: 'Gerar PDF',
        child: _BotaoPdfCotacao(cotacao: cotacao),
      ),
      const SizedBox(width: 6),
      // ── Detalhes ──
      Tooltip(
        message: 'Detalhes',
        child: InkWell(
          onTap: () => onAbrirDetalhe(cotacao),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _kAzul.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.visibility_outlined,
                size: 16, color: _kAzul),
          ),
        ),
      ),
      // ── Remover ──
// ── Cancelar ──
if (!['CONVERTIDA', 'CANCELADA', 'EXPIRADA']
    .contains(cotacao.statusCotacao)) ...[
  const SizedBox(width: 6),
  Tooltip(
    message: 'Cancelar cotação',
    child: InkWell(
      onTap: () => onCancelar(cotacao),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: _kVermelho.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(
          Icons.cancel_outlined,
          size: 16,
          color: _kVermelho,
        ),
      ),
    ),
  ),
],
    ],
  ),
),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Botão PDF da Cotação
// ─────────────────────────────────────────────────────────────────────────────

class _BotaoPdfCotacao extends StatefulWidget {
  final CotacaoModel cotacao;
  const _BotaoPdfCotacao({required this.cotacao});

  @override
  State<_BotaoPdfCotacao> createState() => _BotaoPdfCotacaoState();
}

class _BotaoPdfCotacaoState extends State<_BotaoPdfCotacao> {
  bool _gerando = false;

Future<void> _gerarPdf() async {
  if (_gerando) return;
  setState(() => _gerando = true);
  try {
    ClienteModel? cliente;
    if (widget.cotacao.idCliente != null) {
      cliente = await context
          .read<ClienteListaProvider>()
          .buscarPorId(widget.cotacao.idCliente!);
    }

    final file = await CotacaoPdfService.instance.gerarCotacao(
      widget.cotacao,
      cliente: cliente,
    );
    if (!mounted) return;
    await CotacaoPdfService.instance.abrirPdf(file);
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Erro ao gerar PDF: $e'),
        backgroundColor: _kVermelho,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  } finally {
    if (mounted) setState(() => _gerando = false);
  }
}


  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _gerarPdf,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: _kVerde.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: _gerando
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _kVerde,
                ),
              )
            : const Icon(Icons.picture_as_pdf_outlined,
                size: 16, color: _kVerde),
      ),
    );
  }
}