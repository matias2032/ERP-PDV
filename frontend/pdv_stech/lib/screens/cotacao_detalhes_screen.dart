// lib/screens/cotacao_detalhes_screen.dart

import 'package:flutter/material.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';

// ─── Cores ───────────────────────────────────────────────────────────────────
// As antigas constantes foram substituídas pelo tema:
//   _kPrimary    → context.cores.marca (texto/ícone/borda)
//                  context.cores.marcaBotao (fundo de botão / cartão Total)
//                  AppColors.azulMarca / azulMarcaEscuro (AppBar)
//   _kAccent     → AppColors.vermelhoMarca (FUNDO: botão, snackbar; texto branco)
//                  context.cores.acentoTexto (vermelho como texto/ícone/borda)
//   _kBackground → context.cores.fundo
//   _kCotacao    → _kCotacaoBotao (fundo, igual nos dois temas, texto branco)
//                  context.cotacaoTexto (azul-cotação como TEXTO/ÍCONE:
//                  mais claro no tema escuro para manter contraste)
//   Colors.green → cor de sucesso fixa (snackbar) / context.cores.sucesso (texto)
//   Colors.orange→ orange.shade800 (snackbar) — texto branco por cima
//   Colors.blue  → context.cores.info
//   Colors.grey  → context.cores.textoSecundario / icone

/// Azul da cotação usado como FUNDO de botão (texto branco por cima: 5.1:1).
const _kCotacaoBotao = Color(0xFF0077B6);

/// Verde de snackbar de sucesso (fundo fixo, texto branco por cima).
const _kSnackSucesso = Color(0xFF388E3C);

/// Azul da cotação para TEXTO/ÍCONE em cada tema.
/// Escuro: 0xFF4FC3F7 → ~9:1 sobre a superfície 181C30.
extension _CotacaoCores on BuildContext {
  Color get cotacaoTexto =>
      escuro ? const Color(0xFF4FC3F7) : _kCotacaoBotao;
}

