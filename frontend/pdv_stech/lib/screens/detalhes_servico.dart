//detalhes_servico.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:intl/intl.dart';
import 'package:api_compartilhado/api_config.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';

class DetalhesServicoScreen extends StatefulWidget {
  final ServicoModel servico;
  const DetalhesServicoScreen({Key? key, required this.servico}) : super(key: key);

  @override
  State<DetalhesServicoScreen> createState() => _DetalhesServicoScreenState();
}

class _DetalhesServicoScreenState extends State<DetalhesServicoScreen> {
    final _currencyFmt   = NumberFormat.currency(locale: 'pt_PT', symbol: 'MZN');
  final _obsCtrl       = TextEditingController();

  int  _quantidade    = 1;
  bool _criandoPedido = false;

  final _qtdCtrl  = TextEditingController(text: '1');
  final _qtdFocus = FocusNode();

  ServicoModel get servico      => widget.servico;
  double get totalParcial       => servico.precoUnitario * _quantidade;
PedidoModel? get _pedidoAtivo =>
    PedidoAtivoController.instance.pedidoAtivo.value ??
    context.read<PedidoProvider>().pedidoActual;

bool get _temPedidoAtivo => _pedidoAtivo != null;

bool get _edicaoCredito =>
    PedidoAtivoController.instance.edicaoCredito;
  @override
  void initState() {
    super.initState();
    _qtdFocus.addListener(() {
      if (_qtdFocus.hasFocus) {
        _qtdCtrl.selection =
            TextSelection(baseOffset: 0, extentOffset: _qtdCtrl.text.length);
      } else {
        _sincronizarCampo();
      }
    });
  }

  @override
  void dispose() {
    _obsCtrl.dispose();
    _qtdCtrl.dispose();
    _qtdFocus.dispose();
    super.dispose();
  }

  void _sincronizarCampo() {
    final t = _quantidade.toString();
    if (_qtdCtrl.text != t) {
      _qtdCtrl.value = TextEditingValue(
        text: t,
        selection: TextSelection.collapsed(offset: t.length),
      );
    }
  }

  void _incrementar() {
    setState(() => _quantidade++);
    _sincronizarCampo();
  }

  void _decrementar() {
    if (_quantidade > 1) {
      setState(() => _quantidade--);
      _sincronizarCampo();
    }
  }

  void _setQuantidade(int v) {
    if (v >= 1) setState(() => _quantidade = v); // não mexe no campo enquanto digita
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
      await context.read<PedidoProvider>().adicionarItemServico(
        _pedidoAtivo!.idPedido,
        ItemServicoRequestModel(
          idServico:   servico.idServico,
          quantidade:  _quantidade,
          observacoes: _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
        ),
      );
    } else {
      await context.read<PedidoProvider>().criarPedido(
        PedidoRequestModel(
          idUsuario:       SessaoService.instance.idUsuario,
          idTipoPagamento: 1,
          itensServico: [
            ItemServicoRequestModel(
              idServico:   servico.idServico,
              quantidade:  _quantidade,
              observacoes: _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
            ),
          ],
        ),
      );
    }

    if (!mounted) return;

