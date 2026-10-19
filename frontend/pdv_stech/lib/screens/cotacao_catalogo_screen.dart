// lib/screens/cotacao_catalogo_screen.dart

import 'package:flutter/material.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:api_compartilhado/api_config.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_sidebar.dart';
import 'cotacao_detalhes_produto.dart';
import 'cotacao_detalhes_servico.dart';
import 'cotacoes_abertas_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// CORES
// ═══════════════════════════════════════════════════════════════════════════
// As antigas constantes (_kPrimary, _kAccent, _kBackground) foram
// substituídas pelo tema:
//   _kPrimary    → context.cores.marca (texto/ícone/borda)
//                  context.cores.marcaBotao (fundo de botão/chip activo)
//                  AppColors.azulMarca / azulMarcaEscuro (AppBar)
//   _kAccent     → AppColors.vermelhoMarca (fundo: badge, indicador da aba;
//                  texto branco por cima)
//                  context.cores.acentoTexto (vermelho como texto/ícone/spinner)
//   _kBackground → context.cores.fundo
//   Colors.red / green / blue / grey → perigo / sucesso / info / textoSecundario /
//                  desactivado (variantes legíveis nos dois temas)

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
    final c = context.cores;

    return Scaffold(
      backgroundColor: c.fundo,
      drawer: const AppSidebar(currentRoute: '/criar_cotacao'),
      appBar: AppBar(
        // Mesmo critério da AppBar do tema escuro (azulMarcaEscuro).
        backgroundColor:
            context.escuro ? AppColors.azulMarcaEscuro : AppColors.azulMarca,
        foregroundColor: AppColors.branco,
        elevation: 0,
        title: const Text(
          'Catálogo — Cotação',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        actions: const [_BadgeCotacoesAbertas()],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.vermelhoMarca,
          indicatorWeight: 3,
          labelColor: AppColors.branco,
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

    final c = context.cores;
    final provider = context.watch<ProdutoProvider>();

    if (!provider.isLoading && provider.errorMessage == null) {
      _todos = provider.produtosAtivos;
      _aplicarFiltros();
    }

    return Scaffold(
      backgroundColor: c.fundo,
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
    final c = context.cores;

    return Container(
      color: c.marca.withValues(alpha: context.escuro ? 0.08 : 0.04),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Pesquisar produto…',
              prefixIcon: Icon(Icons.search, color: c.marca),
              suffixIcon: _buscaNome.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() { _buscaNome = ''; _aplicarFiltros(); });
                      })
                  : null,
              filled: true,
              fillColor: c.superficie,
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
              style: TextStyle(fontSize: 11, color: c.textoSecundario),
            ),
          ),
        ],
      ),
    );
  }

  // ── Lista ──────────────────────────────────────────────────────────────
  Widget _buildLista(ProdutoProvider provider) {
    final c = context.cores;

    if (provider.isLoading) {
      return Center(child: CircularProgressIndicator(color: c.marca));
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
      color: c.acentoTexto,
      backgroundColor: c.superficie,
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
    final c = context.cores;

    return Container(
      color: c.marca.withValues(alpha: context.escuro ? 0.08 : 0.04),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Pesquisar serviço…',
              prefixIcon: Icon(Icons.search, color: c.marca),
              suffixIcon: _buscaNomeServ.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() { _buscaNomeServ = ''; _aplicarFiltros(); });
                      })
                  : null,
              filled: true,
              fillColor: c.superficie,
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
              style: TextStyle(fontSize: 11, color: c.textoSecundario),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final c = context.cores;
    final provider = context.watch<ServicoProvider>();

    if (!provider.isLoading && provider.errorMessage == null) {
      _todos = provider.servicos;
      _aplicarFiltros();
    }

    return Scaffold(
      backgroundColor: c.fundo,
      body: Column(
        children: [
          _buildFiltros(),
          Expanded(child: _buildLista(provider)),
        ],
      ),
    );
  }

  Widget _buildLista(ServicoProvider provider) {
    final c = context.cores;

    if (provider.isLoading) {
      return Center(child: CircularProgressIndicator(color: c.marca));
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
      color: c.acentoTexto,
      backgroundColor: c.superficie,
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
              style: const TextStyle(fontSize: 10, color: AppColors.branco),
            ),
            backgroundColor: AppColors.vermelhoMarca,
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
    final c = context.cores;
    final temPromo = produto.precoPromocional != null;

    return Container(
      decoration: BoxDecoration(
        color: isAlternate ? c.linhaAlternada : c.superficie,
        border: Border(bottom: BorderSide(color: c.borda, width: 1)),
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
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.marca),
                ),
              ),
              Expanded(
                flex: 2,
                child: temPromo
                    ? Text(
                        currencyFmt.format(produto.precoPromocional),
                        style: TextStyle(fontSize: 12, color: c.acentoTexto, fontWeight: FontWeight.w700),
                      )
                    : Text(
                        currencyFmt.format(produto.preco),
                        style: TextStyle(fontSize: 12, color: c.marca, fontWeight: FontWeight.w500),
                      ),
              ),
              Expanded(
                flex: 2,
                child: Row(children: [
                  Icon(Icons.inventory_2_outlined, size: 14, color: c.sucesso),
                  const SizedBox(width: 4),
                  Text('${produto.quantidadeEstoque}',
                      style: TextStyle(fontSize: 12, color: c.textoSecundario)),
                ]),
              ),
              SizedBox(
                width: 80,
                child: TextButton(
                  onPressed: onTap,
                  style: TextButton.styleFrom(
                    backgroundColor: c.marcaBotao,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Adicionar',
                      style: TextStyle(color: AppColors.branco, fontSize: 11, fontWeight: FontWeight.w600)),
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
    final c = context.cores;

    return Container(
      decoration: BoxDecoration(
        color: isAlternate ? c.linhaAlternada : c.superficie,
        border: Border(bottom: BorderSide(color: c.borda, width: 1)),
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
                        color: c.marca.withValues(alpha: context.escuro ? 0.16 : 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.miscellaneous_services, size: 16, color: c.marca),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        servico.nomeServico,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.marca),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  currencyFmt.format(servico.precoUnitario),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.marca),
                ),
              ),
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: c.infoFundo,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: c.info.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    servico.unidade,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: c.info, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              SizedBox(
                width: 80,
                child: TextButton(
                  onPressed: onTap,
                  style: TextButton.styleFrom(
                    backgroundColor: c.marcaBotao,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Adicionar',
                      style: TextStyle(color: AppColors.branco, fontSize: 11, fontWeight: FontWeight.w600)),
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
    final c = context.cores;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 56, color: c.perigo),
            const SizedBox(height: 12),
            Text(mensagem, textAlign: TextAlign.center, style: TextStyle(color: c.perigo)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(backgroundColor: c.marcaBotao),
              icon: const Icon(Icons.refresh, color: AppColors.branco),
              label: const Text('Tentar Novamente', style: TextStyle(color: AppColors.branco)),
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
    final c = context.cores;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icone, size: 72, color: c.desactivado),
          const SizedBox(height: 12),
          Text(mensagem, style: TextStyle(fontSize: 16, color: c.textoSecundario)),
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
    final c = context.cores;
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
          color: ativo ? c.marcaBotao : c.superficie,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ativo ? c.marcaBotao : c.borda),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.tune, size: 15, color: ativo ? AppColors.branco : c.textoSecundario),
          const SizedBox(width: 5),
          Text(
            ativo ? '${fmt.format(safeMin)} – ${fmt.format(safeMax)}' : 'Faixa de Preço',
            style: TextStyle(
              fontSize: 12,
              color: ativo ? AppColors.branco : c.textoSecundario,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (ativo) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => onChanged(0, precoMaxAbsoluto),
              child: const Icon(Icons.close, size: 13, color: AppColors.branco),
            ),
          ],
        ]),
      ),
    );
  }

  void _abrirModal(BuildContext context) {
    final c = context.cores;

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
                Text('Faixa de Preço',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.marca)),
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
                  activeColor: c.marca,
                  inactiveColor: c.marca.withValues(alpha: 0.15),
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
                    style: ElevatedButton.styleFrom(backgroundColor: c.marcaBotao),
                    onPressed: () {
                      onChanged(tempMin, tempMax);
                      Navigator.pop(ctx);
                    },
                    child: const Text('Aplicar', style: TextStyle(color: AppColors.branco)),
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