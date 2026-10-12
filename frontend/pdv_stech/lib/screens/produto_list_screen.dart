// lib/screens/produto_list_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:intl/intl.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/filtros_listagem.dart';
import '../widgets/campo_pesquisa.dart';
import '../theme/app_theme.dart';
import 'produto_form_screen.dart';
import 'package:api_compartilhado/providers/produto_provider.dart';

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

  /// Filtra pelo preço FINAL (com IVA; promocional se existir) — o mesmo
  /// valor que o operador vê e cobra.
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
      builder: (ctx) {
        final c = ctx.cores;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(
            '${produto.estaAtivo ? 'Desativar' : 'Ativar'} Produto',
            style: TextStyle(
                fontWeight: FontWeight.w700, color: c.marca, fontSize: 17),
          ),
          content: Text(
            'Tem certeza que deseja $novoStatus o produto "${produto.nomeProduto}"?',
            style: TextStyle(fontSize: 14, color: c.textoSecundario),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancelar',
                  style: TextStyle(color: c.textoSecundario)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    produto.estaAtivo ? Colors.orange : Colors.green,
                foregroundColor: AppColors.branco,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(produto.estaAtivo ? 'Desativar' : 'Ativar'),
            ),
          ],
        );
      },
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
          backgroundColor: AppColors.vermelhoMarca,
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
      backgroundColor: context.cores.fundo,
      appBar: _buildAppBar(),
      drawer: const AppSidebar(currentRoute: '/gerenciar_produtos'),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navegarParaFormulario(),
        backgroundColor: AppColors.vermelhoMarca,
        child: const Icon(Icons.add, color: AppColors.branco),
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
              color: AppColors.vermelhoMarca,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.inventory_2_rounded,
                color: AppColors.branco, size: 20),
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
      backgroundColor:
          context.escuro ? AppColors.azulMarcaEscuro : AppColors.azulMarca,
      foregroundColor: AppColors.branco,
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
    final c = context.cores;
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
      return Center(child: CircularProgressIndicator(color: c.marca));
    }

    if (provider.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: c.acentoTexto),
            const SizedBox(height: 16),
            Text(
              provider.errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.acentoTexto),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: provider.listar,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar Novamente'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: c.marcaBotao,
                  foregroundColor: AppColors.branco),
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
            Icon(Icons.inventory_2_outlined, size: 80, color: c.desactivado),
            const SizedBox(height: 16),
            Text(
              'Nenhum produto encontrado',
              style: TextStyle(fontSize: 18, color: c.textoSecundario),
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
                      Icon(Icons.search_off, size: 72, color: c.desactivado),
                      const SizedBox(height: 12),
                      Text('Nenhum produto corresponde ao filtro',
                          style: TextStyle(
                              fontSize: 16, color: c.textoSecundario)),
                      TextButton(
                        onPressed: _limparFiltros,
                        child: const Text('Limpar filtros'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    const _CabecalhoTabela(),
                    Expanded(
                      child: RefreshIndicator(
                        color: c.marca,
                        onRefresh: () => provider.listar(),
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
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
                    ),
                  ],
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
    final c = context.cores;
    final precoMaxAbs = todos.isEmpty
        ? 0.0
        : todos.map((p) => p.precoEfectivo).reduce((a, b) => a > b ? a : b);

    return Container(
      color: c.marca.withValues(alpha: 0.04),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        children: [
          CampoPesquisa(
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
                  onChanged: (min, max) => setState(() {
                    _precoMin = min;
                    _precoMax = max;
                  }),
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
                    foregroundColor: c.acentoTexto,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 24),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
              else
                const SizedBox.shrink(),
              Text('$totalFiltrado produto(s) encontrado(s)',
                  style: TextStyle(fontSize: 11, color: c.textoSecundario)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cabeçalho da tabela — mesmas proporções (flex) das colunas da linha
// ─────────────────────────────────────────────────────────────────────────────

class _CabecalhoTabela extends StatelessWidget {
  const _CabecalhoTabela();

  @override
  Widget build(BuildContext context) {
    const estilo = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppColors.branco,
      letterSpacing: 0.3,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.escuro ? AppColors.azulMarcaEscuro : AppColors.azulMarca,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('PRODUTO', style: estilo)),
          Expanded(flex: 2, child: Text('MARCA', style: estilo)),
          Expanded(flex: 2, child: Text('CATEGORIA', style: estilo)),
          Expanded(flex: 2, child: Text('PREÇO', style: estilo)),
          Expanded(flex: 2, child: Text('ESTOQUE', style: estilo)),
          Expanded(flex: 1, child: Text('ESTADO', style: estilo)),
          SizedBox(
            width: 100,
            child: Text('AÇÕES', textAlign: TextAlign.end, style: estilo),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Linha de tabela
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
    final c = context.cores;
    final temPromo = produto.precoPromocional != null;
    final semEstoque = produto.quantidadeEstoque <= 0;

    final nomeMarca = produto.marcas.isNotEmpty
        ? marcasPorId[produto.marcas.first] ?? 'Marca #${produto.marcas.first}'
        : '—';

    final nomeCategoria = produto.categorias.isNotEmpty
        ? categoriasPorId[produto.categorias.first] ??
            'Categoria #${produto.categorias.first}'
        : '—';

    // Preço FINAL (com IVA): promocional se existir, senão o normal.
    final precoPrincipal = produto.precoPromocional ?? produto.preco;

    return Container(
      decoration: BoxDecoration(
        color: isAlternate ? c.linhaAlternada : c.superficie,
        border: Border(bottom: BorderSide(color: c.borda)),
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
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.marca,
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
                style: TextStyle(
                  fontSize: 12,
                  color: c.textoSecundario,
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
                style: TextStyle(
                  fontSize: 12,
                  color: c.textoSecundario,
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
                      color: temPromo ? c.acentoTexto : c.marca,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (temPromo)
                    Text(
                      currencyFmt.format(produto.preco),
                      style: TextStyle(
                        fontSize: 10,
                        color: c.textoSecundario,
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
                    color: semEstoque ? c.perigo : c.sucesso,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    semEstoque ? 'Esgotado' : '${produto.quantidadeEstoque}',
                    style: TextStyle(
                      fontSize: 12,
                      color: semEstoque ? c.perigo : c.icone,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: produto.estaAtivo ? c.sucessoFundo : c.perigoFundo,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: produto.estaAtivo ? c.sucesso : c.perigo,
                  ),
                ),
                child: Text(
                  produto.estaAtivo ? 'Ativo' : 'Inativo',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: produto.estaAtivo ? c.sucesso : c.perigo,
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
                          color: c.marca.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child:
                            Icon(Icons.edit_rounded, size: 16, color: c.marca),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: produto.estaAtivo ? 'Desativar' : 'Ativar',
                    child: InkWell(
                      onTap: onToggle,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: (produto.estaAtivo ? c.aviso : c.sucesso)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          produto.estaAtivo
                              ? Icons.block_rounded
                              : Icons.check_circle_outline_rounded,
                          size: 16,
                          color: produto.estaAtivo ? c.aviso : c.sucesso,
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