    final provider = context.read<PedidoProvider>();
    if (provider.status == PedidoStatus.success) {
var resultado = provider.pedidoActual!;

if (_edicaoCredito || resultado.ehCredito || resultado.estaEmDivida) {
  final atualizado = await provider.buscarPorId(resultado.idPedido);
  if (atualizado != null) {
    resultado = atualizado;
  }
}
if (_edicaoCredito || resultado.ehCredito || resultado.estaEmDivida) {
  context.read<PedidoProvider>().definirPedidoActual(resultado);

  // Mantém bloqueados apenas os itens que já existiam antes da edição.
  PedidoAtivoController.instance.actualizarPedidoMantendoBloqueios(resultado);
} else {
  context.read<PedidoProvider>().definirPedidoActual(resultado);
  PedidoAtivoController.instance.definir(resultado);
}

_snack(
  _temPedidoAtivo
      ? '✅ Serviço adicionado ao pedido ${resultado.referencia}'
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
                Text(servico.nomeServico, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                _dialogRow('Quantidade', '$_quantidade ${servico.unidade}${_quantidade > 1 ? 's' : ''}'),
                _dialogRow('Preço por ${servico.unidade}', _currencyFmt.format(servico.precoUnitario)),
                const Divider(height: 16),
                _dialogRow('Subtotal', _currencyFmt.format(totalParcial), bold: true),
                if (_obsCtrl.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _dialogInfoBox(icon: Icons.notes, texto: 'Obs: ${_obsCtrl.text.trim()}', cor: context.cores.textoSecundario),
                ],
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
              // ← padding reduzido
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 8),   // ← era 14
                  _buildPrecoCard(),
                  const SizedBox(height: 8),   // ← era 12
                  if (servico.descricao != null && servico.descricao!.isNotEmpty) ...[
                    _buildDescricaoCard(),
                    const SizedBox(height: 8),
                  ],
                  _buildSelectorQuantidade(),
                  const SizedBox(height: 8),   // ← era 12
                  _buildObservacoes(),
                  const SizedBox(height: 14),  // ← era 24
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
      pinned: true,
      expandedHeight: 120, // ← era 180
      backgroundColor: AppColors.azulMarca,
      foregroundColor: AppColors.branco,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.branco.withValues(alpha: 0.15), shape: BoxShape.circle),
        child: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(56, 0, 16, 14),
        title: Text(servico.nomeServico,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.branco),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [AppColors.azulMarca, AppColors.azulMarca.withBlue(140)],
            ),
          ),
          child: Center(
            child: Container(
              width: 56, height: 56, // ← era 80×80
              decoration: BoxDecoration(color: AppColors.branco.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: const Icon(Icons.miscellaneous_services, size: 30, color: AppColors.branco), // ← era 42
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final c = context.cores;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: Text(servico.nomeServico,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.marca, height: 1.2)), // ← era 22
      ),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: c.marca.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.marca.withValues(alpha: 0.2)),
        ),
        child: Text(servico.unidade,
            style: TextStyle(fontSize: 11, color: c.marca, fontWeight: FontWeight.w600)),
      ),
    ]);
  }

  Widget _buildPrecoCard() {
    final c = context.cores;
    return _card(
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Preço por ${servico.unidade}', style: TextStyle(color: c.textoSecundario, fontSize: 11)),
          const SizedBox(height: 2),
          Text(_currencyFmt.format(servico.precoUnitario),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: c.marca)), // ← era 28
        ]),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: c.marca.withValues(alpha: 0.08), shape: BoxShape.circle),
          child: Icon(Icons.attach_money, color: c.marca, size: 20), // ← era 24
        ),
      ]),
    );
  }

  Widget _buildDescricaoCard() {
    final c = context.cores;
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Descrição',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: c.marca)),
        const SizedBox(height: 6),
        Text(servico.descricao!,
            style: TextStyle(color: c.textoSecundario, fontSize: 13, height: 1.4)),
      ]),
    );
  }

  Widget _buildSelectorQuantidade() {
    final c = context.cores;
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.straighten, size: 14, color: c.marca),
          const SizedBox(width: 5),
          Text('Quantidade de ${servico.unidade}s',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: c.marca)),
        ]),
        const SizedBox(height: 2),
        Text(
          'Ex: 4 × ${_currencyFmt.format(servico.precoUnitario)} = ${_currencyFmt.format(servico.precoUnitario * 4)}',
          style: TextStyle(color: c.textoSecundario, fontSize: 11),
        ),
        const SizedBox(height: 10), // ← era 14

        Row(children: [
          _btnQtd(icon: Icons.remove, onTap: _decrementar, habilitado: _quantidade > 1),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 44, // ← era 52
              decoration: BoxDecoration(
                color: c.fundo,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.marca.withValues(alpha: 0.2)),
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
          _btnQtd(icon: Icons.add, onTap: _incrementar, habilitado: true),
        ]),
        const SizedBox(height: 10), // ← era 14

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // ← era 16/12
          decoration: BoxDecoration(
            color: c.marca.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total estimado:', style: TextStyle(color: c.textoSecundario, fontSize: 13)),
              Text(_currencyFmt.format(totalParcial),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.marca)), // ← era 18
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.info_outline, size: 11, color: c.desactivado),
          const SizedBox(width: 4),
          Expanded(
            child: Text('Serviços não têm limite de quantidade.',
                style: TextStyle(fontSize: 10, color: c.textoSecundario)),
          ),
        ]),
      ]),
    );
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

  Widget _buildObservacoes() {
    final c = context.cores;
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Observações',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: c.marca)),
        const SizedBox(height: 2),
        Text('Opcional — ex: papel A4, cores, instruções especiais.',
            style: TextStyle(fontSize: 11, color: c.textoSecundario)),
        const SizedBox(height: 8),
        TextField(
          controller: _obsCtrl,
          maxLines: 2,       // ← era 3
          maxLength: 150,    // ← era 200
          decoration: InputDecoration(
            hintText: 'Escreva aqui…',
            hintStyle: TextStyle(color: c.textoSecundario, fontSize: 12),
            filled: true,
            fillColor: c.fundo,
            contentPadding: const EdgeInsets.all(10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: c.marca.withValues(alpha: 0.15)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: c.marca.withValues(alpha: 0.15)),
            ),
          ),
        ),
      ]),
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
              adicionando
                  ? Icons.add_shopping_cart
                  : Icons.shopping_cart_checkout,
            );

      return SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: _criandoPedido ? null : _adicionarAoPedido,
          icon: icone,
          label: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: adicionando ? Colors.green[700] : context.cores.marcaBotao,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 3,
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