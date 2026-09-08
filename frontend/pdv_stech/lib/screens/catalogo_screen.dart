import 'package:flutter/material.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:api_compartilhado/api_config.dart';
import 'package:intl/intl.dart';
import '../widgets/app_sidebar.dart';
import 'detalhes_produto.dart';
import 'detalhes_servico.dart';
import 'pedidos_abertos.dart';
import 'package:provider/provider.dart';
import 'package:api_compartilhado/api_compartilhado.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTES DE CORES
// ═══════════════════════════════════════════════════════════════════════════════

const _kPrimary    = Color.fromARGB(255, 58, 62, 79);
const _kAccent     = Color(0xFFC8102E);
const _kBackground = Color(0xFFF4F5F7);
const _kCardBg     = Colors.white;

// ═══════════════════════════════════════════════════════════════════════════════
// TELA PRINCIPAL
// ═══════════════════════════════════════════════════════════════════════════════

class CatalogoScreen extends StatefulWidget {
  const CatalogoScreen({Key? key}) : super(key: key);

  @override
  State<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends State<CatalogoScreen>
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
      drawer: const AppSidebar(currentRoute: '/catalogo'),
     

appBar: AppBar(
  backgroundColor: _kPrimary,
  foregroundColor: Colors.white,
  elevation: 0,
  title: const Text(
    'Catálogo',
    style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
  ),
  actions: [
    _BadgePedidosAbertos(),
  ],
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
body: Column(
  children: [
    const _BannerEdicaoCredito(),
    Expanded(
      child: TabBarView(
        controller: _tabController,
        children: const [
          _ProdutosTab(),
          _ServicosTab(),
        ],
      ),
    ),
  ],
),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ABA DE PRODUTOS
// ═══════════════════════════════════════════════════════════════════════════════

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

 

  // filtros
  String _buscaNome   = '';
  double _precoMin    = 0;
  double _precoMax    = 999999;
  // IDs seleccionados (vindos de listas reais; aqui guardamos só os IDs)
  Set<int> _categoriasSel = {};
  Set<int> _marcasSel     = {};

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
      final matchNome = p.nomeProduto.toLowerCase().contains(_buscaNome);
      final matchPreco = p.precoEfectivo >= _precoMin && p.precoEfectivo <= _precoMax;
      final matchCat = _categoriasSel.isEmpty ||
          p.categorias.any((id) => _categoriasSel.contains(id));
      final matchMarca = _marcasSel.isEmpty ||
          p.marcas.any((id) => _marcasSel.contains(id));
      return matchNome && matchPreco && matchCat && matchMarca;
    }).toList();
  }

Future<void> _toggleStatus(ProdutoModel produto) async {
  final ok = await _confirmarDialog(
    context,
    titulo: '${produto.estaAtivo ? 'Desativar' : 'Ativar'} Produto',
    corpo: 'Deseja ${produto.estaAtivo ? 'desativar' : 'ativar'} "${produto.nomeProduto}"?',
    corBotao: produto.estaAtivo ? Colors.orange : Colors.green,
    labelBotao: produto.estaAtivo ? 'Desativar' : 'Ativar',
  );
  if (!ok) return;

  await context.read<ProdutoProvider>().toggleAtivo(produto.idProduto);

  if (!mounted) return;
  final provider = context.read<ProdutoProvider>();
  if (provider.status == ProdutoStatus.success) {
    _mostrarSnack('Status atualizado com sucesso!', Colors.green);
  } else {
    _mostrarSnack('Erro: ${provider.errorMessage}', Colors.red);
  }
}




  void _mostrarSnack(String msg, Color cor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: cor),
    );
  }

