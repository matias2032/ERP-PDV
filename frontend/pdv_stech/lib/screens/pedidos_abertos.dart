// lib/screens/pedidos_abertos.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import 'finalizar_pedido.dart';
import 'devolucao_troca_screen.dart';

class PedidosAbertosScreen extends StatefulWidget {
  const PedidosAbertosScreen({Key? key}) : super(key: key);

  @override
  State<PedidosAbertosScreen> createState() => _PedidosAbertosScreenState();
}

class _PedidosAbertosScreenState extends State<PedidosAbertosScreen> {
  final _currencyFmt = NumberFormat.currency(locale: 'pt_PT', symbol: 'MZN');

  bool _operacaoEmAndamento = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PedidoProvider>().listarPorStatus('aberto');
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DADOS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _carregar() async {
    await context.read<PedidoProvider>().listarPorStatus('aberto');
  }

  Future<void> _sincronizarPedidoCreditoAtivo() async {
  final ativo = PedidoAtivoController.instance.pedidoAtivo.value;

  if (ativo == null) return;
  if (!PedidoAtivoController.instance.edicaoCredito) return;
  if (!ativo.ehCredito && !ativo.estaEmDivida) return;

  final provider = context.read<PedidoProvider>();

  final atualizado = await provider.buscarPorId(ativo.idPedido);

  if (atualizado != null) {
    provider.definirPedidoActual(atualizado);

    // Mantém os itens antigos bloqueados,
    // mas actualiza a lista visível com os itens novos.
    PedidoAtivoController.instance.actualizarPedidoMantendoBloqueios(
      atualizado,
    );
  }
}

List<PedidoModel> _pedidosVisiveis(PedidoProvider provider) {
  final pedidos = [...provider.pedidos];

  final pedidoAtivo = PedidoAtivoController.instance.pedidoAtivo.value;
  final pedidoActual = provider.pedidoActual;

  PedidoModel? creditoAtivo = pedidoAtivo;

  if (pedidoActual != null &&
      pedidoAtivo != null &&
      pedidoActual.idPedido == pedidoAtivo.idPedido) {
    creditoAtivo = pedidoActual;
  }

  if (creditoAtivo != null &&
      PedidoAtivoController.instance.edicaoCredito &&
      (creditoAtivo.ehCredito || creditoAtivo.estaEmDivida)) {
    final index = pedidos.indexWhere(
      (p) => p.idPedido == creditoAtivo!.idPedido,
    );

    if (index == -1) {
      pedidos.insert(0, creditoAtivo);
    } else {
      pedidos[index] = creditoAtivo;
    }
  }

  return pedidos;
}

  // ══════════════════════════════════════════════════════════════════════════
  // ACÇÕES
  // ══════════════════════════════════════════════════════════════════════════

Future<void> _cancelarPedido(PedidoModel pedido) async {
    if (_operacaoEmAndamento) return;

    final ok = await _dialogoCancelamento(pedido);
    if (!ok) return;

    setState(() => _operacaoEmAndamento = true);

    try {
      await context.read<PedidoProvider>().cancelarPedido(
            pedido.idPedido,
            CancelamentoPedidoRequestModel(
              idUsuarioCancelou: SessaoService.instance.idUsuario,
              motivo: 'Cancelado pelo operador',
            ),
          );

      if (!mounted) return;

      final provider = context.read<PedidoProvider>();

      if (provider.status == PedidoStatus.success) {
        _snack('Pedido ${pedido.referencia} cancelado', Colors.orange);
        await _carregar();
      } else if (provider.erroEhPedidoJaFaturado) {
        await _tratarPedidoJaFaturado(pedido);
      } else {
        _snack('Erro ao cancelar: ${provider.errorMessage}',
            AppColors.vermelhoMarca);
      }
    } finally {
      if (mounted) setState(() => _operacaoEmAndamento = false);
    }
  }

