// lib/screens/cotacao_detalhes_servico.dart

import 'package:flutter/material.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';


const _kPrimary    = Color(0xFF1B2A6B);
const _kAccent     = Color.fromARGB(255, 200, 16, 46);
const _kBackground = Color(0xFFF4F5F7);
const _kCotacao    = Color(0xFF0077B6);

class CotacaoDetalhesServicoScreen extends StatefulWidget {
  final ServicoModel servico;
  const CotacaoDetalhesServicoScreen({Key? key, required this.servico})
      : super(key: key);

  @override
  State<CotacaoDetalhesServicoScreen> createState() =>
      _CotacaoDetalhesServicoScreenState();
}

class _CotacaoDetalhesServicoScreenState
    extends State<CotacaoDetalhesServicoScreen> {
  final _currencyFmt = NumberFormat.currency(locale: 'pt_PT', symbol: 'MZN');
  final _obsCtrl     = TextEditingController();

  int  _quantidade  = 1;
  bool _processando = false;

@override
void initState() {
  super.initState();
  CotacaoAtivaController.instance.limparSeNaoAberta();
  WidgetsBinding.instance.addPostFrameCallback((_) => _sincronizarCotacaoAtiva());
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
    CotacaoAtivaController.instance.limpar();
  }
}

  ServicoModel get servico  => widget.servico;
  double get totalParcial   => servico.precoUnitario * _quantidade;

  CotacaoModel? get _cotacaoAtiva =>
      CotacaoAtivaController.instance.cotacaoAtiva.value;
bool get _temCotacaoAtiva => _cotacaoAtiva != null && _cotacaoAtiva!.estaAberta;
  @override
  void dispose() {
    _obsCtrl.dispose();
    super.dispose();
  }

  void _incrementar()        => setState(() => _quantidade++);
  void _decrementar()        { if (_quantidade > 1) setState(() => _quantidade--); }
  void _setQuantidade(int v) { if (v >= 1) setState(() => _quantidade = v); }

  // ── Acção principal ───────────────────────────────────────────────────────
