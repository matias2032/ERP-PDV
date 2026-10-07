import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import '../widgets/app_sidebar.dart';
import 'package:http/http.dart' as http;
import 'package:api_compartilhado/api_config.dart';

// ── Cores STech Engenharia ────────────────────────────────────────────────────
const _kVermelho = Color(0xFFC8102E);
const _kAzul = Color(0xFF1B2A6B);
const _kBranco = Colors.white;
const _kCinzaClaro = Color(0xFFF4F5F7);
const _kCinzaTexto = Color(0xFF6B7280);

enum _FiltroCredito {
  todos,
  pendente,
  parcial,
  pago,
  vencido,
}

class PedidosCreditoScreen extends StatefulWidget {
  const PedidosCreditoScreen({super.key});

  @override
  State<PedidosCreditoScreen> createState() => _PedidosCreditoScreenState();
}

class _PedidosCreditoScreenState extends State<PedidosCreditoScreen> {
  final _searchController = TextEditingController();
  final _currencyFmt = NumberFormat.currency(locale: 'pt_PT', symbol: 'MZN');

  _FiltroCredito _filtro = _FiltroCredito.todos;
  String _termo = '';
  String? _erroLocal;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _carregar();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() => _erroLocal = null);

    await context.read<PedidoProvider>().listarEmDivida();

    if (mounted) {
      setState(() {
        _erroLocal = context.read<PedidoProvider>().errorMessage;
      });
    }
  }

  void _onPesquisar(String termo) {
    setState(() => _termo = termo.trim().toLowerCase());
  }

  void _limparPesquisa() {
    _searchController.clear();
    setState(() => _termo = '');
  }

  void _alterarFiltro(_FiltroCredito filtro) {
    setState(() => _filtro = filtro);
  }

  Future<void> _abrirDetalhes(PedidoModel pedido) async {
    final resultado = await Navigator.of(context).pushNamed(
      '/pedidos_credito/detalhes',
      arguments: pedido,
    );

    if (resultado == true && mounted) {
      await _carregar();
    }
  }

  Future<bool> _confirmarEntradaEdicaoCredito(PedidoModel pedido) async {
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Text(
            'Editar dívida',
            style: TextStyle(
              color: _kAzul,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pedido.referencia,
                style: const TextStyle(
                  color: _kAzul,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Vai entrar no modo de edição deste pedido a crédito.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              const Text(
                'Todos os produtos ou serviços adicionados no catálogo serão anexados a esta dívida.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.amber.withOpacity(0.35),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Use esta opção apenas quando quiser acrescentar novos itens à dívida.',
                        style: TextStyle(
                          fontSize: 12,
                          color: _kCinzaTexto,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Entrar em edição'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[700],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ) ??
      false;
}

Future<void> _editarPedidoCredito(PedidoModel pedido) async {
  final confirmar = await _confirmarEntradaEdicaoCredito(pedido);

  if (!confirmar) return;

  final provider = context.read<PedidoProvider>();

  // Busca versão completa/actualizada com itens
  final atualizado = await provider.buscarPorId(pedido.idPedido);
  final pedidoParaEditar = atualizado ?? pedido;

  provider.definirPedidoActual(pedidoParaEditar);
  PedidoAtivoController.instance.definirEdicaoCredito(pedidoParaEditar);

  await Navigator.of(context).pushNamed('/catalogo');

  if (!mounted) return;

  await _carregar();
}



  List<PedidoModel> _filtrar(List<PedidoModel> pedidos) {
    var lista = pedidos.where((p) => p.ehCredito).toList();

    if (_termo.isNotEmpty) {
      lista = lista.where((p) {
        final ref = p.referencia.toLowerCase();
        final idCliente = p.idCliente?.toString() ?? '';
        final idPedido = p.idPedido.toString();

        return ref.contains(_termo) ||
            idCliente.contains(_termo) ||
            idPedido.contains(_termo);
      }).toList();
    }

    switch (_filtro) {
      case _FiltroCredito.todos:
        break;

      case _FiltroCredito.pendente:
        lista = lista.where((p) => p.statusPagamento == 'PENDENTE').toList();

      case _FiltroCredito.parcial:
        lista = lista.where((p) => p.statusPagamento == 'PARCIAL').toList();

      case _FiltroCredito.pago:
        lista = lista.where((p) => p.statusPagamento == 'PAGO').toList();

      case _FiltroCredito.vencido:
        lista = lista.where(_pedidoVencido).toList();
    }

    lista.sort((a, b) {
      final av = _pedidoVencido(a) ? 1 : 0;
      final bv = _pedidoVencido(b) ? 1 : 0;

      if (av != bv) return bv.compareTo(av);

      final ad = a.dataAberturaCredito ?? a.dataPedido;
      final bd = b.dataAberturaCredito ?? b.dataPedido;

      return bd.compareTo(ad);
    });

    return lista;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PedidoProvider>();
    final pedidos = _filtrar(provider.pedidosEmDivida);

    return Scaffold(
      backgroundColor: _kCinzaClaro,
      appBar: _buildAppBar(),
      drawer: const AppSidebar(currentRoute: '/pedidos_credito'),
      body: Column(
        children: [
          _BarraPesquisa(
            controller: _searchController,
            total: pedidos.length,
            onChanged: _onPesquisar,
            onLimpar: _limparPesquisa,
          ),
          _FiltroStatus(
            filtro: _filtro,
            onChanged: _alterarFiltro,
          ),
          _ResumoDividas(
            pedidos: pedidos,
            currencyFmt: _currencyFmt,
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              color: _kAzul,
              onRefresh: _carregar,
              child:_ListagemDividas(
  pedidos: pedidos,
  carregando: provider.isLoading,
  erro: _erroLocal,
  currencyFmt: _currencyFmt,
  onRecarregar: _carregar,
  onDetalhes: _abrirDetalhes,
  onEditar: _editarPedidoCredito,
),
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
            child: const Icon(
              Icons.credit_score_rounded,
              color: _kBranco,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Pedidos a Crédito',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Recarregar',
          onPressed: _carregar,
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Barra de pesquisa
// ═════════════════════════════════════════════════════════════════════════════

class _BarraPesquisa extends StatelessWidget {
  final TextEditingController controller;
  final int total;
  final ValueChanged<String> onChanged;
  final VoidCallback onLimpar;

  const _BarraPesquisa({
    required this.controller,
    required this.total,
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
                hintText: 'Pesquisar por referência, ID do pedido ou cliente...',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: _kCinzaTexto,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: _kAzul,
                ),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: _kCinzaTexto,
                          size: 18,
                        ),
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
          Text(
            '$total dívida(s)',
            style: const TextStyle(
              fontSize: 13,
              color: _kCinzaTexto,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Filtros
// ═════════════════════════════════════════════════════════════════════════════

class _FiltroStatus extends StatelessWidget {
  final _FiltroCredito filtro;
  final ValueChanged<_FiltroCredito> onChanged;

  const _FiltroStatus({
    required this.filtro,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBranco,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _chip('Todos', _FiltroCredito.todos, Icons.list_alt_rounded),
            _chip('Pendentes', _FiltroCredito.pendente, Icons.schedule_rounded),
            _chip('Parciais', _FiltroCredito.parcial, Icons.paid_outlined),
            _chip('Vencidos', _FiltroCredito.vencido, Icons.warning_amber_rounded),
            _chip('Pagos', _FiltroCredito.pago, Icons.check_circle_outline_rounded),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, _FiltroCredito valor, IconData icon) {
    final ativo = filtro == valor;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: ativo,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: ativo ? _kBranco : _kCinzaTexto,
            ),
            const SizedBox(width: 5),
            Text(label),
          ],
        ),
        selectedColor: _kAzul,
        backgroundColor: _kCinzaClaro,
        labelStyle: TextStyle(
          color: ativo ? _kBranco : _kCinzaTexto,
          fontSize: 12,
          fontWeight: ativo ? FontWeight.w700 : FontWeight.w500,
        ),
        side: BorderSide(
          color: ativo ? _kAzul : const Color(0xFFE5E7EB),
        ),
        onSelected: (_) => onChanged(valor),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Resumo
// ═════════════════════════════════════════════════════════════════════════════

class _ResumoDividas extends StatelessWidget {
  final List<PedidoModel> pedidos;
  final NumberFormat currencyFmt;

  const _ResumoDividas({
    required this.pedidos,
    required this.currencyFmt,
  });

  @override
  Widget build(BuildContext context) {
    final totalFacturado = pedidos.fold<double>(
      0,
      (soma, p) => soma + p.total,
    );

    final totalPago = pedidos.fold<double>(
      0,
      (soma, p) => soma + p.valorPago,
    );

    final saldo = pedidos.fold<double>(
      0,
      (soma, p) => soma + p.saldoDevedorCalculado,
    );

    final vencidos = pedidos.where(_pedidoVencido).length;

    return Container(
      color: _kBranco,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: _ResumoCard(
              label: 'Facturado',
              valor: currencyFmt.format(totalFacturado),
              icon: Icons.receipt_long_rounded,
              cor: _kAzul,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ResumoCard(
              label: 'Pago',
              valor: currencyFmt.format(totalPago),
              icon: Icons.payments_rounded,
              cor: Colors.green,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ResumoCard(
              label: 'Saldo',
              valor: currencyFmt.format(saldo),
              icon: Icons.account_balance_wallet_outlined,
              cor: _kVermelho,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ResumoCard(
              label: 'Vencidos',
              valor: '$vencidos',
              icon: Icons.warning_amber_rounded,
              cor: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResumoCard extends StatelessWidget {
  final String label;
  final String valor;
  final IconData icon;
  final Color cor;

  const _ResumoCard({
    required this.label,
    required this.valor,
    required this.icon,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cor.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: cor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _kCinzaTexto,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  valor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cor,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Listagem
// ═════════════════════════════════════════════════════════════════════════════

class _ListagemDividas extends StatelessWidget {
  final List<PedidoModel> pedidos;
  final bool carregando;
  final String? erro;
  final NumberFormat currencyFmt;
  final Future<void> Function() onRecarregar;
  final Future<void> Function(PedidoModel) onDetalhes;
  final Future<void> Function(PedidoModel) onEditar;

const _ListagemDividas({
  required this.pedidos,
  required this.carregando,
  required this.erro,
  required this.currencyFmt,
  required this.onRecarregar,
  required this.onDetalhes,
  required this.onEditar,
});

  @override
  Widget build(BuildContext context) {
    if (carregando) {
      return const Center(
        child: CircularProgressIndicator(color: _kAzul),
      );
    }

    if (erro != null) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          const Icon(
            Icons.error_outline,
            color: _kVermelho,
            size: 48,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              erro!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kVermelho),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              onPressed: onRecarregar,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAzul,
                foregroundColor: _kBranco,
              ),
            ),
          ),
        ],
      );
    }

    if (pedidos.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Icon(
            Icons.credit_score_outlined,
            color: _kCinzaTexto,
            size: 52,
          ),
          SizedBox(height: 12),
          Center(
            child: Text(
              'Nenhuma dívida encontrada.',
              style: TextStyle(color: _kCinzaTexto),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: _kAzul,
            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: const Row(
            children: [
              SizedBox(width: 36),
              SizedBox(width: 14),
              Expanded(
                flex: 3,
                child: Text(
                  'Pedido / Cliente',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Factura',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Total / Pago',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Saldo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Estado',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
SizedBox(width: 130),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
            itemCount: pedidos.length,
      itemBuilder: (_, i) => _LinhaDivida(
  pedido: pedidos[i],
  isAlternate: i.isOdd,
  currencyFmt: currencyFmt,
  onDetalhes: onDetalhes,
  onEditar: onEditar,
),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Linha da dívida
// ═════════════════════════════════════════════════════════════════════════════

class _LinhaDivida extends StatefulWidget {
  final PedidoModel pedido;
  final bool isAlternate;
  final NumberFormat currencyFmt;
  final Future<void> Function(PedidoModel) onDetalhes;
  final Future<void> Function(PedidoModel) onEditar;

const _LinhaDivida({
  required this.pedido,
  required this.isAlternate,
  required this.currencyFmt,
  required this.onDetalhes,
  required this.onEditar,
});

  @override
  State<_LinhaDivida> createState() => _LinhaDividaState();
}

class _LinhaDividaState extends State<_LinhaDivida> {
  ClienteModel? _cliente;
  bool _carregandoCliente = false;

  PedidoModel get p => widget.pedido;

  @override
  void initState() {
    super.initState();
    _carregarCliente();
  }

  Future<void> _carregarCliente() async {
    if (_cliente != null || p.idCliente == null) return;

    setState(() => _carregandoCliente = true);

    try {
      final service = ClienteService(
        baseUrl: ApiConfig.baseUrl,
        httpClient: http.Client(),
      );

      final cliente = await service.buscarPorId(p.idCliente!);

      if (mounted) {
        setState(() => _cliente = cliente);
      }
    } catch (_) {
      // silencioso — mantém fallback para ID
    } finally {
      if (mounted) {
        setState(() => _carregandoCliente = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final saldo = p.saldoDevedorCalculado;
    final vencido = _pedidoVencido(p);
    final progresso =
        p.total <= 0 ? 0.0 : (p.valorPago / p.total).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: widget.isAlternate ? const Color(0xFFF0F2FA) : Colors.white,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE8EAF0)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _kAzul.withOpacity(0.12),
              child: const Icon(
                Icons.receipt_long_rounded,
                color: _kAzul,
                size: 18,
              ),
            ),
            const SizedBox(width: 14),

            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.referencia,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kAzul,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (_carregandoCliente)
                    const SizedBox(
                      height: 12,
                      width: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Text(
                      _cliente?.nomeCompleto ??
                          (p.idCliente != null
                              ? 'ID: ${p.idCliente}'
                              : 'Cliente não informado'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _kCinzaTexto,
                      ),
                    ),
                  const SizedBox(height: 4),
                  _MiniInfo(
                    icon: Icons.calendar_today_outlined,
                    label: _formatarData(
                      p.dataAberturaCredito ?? p.dataPedido,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              flex: 2,
              child: Text(
                p.idDocumentoFacturaCredito != null
                    ? 'Doc. #${p.idDocumentoFacturaCredito}'
                    : 'Pendente',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: p.idDocumentoFacturaCredito != null
                      ? _kAzul
                      : Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.currencyFmt.format(p.total),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _kAzul,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Pago: ${widget.currencyFmt.format(p.valorPago)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: _kCinzaTexto,
                    ),
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progresso,
                      minHeight: 5,
                      backgroundColor: _kCinzaClaro,
                      color: progresso >= 1 ? Colors.green : _kAzul,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              flex: 2,
              child: Text(
                widget.currencyFmt.format(saldo),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: saldo <= 0 ? Colors.green : _kVermelho,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),

            Expanded(
              flex: 2,
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  _BadgeStatus(
                    label: _statusLabel(p),
                    color: _statusColor(p),
                  ),
                  if (vencido)
                    const _BadgeStatus(
                      label: 'Vencido',
                      color: Colors.orange,
                    ),
                ],
              ),
            ),

            SizedBox(
  width: 130,
  child: Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      Tooltip(
        message: 'Editar pedido a crédito',
        child: InkWell(
          onTap: () => widget.onEditar(p),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.10),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.edit_outlined,
              size: 17,
              color: Colors.orange,
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Tooltip(
        message: 'Ver detalhes da dívida',
        child: InkWell(
          onTap: () => widget.onDetalhes(p),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _kAzul.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.visibility_outlined,
              size: 17,
              color: _kAzul,
            ),
          ),
        ),
      ),
    ],
  ),
),
          ],
        ),
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniInfo({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 11, color: _kCinzaTexto),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: _kCinzaTexto,
          ),
        ),
      ],
    );
  }
}

class _BadgeStatus extends StatelessWidget {
  final String label;
  final Color color;

  const _BadgeStatus({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Helpers
// ═════════════════════════════════════════════════════════════════════════════

bool _pedidoVencido(PedidoModel pedido) {
  if (pedido.pagamentoPago) return false;

  final vencimento = pedido.dataVencimentoCredito;
  if (vencimento == null) return false;

  final hoje = DateTime.now();
  final hojeLimpo = DateTime(hoje.year, hoje.month, hoje.day);
  final vencLimpo = DateTime(
    vencimento.year,
    vencimento.month,
    vencimento.day,
  );

  return vencLimpo.isBefore(hojeLimpo);
}

String _statusLabel(PedidoModel pedido) {
  switch (pedido.statusPagamento.toUpperCase()) {
    case 'PAGO':
      return 'Pago';
    case 'PARCIAL':
      return 'Parcial';
    case 'PENDENTE':
      return 'Pendente';
    default:
      return pedido.statusPagamento;
  }
}

Color _statusColor(PedidoModel pedido) {
  switch (pedido.statusPagamento.toUpperCase()) {
    case 'PAGO':
      return Colors.green;
    case 'PARCIAL':
      return _kAzul;
    case 'PENDENTE':
      return _kVermelho;
    default:
      return _kCinzaTexto;
  }
}

String _formatarData(DateTime? data) {
  if (data == null) return '—';
  return DateFormat('dd/MM/yyyy').format(data);
}