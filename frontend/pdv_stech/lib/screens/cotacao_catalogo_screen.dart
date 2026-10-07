// lib/screens/cotacao_catalogo_screen.dart

import 'package:flutter/material.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:api_compartilhado/api_config.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../widgets/app_sidebar.dart';
import 'cotacao_detalhes_produto.dart';
import 'cotacao_detalhes_servico.dart';
import 'cotacoes_abertas_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// CONSTANTES DE CORES
// ═══════════════════════════════════════════════════════════════════════════

const _kPrimary    = Color(0xFF1B2A6B);
const _kAccent     = Color(0xFFC8102E);
const _kBackground = Color(0xFFF4F5F7);

// ═══════════════════════════════════════════════════════════════════════════
// TELA PRINCIPAL
// ═══════════════════════════════════════════════════════════════════════════

class CotacaoCatalogoScreen extends StatefulWidget {
  const CotacaoCatalogoScreen({Key? key}) : super(key: key);

  @override
  State<CotacaoCatalogoScreen> createState() => _CotacaoCatalogoScreenState();
}

class _CotacaoCatalogoScreenState extends State<CotacaoCatalogoScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackground,
      drawer: const AppSidebar(currentRoute: '/criar_cotacao'),
      appBar: AppBar(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Catálogo — Cotação',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        actions: const [_BadgeCotacoesAbertas()],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _kAccent,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Produtos'),
            Tab(icon: Icon(Icons.miscellaneous_services_outlined), text: 'Serviços'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ProdutosTab(),
          _ServicosTab(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ABA DE PRODUTOS
// ═══════════════════════════════════════════════════════════════════════════

class _ProdutosTab extends StatefulWidget {
  const _ProdutosTab();

  @override
  State<_ProdutosTab> createState() => _ProdutosTabState();
}

class _ProdutosTabState extends State<_ProdutosTab>
    with AutomaticKeepAliveClientMixin {
  final _searchCtrl = TextEditingController();
  final _currencyFmt = NumberFormat.currency(locale: 'pt_PT', symbol: 'MZN');

  List<ProdutoModel> _todos     = [];
  List<ProdutoModel> _filtrados = [];

  String _buscaNome = '';
  double _precoMin  = 0;
  double _precoMax  = 999999;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProdutoProvider>().listarAtivos();
    });
    _searchCtrl.addListener(() {
      setState(() {
        _buscaNome = _searchCtrl.text.toLowerCase();
        _aplicarFiltros();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _aplicarFiltros() {
    _filtrados = _todos.where((p) {
      final matchNome  = p.nomeProduto.toLowerCase().contains(_buscaNome);
      final matchPreco = p.precoEfectivo >= _precoMin && p.precoEfectivo <= _precoMax;
      return matchNome && matchPreco;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final provider = context.watch<ProdutoProvider>();

    if (!provider.isLoading && provider.errorMessage == null) {
      _todos = provider.produtosAtivos;
      _aplicarFiltros();
    }

    return Scaffold(
      backgroundColor: _kBackground,
      body: Column(
        children: [
          _buildFiltros(),
          Expanded(child: _buildLista(provider)),
        ],
      ),
    );
  }

  // ── Painel de Filtros ──────────────────────────────────────────────────
  Widget _buildFiltros() {
    return Container(
      color: _kPrimary.withOpacity(0.04),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Pesquisar produto…',
              prefixIcon: const Icon(Icons.search, color: _kPrimary),
              suffixIcon: _buscaNome.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() { _buscaNome = ''; _aplicarFiltros(); });
                      })
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) => setState(() { _buscaNome = v.toLowerCase(); _aplicarFiltros(); }),
          ),
          const SizedBox(height: 8),
          _FiltroPrecoRow(
            precoMin: _precoMin,
            precoMax: _precoMax,
            precoMaxAbsoluto: _todos.isEmpty
                ? 999999
                : _todos.map((p) => p.precoEfectivo).reduce((a, b) => a > b ? a : b),
            onChanged: (min, max) =>
                setState(() { _precoMin = min; _precoMax = max; _aplicarFiltros(); }),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_filtrados.length} produto(s) encontrado(s)',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Lista ──────────────────────────────────────────────────────────────
  Widget _buildLista(ProdutoProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator(color: _kPrimary));
    }
    if (provider.errorMessage != null) {
      return _ErroWidget(
        mensagem: provider.errorMessage!,
        onRetry: () => context.read<ProdutoProvider>().listarAtivos(),
      );
    }
    if (_filtrados.isEmpty) {
      return _VazioWidget(
        icone: Icons.inventory_2_outlined,
        mensagem: _todos.isEmpty
            ? 'Nenhum produto cadastrado'
            : 'Nenhum produto corresponde ao filtro',
      );
    }

    return RefreshIndicator(
      color: _kAccent,
      onRefresh: () => context.read<ProdutoProvider>().listarAtivos(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
        itemCount: _filtrados.length,
        itemBuilder: (_, i) {
          final produto = _filtrados[i];
          return _ProdutoLinhaTabela(
            produto: produto,
            currencyFmt: _currencyFmt,
            isAlternate: i.isOdd,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CotacaoDetalhesProdutoScreen(produto: produto),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ABA DE SERVIÇOS
// ═══════════════════════════════════════════════════════════════════════════

class _ServicosTab extends StatefulWidget {
  const _ServicosTab();

  @override
  State<_ServicosTab> createState() => _ServicosTabState();
}

class _ServicosTabState extends State<_ServicosTab>
    with AutomaticKeepAliveClientMixin {
  final _searchCtrl = TextEditingController();
  final _currencyFmt = NumberFormat.currency(locale: 'pt_PT', symbol: 'MZN');

  List<ServicoModel> _filtrados = [];
  List<ServicoModel> _todos     = [];

  String _buscaNomeServ = '';
  double _precoMinServ  = 0;
  double _precoMaxServ  = 999999;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ServicoProvider>().carregarServicosAtivos();
    });
    _searchCtrl.addListener(() {
      setState(() {
        _buscaNomeServ = _searchCtrl.text.toLowerCase();
        _aplicarFiltros();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _aplicarFiltros() {
    _filtrados = _todos.where((s) {
      final matchNome  = s.nomeServico.toLowerCase().contains(_buscaNomeServ);
      final matchPreco = s.precoUnitario >= _precoMinServ && s.precoUnitario <= _precoMaxServ;
      return matchNome && matchPreco;
    }).toList();
  }

  Widget _buildFiltros() {
    return Container(
      color: _kPrimary.withOpacity(0.04),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Pesquisar serviço…',
              prefixIcon: const Icon(Icons.search, color: _kPrimary),
              suffixIcon: _buscaNomeServ.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() { _buscaNomeServ = ''; _aplicarFiltros(); });
                      })
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) => setState(() { _buscaNomeServ = v.toLowerCase(); _aplicarFiltros(); }),
          ),
          const SizedBox(height: 8),
          _FiltroPrecoRow(
            precoMin: _precoMinServ,
            precoMax: _precoMaxServ,
            precoMaxAbsoluto: _todos.isEmpty
                ? 999999
                : _todos.map((s) => s.precoUnitario).reduce((a, b) => a > b ? a : b),
            onChanged: (min, max) =>
                setState(() { _precoMinServ = min; _precoMaxServ = max; _aplicarFiltros(); }),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_filtrados.length} serviço(s) encontrado(s)',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final provider = context.watch<ServicoProvider>();

    if (!provider.isLoading && provider.errorMessage == null) {
      _todos = provider.servicos;
      _aplicarFiltros();
    }

    return Scaffold(
      backgroundColor: _kBackground,
      body: Column(
        children: [
          _buildFiltros(),
          Expanded(child: _buildLista(provider)),
        ],
      ),
    );
  }

  Widget _buildLista(ServicoProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator(color: _kPrimary));
    }
    if (provider.errorMessage != null) {
      return _ErroWidget(
        mensagem: provider.errorMessage!,
        onRetry: () => context.read<ServicoProvider>().carregarServicosAtivos(),
      );
    }
    if (_filtrados.isEmpty) {
      return _VazioWidget(
        icone: Icons.miscellaneous_services_outlined,
        mensagem: _todos.isEmpty
            ? 'Nenhum serviço cadastrado'
            : 'Nenhum serviço corresponde ao filtro',
      );
    }

    return RefreshIndicator(
      color: _kAccent,
      onRefresh: () => context.read<ServicoProvider>().carregarServicosAtivos(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
        itemCount: _filtrados.length,
        itemBuilder: (_, i) {
          final servico = _filtrados[i];
          return _ServicoLinhaTabela(
            servico: servico,
            currencyFmt: _currencyFmt,
            isAlternate: i.isOdd,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CotacaoDetalhesServicoScreen(servico: servico),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BADGE — Cotações abertas
// ═══════════════════════════════════════════════════════════════════════════

class _BadgeCotacoesAbertas extends StatefulWidget {
  const _BadgeCotacoesAbertas();

  @override
  State<_BadgeCotacoesAbertas> createState() => _BadgeCotacoesAbertasState();
}

class _BadgeCotacoesAbertasState extends State<_BadgeCotacoesAbertas> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CotacaoProvider>().listarPorStatus('ABERTA');
    });
  }

  @override
  Widget build(BuildContext context) {
    final cotacoes = context.watch<CotacaoProvider>().cotacoes;

    return ValueListenableBuilder<CotacaoModel?>(
      valueListenable: CotacaoAtivaController.instance.cotacaoAtiva,
      builder: (_, cotacaoAtiva, __) {
        var count = cotacoes.length;

        final ativaJaEstaNaLista = cotacaoAtiva == null
            ? true
            : cotacoes.any((c) => c.idCotacao == cotacaoAtiva.idCotacao);

        if (cotacaoAtiva != null &&
            cotacaoAtiva.estaAberta &&
            !ativaJaEstaNaLista) {
          count++;
        }

        return IconButton(
          tooltip: 'Cotações Abertas',
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CotacoesAbertasScreen(),
              ),
            );

            if (mounted) {
              context.read<CotacaoProvider>().listarPorStatus('ABERTA');
            }
          },
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text(
              count > 99 ? '99+' : '$count',
              style: const TextStyle(fontSize: 10, color: Colors.white),
            ),
            backgroundColor: _kAccent,
            child: const Icon(Icons.request_quote_outlined),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LINHAS DE TABELA
// ═══════════════════════════════════════════════════════════════════════════

class _ProdutoLinhaTabela extends StatelessWidget {
  const _ProdutoLinhaTabela({
    required this.produto,
    required this.currencyFmt,
    required this.isAlternate,
    required this.onTap,
  });

  final ProdutoModel produto;
  final NumberFormat currencyFmt;
  final bool isAlternate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final temPromo = produto.precoPromocional != null;

    return Container(
      decoration: BoxDecoration(
        color: isAlternate ? const Color(0xFFF0F2FA) : Colors.white,
        border: const Border(bottom: BorderSide(color: Color(0xFFE8EAF0), width: 1)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  produto.nomeProduto,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kPrimary),
                ),
              ),
              Expanded(
                flex: 2,
                child: temPromo
                    ? Text(
                        currencyFmt.format(produto.precoPromocional),
                        style: const TextStyle(fontSize: 12, color: _kAccent, fontWeight: FontWeight.w700),
                      )
                    : Text(
                        currencyFmt.format(produto.preco),
                        style: const TextStyle(fontSize: 12, color: _kPrimary, fontWeight: FontWeight.w500),
                      ),
              ),
              Expanded(
                flex: 2,
                child: Row(children: [
                  Icon(Icons.inventory_2_outlined, size: 14, color: Colors.green[600]),
                  const SizedBox(width: 4),
                  Text('${produto.quantidadeEstoque}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                ]),
              ),
              SizedBox(
                width: 80,
                child: TextButton(
                  onPressed: onTap,
                  style: TextButton.styleFrom(
                    backgroundColor: _kPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Adicionar',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServicoLinhaTabela extends StatelessWidget {
  const _ServicoLinhaTabela({
    required this.servico,
    required this.currencyFmt,
    required this.isAlternate,
    required this.onTap,
  });

  final ServicoModel servico;
  final NumberFormat currencyFmt;
  final bool isAlternate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isAlternate ? const Color(0xFFF0F2FA) : Colors.white,
        border: const Border(bottom: BorderSide(color: Color(0xFFE8EAF0), width: 1)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _kPrimary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.miscellaneous_services, size: 16, color: _kPrimary),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        servico.nomeServico,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  currencyFmt.format(servico.precoUnitario),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kPrimary),
                ),
              ),
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    servico.unidade,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: Colors.blue[700], fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              SizedBox(
                width: 80,
                child: TextButton(
                  onPressed: onTap,
                  style: TextButton.styleFrom(
                    backgroundColor: _kPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Adicionar',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGETS REUTILIZÁVEIS
// ═══════════════════════════════════════════════════════════════════════════

class _ErroWidget extends StatelessWidget {
  const _ErroWidget({required this.mensagem, required this.onRetry});
  final String mensagem;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.red),
            const SizedBox(height: 12),
            Text(mensagem, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(backgroundColor: _kPrimary),
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text('Tentar Novamente', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _VazioWidget extends StatelessWidget {
  const _VazioWidget({required this.icone, required this.mensagem});
  final IconData icone;
  final String mensagem;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icone, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(mensagem, style: TextStyle(fontSize: 16, color: Colors.grey[500])),
        ],
      ),
    );
  }
}

// ─── Filtro de preço compacto (igual ao de catalogo_screen.dart) ──────────────

class _FiltroPrecoRow extends StatelessWidget {
  const _FiltroPrecoRow({
    required this.precoMin,
    required this.precoMax,
    required this.precoMaxAbsoluto,
    required this.onChanged,
  });

  final double precoMin;
  final double precoMax;
  final double precoMaxAbsoluto;
  final void Function(double min, double max) onChanged;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.compactCurrency(locale: 'pt_PT', symbol: 'MZN');

    final safeMin = precoMin.clamp(0.0, precoMaxAbsoluto);
    final safeMax = precoMax.clamp(safeMin, precoMaxAbsoluto);
    final ativo = safeMin > 0 || safeMax < precoMaxAbsoluto;

    return GestureDetector(
      onTap: () => _abrirModal(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: ativo ? _kPrimary : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ativo ? _kPrimary : Colors.grey.shade300),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.tune, size: 15, color: ativo ? Colors.white : Colors.grey[600]),
          const SizedBox(width: 5),
          Text(
            ativo ? '${fmt.format(safeMin)} – ${fmt.format(safeMax)}' : 'Faixa de Preço',
            style: TextStyle(
              fontSize: 12,
              color: ativo ? Colors.white : Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          if (ativo) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => onChanged(0, precoMaxAbsoluto),
              child: const Icon(Icons.close, size: 13, color: Colors.white),
            ),
          ],
        ]),
      ),
    );
  }

  void _abrirModal(BuildContext context) {
    double tempMin = precoMin.clamp(0.0, precoMaxAbsoluto);
    double tempMax = precoMax.clamp(tempMin, precoMaxAbsoluto);

    if (precoMaxAbsoluto <= 0) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      useSafeArea: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) {
          final fmt2 = NumberFormat.currency(locale: 'pt_PT', symbol: 'MZN');
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Faixa de Preço',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kPrimary)),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(fmt2.format(tempMin), style: const TextStyle(fontSize: 12)),
                  Text(fmt2.format(tempMax), style: const TextStyle(fontSize: 12)),
                ]),
                RangeSlider(
                  values: RangeValues(tempMin, tempMax),
                  min: 0,
                  max: precoMaxAbsoluto,
                  divisions: precoMaxAbsoluto > 0
                      ? (precoMaxAbsoluto / 100).ceil().clamp(1, 100)
                      : 1,
                  activeColor: _kPrimary,
                  inactiveColor: _kPrimary.withOpacity(0.15),
                  onChanged: (v) {
                    setModal(() {
                      tempMin = v.start;
                      tempMax = v.end;
                    });
                  },
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: _kPrimary),
                    onPressed: () {
                      onChanged(tempMin, tempMax);
                      Navigator.pop(ctx);
                    },
                    child: const Text('Aplicar', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}