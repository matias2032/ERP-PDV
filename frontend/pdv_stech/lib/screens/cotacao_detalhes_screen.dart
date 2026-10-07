// lib/screens/cotacao_detalhes_screen.dart

import 'package:flutter/material.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

const _kPrimary    = Color(0xFF1B2A6B);
const _kAccent     = Color(0xFFC8102E);
const _kBackground = Color(0xFFF4F5F7);
const _kCotacao    = Color(0xFF0077B6);

class CotacaoDetalhesScreen extends StatefulWidget {
  final CotacaoModel cotacao;
  const CotacaoDetalhesScreen({Key? key, required this.cotacao}) : super(key: key);

  @override
  State<CotacaoDetalhesScreen> createState() => _CotacaoDetalhesScreenState();
}

class _CotacaoDetalhesScreenState extends State<CotacaoDetalhesScreen> {
  final _currencyFmt = NumberFormat.currency(locale: 'pt_PT', symbol: 'MZN');
  bool _processando = false;

  // ══════════════════════════════════════════════════════════════════════════
  // ACÇÕES
  // ══════════════════════════════════════════════════════════════════════════

Future<void> _converter() async {
  if (_processando) return;
  final ok = await _dialogoConfirmacao(
    titulo: 'Converter em Pedido',
    mensagem: 'Deseja converter a cotação ${widget.cotacao.referencia} em pedido?',
    labelBotao: 'Converter',
    corBotao: _kCotacao,
    icone: Icons.swap_horiz,
    aviso: 'O stock será decrementado e a cotação ficará CONVERTIDA.',
  );
  if (!ok) return;

  setState(() => _processando = true);
  try {
final pedido = await context.read<CotacaoProvider>().converterEmPedido(
  widget.cotacao.idCotacao,
  ConverterCotacaoEmPedidoRequestModel(
    idTipoPagamento: 1,
    idCliente: widget.cotacao.idCliente,
    nomeClienteSingular: widget.cotacao.nomeClienteSingular,
    apelidoClienteSingular: widget.cotacao.apelidoClienteSingular,
  ),
);
    if (!mounted) return;

    final provider = context.read<CotacaoProvider>();
    if (pedido != null && provider.status == CotacaoStatus.success) {
      // ← LINHA ADICIONADA
      CotacaoAtivaController.instance.limpar();
      _snack('Cotação convertida no pedido ${pedido.referencia}!', Colors.green);
      Navigator.pop(context, 'convertida');
    } else {
      _snack('Erro: ${provider.errorMessage}', _kAccent);
    }
  } finally {
    if (mounted) setState(() => _processando = false);
  }
}

