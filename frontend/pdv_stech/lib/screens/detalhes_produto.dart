// ─────────────────────────────────────────────────────────────────────────────
// DetalhesProdutoScreen
// ─────────────────────────────────────────────────────────────────────────────

//detalhes_produto.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:api_compartilhado/api_config.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';

class DetalhesProdutoScreen extends StatefulWidget {
  final ProdutoModel produto;
  final List<dynamic> marcas;
  final List<dynamic> categorias;

  const DetalhesProdutoScreen({
    Key? key,
    required this.produto,
    required this.marcas,
    required this.categorias,
  }) : super(key: key);

  @override
  State<DetalhesProdutoScreen> createState() => _DetalhesProdutoScreenState();
}

class _DetalhesProdutoScreenState extends State<DetalhesProdutoScreen> {
  
  final _currencyFmt   = NumberFormat.currency(locale: 'pt_PT', symbol: 'MZN');

  int  _quantidade    = 1;
  bool _criandoPedido = false;

  final _qtdCtrl  = TextEditingController(text: '1');
  final _qtdFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _qtdFocus.addListener(() {
      if (_qtdFocus.hasFocus) {
        // Ao tocar no campo, selecciona tudo: o novo número substitui o antigo
        _qtdCtrl.selection =
            TextSelection(baseOffset: 0, extentOffset: _qtdCtrl.text.length);
      } else {
        // Ao sair do campo, corrige valores vazios ou "0"
        _sincronizarCampo();
      }
    });
  }

  @override
  void dispose() {
    _qtdCtrl.dispose();
    _qtdFocus.dispose();
    super.dispose();
  }

  /// Escreve _quantidade no campo (só quando o texto difere).
  void _sincronizarCampo() {
    final t = _quantidade.toString();
    if (_qtdCtrl.text != t) {
      _qtdCtrl.value = TextEditingValue(
        text: t,
        selection: TextSelection.collapsed(offset: t.length),
      );
    }
  }

  ProdutoModel get produto      => widget.produto;
  double get precoEfetivo       => produto.precoPromocional ?? produto.preco;
  double get totalParcial       => precoEfetivo * _quantidade;
  bool   get temPromocao        => produto.precoPromocional != null;
  bool   get semEstoque         => produto.quantidadeEstoque == 0;
PedidoModel? get _pedidoAtivo =>
    PedidoAtivoController.instance.pedidoAtivo.value ??
    context.read<PedidoProvider>().pedidoActual;

bool get _temPedidoAtivo => _pedidoAtivo != null;

bool get _edicaoCredito =>
    PedidoAtivoController.instance.edicaoCredito;

  String get nomesMarcas {
    if (produto.marcas.isEmpty) return 'Sem marca';
    return produto.marcas.map((id) {
      final m = widget.marcas.firstWhere((x) => x.idMarca == id, orElse: () => null);
      return m?.nomeMarca ?? 'ID $id';
    }).join(', ');
  }

  String get nomesCategorias {
    if (produto.categorias.isEmpty) return 'Sem categoria';
    return produto.categorias.map((id) {
      final c = widget.categorias.firstWhere((x) => x.idCategoria == id, orElse: () => null);
      return c?.nomeCategoria ?? 'ID $id';
    }).join(', ');
  }

  void _incrementar() {
    if (_quantidade < produto.quantidadeEstoque) {
      setState(() => _quantidade++);
      _sincronizarCampo();
    } else {
      _snack('Quantidade máxima em estoque atingida', Colors.orange);
    }
  }

  void _decrementar() {
    if (_quantidade > 1) {
      setState(() => _quantidade--);
      _sincronizarCampo();
    }
  }

  void _setQuantidade(int v) {
    if (v < 1) return; // campo vazio/0 enquanto digita: ignora
    if (v > produto.quantidadeEstoque) {
      _snack('Máximo disponível: ${produto.quantidadeEstoque}', Colors.orange);
      setState(() => _quantidade = produto.quantidadeEstoque);
      _sincronizarCampo(); // só reescreve o campo quando ultrapassa o limite
      return;
    }
    setState(() => _quantidade = v); // NÃO mexe no campo: o utilizador está a digitar
  }
// SUBSTITUI O MÉTODO INTEIRO:

Future<void> _adicionarAoPedido() async {
  if (_criandoPedido) return;

  // Última defesa: se, por qualquer motivo, ainda restar um pedido
  // activo já encerrado (ex.: estado antigo em memória), não abre o
  // diálogo — limpa e trata como pedido novo.
  if (_temPedidoAtivo && !_pedidoAtivo!.podeReceberNovosItens) {
    final referenciaEncerrada = _pedidoAtivo!.referencia;
    PedidoAtivoController.instance.limpar();
    context.read<PedidoProvider>().limparPedidoActual();
    if (mounted) setState(() {});
    _snack(
      'O pedido $referenciaEncerrada já foi encerrado. Um novo pedido será iniciado.',
      Colors.orange,
    );
    return;
  }

  final ok = await _dialogConfirmacao();
  if (!ok) return;

  setState(() => _criandoPedido = true);
  try {
    if (_temPedidoAtivo) {
      await context.read<PedidoProvider>().adicionarItemProduto(
        _pedidoAtivo!.idPedido,
        ItemPedidoRequestModel(
          idProduto:  produto.idProduto,
          quantidade: _quantidade,
        ),
      );
    } else {
      await context.read<PedidoProvider>().criarPedido(
        PedidoRequestModel(
          idUsuario:       SessaoService.instance.idUsuario,
          idTipoPagamento: 1,
          itensProduto: [
            ItemPedidoRequestModel(
              idProduto:  produto.idProduto,
              quantidade: _quantidade,
            ),
          ],
        ),
      );
    }

    if (!mounted) return;

    final provider = context.read<PedidoProvider>();
    if (provider.status == PedidoStatus.success) {
        context.read<ProdutoProvider>().listarAtivos(); 
        
var resultado = provider.pedidoActual!;

if (_edicaoCredito || resultado.ehCredito || resultado.estaEmDivida) {
  final atualizado = await provider.buscarPorId(resultado.idPedido);
  if (atualizado != null) {
    resultado = atualizado;
  }
}

if (_edicaoCredito || resultado.ehCredito || resultado.estaEmDivida) {
  context.read<PedidoProvider>().definirPedidoActual(resultado);

  // Importante:
  // Não recalcula os bloqueios, senão o novo item também fica bloqueado.
  PedidoAtivoController.instance.actualizarPedidoMantendoBloqueios(resultado);
} else {
  context.read<PedidoProvider>().definirPedidoActual(resultado);
  PedidoAtivoController.instance.definir(resultado);
}

_snack(
  _temPedidoAtivo
      ? '✅ Item adicionado ao pedido ${resultado.referencia}'
      : '✅ Pedido ${resultado.referencia} criado!',
  Colors.green,
);

Navigator.pop(context, resultado);
    } else {
      _snack('Erro: ${provider.errorMessage}', AppColors.vermelhoMarca);
    }
  } finally {
    if (mounted) setState(() => _criandoPedido = false);
  }
}

  Future<bool> _dialogConfirmacao() async {
    final adicionando = _temPedidoAtivo;
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              adicionando ? 'Adicionar ao Pedido' : 'Confirmar Pedido',
              style: TextStyle(color: context.cores.marca, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (adicionando) ...[
                  _dialogInfoBox(icon: Icons.shopping_cart, texto: 'Pedido activo: ${_pedidoAtivo!.referencia}', cor: context.cores.marca),
                  const SizedBox(height: 8),
                ],
                Text(produto.nomeProduto, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                _dialogRow('Quantidade', '$_quantidade'),
                _dialogRow('Preço unitário', _currencyFmt.format(precoEfetivo)),
                const Divider(height: 16),
                _dialogRow('Subtotal', _currencyFmt.format(totalParcial), bold: true),
                const SizedBox(height: 8),
                _dialogInfoBox(
                  icon: adicionando ? Icons.add_shopping_cart : Icons.info_outline,
                  texto: adicionando
                      ? 'Item adicionado ao pedido ${_pedidoAtivo!.referencia}.'
                      : 'O pedido ficará em "Por Finalizar" aguardando confirmação.',
                  cor: adicionando ? context.cores.sucesso : context.cores.info,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: adicionando ? Colors.green[700] : context.cores.marcaBotao,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(adicionando ? 'Adicionar' : 'Confirmar'),
              ),
            ],
          ),
        ) ?? false;
  }

  Widget _dialogInfoBox({required IconData icon, required String texto, required Color cor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cor.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Icon(icon, size: 15, color: cor),
        const SizedBox(width: 6),
        Expanded(child: Text(texto, style: TextStyle(fontSize: 11, color: cor))),
      ]),
    );
  }

  Widget _dialogRow(String label, String valor, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: context.cores.textoSecundario, fontSize: 12)),
          Text(valor, style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            fontSize: bold ? 15 : 13,
            color: bold ? context.cores.marca : context.cores.textoPrincipal,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cores.fundo,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 16), // ← era 16/16/16/32
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 8),
                  _buildPrecoCard(),
                  const SizedBox(height: 8),
                  _buildInfoCard(),
                  if (produto.descricao != null && produto.descricao!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildDescricaoCard(),
                  ],
                  const SizedBox(height: 8),
                  _buildEstoqueCard(),
                  if (!semEstoque) ...[
                    const SizedBox(height: 8),
                    _buildSelectorQuantidade(),
                  ],
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

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 160, // ← era 280
      pinned: true,
      backgroundColor: AppColors.azulMarca,
      foregroundColor: AppColors.branco,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.branco.withValues(alpha: 0.15), shape: BoxShape.circle),
        child: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      flexibleSpace: FlexibleSpaceBar(background: _buildImagemHero()),
    );
  }

  Widget _buildImagemHero() {
    final c = context.cores;
    if (produto.imagemPrincipalUrl == null || produto.imagemPrincipalUrl!.isEmpty) {
      return Container(
        color: c.marca.withValues(alpha: 0.15),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.inventory_2_outlined, size: 56, color: c.marca.withValues(alpha: 0.4)), // ← era 72
          const SizedBox(height: 6),
          Text('Sem imagem', style: TextStyle(color: c.marca.withValues(alpha: 0.5), fontSize: 13)),
        ]),
      );
    }
    return Image.network(
      '${ApiConfig.baseUrl}${produto.imagemPrincipalUrl}',
      fit: BoxFit.cover,
      width: double.infinity,
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : Container(color: c.superficieAlt, child: Center(child: CircularProgressIndicator(color: c.marca))),
      errorBuilder: (_, __, ___) =>
          Container(color: c.superficieAlt, child: Icon(Icons.broken_image, size: 52, color: c.desactivado)),
    );
  }

  Widget _buildHeader() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (temPromocao)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          margin: const EdgeInsets.only(bottom: 5),
          decoration: BoxDecoration(color: AppColors.vermelhoMarca, borderRadius: BorderRadius.circular(20)),
          child: const Text('🏷️ PROMOÇÃO',
              style: TextStyle(color: AppColors.branco, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
      Text(produto.nomeProduto,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.cores.marca, height: 1.2)), // ← era 22
    ]);
  }

  Widget _buildPrecoCard() {
    final c = context.cores;
    return _card(
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Preço', style: TextStyle(color: c.textoSecundario, fontSize: 11)),
          const SizedBox(height: 2),
          if (temPromocao)
            Text(_currencyFmt.format(produto.preco),
                style: TextStyle(color: c.textoSecundario, decoration: TextDecoration.lineThrough, fontSize: 13)),
          Text(_currencyFmt.format(precoEfetivo),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: temPromocao ? c.acentoTexto : c.marca)), // ← era 28
        ]),
        if (temPromocao) ...[
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: c.acento.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(Icons.local_offer, color: c.acentoTexto, size: 18),
          ),
        ],
      ]),
    );
  }

  Widget _buildInfoCard() {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Informações',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: context.cores.marca)),
        const SizedBox(height: 8),
        _infoRow(Icons.label_outline, 'Marca', nomesMarcas),
        const Divider(height: 12),
        _infoRow(Icons.category_outlined, 'Categoria', nomesCategorias),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String label, String valor) {
    return Row(children: [
      Icon(icon, size: 15, color: context.cores.marca.withValues(alpha: 0.5)),
      const SizedBox(width: 6),
      Text('$label:', style: TextStyle(color: context.cores.textoSecundario, fontSize: 12)),
      const SizedBox(width: 5),
      Expanded(
        child: Text(valor, textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
      ),
    ]);
  }

  Widget _buildDescricaoCard() {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Descrição',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: context.cores.marca)),
        const SizedBox(height: 6),
        Text(produto.descricao!,
            style: TextStyle(color: context.cores.textoSecundario, fontSize: 13, height: 1.4)),
      ]),
    );
  }

  Widget _buildEstoqueCard() {
    final c = context.cores;
    final estoque = produto.quantidadeEstoque;
    final Color cor;
    final IconData icon;
    final String texto;

    if (estoque == 0) {
      cor = c.acentoTexto; icon = Icons.remove_circle_outline; texto = 'Produto sem estoque';
    } else if (estoque <= 5) {
      cor = c.aviso; icon = Icons.warning_amber_outlined;
      texto = 'Apenas $estoque unidade${estoque > 1 ? 's' : ''} disponíve${estoque > 1 ? 'is' : 'l'}';
    } else {
      cor = c.sucesso; icon = Icons.inventory_2_outlined;
      texto = '$estoque unidades disponíveis';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // ← era 14/12
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cor.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: cor, size: 18),
        const SizedBox(width: 8),
        Text(texto, style: TextStyle(color: cor, fontWeight: FontWeight.w500, fontSize: 13)),
      ]),
    );
  }

  Widget _buildSelectorQuantidade() {
    final c = context.cores;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Quantidade',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: c.marca)),
      const SizedBox(height: 8),
      Row(children: [
        _btnQtd(icon: Icons.remove, onTap: _decrementar, habilitado: _quantidade > 1),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 44, // ← era 52
            decoration: BoxDecoration(
              color: c.superficie,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.borda),
            ),
            child: Center(
child: TextField(
  controller: _qtdCtrl,
  focusNode: _qtdFocus,
  textAlign: TextAlign.center,
  keyboardType: TextInputType.number,
  inputFormatters: [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(7),
  ],
  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.marca),
  decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
  onChanged: (v) { final n = int.tryParse(v); if (n != null) _setQuantidade(n); },
  onSubmitted: (_) => _sincronizarCampo(),
),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _btnQtd(icon: Icons.add, onTap: _incrementar, habilitado: _quantidade < produto.quantidadeEstoque),
      ]),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: c.marca.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total estimado:', style: TextStyle(color: c.textoSecundario, fontSize: 13)),
            Text(_currencyFmt.format(totalParcial),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.marca)),
          ],
        ),
      ),
    ]);
  }

  Widget _btnQtd({required IconData icon, required VoidCallback onTap, required bool habilitado}) {
    final c = context.cores;
    return Material(
      color: habilitado ? c.marcaBotao : c.superficieAlt,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: habilitado ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 44, height: 44, // ← era 52×52
          child: Icon(icon, color: habilitado ? AppColors.branco : c.desactivado, size: 20),
        ),
      ),
    );
  }

  // SUBSTITUI O MÉTODO INTEIRO:

