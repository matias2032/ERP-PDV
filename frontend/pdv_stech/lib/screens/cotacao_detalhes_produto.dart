// lib/screens/cotacao_detalhes_produto.dart


import 'package:flutter/material.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:api_compartilhado/api_config.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';


const _kPrimary    = Color(0xFF1B2A6B);
const _kAccent     = Color(0xFFC8102E);
const _kBackground = Color(0xFFF4F5F7);

// ─── Cor de destaque para cotação (distingue visualmente do fluxo de pedidos) ──
const _kCotacao = Color(0xFF0077B6);

class CotacaoDetalhesProdutoScreen extends StatefulWidget {
  final ProdutoModel produto;
  final List<dynamic> marcas;
  final List<dynamic> categorias;

  const CotacaoDetalhesProdutoScreen({
    Key? key,
    required this.produto,
    this.marcas      = const [],
    this.categorias  = const [],
  }) : super(key: key);

  @override
  State<CotacaoDetalhesProdutoScreen> createState() =>
      _CotacaoDetalhesProdutoScreenState();
}

class _CotacaoDetalhesProdutoScreenState
    extends State<CotacaoDetalhesProdutoScreen> {
  final _currencyFmt =
      NumberFormat.currency(locale: 'pt_PT', symbol: 'MZN');

  int  _quantidade    = 1;
  bool _processando   = false;

  // ── Atalhos ──────────────────────────────────────────────────────────────
  ProdutoModel get produto   => widget.produto;
  double get precoEfetivo    => produto.precoPromocional ?? produto.preco;
  double get totalParcial    => precoEfetivo * _quantidade;
  bool   get temPromocao     => produto.precoPromocional != null;

  // NOTA: na cotação NÃO bloqueamos por stock — o campo é apenas informativo.
  bool get semEstoque        => produto.quantidadeEstoque == 0;

  CotacaoModel? get _cotacaoAtiva =>
      CotacaoAtivaController.instance.cotacaoAtiva.value;
bool get _temCotacaoAtiva => _cotacaoAtiva != null && _cotacaoAtiva!.estaAberta;

@override
void initState() {
  super.initState();
  // Limpa cotação activa se já não estiver ABERTA
  CotacaoAtivaController.instance.limparSeNaoAberta();
  // Sincroniza com o backend em background
  _sincronizarCotacaoAtiva();
}


Future<void> _sincronizarCotacaoAtiva() async {
  final cotacao = CotacaoAtivaController.instance.cotacaoAtiva.value;
  if (cotacao == null) return;
  try {
    final fresca = await context.read<CotacaoProvider>().buscarPorId(cotacao.idCotacao);
    if (!mounted) return;
    if (fresca == null || !fresca.estaAberta) {
      CotacaoAtivaController.instance.limpar();
    } else {
      CotacaoAtivaController.instance.definir(fresca);
    }
  } catch (_) {
    // falha silenciosa — limpa por precaução
    CotacaoAtivaController.instance.limpar();
  }
}
  // ── Nomes auxiliares ──────────────────────────────────────────────────────
  String get nomesMarcas {
    if (produto.marcas.isEmpty) return 'Sem marca';
    return produto.marcas.map((id) {
      final m = widget.marcas
          .firstWhere((x) => x.idMarca == id, orElse: () => null);
      return m?.nomeMarca ?? 'ID $id';
    }).join(', ');
  }

  String get nomesCategorias {
    if (produto.categorias.isEmpty) return 'Sem categoria';
    return produto.categorias.map((id) {
      final c = widget.categorias
          .firstWhere((x) => x.idCategoria == id, orElse: () => null);
      return c?.nomeCategoria ?? 'ID $id';
    }).join(', ');
  }

  // ── Controlo de quantidade ────────────────────────────────────────────────
  void _incrementar() => setState(() => _quantidade++);

  void _decrementar() {
    if (_quantidade > 1) setState(() => _quantidade--);
  }

  void _setQuantidade(int v) {
    if (v < 1) return;
    setState(() => _quantidade = v);
  }

  // ── Acção principal ───────────────────────────────────────────────────────
Future<void> _adicionarACotacao() async {
  if (_processando) return;

  final ok = await _dialogConfirmacao();
  if (!ok) return;

    setState(() => _processando = true);
    try {
      final cotacaoProvider = context.read<CotacaoProvider>();

      if (_temCotacaoAtiva) {
        // ── Adiciona à cotação activa ────────────────────────────────────
        final cotacaoActualizada = await cotacaoProvider.adicionarProduto(
          _cotacaoAtiva!.idCotacao,
          AdicionarProdutoCotacaoRequestModel(
            idProduto:   produto.idProduto,
            quantidade:  _quantidade,
            // precoUnitario: null → backend/repositório usa o preço actual
          ),
        );
        if (!mounted) return;

        if (cotacaoProvider.status == CotacaoStatus.success &&
            cotacaoActualizada != null) {
          CotacaoAtivaController.instance.definir(cotacaoActualizada);
          _snack(
            '✅ Item adicionado à cotação ${cotacaoActualizada.referencia}',
            Colors.green,
          );
          Navigator.pop(context, cotacaoActualizada);
        } else {
          _snack('Erro: ${cotacaoProvider.errorMessage}', _kAccent);
        }
      } else {
        // ── Cria nova cotação e adiciona o item ──────────────────────────
        final novaCotacao = await cotacaoProvider.criarCotacao(
          CriarCotacaoRequestModel(idUsuario: SessaoService.instance.idUsuario),
        );
        if (!mounted) return;

        if (novaCotacao == null ||
            cotacaoProvider.status != CotacaoStatus.success) {
          _snack('Erro ao criar cotação: ${cotacaoProvider.errorMessage}',
              _kAccent);
          return;
        }

        final cotacaoComItem = await cotacaoProvider.adicionarProduto(
          novaCotacao.idCotacao,
          AdicionarProdutoCotacaoRequestModel(
            idProduto:  produto.idProduto,
            quantidade: _quantidade,
          ),
        );
        if (!mounted) return;

        final cotacaoFinal = cotacaoComItem ?? novaCotacao;
        CotacaoAtivaController.instance.definir(cotacaoFinal);

        _snack(
          '✅ Cotação ${cotacaoFinal.referencia} criada!',
          _kCotacao,
        );
        Navigator.pop(context, cotacaoFinal);
      }
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  // ── Diálogo de confirmação ────────────────────────────────────────────────
  Future<bool> _dialogConfirmacao() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: Text(
              _temCotacaoAtiva
                  ? 'Adicionar à Cotação'
                  : 'Nova Cotação',
              style: const TextStyle(
                  color: _kPrimary, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_temCotacaoAtiva) ...[
                  _dialogInfoBox(
                    icon: Icons.request_quote_outlined,
                    texto:
                        'Cotação activa: ${_cotacaoAtiva!.referencia}',
                    cor: _kCotacao,
                  ),
                  const SizedBox(height: 8),
                ],
                Text(produto.nomeProduto,
                    style:
                        const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                _dialogRow('Quantidade', '$_quantidade'),
                _dialogRow('Preço unitário',
                    _currencyFmt.format(precoEfetivo)),
                const Divider(height: 16),
                _dialogRow('Subtotal',
                    _currencyFmt.format(totalParcial),
                    bold: true),
                const SizedBox(height: 8),
                // Aviso de stock baixo/zero (informativo, não bloqueante)
                if (semEstoque)
                  _dialogInfoBox(
                    icon: Icons.info_outline,
                    texto:
                        'Produto sem stock actual — pode ser incluído na cotação na mesma.',
                    cor: Colors.orange,
                  ),
                if (!semEstoque && produto.quantidadeEstoque <= 5)
                  _dialogInfoBox(
                    icon: Icons.warning_amber_outlined,
                    texto:
                        'Stock baixo: ${produto.quantidadeEstoque} unidade(s) disponível(is).',
                    cor: Colors.orange,
                  ),
                const SizedBox(height: 4),
                _dialogInfoBox(
                  icon: _temCotacaoAtiva
                      ? Icons.add_shopping_cart
                      : Icons.request_quote_outlined,
                  texto: _temCotacaoAtiva
                      ? 'Item adicionado à cotação ${_cotacaoAtiva!.referencia}.'
                      : 'Uma nova cotação será criada com este item.',
                  cor: _kCotacao,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kCotacao,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                    _temCotacaoAtiva ? 'Adicionar' : 'Criar Cotação'),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ── Helpers de diálogo ────────────────────────────────────────────────────
  Widget _dialogInfoBox(
      {required IconData icon,
      required String texto,
      required Color cor}) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cor.withOpacity(0.25)),
      ),
      child: Row(children: [
        Icon(icon, size: 15, color: cor),
        const SizedBox(width: 6),
        Expanded(
            child: Text(texto,
                style: TextStyle(fontSize: 11, color: cor))),
      ]),
    );
  }

  Widget _dialogRow(String label, String valor, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  TextStyle(color: Colors.grey[600], fontSize: 12)),
          Text(valor,
              style: TextStyle(
                fontWeight:
                    bold ? FontWeight.bold : FontWeight.w500,
                fontSize: bold ? 15 : 13,
                color: bold ? _kPrimary : Colors.black87,
              )),
        ],
      ),
    );
  }

  void _snack(String msg, Color cor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: cor,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ════════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackground,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 8),
                  _buildPrecoCard(),
                  const SizedBox(height: 8),
                  _buildInfoCard(),
                  if (produto.descricao != null &&
                      produto.descricao!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildDescricaoCard(),
                  ],
                  const SizedBox(height: 8),
                  // Stock: informativo, nunca bloqueante
                  _buildEstoqueCard(),
                  const SizedBox(height: 8),
                  _buildSelectorQuantidade(),
                  const SizedBox(height: 14),
                  _buildBotao(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      backgroundColor: _kPrimary,
      foregroundColor: Colors.white,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            shape: BoxShape.circle),
        child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)),
      ),
      // Chip de contexto no topo direito
      actions: [
        ValueListenableBuilder<CotacaoModel?>(
          valueListenable:
              CotacaoAtivaController.instance.cotacaoAtiva,
          builder: (_, cotacao, __) {
            if (cotacao == null) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 10),
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _kCotacao.withOpacity(0.85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.request_quote_outlined,
                    size: 14, color: Colors.white),
                const SizedBox(width: 4),
                Text(cotacao.referencia,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
              ]),
            );
          },
        ),
      ],
      flexibleSpace:
          FlexibleSpaceBar(background: _buildImagemHero()),
    );
  }

  Widget _buildImagemHero() {
    if (produto.imagemPrincipalUrl == null ||
        produto.imagemPrincipalUrl!.isEmpty) {
      return Container(
        color: _kPrimary.withOpacity(0.15),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined,
                  size: 56, color: _kPrimary.withOpacity(0.4)),
              const SizedBox(height: 6),
              Text('Sem imagem',
                  style: TextStyle(
                      color: _kPrimary.withOpacity(0.5),
                      fontSize: 13)),
            ]),
      );
    }
    return Image.network(
      '${ApiConfig.baseUrl}${produto.imagemPrincipalUrl}',
      fit: BoxFit.cover,
      width: double.infinity,
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : Container(
              color: Colors.grey[200],
              child: const Center(
                  child: CircularProgressIndicator(
                      color: _kPrimary))),
      errorBuilder: (_, __, ___) => Container(
          color: Colors.grey[100],
          child: const Icon(Icons.broken_image,
              size: 52, color: Colors.grey)),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (temPromocao)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              margin: const EdgeInsets.only(bottom: 5),
              decoration: BoxDecoration(
                  color: _kAccent,
                  borderRadius: BorderRadius.circular(20)),
              child: const Text('🏷️ PROMOÇÃO',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
            ),
          Text(produto.nomeProduto,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _kPrimary,
                  height: 1.2)),
        ]);
  }

  // ── Cards de detalhe ──────────────────────────────────────────────────────
  Widget _buildPrecoCard() {
    return _card(
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Preço',
              style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          const SizedBox(height: 2),
          if (temPromocao)
            Text(
              _currencyFmt.format(produto.preco),
              style: const TextStyle(
                  color: Colors.grey,
                  decoration: TextDecoration.lineThrough,
                  fontSize: 13),
            ),
          Text(
            _currencyFmt.format(precoEfetivo),
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: temPromocao ? _kAccent : _kPrimary),
          ),
        ]),
        if (temPromocao) ...[
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: _kAccent.withOpacity(0.1),
                shape: BoxShape.circle),
            child: Icon(Icons.local_offer, color: _kAccent, size: 18),
          ),
        ],
      ]),
    );
  }

  Widget _buildInfoCard() {
    return _card(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Informações',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: _kPrimary)),
            const SizedBox(height: 8),
            _infoRow(Icons.label_outline, 'Marca', nomesMarcas),
            const Divider(height: 12),
            _infoRow(
                Icons.category_outlined, 'Categoria', nomesCategorias),
          ]),
    );
  }

  Widget _infoRow(IconData icon, String label, String valor) {
    return Row(children: [
      Icon(icon, size: 15, color: _kPrimary.withOpacity(0.5)),
      const SizedBox(width: 6),
      Text('$label:',
          style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      const SizedBox(width: 5),
      Expanded(
        child: Text(valor,
            textAlign: TextAlign.end,
            style: const TextStyle(
                fontWeight: FontWeight.w500, fontSize: 12)),
      ),
    ]);
  }

  Widget _buildDescricaoCard() {
    return _card(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Descrição',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: _kPrimary)),
            const SizedBox(height: 6),
            Text(produto.descricao!,
                style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 13,
                    height: 1.4)),
          ]),
    );
  }

  /// Stock é informativo — nunca bloqueia a adição à cotação.
  Widget _buildEstoqueCard() {
    final estoque = produto.quantidadeEstoque;
    final Color cor;
    final IconData icon;
    final String texto;

    if (estoque == 0) {
      // Laranja (aviso) em vez de vermelho (bloqueio)
      cor  = Colors.orange;
      icon = Icons.info_outline;
      texto = 'Sem stock actual — pode ser cotado na mesma';
    } else if (estoque <= 5) {
      cor  = Colors.orange;
      icon = Icons.warning_amber_outlined;
      texto =
          'Stock baixo: $estoque unidade${estoque > 1 ? 's' : ''} disponíve${estoque > 1 ? 'is' : 'l'}';
    } else {
      cor  = Colors.green;
      icon = Icons.inventory_2_outlined;
      texto = '$estoque unidades disponíveis';
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cor.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: cor, size: 18),
        const SizedBox(width: 8),
        Text(texto,
            style: TextStyle(
                color: cor,
                fontWeight: FontWeight.w500,
                fontSize: 13)),
      ]),
    );
  }

  // ── Selector de quantidade ─────────────────────────────────────────────────
  Widget _buildSelectorQuantidade() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Quantidade',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: _kPrimary)),
      const SizedBox(height: 8),
      Row(children: [
        _btnQtd(
            icon: Icons.remove,
            onTap: _decrementar,
            habilitado: _quantidade > 1),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Center(
              child: TextFormField(
                key: ValueKey(_quantidade),
                initialValue: _quantidade.toString(),
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _kPrimary),
                decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero),
                onChanged: (v) {
                  final n = int.tryParse(v);
                  if (n != null) _setQuantidade(n);
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Sem limite de stock para o incrementar
        _btnQtd(
            icon: Icons.add, onTap: _incrementar, habilitado: true),
      ]),
      const SizedBox(height: 8),
      Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            color: _kPrimary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total estimado:',
                style:
                    TextStyle(color: Colors.grey[700], fontSize: 13)),
            Text(_currencyFmt.format(totalParcial),
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _kPrimary)),
          ],
        ),
      ),
    ]);
  }

  Widget _btnQtd(
      {required IconData icon,
      required VoidCallback onTap,
      required bool habilitado}) {
    return Material(
      color: habilitado ? _kCotacao : Colors.grey[200],
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: habilitado ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon,
              color:
                  habilitado ? Colors.white : Colors.grey[400],
              size: 20),
        ),
      ),
    );
  }

  // ── Botão principal ───────────────────────────────────────────────────────
  Widget _buildBotao() {
  return ValueListenableBuilder<CotacaoModel?>(
    valueListenable: CotacaoAtivaController.instance.cotacaoAtiva,
    builder: (_, cotacao, __) {
      // ← só considera activa se estiver ABERTA
      final adicionando = cotacao != null && cotacao.estaAberta;

      final label = _processando
          ? (adicionando ? 'A adicionar...' : 'A criar cotação...')
          : adicionando
              ? 'Adicionar à ${cotacao!.referencia}'
              : 'Criar Cotação';

      final icone = _processando
          ? const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Icon(adicionando
              ? Icons.add_shopping_cart
              : Icons.request_quote_outlined);

      return SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: _processando ? null : _adicionarACotacao,
          icon: icone,
          label: Text(label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: adicionando ? Colors.green[700] : _kCotacao,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 3,
          ),
        ),
      );
    },
  );
}

  // ── Util ──────────────────────────────────────────────────────────────────
  Widget _card({required Widget child}) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(10), child: child),
    );
  }
}