  Future<void> _reabrir() async {
    if (_processando) return;
    final ok = await _dialogoConfirmacao(
      titulo: 'Reabrir Cotação',
      mensagem: 'A cotação voltará para ABERTA e poderá ser editada novamente.',
      labelBotao: 'Reabrir',
      corBotao: _kPrimary,
      icone: Icons.edit_outlined,
    );
    if (!ok) return;

    setState(() => _processando = true);
    try {
      await context.read<CotacaoProvider>().atualizarCotacao(
        widget.cotacao.idCotacao,
        const AtualizarCotacaoRequestModel(statusCotacao: 'ABERTA'),
      );
      if (!mounted) return;

      final provider = context.read<CotacaoProvider>();
      if (provider.status == CotacaoStatus.success) {
        _snack('Cotação reaberta para edição.', Colors.orange);
        Navigator.pop(context, 'reaberta');
      } else {
        _snack('Erro: ${provider.errorMessage}', _kAccent);
      }
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

Future<void> _cancelar() async {
  if (_processando) return;
  final ok = await _dialogoConfirmacao(
    titulo: 'Cancelar Cotação',
    mensagem: 'A cotação ficará CANCELADA e não poderá ser editada.',
    labelBotao: 'Cancelar Cotação',
    corBotao: _kAccent,
    icone: Icons.cancel_outlined,
  );
  if (!ok) return;

  setState(() => _processando = true);
  try {
    await context.read<CotacaoProvider>().atualizarCotacao(
      widget.cotacao.idCotacao,
      const AtualizarCotacaoRequestModel(statusCotacao: 'CANCELADA'),
    );
    if (!mounted) return;

    final provider = context.read<CotacaoProvider>();
    if (provider.status == CotacaoStatus.success) {
      // ← LINHA ADICIONADA
      CotacaoAtivaController.instance.limpar();
      _snack('Cotação cancelada.', Colors.orange);
      Navigator.pop(context, 'cancelada');
    } else {
      _snack('Erro: ${provider.errorMessage}', _kAccent);
    }
  } finally {
    if (mounted) setState(() => _processando = false);
  }
}

  // ══════════════════════════════════════════════════════════════════════════
  // DIÁLOGOS
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> _dialogoConfirmacao({
    required String titulo,
    required String mensagem,
    required String labelBotao,
    required Color corBotao,
    required IconData icone,
    String? aviso,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(titulo,
                style: const TextStyle(color: _kPrimary, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.cotacao.referencia,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: _kPrimary)),
                const SizedBox(height: 8),
                Text(mensagem, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                if (aviso != null) ...[
                  const SizedBox(height: 10),
                  _infoBox(icon: icone, texto: aviso, cor: corBotao),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Voltar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: corBotao,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(labelBotao),
              ),
            ],
          ),
        ) ??
        false;
  }



  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final cotacao = widget.cotacao;

    return Scaffold(
      backgroundColor: _kBackground,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(cotacao),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCardResumo(cotacao),
                  const SizedBox(height: 10),
                  _buildCardCliente(cotacao),
                  const SizedBox(height: 10),
                  if (cotacao.validadeAte != null) ...[
                    _buildCardValidade(cotacao),
                    const SizedBox(height: 10),
                  ],
                  _buildCardTotal(cotacao),
                  const SizedBox(height: 20),
                  _buildBotoes(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  Widget _buildAppBar(CotacaoModel cotacao) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 120,
      backgroundColor: _kPrimary,
      foregroundColor: Colors.white,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
        child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_kPrimary, _kPrimary.withBlue(140)],
            ),
          ),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.check_circle_outline,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cotacao.referencia,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    _buildBadge('PRONTA'),
                  ],
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ── Cards ─────────────────────────────────────────────────────────────────

  Widget _buildCardResumo(CotacaoModel cotacao) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _secLabel(Icons.receipt_outlined, 'Itens da Cotação'),
          const SizedBox(height: 10),
          if (cotacao.itensProduto.isNotEmpty) ...[
            _sectionLabel(Icons.inventory_2_outlined, 'Produtos'),
            const SizedBox(height: 6),
            ...cotacao.itensProduto.map(_linhaItemProduto),
            const SizedBox(height: 8),
          ],
          if (cotacao.itensServico.isNotEmpty) ...[
            _sectionLabel(Icons.miscellaneous_services_outlined, 'Serviços'),
            const SizedBox(height: 6),
            ...cotacao.itensServico.map(_linhaItemServico),
          ],
          if (!cotacao.temItens)
            Center(
              child: Text('Sem itens',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13)),
            ),
        ],
      ),
    );
  }

  String _nomeClienteCotacao(CotacaoModel c) {
  if (c.nomeCliente != null && c.nomeCliente!.trim().isNotEmpty) {
    return c.nomeCliente!.trim();
  }

  final nomeSingular = [
    c.nomeClienteSingular,
    c.apelidoClienteSingular,
  ]
      .where((v) => v != null && v.trim().isNotEmpty)
      .join(' ')
      .trim();

  if (nomeSingular.isNotEmpty) {
    return nomeSingular;
  }

  return 'Sem cliente associado';
}

bool _cotacaoTemCliente(CotacaoModel c) {
  return _nomeClienteCotacao(c) != 'Sem cliente associado';
}

bool _cotacaoEhSingular(CotacaoModel c) {
  return (c.nomeCliente == null || c.nomeCliente!.trim().isEmpty) &&
      ((c.nomeClienteSingular != null && c.nomeClienteSingular!.trim().isNotEmpty) ||
          (c.apelidoClienteSingular != null && c.apelidoClienteSingular!.trim().isNotEmpty));
}