  /// Pedido já tem factura emitida — não pode ser cancelado directamente.
  /// Oferece o fluxo de devolução/Nota de Crédito em vez de repetir o erro.
  Future<void> _tratarPedidoJaFaturado(PedidoModel pedido) async {
    final irParaDevolucao = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'Pedido já facturado',
              style: TextStyle(
                  color: ctx.cores.marca, fontWeight: FontWeight.bold),
            ),
            content: const Text(
              'Este pedido já tem factura emitida e não pode ser cancelado '
              'directamente. Deseja processar uma devolução/anulação?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ctx.cores.marcaBotao,
                  foregroundColor: AppColors.branco,
                ),
                child: const Text('Ir para devolução'),
              ),
            ],
          ),
        ) ??
        false;

    if (!irParaDevolucao || !mounted) return;

    await context
        .read<DocumentoFiscalProvider>()
        .carregarPorPedido(pedido.idPedido);
    if (!mounted) return;

    final documentos = context.read<DocumentoFiscalProvider>().documentos;

    DocumentoFiscalModel? documentoValido;
    for (final d in documentos) {
      if ((d.tipoDocumento.codigo == 'FAT' || d.tipoDocumento.codigo == 'VD') &&
          !d.anulado) {
        documentoValido = d;
        break;
      }
    }

    if (documentoValido == null) {
      _snack(
        'Não foi encontrado um documento fiscal válido para este pedido.',
        AppColors.vermelhoMarca,
      );
      return;
    }

    final resultado = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => DevolucaoTrocaScreen(
          idPedido: pedido.idPedido,
          idDocumentoOrigem: documentoValido!.id,
          pedidoInicial: pedido,
          documentoOrigem: documentoValido,
        ),
      ),
    );

    if (resultado != null && mounted) {
      await _carregar();
    }
  }

  Future<void> _abrirFinalizar(
    PedidoModel pedido, {
    ModoFinalizacaoPedido modo = ModoFinalizacaoPedido.normal,
  }) async {
    final finalizado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FinalizarPedidoScreen(
          pedido: pedido,
          modo: modo,
        ),
      ),
    );

    if (finalizado == true && mounted) {
      await _carregar();
    }
  }

  Future<void> _abrirCredito(PedidoModel pedido) async {
    await _abrirFinalizar(
      pedido,
      modo: ModoFinalizacaoPedido.credito,
    );
  }

Future<void> _editarPedido(PedidoModel pedido) async {
  if (!pedido.podeReceberNovosItens) {
    // Pedido já encerrado (finalizado/cancelado/crédito liquidado),
    // mas ainda visível temporariamente nesta lista — nunca reactivar.
    PedidoAtivoController.instance.limpar();
    context.read<PedidoProvider>().limparPedidoActual();
    _snack('Este pedido já foi encerrado e não pode receber novos itens.',
        AppColors.vermelhoMarca);
    await _carregar();
    return;
  }

  if (pedido.ehCredito || pedido.estaEmDivida) {
    PedidoAtivoController.instance.definirEdicaoCredito(pedido);
    context.read<PedidoProvider>().definirPedidoActual(pedido);
  } else {
    PedidoAtivoController.instance.definir(pedido);
    context.read<PedidoProvider>().definirPedidoActual(pedido);
  }

  await Navigator.pushNamed(context, '/catalogo');

  if (!mounted) return;

  if (pedido.ehCredito || pedido.estaEmDivida) {
    await _sincronizarPedidoCreditoAtivo();
  } else {
    PedidoAtivoController.instance.limpar();
    context.read<PedidoProvider>().limparPedidoActual();
  }

  await _carregar();

  if (mounted) setState(() {});
}
Future<void> _eliminarItemProduto(ItemPedidoModel item) async {
  if (_operacaoEmAndamento) return;

  final ok = await _confirmarEliminarItem(
    titulo: 'Remover produto',
    mensagem: 'Deseja remover "${item.nomeProduto}" deste pedido?',
  );

  if (!ok) return;

  setState(() => _operacaoEmAndamento = true);

  try {
    final pedido = _buscarPedidoDoItemProduto(item);

    if (pedido == null) {
      throw Exception('Pedido do item não encontrado na lista visível.');
    }

    final atualizado = await context.read<PedidoProvider>().eliminarItemProduto(
          pedido.idPedido,
          item.idItemPedido,
        );

    if (atualizado != null) {
      context.read<PedidoProvider>().definirPedidoActual(atualizado);

      if (PedidoAtivoController.instance.edicaoCredito) {
        PedidoAtivoController.instance
            .actualizarPedidoMantendoBloqueios(atualizado);
      } else {
        PedidoAtivoController.instance.definir(atualizado);
      }
    }

    _snack('Produto removido do pedido', Colors.green);
    await _carregar();
    await _sincronizarPedidoCreditoAtivo();
if (mounted) setState(() {});
  } catch (e) {
    _snack('Erro ao remover produto: $e', AppColors.vermelhoMarca);
  } finally {
    if (mounted) setState(() => _operacaoEmAndamento = false);
  }
}

