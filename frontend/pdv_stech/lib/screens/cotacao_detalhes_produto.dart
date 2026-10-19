// lib/screens/cotacao_detalhes_produto.dart

import 'package:flutter/material.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:api_compartilhado/api_config.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';

// ─── Cores ───────────────────────────────────────────────────────────────────
// As antigas constantes (_kPrimary, _kAccent, _kBackground) foram
// substituídas pelo tema:
//   _kPrimary    → context.cores.marca (texto/ícone/borda)
//                  AppColors.azulMarca / azulMarcaEscuro (AppBar)
//   _kAccent     → AppColors.vermelhoMarca (fundo: etiqueta de promoção, snackbar de erro;
//                  texto branco por cima)
//                  context.cores.acentoTexto (vermelho como texto/ícone)
//   _kBackground → context.cores.fundo
//   Colors.orange / green / grey → aviso / sucesso / textoSecundario / desactivado

// ─── Cor de destaque para cotação (distingue visualmente do fluxo de pedidos) ──
// FUNDO fixo com texto/ícone BRANCO por cima (igual nos dois temas, 5:1).
// Para usar como TEXTO/BORDA sobre superfícies, usar [_cotacaoTexto], que no
// tema escuro troca para `info` (o azul fixo teria pouco contraste).
const _kCotacao = Color(0xFF0077B6);