class CotacaoDetalhesScreen extends StatefulWidget {
  final CotacaoModel cotacao;
  const CotacaoDetalhesScreen({Key? key, required this.cotacao})
      : super(key: key);

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
      mensagem:
          'Deseja converter a cotação ${widget.cotacao.referencia} em pedido?',
      labelBotao: 'Converter',
      corBotao: _kCotacaoBotao,
      icone: Icons.swap_horiz,
      aviso: 'O stock será decrementado e a cotação ficará CONVERTIDA.',
      corAviso: context.cotacaoTexto,
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
        _snack('Cotação convertida no pedido ${pedido.referencia}!',
            _kSnackSucesso);
        Navigator.pop(context, 'convertida');
      } else {
        _snack('Erro: ${provider.errorMessage}', AppColors.vermelhoMarca);
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
      corBotao: context.cores.marcaBotao,
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
        _snack('Cotação reaberta para edição.', Colors.orange.shade800);
        Navigator.pop(context, 'reaberta');
      } else {
        _snack('Erro: ${provider.errorMessage}', AppColors.vermelhoMarca);
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
      corBotao: AppColors.vermelhoMarca,
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
        _snack('Cotação cancelada.', Colors.orange.shade800);
        Navigator.pop(context, 'cancelada');
      } else {
        _snack('Erro: ${provider.errorMessage}', AppColors.vermelhoMarca);
      }
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DIÁLOGOS
  // ══════════════════════════════════════════════════════════════════════════

  /// [corBotao] é usada como FUNDO do botão (texto branco por cima).
  /// [corAviso] é a cor do aviso como TEXTO/ÍCONE; se omitida, usa [corBotao].
  Future<bool> _dialogoConfirmacao({
    required String titulo,
    required String mensagem,
    required String labelBotao,
    required Color corBotao,
    required IconData icone,
    String? aviso,
    Color? corAviso,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) {
            final c = ctx.cores;
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text(titulo,
                  style: TextStyle(
                      color: c.marca, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.cotacao.referencia,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: c.marca)),
                  const SizedBox(height: 8),
                  Text(mensagem,
                      style: TextStyle(color: c.icone, fontSize: 13)),
                  if (aviso != null) ...[
                    const SizedBox(height: 10),
                    _infoBox(
                        icon: icone,
                        texto: aviso,
                        cor: corAviso ?? corBotao),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(labelBotao),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final cotacao = widget.cotacao;
    final c = context.cores;

    return Scaffold(
      backgroundColor: c.fundo,
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
    // Mesmo critério da AppBar do tema escuro (azulMarcaEscuro).
    final corBarra =
        context.escuro ? AppColors.azulMarcaEscuro : AppColors.azulMarca;

    return SliverAppBar(
      pinned: true,
      expandedHeight: 120,
      backgroundColor: corBarra,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle),
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
              colors: [corBarra, corBarra.withBlue(140)],
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
                    color: Colors.white.withValues(alpha: 0.15),
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
    final c = context.cores;

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
                  style: TextStyle(color: c.textoSecundario, fontSize: 13)),
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
    ].where((v) => v != null && v.trim().isNotEmpty).join(' ').trim();

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
        ((c.nomeClienteSingular != null &&
                c.nomeClienteSingular!.trim().isNotEmpty) ||
            (c.apelidoClienteSingular != null &&
                c.apelidoClienteSingular!.trim().isNotEmpty));
  }

  Widget _buildCardCliente(CotacaoModel cotacao) {
    final c = context.cores;
    final escuro = context.escuro;
    final nomeCliente = _nomeClienteCotacao(cotacao);
    final temCliente = _cotacaoTemCliente(cotacao);
    final ehSingular = _cotacaoEhSingular(cotacao);

    return _card(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c.marca.withValues(alpha: escuro ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              ehSingular ? Icons.person_outline : Icons.business_outlined,
              color: c.marca,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cliente',
                  style: TextStyle(fontSize: 11, color: c.textoSecundario),
                ),
                const SizedBox(height: 2),
                Text(
                  nomeCliente,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: temCliente ? c.marca : c.textoSecundario,
                  ),
                ),
                if (temCliente && ehSingular) ...[
                  const SizedBox(height: 3),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: c.textoSecundario
                          .withValues(alpha: escuro ? 0.18 : 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Cliente singular',
                      style: TextStyle(
                        fontSize: 10,
                        color: c.textoSecundario,
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
    final c = context.cores;
    final validade = cotacao.validadeAte!;
    final expirou = validade.isBefore(DateTime.now());
    final cor = expirou ? c.acentoTexto : c.sucesso;

    return _card(
      child: Row(children: [
        Icon(Icons.event_outlined, color: cor, size: 20),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Validade',
                style: TextStyle(fontSize: 11, color: c.textoSecundario)),
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
              color: c.acentoTexto
                  .withValues(alpha: context.escuro ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Expirada',
                style: TextStyle(
                    color: c.acentoTexto,
                    fontSize: 11,
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
        // marcaBotao = azul da marca no claro; azul mais vivo no escuro
        // (o azulMarcaEscuro quase não se distinguiria do fundo).
        color: context.cores.marcaBotao,
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
    final c = context.cores;

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
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.swap_horiz),
            label: const Text('Converter em Pedido',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kCotacaoBotao,
              foregroundColor: Colors.white,
              // Estado desactivado explícito: o spinner branco tem de
              // continuar visível em ambos os temas enquanto processa.
              disabledBackgroundColor: _kCotacaoBotao.withValues(alpha: 0.6),
              disabledForegroundColor: Colors.white70,
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
                foregroundColor: c.marca,
                side: BorderSide(color: c.marca),
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
                foregroundColor: c.acentoTexto,
                side: BorderSide(color: c.acentoTexto),
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
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(config.$2, size: 10, color: Colors.white),
        const SizedBox(width: 4),
        Text(config.$3,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold)),
      ]),
    );
  }

  (Color, IconData, String) _statusConfig(String status) => switch (status) {
        'ABERTA' => (_kCotacaoBotao, Icons.radio_button_on, 'Aberta'),
        'PRONTA' => (Colors.teal, Icons.check_circle_outline, 'Pronta'),
        'CONVERTIDA' => (AppColors.azulMarca, Icons.swap_horiz, 'Convertida'),
        'CANCELADA' =>
          (AppColors.vermelhoMarca, Icons.cancel_outlined, 'Cancelada'),
        'EXPIRADA' => (Colors.grey, Icons.timer_off_outlined, 'Expirada'),
        _ => (Colors.grey, Icons.help_outline, status),
      };

  Widget _card({required Widget child}) => Card(
        elevation: 0,
        color: context.cores.superficie,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(padding: const EdgeInsets.all(14), child: child),
      );

  Widget _secLabel(IconData icon, String texto) {
    final c = context.cores;
    return Row(children: [
      Icon(icon, size: 14, color: c.marca),
      const SizedBox(width: 6),
      Text(texto,
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 13, color: c.marca)),
    ]);
  }

  Widget _sectionLabel(IconData icon, String texto) {
    final c = context.cores;
    return Row(children: [
      Icon(icon, size: 13, color: c.marca.withValues(alpha: 0.5)),
      const SizedBox(width: 5),
      Text(texto,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c.textoSecundario)),
    ]);
  }

  Widget _linhaItemProduto(CotacaoItemProdutoModel item) {
    final c = context.cores;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
              color: c.marca.withValues(alpha: context.escuro ? 0.15 : 0.07),
              borderRadius: BorderRadius.circular(6)),
          child: Text('${item.quantidade}×',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: c.marca)),
        ),
        const SizedBox(width: 8),
        Expanded(
            child: Text(item.nomeProduto ?? 'Produto #${item.idProduto}',
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis)),
        Text(_currencyFmt.format(item.subtotal),
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500, color: c.marca)),
      ]),
    );
  }

  Widget _linhaItemServico(CotacaoItemServicoModel item) {
    final c = context.cores;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
              color: c.info.withValues(alpha: context.escuro ? 0.15 : 0.07),
              borderRadius: BorderRadius.circular(6)),
          child: Text('${item.quantidade}×',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: c.info)),
        ),
        const SizedBox(width: 8),
        Expanded(
            child: Text(item.nomeServico ?? 'Serviço #${item.idServico}',
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis)),
        Text(_currencyFmt.format(item.subtotal),
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500, color: c.marca)),
      ]),
    );
  }

  Widget _infoBox(
          {required IconData icon,
          required String texto,
          required Color cor}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: context.escuro ? 0.12 : 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cor.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Icon(icon, size: 15, color: cor),
          const SizedBox(width: 7),
          Expanded(
              child: Text(texto, style: TextStyle(fontSize: 11, color: cor))),
        ]),
      );

  /// Fundo colorido FIXO + texto branco explícito: sem isso, no tema escuro
  /// o texto herdaria `textoPrincipal` (claro) e perderia contraste.
  void _snack(String msg, Color cor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: cor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}