Future<void> _adicionarACotacao() async {
  if (_processando) return;
    final ok = await _dialogConfirmacao();
  if (!ok) return;
    setState(() => _processando = true);
    try {
      final cotacaoProvider = context.read<CotacaoProvider>();
      final obs = _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim();

      if (_temCotacaoAtiva) {
        // ── Adiciona à cotação activa ────────────────────────────────────
        final cotacaoActualizada = await cotacaoProvider.adicionarServico(
          _cotacaoAtiva!.idCotacao,
          AdicionarServicoCotacaoRequestModel(
            idServico:   servico.idServico,
            quantidade:  _quantidade,
            observacoes: obs,
          ),
        );
        if (!mounted) return;

        if (cotacaoProvider.status == CotacaoStatus.success &&
            cotacaoActualizada != null) {
          CotacaoAtivaController.instance.definir(cotacaoActualizada);
          _snack(
            '✅ Serviço adicionado à cotação ${cotacaoActualizada.referencia}',
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
          _snack(
              'Erro ao criar cotação: ${cotacaoProvider.errorMessage}', _kAccent);
          return;
        }

        final cotacaoComItem = await cotacaoProvider.adicionarServico(
          novaCotacao.idCotacao,
          AdicionarServicoCotacaoRequestModel(
            idServico:   servico.idServico,
            quantidade:  _quantidade,
            observacoes: obs,
          ),
        );
        if (!mounted) return;

        final cotacaoFinal = cotacaoComItem ?? novaCotacao;
        CotacaoAtivaController.instance.definir(cotacaoFinal);

        _snack('✅ Cotação ${cotacaoFinal.referencia} criada!', _kCotacao);
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
              _temCotacaoAtiva ? 'Adicionar à Cotação' : 'Nova Cotação',
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
                    texto: 'Cotação activa: ${_cotacaoAtiva!.referencia}',
                    cor: _kCotacao,
                  ),
                  const SizedBox(height: 8),
                ],
                Text(servico.nomeServico,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                _dialogRow(
                  'Quantidade',
                  '$_quantidade ${servico.unidade}${_quantidade > 1 ? 's' : ''}',
                ),
                _dialogRow(
                  'Preço por ${servico.unidade}',
                  _currencyFmt.format(servico.precoUnitario),
                ),
                const Divider(height: 16),
                _dialogRow('Subtotal', _currencyFmt.format(totalParcial),
                    bold: true),
                if (_obsCtrl.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _dialogInfoBox(
                    icon: Icons.notes,
                    texto: 'Obs: ${_obsCtrl.text.trim()}',
                    cor: Colors.grey,
                  ),
                ],
                const SizedBox(height: 8),
                _dialogInfoBox(
                  icon: _temCotacaoAtiva
                      ? Icons.add_shopping_cart
                      : Icons.request_quote_outlined,
                  texto: _temCotacaoAtiva
                      ? 'Item adicionado à cotação ${_cotacaoAtiva!.referencia}.'
                      : 'Uma nova cotação será criada com este serviço.',
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
                  if (servico.descricao != null &&
                      servico.descricao!.isNotEmpty) ...[
                    _buildDescricaoCard(),
                    const SizedBox(height: 8),
                  ],
                  _buildSelectorQuantidade(),
                  const SizedBox(height: 8),
                  _buildObservacoes(),
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
      pinned: true,
      expandedHeight: 120,
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
      // Chip de cotação activa (espelho do detalhes_produto de cotação)
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
              child:
                  Row(mainAxisSize: MainAxisSize.min, children: [
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
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(56, 0, 16, 14),
        title: Text(
          servico.nomeServico,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_kPrimary, _kPrimary.withBlue(140)],
            ),
          ),
          child: Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  shape: BoxShape.circle),
              child: const Icon(Icons.miscellaneous_services,
                  size: 30, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: Text(servico.nomeServico,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _kPrimary,
                height: 1.2)),
      ),
      const SizedBox(width: 8),
      Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _kPrimary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kPrimary.withOpacity(0.2)),
        ),
        child: Text(servico.unidade,
            style: const TextStyle(
                fontSize: 11,
                color: _kPrimary,
                fontWeight: FontWeight.w600)),
      ),
    ]);
  }

  // ── Cards de detalhe ──────────────────────────────────────────────────────
  Widget _buildPrecoCard() {
    return _card(
      child: Row(children: [
        Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Preço por ${servico.unidade}',
                  style: TextStyle(
                      color: Colors.grey[500], fontSize: 11)),
              const SizedBox(height: 2),
              Text(_currencyFmt.format(servico.precoUnitario),
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _kPrimary)),
            ]),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: _kPrimary.withOpacity(0.08),
              shape: BoxShape.circle),
          child: const Icon(Icons.attach_money,
              color: _kPrimary, size: 20),
        ),
      ]),
    );
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
            Text(servico.descricao!,
                style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 13,
                    height: 1.4)),
          ]),
    );
  }

  // ── Selector de quantidade ────────────────────────────────────────────────
  Widget _buildSelectorQuantidade() {
    return _card(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.straighten, size: 14, color: _kPrimary),
              const SizedBox(width: 5),
              Text('Quantidade de ${servico.unidade}s',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: _kPrimary)),
            ]),
            const SizedBox(height: 2),
            Text(
              'Ex: 4 × ${_currencyFmt.format(servico.precoUnitario)} = ${_currencyFmt.format(servico.precoUnitario * 4)}',
              style:
                  TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
            const SizedBox(height: 10),
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
                    color: _kBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _kPrimary.withOpacity(0.2)),
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
              _btnQtd(
                  icon: Icons.add,
                  onTap: _incrementar,
                  habilitado: true),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total estimado:',
                      style: TextStyle(
                          color: Colors.grey[700], fontSize: 13)),
                  Text(_currencyFmt.format(totalParcial),
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _kPrimary)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.info_outline,
                  size: 11, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                    'Serviços não têm limite de quantidade.',
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey[400])),
              ),
            ]),
          ]),
    );
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

  // ── Observações ───────────────────────────────────────────────────────────
  Widget _buildObservacoes() {
    return _card(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Observações',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: _kPrimary)),
            const SizedBox(height: 2),
            Text(
                'Opcional — ex: papel A4, cores, instruções especiais.',
                style: TextStyle(
                    fontSize: 11, color: Colors.grey[500])),
            const SizedBox(height: 8),
            TextField(
              controller: _obsCtrl,
              maxLines: 2,
              maxLength: 150,
              decoration: InputDecoration(
                hintText: 'Escreva aqui…',
                hintStyle: TextStyle(
                    color: Colors.grey[400], fontSize: 12),
                filled: true,
                fillColor: _kBackground,
                contentPadding: const EdgeInsets.all(10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: _kPrimary.withOpacity(0.15)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: _kPrimary.withOpacity(0.15)),
                ),
              ),
            ),
          ]),
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
      child:
          Padding(padding: const EdgeInsets.all(10), child: child),
    );
  }
}