Widget _buildBotao() {
  return ValueListenableBuilder<PedidoModel?>(
    valueListenable: PedidoAtivoController.instance.pedidoAtivo,
    builder: (_, pedidoAtivoController, __) {
      final pedidoActual =
          pedidoAtivoController ?? context.watch<PedidoProvider>().pedidoActual;

      final adicionando = pedidoActual != null;
      final edicaoCredito = PedidoAtivoController.instance.edicaoCredito;

      final label = _criandoPedido
          ? (adicionando ? 'A adicionar...' : 'A criar pedido...')
          : semEstoque
              ? 'Produto Indisponível'
              : adicionando
                  ? edicaoCredito
                      ? 'Adicionar ao crédito ${pedidoActual.referencia}'
                      : 'Adicionar ao ${pedidoActual.referencia}'
                  : 'Criar Pedido';

      final icone = _criandoPedido
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(
              semEstoque
                  ? Icons.block
                  : adicionando
                      ? Icons.add_shopping_cart
                      : Icons.shopping_cart_checkout,
            );

      return SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: semEstoque || _criandoPedido ? null : _adicionarAoPedido,
          icon: icone,
          label: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: semEstoque
                ? Colors.grey
                : adicionando
                    ? Colors.green[700]
                    : context.cores.marcaBotao,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: semEstoque ? 0 : 3,
          ),
        ),
      );
    },
  );
}

  Widget _card({required Widget child}) {
    return Card(
      elevation: 0,
      color: context.cores.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(10), child: child), // ← era 16
    );
  }
}