// ─────────────────────────────────────────────────────────────────────────────
// DetalhesProdutoScreen
// ─────────────────────────────────────────────────────────────────────────────

//detalhes_produto.dart

import 'package:flutter/material.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:api_compartilhado/api_config.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

const _kPrimary    =Color.fromARGB(255, 58, 62, 79);
const _kAccent     = Color(0xFFC8102E);
const _kBackground = Color(0xFFF4F5F7);

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
    } else {
      _snack('Quantidade máxima em estoque atingida', Colors.orange);
    }
  }

  void _decrementar() { if (_quantidade > 1) setState(() => _quantidade--); }

  void _setQuantidade(int v) {
    if (v < 1) return;
    if (v > produto.quantidadeEstoque) {
      _snack('Máximo disponível: ${produto.quantidadeEstoque}', Colors.orange);
      setState(() => _quantidade = produto.quantidadeEstoque);
      return;
    }
    setState(() => _quantidade = v);
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
      _snack('Erro: ${provider.errorMessage}', _kAccent);
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
              style: const TextStyle(color: _kPrimary, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (adicionando) ...[
                  _dialogInfoBox(icon: Icons.shopping_cart, texto: 'Pedido activo: ${_pedidoAtivo!.referencia}', cor: _kPrimary),
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
                  cor: adicionando ? Colors.green : Colors.blue,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: adicionando ? Colors.green[700] : _kPrimary,
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
        color: cor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cor.withOpacity(0.25)),
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
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          Text(valor, style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackground,
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
      backgroundColor: _kPrimary,
      foregroundColor: Colors.white,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
        child: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      flexibleSpace: FlexibleSpaceBar(background: _buildImagemHero()),
    );
  }

  Widget _buildImagemHero() {
    if (produto.imagemPrincipalUrl == null || produto.imagemPrincipalUrl!.isEmpty) {
      return Container(
        color: _kPrimary.withOpacity(0.15),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.inventory_2_outlined, size: 56, color: _kPrimary.withOpacity(0.4)), // ← era 72
          const SizedBox(height: 6),
          Text('Sem imagem', style: TextStyle(color: _kPrimary.withOpacity(0.5), fontSize: 13)),
        ]),
      );
    }
    return Image.network(
      '${ApiConfig.baseUrl}${produto.imagemPrincipalUrl}',
      fit: BoxFit.cover,
      width: double.infinity,
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : Container(color: Colors.grey[200], child: const Center(child: CircularProgressIndicator(color: _kPrimary))),
      errorBuilder: (_, __, ___) =>
          Container(color: Colors.grey[100], child: const Icon(Icons.broken_image, size: 52, color: Colors.grey)),
    );
  }

  Widget _buildHeader() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (temPromocao)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          margin: const EdgeInsets.only(bottom: 5),
          decoration: BoxDecoration(color: _kAccent, borderRadius: BorderRadius.circular(20)),
          child: const Text('🏷️ PROMOÇÃO',
              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
      Text(produto.nomeProduto,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kPrimary, height: 1.2)), // ← era 22
    ]);
  }

  Widget _buildPrecoCard() {
    return _card(
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Preço', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          const SizedBox(height: 2),
          if (temPromocao)
            Text(_currencyFmt.format(produto.preco),
                style: const TextStyle(color: Colors.grey, decoration: TextDecoration.lineThrough, fontSize: 13)),
          Text(_currencyFmt.format(precoEfetivo),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: temPromocao ? _kAccent : _kPrimary)), // ← era 28
        ]),
        if (temPromocao) ...[
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _kAccent.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.local_offer, color: _kAccent, size: 18),
          ),
        ],
      ]),
    );
  }

  Widget _buildInfoCard() {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Informações',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _kPrimary)),
        const SizedBox(height: 8),
        _infoRow(Icons.label_outline, 'Marca', nomesMarcas),
        const Divider(height: 12),
        _infoRow(Icons.category_outlined, 'Categoria', nomesCategorias),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String label, String valor) {
    return Row(children: [
      Icon(icon, size: 15, color: _kPrimary.withOpacity(0.5)),
      const SizedBox(width: 6),
      Text('$label:', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
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
        const Text('Descrição',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _kPrimary)),
        const SizedBox(height: 6),
        Text(produto.descricao!,
            style: TextStyle(color: Colors.grey[700], fontSize: 13, height: 1.4)),
      ]),
    );
  }

  Widget _buildEstoqueCard() {
    final estoque = produto.quantidadeEstoque;
    final Color cor;
    final IconData icon;
    final String texto;

    if (estoque == 0) {
      cor = _kAccent; icon = Icons.remove_circle_outline; texto = 'Produto sem estoque';
    } else if (estoque <= 5) {
      cor = Colors.orange; icon = Icons.warning_amber_outlined;
      texto = 'Apenas $estoque unidade${estoque > 1 ? 's' : ''} disponíve${estoque > 1 ? 'is' : 'l'}';
    } else {
      cor = Colors.green; icon = Icons.inventory_2_outlined;
      texto = '$estoque unidades disponíveis';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // ← era 14/12
      decoration: BoxDecoration(
        color: cor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cor.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: cor, size: 18),
        const SizedBox(width: 8),
        Text(texto, style: TextStyle(color: cor, fontWeight: FontWeight.w500, fontSize: 13)),
      ]),
    );
  }

  Widget _buildSelectorQuantidade() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Quantidade',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _kPrimary)),
      const SizedBox(height: 8),
      Row(children: [
        _btnQtd(icon: Icons.remove, onTap: _decrementar, habilitado: _quantidade > 1),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 44, // ← era 52
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
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kPrimary),
                decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
                onChanged: (v) { final n = int.tryParse(v); if (n != null) _setQuantidade(n); },
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
        decoration: BoxDecoration(color: _kPrimary.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total estimado:', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
            Text(_currencyFmt.format(totalParcial),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kPrimary)),
          ],
        ),
      ),
    ]);
  }

  Widget _btnQtd({required IconData icon, required VoidCallback onTap, required bool habilitado}) {
    return Material(
      color: habilitado ? _kPrimary : Colors.grey[200],
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: habilitado ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 44, height: 44, // ← era 52×52
          child: Icon(icon, color: habilitado ? Colors.white : Colors.grey[400], size: 20),
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
                    : _kPrimary,
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
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(10), child: child), // ← era 16
    );
  }
}

