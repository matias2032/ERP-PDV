// lib/screens/produto_list_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:intl/intl.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/filtros_listagem.dart';
import 'produto_form_screen.dart';
import 'package:api_compartilhado/providers/produto_provider.dart';

// ── Paleta STech ─────────────────────────────────────────────────────────────
const _kVermelho   = Color(0xFFC8102E);
const _kAzul       = Color(0xFF1B2A6B);
const _kBranco     = Colors.white;
const _kCinzaClaro = Color(0xFFF4F5F7);
const _kCinzaTexto = Color(0xFF6B7280);

// ─────────────────────────────────────────────────────────────────────────────

class ProdutoListScreen extends StatefulWidget {
  const ProdutoListScreen({super.key});

  @override
  State<ProdutoListScreen> createState() => _ProdutoListScreenState();
}

class _ProdutoListScreenState extends State<ProdutoListScreen> {
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'pt_PT',
    symbol: 'MZN',
  );

  // ── Filtros ──────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  String _busca = '';
  double _precoMin = 0;
  double _precoMax = double.infinity;
  Set<int> _categoriasSel = {};
  Set<int> _marcasSel = {};
  EstadoFiltro _estado = EstadoFiltro.todos;

  bool get _temFiltros =>
      _busca.isNotEmpty ||
      _precoMin > 0 ||
      _precoMax != double.infinity ||
      _categoriasSel.isNotEmpty ||
      _marcasSel.isNotEmpty ||
      _estado != EstadoFiltro.todos;

  void _limparFiltros() {
    _searchCtrl.clear();
    setState(() {
      _busca = '';
      _precoMin = 0;
      _precoMax = double.infinity;
      _categoriasSel = {};
      _marcasSel = {};
      _estado = EstadoFiltro.todos;
    });
  }

  List<ProdutoModel> _filtrar(List<ProdutoModel> todos) {
    return todos.where((p) {
      final matchNome = p.nomeProduto.toLowerCase().contains(_busca);
      final matchPreco =
          p.precoEfectivo >= _precoMin && p.precoEfectivo <= _precoMax;
      final matchCat = _categoriasSel.isEmpty ||
          p.categorias.any(_categoriasSel.contains);
      final matchMarca =
          _marcasSel.isEmpty || p.marcas.any(_marcasSel.contains);
      final matchEstado = _estado == EstadoFiltro.todos ||
          (_estado == EstadoFiltro.ativos ? p.estaAtivo : !p.estaAtivo);
      return matchNome && matchPreco && matchCat && matchMarca && matchEstado;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProdutoProvider>().listar();
      context.read<MarcaProvider>().carregarMarcas();
      context.read<CategoriaProvider>().carregarCategorias();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Acções ────────────────────────────────────────────────────────────────

  Future<void> _toggleStatus(ProdutoModel produto) async {
    final novoStatus = produto.estaAtivo ? 'desativar' : 'ativar';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          '${produto.estaAtivo ? 'Desativar' : 'Ativar'} Produto',
          style: const TextStyle(
              fontWeight: FontWeight.w700, color: _kAzul, fontSize: 17),
        ),
        content: Text(
          'Tem certeza que deseja $novoStatus o produto "${produto.nomeProduto}"?',
          style: const TextStyle(fontSize: 14, color: _kCinzaTexto),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar',
                style: TextStyle(color: _kCinzaTexto)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  produto.estaAtivo ? Colors.orange : Colors.green,
              foregroundColor: _kBranco,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(produto.estaAtivo ? 'Desativar' : 'Ativar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    final sucesso =
        await context.read<ProdutoProvider>().toggleAtivo(produto.idProduto);

    if (!mounted) return;

    if (sucesso) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Estado do produto actualizado com sucesso.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      final erro =
          context.read<ProdutoProvider>().errorMessage ?? 'Erro desconhecido';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao actualizar estado: $erro'),
          backgroundColor: _kVermelho,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _navegarParaFormulario([ProdutoModel? produto]) async {
    final houveAlteracao = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProdutoFormScreen(produto: produto),
      ),
    );
    if (houveAlteracao == true && mounted) {
      context.read<ProdutoProvider>().listar();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kCinzaClaro,
      appBar: _buildAppBar(),
      drawer: const AppSidebar(currentRoute: '/gerenciar_produtos'),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navegarParaFormulario(),
        backgroundColor: _kVermelho,
        child: const Icon(Icons.add, color: _kBranco),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _kVermelho,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.inventory_2_rounded,
                color: _kBranco, size: 20),
          ),
          const SizedBox(width: 10),
          const Text(
            'Produtos',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3),
          ),
        ],
      ),
      backgroundColor: _kAzul,
      foregroundColor: _kBranco,
      elevation: 0,
      actions: [
        Consumer<ProdutoProvider>(
          builder: (_, p, __) => IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Recarregar',
            onPressed: p.isLoading ? null : p.listar,
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBody() {
    final provider = context.watch<ProdutoProvider>();
    
    final marcaProvider = context.watch<MarcaProvider>();
final categoriaProvider = context.watch<CategoriaProvider>();

final marcasPorId = {
  for (final marca in marcaProvider.marcas) marca.id: marca.nomeMarca,
};

final categoriasPorId = {
  for (final categoria in categoriaProvider.categorias)
    categoria.id: categoria.nomeCategoria,
};

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator(color: _kAzul));
    }

    if (provider.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: _kVermelho),
            const SizedBox(height: 16),
            Text(
              provider.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kVermelho),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: provider.listar,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar Novamente'),
              style: ElevatedButton.styleFrom(backgroundColor: _kAzul),
            ),
          ],
        ),
      );
    }

    if (provider.produtos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Nenhum produto encontrado',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    final filtrados = _filtrar(provider.produtos);

    return Column(
      children: [
        _buildFiltros(
          todos: provider.produtos,
          marcasPorId: marcasPorId,
          categoriasPorId: categoriasPorId,
          totalFiltrado: filtrados.length,
        ),
        Expanded(
          child: filtrados.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off,
                          size: 72, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('Nenhum produto corresponde ao filtro',
                          style: TextStyle(
                              fontSize: 16, color: Colors.grey[500])),
                      TextButton(
                        onPressed: _limparFiltros,
                        child: const Text('Limpar filtros'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: _kAzul,
                  onRefresh: () async => provider.listar(),
                  child: Column(
                    children: [
                      Container( /* cabeçalho da tabela: inalterado */ ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                          itemCount: filtrados.length,
                          itemBuilder: (_, i) => _ProdutoLinhaTabela(
                            produto: filtrados[i],
                            currencyFmt: _currencyFormat,
                            isAlternate: i.isOdd,
                            marcasPorId: marcasPorId,
                            categoriasPorId: categoriasPorId,
                            onEditar: () =>
                                _navegarParaFormulario(filtrados[i]),
                            onToggle: () => _toggleStatus(filtrados[i]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

    Widget _buildFiltros({
    required List<ProdutoModel> todos,
    required Map<int, String> marcasPorId,
    required Map<int, String> categoriasPorId,
    required int totalFiltrado,
  }) {
    final precoMaxAbs = todos.isEmpty
        ? 0.0
        : todos.map((p) => p.precoEfectivo).reduce((a, b) => a > b ? a : b);

    return Container(
      color: _kAzul.withOpacity(0.04),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        children: [
          FiltroPesquisa(
            controller: _searchCtrl,
            hint: 'Pesquisar produto…',
            onChanged: (v) => setState(() => _busca = v.toLowerCase()),
            onClear: () {
              _searchCtrl.clear();
              setState(() => _busca = '');
            },
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FiltroPrecoRow(
                  precoMin: _precoMin,
                  precoMax: _precoMax,
                  precoMaxAbsoluto: precoMaxAbs,
                  onChanged: (min, max) =>
                      setState(() { _precoMin = min; _precoMax = max; }),
                ),
                const SizedBox(width: 6),
                FiltroSelecaoMultipla(
                  rotulo: 'Categoria',
                  icone: Icons.category_outlined,
                  opcoes: categoriasPorId,
                  selecionados: _categoriasSel,
                  onChanged: (s) => setState(() => _categoriasSel = s),
                ),
                const SizedBox(width: 6),
                FiltroSelecaoMultipla(
                  rotulo: 'Marca',
                  icone: Icons.sell_outlined,
                  opcoes: marcasPorId,
                  selecionados: _marcasSel,
                  onChanged: (s) => setState(() => _marcasSel = s),
                ),
                const SizedBox(width: 12),
                FiltroEstadoChips(
                  selecionado: _estado,
                  onChanged: (e) => setState(() => _estado = e),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_temFiltros)
                TextButton.icon(
                  onPressed: _limparFiltros,
                  icon: const Icon(Icons.filter_alt_off, size: 14),
                  label: const Text('Limpar filtros',
                      style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    foregroundColor: _kVermelho,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 24),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
              else
                const SizedBox.shrink(),
              Text('$totalFiltrado produto(s) encontrado(s)',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Linha de tabela — sem alterações de lógica, apenas mantida
// ─────────────────────────────────────────────────────────────────────────────

class _ProdutoLinhaTabela extends StatelessWidget {
const _ProdutoLinhaTabela({
  required this.produto,
  required this.currencyFmt,
  required this.isAlternate,
  required this.marcasPorId,
  required this.categoriasPorId,
  required this.onEditar,
  required this.onToggle,
});

final ProdutoModel produto;
final NumberFormat currencyFmt;
final bool isAlternate;
final Map<int, String> marcasPorId;
final Map<int, String> categoriasPorId;
final VoidCallback onEditar;
final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final temPromo   = produto.precoPromocional != null;
    final semEstoque = produto.quantidadeEstoque <= 0;

    final nomeMarca = produto.marcas.isNotEmpty
    ? marcasPorId[produto.marcas.first] ?? 'Marca #${produto.marcas.first}'
    : '—';

final nomeCategoria = produto.categorias.isNotEmpty
    ? categoriasPorId[produto.categorias.first] ??
        'Categoria #${produto.categorias.first}'
    : '—';

final precoPrincipal = produto.precoPromocional ?? produto.preco;

    return Container(
      decoration: BoxDecoration(
        color: isAlternate ? const Color(0xFFF0F2FA) : _kBranco,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE8EAF0)),
        ),
      ),
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
                  color: _kAzul,
                ),
              ),
            ),

            // Marca
Expanded(
  flex: 2,
  child: Text(
    nomeMarca,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(
      fontSize: 12,
      color: _kCinzaTexto,
      fontWeight: FontWeight.w500,
    ),
  ),
),

// Categoria
Expanded(
  flex: 2,
  child: Text(
    nomeCategoria,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(
      fontSize: 12,
      color: _kCinzaTexto,
      fontWeight: FontWeight.w500,
    ),
  ),
),

// Preço
Expanded(
  flex: 2,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        currencyFmt.format(precoPrincipal),
        style: TextStyle(
          fontSize: 12,
          color: temPromo ? _kVermelho : _kAzul,
          fontWeight: FontWeight.w700,
        ),
      ),
      if (temPromo)
        Text(
          currencyFmt.format(produto.preco),
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
            decoration: TextDecoration.lineThrough,
          ),
        ),
    ],
  ),
),

// Estoque
Expanded(
  flex: 2,
  child: Row(
    children: [
      Icon(
        semEstoque
            ? Icons.warning_amber_rounded
            : Icons.check_circle_outline,
        size: 14,
        color: semEstoque ? Colors.red : Colors.green[600],
      ),
      const SizedBox(width: 4),
      Text(
        semEstoque ? 'Esgotado' : '${produto.quantidadeEstoque}',
        style: TextStyle(
          fontSize: 12,
          color: semEstoque ? Colors.red : Colors.grey[700],
          fontWeight:
              semEstoque ? FontWeight.w700 : FontWeight.normal,
        ),
      ),
    ],
  ),
),

            // Estado
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: produto.estaAtivo
                      ? Colors.green[50]
                      : Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        produto.estaAtivo ? Colors.green : Colors.red,
                  ),
                ),
                child: Text(
                  produto.estaAtivo ? 'Ativo' : 'Inativo',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: produto.estaAtivo
                        ? Colors.green[700]
                        : Colors.red[700],
                  ),
                ),
              ),
            ),

            // Ações
            SizedBox(
              width: 100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Tooltip(
                    message: 'Editar',
                    child: InkWell(
                      onTap: onEditar,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _kAzul.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.edit_rounded,
                            size: 16, color: _kAzul),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message:
                        produto.estaAtivo ? 'Desativar' : 'Ativar',
                    child: InkWell(
                      onTap: onToggle,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: (produto.estaAtivo
                                  ? Colors.orange
                                  : Colors.green)
                              .withOpacity(0.10),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          produto.estaAtivo
                              ? Icons.block_rounded
                              : Icons.check_circle_outline_rounded,
                          size: 16,
                          color: produto.estaAtivo
                              ? Colors.orange
                              : Colors.green[700],
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