@override
Widget build(BuildContext context) {
  super.build(context);

  // Aqui lês o provider. Sempre que ele mudar (novo carregamento,
  // erro, lista actualizada), o Flutter redesenha este widget.
  final provider = context.watch<ProdutoProvider>();

  // Sincroniza a lista local de filtros com o que o Provider tem
  // (só quando não está a carregar e não há erro)
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

  // ── Painel de Filtros ──────────────────────────────────────────────────────
  Widget _buildFiltros() {
    return Container(
      color: _kPrimary.withOpacity(0.04),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        children: [
          // Pesquisa por nome
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

          // Filtro de preço (range)
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

          // Contador
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

  // ── Lista ──────────────────────────────────────────────────────────────────
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
    child: Column(
      children: [
        // cabeçalho da tabela — inalterado
        Container( /* igual ao original */ ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
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
                    builder: (_) => DetalhesProdutoScreen(
                      produto: produto,
                      marcas: const [],
                      categorias: const [],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

}

// ─── Card de Produto (mantido para uso interno/admin) ─────────────────────────

class _ProdutoCard extends StatelessWidget {
  const _ProdutoCard({
    required this.produto,
    required this.currencyFmt,
    required this.onEdit,
    required this.onToggle,
  });

  final ProdutoModel produto;
  final NumberFormat currencyFmt;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final temPromo = produto.precoPromocional != null;
    final semEstoque = produto.quantidadeEstoque <= 0;

    return Card(
      color: _kCardBg,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: produto.estaAtivo ? Colors.transparent : Colors.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imagem
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _ProdutoImagem(produto: produto),
              ),
              const SizedBox(width: 12),

              // Informações
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nome + badge status
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            produto.nomeProduto,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _StatusBadge(ativo: produto.estaAtivo),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Preço
                    Row(
                      children: [
                        Text(
                          currencyFmt.format(produto.precoEfectivo),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: temPromo ? Colors.green[700] : _kPrimary,
                          ),
                        ),
                        if (temPromo) ...[
                          const SizedBox(width: 8),
                          Text(
                            currencyFmt.format(produto.preco),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 4),
                          _PromoTag(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Estoque
                    Row(
                      children: [
                        Icon(
                          semEstoque ? Icons.warning_amber_rounded : Icons.inventory_2,
                          size: 13,
                          color: semEstoque ? Colors.red : Colors.blue[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          semEstoque
                              ? 'Sem estoque'
                              : '${produto.quantidadeEstoque} em estoque',
                          style: TextStyle(
                            fontSize: 12,
                            color: semEstoque ? Colors.red : Colors.grey[700],
                            fontWeight: semEstoque ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Menu
              PopupMenuButton<String>(
                onSelected: (v) => v == 'editar' ? onEdit() : onToggle(),
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'editar',
                    child: Row(children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('Editar'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'status',
                    child: Row(children: [
                      Icon(
                        produto.estaAtivo ? Icons.block : Icons.check_circle_outline,
                        size: 18,
                        color: produto.estaAtivo ? Colors.orange : Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Text(produto.estaAtivo ? 'Desativar' : 'Ativar'),
                    ]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProdutoImagem extends StatelessWidget {
  const _ProdutoImagem({required this.produto});
  final ProdutoModel produto;

  @override
  Widget build(BuildContext context) {
    if (produto.imagemPrincipalUrl == null || produto.imagemPrincipalUrl!.isEmpty) {
      return _placeholder();
    }
    final url = '${ApiConfig.baseUrl}${produto.imagemPrincipalUrl}';
   return Image.network(
  url,
  width: double.infinity,
  height: 90,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : Container(
              width: double.infinity,
              height: 90,
              color: Colors.grey[100],
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2, color: _kPrimary),
              ),
            ),
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }

 Widget _placeholder() => Container(
      width: double.infinity,
      height: 90,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.inventory, color: Colors.grey, size: 32),
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
// ABA DE SERVIÇOS
// ═══════════════════════════════════════════════════════════════════════════════

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


  // filtros
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
Future<void> _toggleStatus(ServicoModel servico) async {
  final ok = await _confirmarDialog(
    context,
    titulo: '${servico.ativo ? 'Desativar' : 'Ativar'} Serviço',
    corpo: 'Deseja ${servico.ativo ? 'desativar' : 'ativar'} "${servico.nomeServico}"?',
    corBotao: servico.ativo ? Colors.orange : Colors.green,
    labelBotao: servico.ativo ? 'Desativar' : 'Ativar',
  );
  if (!ok) return;

  await context.read<ServicoProvider>().toggleEstadoServico(servico.idServico);

  if (!mounted) return;
  final provider = context.read<ServicoProvider>();
  if (provider.errorMessage == null) {
    _mostrarSnack('Status atualizado com sucesso!', Colors.green);
  } else {
    _mostrarSnack('Erro: ${provider.errorMessage}', Colors.red);
  }
}

  void _mostrarSnack(String msg, Color cor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: cor),
    );
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
    child: Column(
      children: [
        // cabeçalho da tabela — inalterado
        Container( /* igual ao original */ ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
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
                    builder: (_) => DetalhesServicoScreen(servico: servico),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
}

// ─── Card de Serviço (mantido para uso interno/admin) ─────────────────────────

class _ServicoCard extends StatelessWidget {
  const _ServicoCard({
    required this.servico,
    required this.currencyFmt,
    required this.onEdit,
    required this.onToggle,
  });

  final ServicoModel servico;
  final NumberFormat currencyFmt;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _kCardBg,
      elevation: 2,
margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: servico.ativo ? Colors.transparent : Colors.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Linha 1: ícone + nome + badge + menu
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ícone ilustrativo
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _kPrimary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.miscellaneous_services,
                      color: _kPrimary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                servico.nomeServico,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w700),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _StatusBadge(ativo: servico.ativo),
                          ],
                        ),
                        if (servico.descricao != null &&
                            servico.descricao!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              servico.descricao!,
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) => v == 'editar' ? onEdit() : onToggle(),
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'editar',
                        child: Row(children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Editar'),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'status',
                        child: Row(children: [
                          Icon(
                            servico.ativo ? Icons.block : Icons.check_circle_outline,
                            size: 18,
                            color: servico.ativo ? Colors.orange : Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(servico.ativo ? 'Desativar' : 'Ativar'),
                        ]),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Linha 2: preço + unidade
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.attach_money, size: 16, color: _kPrimary),
                    const SizedBox(width: 4),
                    Text(
                      currencyFmt.format(servico.precoUnitario),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _kPrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.straighten, size: 12, color: Colors.blue[700]),
                          const SizedBox(width: 4),
                          Text(
                            'por ${servico.unidade}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
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

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGETS REUTILIZÁVEIS
// ═══════════════════════════════════════════════════════════════════════════════

/// Grupo de chips de seleção única para filtros simples.
class _FiltroChips extends StatelessWidget {
  const _FiltroChips({
    required this.label,
    required this.opcoes,
    required this.selecionado,
    required this.onChanged,
  });

  final String label;
  final Map<String, String> opcoes;
  final String selecionado;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: opcoes.entries.map((e) {
          final sel = selecionado == e.key;
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: ChoiceChip(
              label: Text(e.value),
              selected: sel,
              selectedColor: _kPrimary,
              labelStyle: TextStyle(
                fontSize: 11,
                color: sel ? Colors.white : Colors.grey[700],
              ),
              onSelected: (_) => onChanged(e.key),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Badge de status Ativo/Inativo.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.ativo});
  final bool ativo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: ativo ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ativo ? Colors.green : Colors.red),
      ),
      child: Text(
        ativo ? 'Ativo' : 'Inativo',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: ativo ? Colors.green[700] : Colors.red[700],
        ),
      ),
    );
  }
}

/// Tag de promoção.
class _PromoTag extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.green[700],
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'PROMO',
        style: TextStyle(
          fontSize: 9,
          color: Colors.white,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Ecrã de erro com botão de retry.
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
            Text(mensagem,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(backgroundColor: _kPrimary),
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text('Tentar Novamente',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ecrã vazio.
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
          Text(mensagem,
              style: TextStyle(fontSize: 16, color: Colors.grey[500])),
        ],
      ),
    );
  }
}

// ─── Card de produto para o catálogo (vertical, sem acções CRUD) ──────────────
class _ProdutoCardCatalogo extends StatelessWidget {
  const _ProdutoCardCatalogo({
    required this.produto,
    required this.currencyFmt,
    required this.onTap,
  });

  final ProdutoModel produto;
  final NumberFormat currencyFmt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final temPromo   = produto.precoPromocional != null;
    final semEstoque = produto.quantidadeEstoque <= 0;

    return Card(
      color: Colors.white,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: semEstoque ? null : onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagem
           ClipRRect(
  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
  child: Stack(
    children: [
      SizedBox(width: double.infinity, height: 90, child: _ProdutoImagem(produto: produto)),
                  if (temPromo)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _kAccent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('PROMO',
                            style: TextStyle(
                                color: Colors.white, fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  if (semEstoque)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black38,
                        child: const Center(
                          child: Text('SEM ESTOQUE',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Informações
            Padding(
padding: const EdgeInsets.all(7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(produto.nomeProduto,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kPrimary)),
                  const SizedBox(height: 6),

                  // Preço
                  if (temPromo)
                    Text(currencyFmt.format(produto.preco),
                        style: const TextStyle(fontSize: 9, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                  Text(
                    currencyFmt.format(produto.precoEfectivo),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: temPromo ? _kAccent : _kPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Estoque
                  Row(children: [
                    Icon(
                      semEstoque ? Icons.remove_circle_outline : Icons.inventory_2_outlined,
                      size: 13,
                      color: semEstoque ? Colors.red : Colors.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      semEstoque ? 'Esgotado' : '${produto.quantidadeEstoque} disponíveis',
                    style: TextStyle(fontSize: 9, color: semEstoque ? Colors.red : Colors.grey[600]),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ─── Card de serviço para o catálogo (vertical, sem acções CRUD) ──────────────
class _ServicoCardCatalogo extends StatelessWidget {
  const _ServicoCardCatalogo({
    required this.servico,
    required this.currencyFmt,
    required this.onTap,
  });

  final ServicoModel servico;
  final NumberFormat currencyFmt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 2,
margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner de cabeçalho
 Container(
  width: double.infinity,
  padding: const EdgeInsets.symmetric(vertical: 8),  // era 10
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [_kPrimary, _kPrimary.withBlue(140)],
    ),
    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
  ),
  child: const Icon(Icons.miscellaneous_services, color: Colors.white, size: 18),  // era 22
),

            // Informações
            Padding(
  padding: const EdgeInsets.fromLTRB(7, 4, 7, 4),  // era all(7)
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,       // ← impede expansão desnecessária
    children: [
      Text(servico.nomeServico,
          maxLines: 1,                   // era 2
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 11,              // era 14
              fontWeight: FontWeight.w700,
              color: _kPrimary)),
      if (servico.descricao != null && servico.descricao!.isNotEmpty) ...[
        const SizedBox(height: 2),       // era 4
        Text(servico.descricao!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 9, color: Colors.grey[500])),
      ],
      const SizedBox(height: 4),         // era 8
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              currencyFmt.format(servico.precoUnitario),
              style: const TextStyle(
                  fontSize: 11,          // era 15
                  fontWeight: FontWeight.bold,
                  color: _kPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: _kPrimary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              servico.unidade,           // remove "por " para ganhar espaço
              style: const TextStyle(
                  fontSize: 9,           // era 11
                  color: _kPrimary,
                  fontWeight: FontWeight.w500),
          ),
        ),
      ],
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
// ─── Linha de produto na tabela ───────────────────────────────────────────────
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
    final temPromo   = produto.precoPromocional != null;
    final semEstoque = produto.quantidadeEstoque <= 0;

    return Container(
      decoration: BoxDecoration(
        color: isAlternate ? const Color(0xFFF0F2FA) : Colors.white,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE8EAF0), width: 1),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Nome
              Expanded(
                flex: 3,
                child: Text(
                  produto.nomeProduto,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1B2A6B),
                  ),
                ),
              ),

              // Preço normal
              Expanded(
                flex: 2,
                child: Text(
                  currencyFmt.format(produto.preco),
                  style: TextStyle(
                    fontSize: 12,
                    color: temPromo ? Colors.grey : const Color(0xFF1B2A6B),
                    fontWeight: FontWeight.w500,
                    decoration: temPromo ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),

              // Preço promo
              Expanded(
                flex: 2,
                child: temPromo
                    ? Row(
                        children: [
                          Text(
                            currencyFmt.format(produto.precoPromocional),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFC8102E),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFC8102E),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('PROMO',
                                style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      )
                    : Text('—', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              ),

              // Estoque
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Icon(
                      semEstoque ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                      size: 14,
                      color: semEstoque ? Colors.red : Colors.green[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      semEstoque ? 'Esgotado' : '${produto.quantidadeEstoque}',
                      style: TextStyle(
                        fontSize: 12,
                        color: semEstoque ? Colors.red : Colors.grey[700],
                        fontWeight: semEstoque ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),

              // Estado
              Expanded(
                flex: 1,
                child: _StatusBadge(ativo: produto.estaAtivo),
              ),

              // Botão Ver Detalhes
              SizedBox(
                width: 80,
                child: TextButton(
                  onPressed: onTap,
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF1B2A6B),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Detalhes',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Linha de serviço na tabela ───────────────────────────────────────────────
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
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE8EAF0), width: 1),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Nome
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B2A6B).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.miscellaneous_services, size: 16, color: Color(0xFF1B2A6B)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        servico.nomeServico,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1B2A6B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Descrição
              Expanded(
                flex: 3,
                child: Text(
                  servico.descricao ?? '—',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),

              // Preço
              Expanded(
                flex: 2,
                child: Text(
                  currencyFmt.format(servico.precoUnitario),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B2A6B),
                  ),
                ),
              ),

              // Unidade
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

              // Estado
              Expanded(
                flex: 1,
                child: _StatusBadge(ativo: servico.ativo),
              ),

              // Botão Ver Detalhes
              SizedBox(
                width: 80,
                child: TextButton(
                  onPressed: onTap,
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF1B2A6B),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Detalhes',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Widget auxiliar: filtro de preço compacto ────────────────────────────────
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

  // SUBSTITUIR o método build de _FiltroPrecoRow por:
@override
Widget build(BuildContext context) {
  final fmt = NumberFormat.compactCurrency(locale: 'pt_PT', symbol: 'MZN');

  // Garante que os valores nunca excedem os limites
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
          ativo
              ? '${fmt.format(safeMin)} – ${fmt.format(safeMax)}'
              : 'Faixa de Preço',
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

 // SUBSTITUIR _abrirModal por:
void _abrirModal(BuildContext context) {
  // Clamp ao abrir para evitar assertion no RangeSlider
  double tempMin = precoMin.clamp(0.0, precoMaxAbsoluto);
  double tempMax = precoMax.clamp(tempMin, precoMaxAbsoluto);

  // Se max absoluto for 0, não há nada a filtrar
  if (precoMaxAbsoluto <= 0) return;

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    // Resolve o erro de "multiple heroes" no modal
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
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _kPrimary)),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(fmt2.format(tempMin),
                    style: const TextStyle(fontSize: 12)),
                Text(fmt2.format(tempMax),
                    style: const TextStyle(fontSize: 12)),
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
                  style:
                      ElevatedButton.styleFrom(backgroundColor: _kPrimary),
                  onPressed: () {
                    onChanged(tempMin, tempMax);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Aplicar',
                      style: TextStyle(color: Colors.white)),
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

// ═══════════════════════════════════════════════════════════════════════════════
// UTILITÁRIO: Dialog de confirmação
// ═══════════════════════════════════════════════════════════════════════════════

Future<bool> _confirmarDialog(
  BuildContext context, {
  required String titulo,
  required String corpo,
  required Color corBotao,
  required String labelBotao,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(titulo),
      content: Text(corpo),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: corBotao,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(labelBotao),
        ),
      ],
    ),
  );
  return result ?? false;

  

  
}


// catalogo_screen.dart — adicionar ao final do arquivo:
class _BadgePedidosAbertos extends StatefulWidget {
  const _BadgePedidosAbertos();

  @override
  State<_BadgePedidosAbertos> createState() => _BadgePedidosAbertosState();
}

class _BadgePedidosAbertosState extends State<_BadgePedidosAbertos> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PedidoProvider>().listarPorStatus('aberto');
    });
  }

  @override
  Widget build(BuildContext context) {
    final pedidos = context.watch<PedidoProvider>().pedidos;

    return ValueListenableBuilder<PedidoModel?>(
      valueListenable: PedidoAtivoController.instance.pedidoAtivo,
      builder: (_, pedidoAtivo, __) {
        final creditoEmEdicao = pedidoAtivo != null &&
            PedidoAtivoController.instance.edicaoCredito &&
            (pedidoAtivo.ehCredito || pedidoAtivo.estaEmDivida);

        final pedidoAbertoAtivo = pedidoAtivo != null &&
            pedidoAtivo.statusPedido.toLowerCase() == 'aberto';

        var count = pedidos.length;

        final ativoJaEstaNaLista = pedidoAtivo == null
            ? true
            : pedidos.any((p) => p.idPedido == pedidoAtivo.idPedido);

        // Pedido normal recém-criado: entra no badge vermelho imediatamente.
        // Pedido a crédito em edição: entra no badge amarelo imediatamente.
        if (!ativoJaEstaNaLista && (pedidoAbertoAtivo || creditoEmEdicao)) {
          count++;
        }

        final badgeColor = creditoEmEdicao ? Colors.amber[700]! : _kAccent;

        return IconButton(
          tooltip: creditoEmEdicao
              ? 'Pedido a crédito em edição'
              : 'Pedidos Abertos',
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PedidosAbertosScreen(),
              ),
            );

            if (mounted) {
              context.read<PedidoProvider>().listarPorStatus('aberto');
            }
          },
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text(
              count > 99 ? '99+' : '$count',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: badgeColor,
            child: Icon(
              creditoEmEdicao
                  ? Icons.credit_score_rounded
                  : Icons.pending_actions_outlined,
            ),
          ),
        );
      },
    );
  }
}

class _BannerEdicaoCredito extends StatelessWidget {
  const _BannerEdicaoCredito();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PedidoModel?>(
      valueListenable: PedidoAtivoController.instance.pedidoAtivo,
      builder: (_, pedidoAtivo, __) {
        final creditoEmEdicao = pedidoAtivo != null &&
            PedidoAtivoController.instance.edicaoCredito &&
            (pedidoAtivo.ehCredito || pedidoAtivo.estaEmDivida);

        if (!creditoEmEdicao) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.amber[100],
            border: Border(
              bottom: BorderSide(
                color: Colors.amber.shade300,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.amber[900],
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Editando crédito ${pedidoAtivo.referencia} — novos itens serão adicionados à dívida.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.amber[900],
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () async {
                  final sair = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          title: const Text(
                            'Sair da edição?',
                            style: TextStyle(
                              color: _kPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          content: const Text(
                            'Ao sair, os próximos itens adicionados no catálogo já não serão anexados a esta dívida.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Continuar edição'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber[700],
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Sair da edição'),
                            ),
                          ],
                        ),
                      ) ??
                      false;

                  if (!sair) return;

                  PedidoAtivoController.instance.limpar();
                  context.read<PedidoProvider>().limparPedidoActual();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Modo de edição de crédito desactivado.'),
                      backgroundColor: Colors.amber[800],
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Sair'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.amber[900],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}