Color _cotacaoTexto(BuildContext context) =>
    context.escuro ? context.cores.info : _kCotacao;

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
  bool get _temCotacaoAtiva =>
      _cotacaoAtiva != null && _cotacaoAtiva!.estaAberta;

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
            Colors.green.shade700,
          );
          Navigator.pop(context, cotacaoActualizada);
        } else {
          _snack('Erro: ${cotacaoProvider.errorMessage}',
              AppColors.vermelhoMarca);
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
              AppColors.vermelhoMarca);
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
          builder: (ctx) {
            final c = ctx.cores;
            final corCotacao = _cotacaoTexto(ctx);

            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text(
                _temCotacaoAtiva
                    ? 'Adicionar à Cotação'
                    : 'Nova Cotação',
                style: TextStyle(
                    color: c.marca, fontWeight: FontWeight.bold),
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
                      cor: corCotacao,
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
                      cor: c.aviso,
                    ),
                  if (!semEstoque && produto.quantidadeEstoque <= 5)
                    _dialogInfoBox(
                      icon: Icons.warning_amber_outlined,
                      texto:
                          'Stock baixo: ${produto.quantidadeEstoque} unidade(s) disponível(is).',
                      cor: c.aviso,
                    ),
                  const SizedBox(height: 4),
                  _dialogInfoBox(
                    icon: _temCotacaoAtiva
                        ? Icons.add_shopping_cart
                        : Icons.request_quote_outlined,
                    texto: _temCotacaoAtiva
                        ? 'Item adicionado à cotação ${_cotacaoAtiva!.referencia}.'
                        : 'Uma nova cotação será criada com este item.',
                    cor: corCotacao,
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
                    foregroundColor: AppColors.branco,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                      _temCotacaoAtiva ? 'Adicionar' : 'Criar Cotação'),
                ),
              ],
            );
          },
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
        color: cor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cor.withValues(alpha: 0.25)),
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
    final c = context.cores;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  TextStyle(color: c.textoSecundario, fontSize: 12)),
          Text(valor,
              style: TextStyle(
                fontWeight:
                    bold ? FontWeight.bold : FontWeight.w500,
                fontSize: bold ? 15 : 13,
                color: bold ? c.marca : c.textoPrincipal,
              )),
        ],
      ),
    );
  }

  /// Fundo colorido FIXO + texto branco explícito: sem isso, no tema escuro
  /// o texto herdaria `textoPrincipal` (claro) e perderia contraste.
  void _snack(String msg, Color cor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: AppColors.branco)),
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
    final c = context.cores;

    return Scaffold(
      backgroundColor: c.fundo,
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
      // Mesmo critério da AppBar do tema escuro (azulMarcaEscuro).
      backgroundColor:
          context.escuro ? AppColors.azulMarcaEscuro : AppColors.azulMarca,
      foregroundColor: AppColors.branco,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
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
                color: _kCotacao.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.request_quote_outlined,
                    size: 14, color: AppColors.branco),
                const SizedBox(width: 4),
                Text(cotacao.referencia,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.branco,
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
    final c = context.cores;

    if (produto.imagemPrincipalUrl == null ||
        produto.imagemPrincipalUrl!.isEmpty) {
      return Container(
        color: c.marca.withValues(alpha: 0.15),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined,
                  size: 56, color: c.marca.withValues(alpha: 0.4)),
              const SizedBox(height: 6),
              Text('Sem imagem',
                  style: TextStyle(
                      color: c.marca.withValues(alpha: 0.5),
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
              color: c.superficieAlt,
              child: Center(
                  child: CircularProgressIndicator(
                      color: c.marca))),
      errorBuilder: (_, __, ___) => Container(
          color: c.superficie,
          child: Icon(Icons.broken_image,
              size: 52, color: c.desactivado)),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final c = context.cores;

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (temPromocao)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              margin: const EdgeInsets.only(bottom: 5),
              decoration: BoxDecoration(
                  color: AppColors.vermelhoMarca,
                  borderRadius: BorderRadius.circular(20)),
              child: const Text('🏷️ PROMOÇÃO',
                  style: TextStyle(
                      color: AppColors.branco,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
            ),
          Text(produto.nomeProduto,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: c.marca,
                  height: 1.2)),
        ]);
  }

  // ── Cards de detalhe ──────────────────────────────────────────────────────
  Widget _buildPrecoCard() {
    final c = context.cores;

    return _card(
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Preço',
              style: TextStyle(color: c.textoSecundario, fontSize: 11)),
          const SizedBox(height: 2),
          if (temPromocao)
            Text(
              _currencyFmt.format(produto.preco),
              style: TextStyle(
                  color: c.textoSecundario,
                  decoration: TextDecoration.lineThrough,
                  fontSize: 13),
            ),
          Text(
            _currencyFmt.format(precoEfetivo),
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: temPromocao ? c.acentoTexto : c.marca),
          ),
        ]),
        if (temPromocao) ...[
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: c.acentoTexto
                    .withValues(alpha: context.escuro ? 0.18 : 0.1),
                shape: BoxShape.circle),
            child: Icon(Icons.local_offer, color: c.acentoTexto, size: 18),
          ),
        ],
      ]),
    );
  }

  Widget _buildInfoCard() {
    final c = context.cores;

    return _card(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Informações',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: c.marca)),
            const SizedBox(height: 8),
            _infoRow(Icons.label_outline, 'Marca', nomesMarcas),
            const Divider(height: 12),
            _infoRow(
                Icons.category_outlined, 'Categoria', nomesCategorias),
          ]),
    );
  }

  Widget _infoRow(IconData icon, String label, String valor) {
    final c = context.cores;

    return Row(children: [
      Icon(icon, size: 15, color: c.marca.withValues(alpha: 0.6)),
      const SizedBox(width: 6),
      Text('$label:',
          style: TextStyle(color: c.textoSecundario, fontSize: 12)),
      const SizedBox(width: 5),
      Expanded(
        child: Text(valor,
            textAlign: TextAlign.end,
            style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
                color: c.textoPrincipal)),
      ),
    ]);
  }

  Widget _buildDescricaoCard() {
    final c = context.cores;

    return _card(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Descrição',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: c.marca)),
            const SizedBox(height: 6),
            Text(produto.descricao!,
                style: TextStyle(
                    color: c.textoSecundario,
                    fontSize: 13,
                    height: 1.4)),
          ]),
    );
  }

  /// Stock é informativo — nunca bloqueia a adição à cotação.
  Widget _buildEstoqueCard() {
    final c = context.cores;
    final estoque = produto.quantidadeEstoque;
    final Color cor;
    final IconData icon;
    final String texto;

    if (estoque == 0) {
      // Aviso (laranja) em vez de bloqueio (vermelho)
      cor  = c.aviso;
      icon = Icons.info_outline;
      texto = 'Sem stock actual — pode ser cotado na mesma';
    } else if (estoque <= 5) {
      cor  = c.aviso;
      icon = Icons.warning_amber_outlined;
      texto =
          'Stock baixo: $estoque unidade${estoque > 1 ? 's' : ''} disponíve${estoque > 1 ? 'is' : 'l'}';
    } else {
      cor  = c.sucesso;
      icon = Icons.inventory_2_outlined;
      texto = '$estoque unidades disponíveis';
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cor.withValues(alpha: 0.3)),
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
    final c = context.cores;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Quantidade',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: c.marca)),
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
              color: c.superficie,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.borda),
            ),
            child: Center(
              child: TextFormField(
                key: ValueKey(_quantidade),
                initialValue: _quantidade.toString(),
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: c.marca),
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
            color: c.marca.withValues(alpha: context.escuro ? 0.12 : 0.05),
            borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total estimado:',
                style:
                    TextStyle(color: c.textoSecundario, fontSize: 13)),
            Text(_currencyFmt.format(totalParcial),
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: c.marca)),
          ],
        ),
      ),
    ]);
  }

  Widget _btnQtd(
      {required IconData icon,
      required VoidCallback onTap,
      required bool habilitado}) {
    final c = context.cores;

    return Material(
      color: habilitado ? _kCotacao : c.superficieAlt,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: habilitado ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon,
              color: habilitado ? AppColors.branco : c.desactivado,
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
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.branco),
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
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              // Fundos FIXOS (verde / azul cotação) com texto branco por cima.
              backgroundColor:
                  adicionando ? Colors.green.shade700 : _kCotacao,
              foregroundColor: AppColors.branco,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 3,
            ),
          ),
        );
      },
    );
  }

  // ── Util ──────────────────────────────────────────────────────────────────
  Widget _card({required Widget child}) {
    final c = context.cores;

    return Card(
      elevation: 0,
      color: c.superficie,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(10), child: child),
    );
  }
}