Future<void> _eliminarItemServico(ItemPedidoServicoModel item) async {
  if (_operacaoEmAndamento) return;

  final ok = await _confirmarEliminarItem(
    titulo: 'Remover serviço',
    mensagem:
        'Deseja remover "${item.nomeServico ?? 'Serviço #${item.idServico}'}" deste pedido?',
  );

  if (!ok) return;

  setState(() => _operacaoEmAndamento = true);

  try {
    final pedido = _buscarPedidoDoItemServico(item);

    if (pedido == null) {
      throw Exception('Pedido do item não encontrado na lista visível.');
    }

    final atualizado = await context.read<PedidoProvider>().eliminarItemServico(
          pedido.idPedido,
          item.idItemServico,
        );

    if (atualizado != null) {
      context.read<PedidoProvider>().definirPedidoActual(atualizado);

      if (PedidoAtivoController.instance.edicaoCredito) {
        PedidoAtivoController.instance
            .actualizarPedidoMantendoBloqueios(atualizado);
      } else {
        PedidoAtivoController.instance.definir(atualizado);
      }
    }

    _snack('Serviço removido do pedido', Colors.green);
    await _carregar();
    await _sincronizarPedidoCreditoAtivo();
if (mounted) setState(() {});
  } catch (e) {
    _snack('Erro ao remover serviço: $e', AppColors.vermelhoMarca);
  } finally {
    if (mounted) setState(() => _operacaoEmAndamento = false);
  }
}

  // ══════════════════════════════════════════════════════════════════════════
  // DIÁLOGOS
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> _dialogoCancelamento(PedidoModel pedido) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Cancelar Pedido',
              style: TextStyle(
                color: ctx.cores.marca,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pedido.referencia,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: ctx.cores.marca,
                  ),
                ),
                const SizedBox(height: 6),
                _dialogRow('Total', _currencyFmt.format(pedido.total)),
                _dialogRow(
                  'Itens',
                  '${pedido.itensProduto.length + pedido.itensServico.length}',
                ),
                const SizedBox(height: 12),
                _infoBox(
                  icon: Icons.warning_amber,
                  texto: 'O estoque será restaurado automaticamente.',
                  cor: ctx.cores.aviso,
                ),
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
                  backgroundColor: AppColors.vermelhoMarca,
                  foregroundColor: AppColors.branco,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Cancelar Pedido'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _confirmarEliminarItem({
    required String titulo,
    required String mensagem,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              titulo,
              style: TextStyle(
                color: ctx.cores.marca,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(mensagem),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.vermelhoMarca,
                  foregroundColor: AppColors.branco,
                ),
                child: const Text('Remover'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _snack(String msg, Color cor) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: cor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  PedidoModel? _buscarPedidoDoItemProduto(ItemPedidoModel item) {
  final provider = context.read<PedidoProvider>();

  for (final p in _pedidosVisiveis(provider)) {
    final existe = p.itensProduto.any(
      (i) => i.idItemPedido == item.idItemPedido,
    );

    if (existe) return p;
  }

  return null;
}

PedidoModel? _buscarPedidoDoItemServico(ItemPedidoServicoModel item) {
  final provider = context.read<PedidoProvider>();

  for (final p in _pedidosVisiveis(provider)) {
    final existe = p.itensServico.any(
      (i) => i.idItemServico == item.idItemServico,
    );

    if (existe) return p;
  }

  return null;
}

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PedidoProvider>();

    return Scaffold(
      backgroundColor: context.cores.fundo,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(provider),
          SliverToBoxAdapter(
            child: ValueListenableBuilder<PedidoModel?>(
              valueListenable: PedidoAtivoController.instance.pedidoAtivo,
              builder: (_, __, ___) => _buildBody(provider),
            ),
          ),
        ],
      ),
    );
  }

  // ─── SliverAppBar (padrão detalhes_produto) ────────────────────────────────

  Widget _buildAppBar(PedidoProvider provider) {
    final pedidos = _pedidosVisiveis(provider);

    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.azulMarca,
      foregroundColor: AppColors.branco,
      expandedHeight: 120,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.branco.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Atualizar',
          onPressed: provider.isLoading ? null : _carregar,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.azulMarca,
                AppColors.azulMarca.withBlue(140),
              ],
            ),
          ),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.branco.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.pending_actions,
                      color: AppColors.branco,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pedidos Abertos',
                        style: TextStyle(
                          color: AppColors.branco,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        provider.isLoading
                            ? 'A carregar…'
                            : '${pedidos.length} pedido(s)',
                        style: TextStyle(
                          color: AppColors.branco.withValues(alpha: 0.75),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Corpo ─────────────────────────────────────────────────────────────────

  Widget _buildBody(PedidoProvider provider) {
    final c = context.cores;
    final pedidos = _pedidosVisiveis(provider);

    if (provider.isLoading) {
      return SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: c.marca),
              const SizedBox(height: 16),
              Text('A carregar pedidos…',
                  style: TextStyle(color: c.textoSecundario)),
            ],
          ),
        ),
      );
    }

    if (provider.errorMessage != null) {
      return SizedBox(
        height: 300,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: c.acentoTexto),
                const SizedBox(height: 16),
                Text(
                  provider.errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.textoSecundario),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _carregar,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.marcaBotao,
                    foregroundColor: AppColors.branco,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (pedidos.isEmpty) {
      return SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 80,
                color: c.desactivado,
              ),
              const SizedBox(height: 16),
              Text(
                'Nenhum pedido aberto',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: c.textoSecundario,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Todos os pedidos foram finalizados.',
                style: TextStyle(color: c.textoSecundario),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _carregar,
      color: c.acentoTexto,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: pedidos.length,
        itemBuilder: (_, i) => _buildCard(pedidos[i]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CARD DO PEDIDO
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildCard(PedidoModel pedido) {
    final c = context.cores;
    final pedidoActual = context.watch<PedidoProvider>().pedidoActual;
    final pedidoAtivoController =
        PedidoAtivoController.instance.pedidoAtivo.value;

    final isAtivo = pedidoActual?.idPedido == pedido.idPedido ||
        pedidoAtivoController?.idPedido == pedido.idPedido;

    final ehCredito = pedido.ehCredito || pedido.estaEmDivida;

    final totalItens = pedido.itensProduto.length + pedido.itensServico.length;

    return Card(
      elevation: 0,
      color: c.superficie,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isAtivo ? c.sucesso : c.borda,
          width: isAtivo ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabeçalho ──────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: c.marca.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.receipt_outlined,
                    color: c.marca,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pedido.referencia,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: c.marca,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _formatarData(pedido.dataPedido),
                        style: TextStyle(
                          color: c.textoSecundario,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // Badge "Aberto" / "Crédito"
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: ehCredito ? c.avisoFundo : c.infoFundo,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: ehCredito ? c.aviso : c.info,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        ehCredito
                            ? Icons.credit_score_outlined
                            : Icons.radio_button_on,
                        size: 10,
                        color: ehCredito ? c.aviso : c.info,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        ehCredito ? 'Crédito' : 'Aberto',
                        style: TextStyle(
                          color: ehCredito ? c.aviso : c.info,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            Divider(height: 1, color: c.borda),
            const SizedBox(height: 14),

            // ── Itens de produto ───────────────────────────────────────────
            if (pedido.itensProduto.isNotEmpty) ...[
              _sectionLabel(Icons.inventory_2_outlined, 'Produtos'),
              const SizedBox(height: 8),
              ...pedido.itensProduto.map(_buildLinhaItemProduto),
            ],

            // ── Itens de serviço ───────────────────────────────────────────
            if (pedido.itensServico.isNotEmpty) ...[
              const SizedBox(height: 10),
              _sectionLabel(Icons.miscellaneous_services_outlined, 'Serviços'),
              const SizedBox(height: 8),
              ...pedido.itensServico.map(_buildLinhaItemServico),
            ],

            const SizedBox(height: 14),
            Divider(height: 1, color: c.borda),
            const SizedBox(height: 12),

            // ── Rodapé: resumo + acções ────────────────────────────────────
            _buildRodape(pedido, totalItens),
          ],
        ),
      ),
    );
  }

  // ─── Label de secção ──────────────────────────────────────────────────────

  Widget _sectionLabel(IconData icon, String texto) {
    final c = context.cores;
    return Row(
      children: [
        Icon(icon, size: 14, color: c.marca.withValues(alpha: 0.5)),
        const SizedBox(width: 6),
        Text(
          texto,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: c.textoSecundario,
          ),
        ),
      ],
    );
  }

  // ─── Linha de item de produto ─────────────────────────────────────────────

  Widget _buildLinhaItemProduto(ItemPedidoModel item) {
    final c = context.cores;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: c.marca.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${item.quantidade}×',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: c.marca,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.nomeProduto,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            _currencyFmt.format(item.subtotal),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: c.marca,
            ),
          ),
          const SizedBox(width: 6),
          Builder(
            builder: (ctx) {
final bloqueado = item.confirmadoCredito ||
    PedidoAtivoController.instance.produtoEstaBloqueado(
      item.idItemPedido,
    );

              if (bloqueado) {
                return Tooltip(
                  message: 'Item já confirmado no crédito',
                  child: Icon(
                    Icons.lock_outline,
                    color: ctx.cores.textoSecundario,
                    size: 18,
                  ),
                );
              }

              return IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.delete_outline,
                  color: ctx.cores.perigo,
                  size: 20,
                ),
                onPressed: () => _eliminarItemProduto(item),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── Linha de item de serviço ─────────────────────────────────────────────

  Widget _buildLinhaItemServico(ItemPedidoServicoModel item) {
    final c = context.cores;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: c.info.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${item.quantidade}×',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: c.info,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nomeServico ?? 'Serviço #${item.idServico}',
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.observacoes != null && item.observacoes!.isNotEmpty)
                  Text(
                    item.observacoes!,
                    style: TextStyle(fontSize: 11, color: c.textoSecundario),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Text(
            _currencyFmt.format(item.subtotal),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: c.marca,
            ),
          ),
          const SizedBox(width: 6),
          Builder(
            builder: (ctx) {
final bloqueado = item.confirmadoCredito ||
    PedidoAtivoController.instance.servicoEstaBloqueado(
      item.idItemServico,
    );

              if (bloqueado) {
                return Tooltip(
                  message: 'Item já confirmado no crédito',
                  child: Icon(
                    Icons.lock_outline,
                    color: ctx.cores.textoSecundario,
                    size: 18,
                  ),
                );
              }

              return IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.delete_outline,
                  color: ctx.cores.perigo,
                  size: 20,
                ),
                onPressed: () => _eliminarItemServico(item),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── Rodapé do card ───────────────────────────────────────────────────────
Widget _buildAcoesFinalizacaoNormal(PedidoModel pedido) {
  final c = context.cores;
  return Container(
    constraints: const BoxConstraints(maxWidth: 360),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: c.marca.withValues(alpha: 0.035),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: c.marca.withValues(alpha: 0.12),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.task_alt_rounded,
              size: 16,
              color: c.marca.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 6),
            Text(
              'Escolha o tipo de finalização',
              style: TextStyle(
                color: c.marca,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Acção principal: venda normal
        ElevatedButton.icon(
          onPressed: _operacaoEmAndamento
              ? null
              : () => _abrirFinalizar(pedido),
          icon: const Icon(Icons.check_circle_rounded, size: 19),
          label: const Text(
            'Finalizar venda normal',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: c.marcaBotao,
            foregroundColor: AppColors.branco,
            elevation: 2,
            minimumSize: const Size.fromHeight(44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(11),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Acção alternativa: crédito
        InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: _operacaoEmAndamento ? null : () => _abrirCredito(pedido),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: c.aviso.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: c.aviso.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.credit_score_outlined,
                  color: c.aviso,
                  size: 19,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Vender a crédito',
                    style: TextStyle(
                      color: c.aviso,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  'Dívida',
                  style: TextStyle(
                    color: c.aviso,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: c.aviso,
                  size: 13,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}



  Widget _buildRodape(PedidoModel pedido, int totalItens) {
    final c = context.cores;
    final ehCredito = pedido.ehCredito || pedido.estaEmDivida;

    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: _operacaoEmAndamento ? null : () => _editarPedido(pedido),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Itens'),
          style: OutlinedButton.styleFrom(
            foregroundColor: c.marca,
            side: BorderSide(color: c.marca),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),

        if (!ehCredito) ...[
          const SizedBox(width: 6),
          OutlinedButton.icon(
            onPressed:
                _operacaoEmAndamento ? null : () => _cancelarPedido(pedido),
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Cancelar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: c.acentoTexto,
              side: BorderSide(color: c.acentoTexto),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],

        const Spacer(),

        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$totalItens item(s)',
              style: TextStyle(color: c.textoSecundario, fontSize: 11),
            ),
            Text(
              _currencyFmt.format(pedido.total),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: c.marca,
              ),
            ),
          ],
        ),

        const SizedBox(width: 12),

        if (ehCredito)
          ElevatedButton.icon(
            onPressed:
                _operacaoEmAndamento ? null : () => _abrirCredito(pedido),
            icon: const Icon(Icons.credit_score_outlined, size: 18),
            label: const Text(
              'Finalizar crédito',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              // Cor fixa deliberada (botão laranja com texto branco).
              backgroundColor: Colors.orange[700],
              foregroundColor: AppColors.branco,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
          )
        else
  _buildAcoesFinalizacaoNormal(pedido),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // HELPERS DE UI / DIÁLOGO
  // ──────────────────────────────────────────────────────────────────────────

  Widget _infoBox({
    required IconData icon,
    required String texto,
    required Color cor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(fontSize: 12, color: cor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dialogRow(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: context.cores.textoSecundario, fontSize: 13)),
          Text(
            valor,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _formatarData(DateTime data) {
    final diff = DateTime.now().difference(data);

    if (diff.inMinutes < 60) {
      return 'Há ${diff.inMinutes} min';
    }

    if (diff.inHours < 24) {
      return 'Há ${diff.inHours}h';
    }

    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')} '
        '${data.hour.toString().padLeft(2, '0')}:'
        '${data.minute.toString().padLeft(2, '0')}';
  }
}