Widget _buildCardCliente(CotacaoModel cotacao) {
  final nomeCliente = _nomeClienteCotacao(cotacao);
  final temCliente = _cotacaoTemCliente(cotacao);
  final ehSingular = _cotacaoEhSingular(cotacao);

  return _card(
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _kPrimary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            ehSingular ? Icons.person_outline : Icons.business_outlined,
            color: _kPrimary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cliente',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 2),
              Text(
                nomeCliente,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: temCliente ? _kPrimary : Colors.grey,
                ),
              ),
              if (temCliente && ehSingular) ...[
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Cliente singular',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

  Widget _buildCardValidade(CotacaoModel cotacao) {
    final validade = cotacao.validadeAte!;
    final expirou  = validade.isBefore(DateTime.now());
    final cor      = expirou ? _kAccent : Colors.green;

    return _card(
      child: Row(children: [
        Icon(Icons.event_outlined, color: cor, size: 20),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Validade',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
            Text(
              '${validade.day.toString().padLeft(2, '0')}/'
              '${validade.month.toString().padLeft(2, '0')}/'
              '${validade.year}',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: cor),
            ),
          ],
        ),
        if (expirou) ...[
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _kAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Expirada',
                style: TextStyle(color: _kAccent, fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ]),
    );
  }

  Widget _buildCardTotal(CotacaoModel cotacao) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kPrimary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Total',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
          Text(
            _currencyFmt.format(cotacao.total),
            style: const TextStyle(
                color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ── Botões ────────────────────────────────────────────────────────────────

  Widget _buildBotoes() {
    return Column(
      children: [
        // Converter em Pedido
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _processando ? null : _converter,
            icon: _processando
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.swap_horiz),
            label: const Text('Converter em Pedido',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kCotacao,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 3,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          // Reabrir
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _processando ? null : _reabrir,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Reabrir'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kPrimary,
                side: const BorderSide(color: _kPrimary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Cancelar
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _processando ? null : _cancelar,
              icon: const Icon(Icons.cancel_outlined, size: 16),
              label: const Text('Cancelar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kAccent,
                side: const BorderSide(color: _kAccent),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ]),
      ],
    );
  }

  // ── Helpers de UI ─────────────────────────────────────────────────────────

  Widget _buildBadge(String status) {
    final config = _statusConfig(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(config.$2, size: 10, color: Colors.white),
        const SizedBox(width: 4),
        Text(config.$3,
            style: const TextStyle(
                color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  (Color, IconData, String) _statusConfig(String status) => switch (status) {
    'ABERTA'     => (_kCotacao,     Icons.radio_button_on,      'Aberta'),
    'PRONTA'     => (Colors.teal,   Icons.check_circle_outline, 'Pronta'),
    'CONVERTIDA' => (_kPrimary,     Icons.swap_horiz,           'Convertida'),
    'CANCELADA'  => (_kAccent,      Icons.cancel_outlined,      'Cancelada'),
    'EXPIRADA'   => (Colors.grey,   Icons.timer_off_outlined,   'Expirada'),
    _            => (Colors.grey,   Icons.help_outline,         status),
  };

  Widget _card({required Widget child}) => Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(padding: const EdgeInsets.all(14), child: child),
      );

  Widget _secLabel(IconData icon, String texto) => Row(children: [
        Icon(icon, size: 14, color: _kPrimary),
        const SizedBox(width: 6),
        Text(texto,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13, color: _kPrimary)),
      ]);

  Widget _sectionLabel(IconData icon, String texto) => Row(children: [
        Icon(icon, size: 13, color: _kPrimary.withOpacity(0.5)),
        const SizedBox(width: 5),
        Text(texto,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600])),
      ]);

  Widget _linhaItemProduto(CotacaoItemProdutoModel item) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(6)),
            child: Text('${item.quantidade}×',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: _kPrimary)),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Text(item.nomeProduto ?? 'Produto #${item.idProduto}',
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis)),
          Text(_currencyFmt.format(item.subtotal),
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500, color: _kPrimary)),
        ]),
      );

  Widget _linhaItemServico(CotacaoItemServicoModel item) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.07),
                borderRadius: BorderRadius.circular(6)),
            child: Text('${item.quantidade}×',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Text(item.nomeServico ?? 'Serviço #${item.idServico}',
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis)),
          Text(_currencyFmt.format(item.subtotal),
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500, color: _kPrimary)),
        ]),
      );

  Widget _infoBox({required IconData icon, required String texto, required Color cor}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: cor.withOpacity(0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cor.withOpacity(0.25)),
        ),
        child: Row(children: [
          Icon(icon, size: 15, color: cor),
          const SizedBox(width: 7),
          Expanded(child: Text(texto, style: TextStyle(fontSize: 11, color: cor))),
        ]),
      );

  void _snack(String msg, Color cor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: cor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}