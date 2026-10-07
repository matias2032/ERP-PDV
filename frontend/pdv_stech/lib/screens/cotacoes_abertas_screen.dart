// lib/screens/cotacoes_abertas_screen.dart


import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:provider/provider.dart';
import 'cotacao_catalogo_screen.dart';
import 'cotacao_resumo_screen.dart';

// import 'finalizar_pedido.dart';

const _kPrimary    = Color(0xFF1B2A6B);
const _kAccent     = Color(0xFFC8102E);
const _kBackground = Color(0xFFF4F5F7);
const _kCotacao    = Color(0xFF0077B6);

class CotacoesAbertasScreen extends StatefulWidget {
  const CotacoesAbertasScreen({Key? key}) : super(key: key);

  @override
  State<CotacoesAbertasScreen> createState() => _CotacoesAbertasScreenState();
}

class _CotacoesAbertasScreenState extends State<CotacoesAbertasScreen> {
  final _currencyFmt = NumberFormat.currency(locale: 'pt_PT', symbol: 'MZN');
  bool _operacaoEmAndamento = false;

@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    context.read<CotacaoProvider>().listarPorStatus('ABERTA');
    // ← ADICIONADO: limpa o controller se a cotação activa já não for ABERTA
    CotacaoAtivaController.instance.limparSeNaoAberta();
  });
}

  // ══════════════════════════════════════════════════════════════════════════
  // DADOS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _carregar() async {
  await context.read<CotacaoProvider>().listarPorStatus('ABERTA');
}

  // Apenas cotações ainda editáveis (ABERTA, ENVIADA, APROVADA)
  List<CotacaoModel> _cotacoesEditaveis(List<CotacaoModel> todas) =>
    todas.where((c) => c.estaAberta).toList();

  // ══════════════════════════════════════════════════════════════════════════
  // ACÇÕES
  // ══════════════════════════════════════════════════════════════════════════

  /// Define a cotação como activa e navega para o catálogo para adicionar itens.
Future<void> _editarCotacao(CotacaoModel cotacao) async {
  // ← só define se estiver ABERTA (o definir() já filtra, mas explicitamos)
  if (!cotacao.estaAberta) {
    _snack('Esta cotação já não está aberta.', Colors.orange);
    return;
  }
  CotacaoAtivaController.instance.definir(cotacao);
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const CotacaoCatalogoScreen()),
  );
  if (!mounted) return;
  // ← ADICIONADO: ao regressar, limpa se entretanto ficou não-ABERTA
  CotacaoAtivaController.instance.limparSeNaoAberta();
  await _carregar();
}

  /// Cancela a cotação após confirmação.
  Future<void> _cancelarCotacao(CotacaoModel cotacao) async {
    if (_operacaoEmAndamento) return;
    final ok = await _dialogoCancelamento(cotacao);
    if (!ok) return;

    setState(() => _operacaoEmAndamento = true);
    try {
      await context.read<CotacaoProvider>().atualizarCotacao(
        cotacao.idCotacao,
        AtualizarCotacaoRequestModel(statusCotacao: 'CANCELADA'),
      );
      if (!mounted) return;

      final provider = context.read<CotacaoProvider>();
      if (provider.status == CotacaoStatus.success) {
        // Se era a cotação activa, limpa o controller
        if (CotacaoAtivaController.instance.cotacaoAtiva.value?.idCotacao ==
            cotacao.idCotacao) {
          CotacaoAtivaController.instance.limpar();
          
        }
        _snack('Cotação ${cotacao.referencia} cancelada', Colors.orange);
        await _carregar();
      } else {
        _snack('Erro ao cancelar: ${provider.errorMessage}', _kAccent);
      }
    } finally {
      if (mounted) setState(() => _operacaoEmAndamento = false);
    }
  }

  /// Converte a cotação em pedido e navega para FinalizarPedidoScreen.
//   Future<void> _converterEmPedido(CotacaoModel cotacao) async {
//     if (_operacaoEmAndamento) return;
//     if (!cotacao.temItens) {
//       _snack('A cotação não tem itens — adicione pelo menos um antes de converter.', Colors.orange);
//       return;
//     }
//     final ok = await _dialogoConverterEmPedido(cotacao);
//     if (!ok) return;

//     setState(() => _operacaoEmAndamento = true);
//     try {
//       final pedido = await context.read<CotacaoProvider>().converterEmPedido(
//         cotacao.idCotacao,
//         ConverterCotacaoEmPedidoRequestModel(idTipoPagamento: 1),
//       );
//       if (!mounted) return;

// if (pedido != null) {
//   if (CotacaoAtivaController.instance.cotacaoAtiva.value?.idCotacao ==
//       cotacao.idCotacao) {
//     CotacaoAtivaController.instance.limpar();
//   }
//   final gerada = await Navigator.push<bool>(
//     context,
//     MaterialPageRoute(
//       builder: (_) => CotacaoResumoScreen(cotacao: cotacao),
//     ),
//   );
//   if (mounted) {
//     if (gerada == true) {
//       _snack('Cotação ${cotacao.referencia} enviada com sucesso!', Colors.green);
//     }
//     await _carregar();
//   }
// } else {
//         final err = context.read<CotacaoProvider>().errorMessage;
//         _snack('Erro ao converter: ${err ?? 'sem ligação'}', _kAccent);
//       }
//     } finally {
//       if (mounted) setState(() => _operacaoEmAndamento = false);
//     }
//   }

/// Navega para o resumo da cotação para associar cliente.
Future<void> _abrirResumo(CotacaoModel cotacao) async {
  if (_operacaoEmAndamento) return;
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => CotacaoResumoScreen(cotacao: cotacao),
    ),
  );
  if (mounted) await _carregar();
}

  // ══════════════════════════════════════════════════════════════════════════
  // DIÁLOGOS
  // ══════════════════════════════════════════════════════════════════════════

  Future<bool> _dialogoCancelamento(CotacaoModel cotacao) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text('Cancelar Cotação',
                style: TextStyle(
                    color: _kPrimary, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cotacao.referencia,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: _kPrimary)),
                const SizedBox(height: 6),
                _dialogRow('Total', _currencyFmt.format(cotacao.total)),
                _dialogRow(
                  'Itens',
                  '${cotacao.itensProduto.length + cotacao.itensServico.length}',
                ),
                const SizedBox(height: 12),
                _infoBox(
                  icon: Icons.info_outline,
                  texto: 'A cotação ficará marcada como CANCELADA e não poderá ser editada.',
                  cor: Colors.orange,
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
                  backgroundColor: _kAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Cancelar Cotação'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _dialogoConverterEmPedido(CotacaoModel cotacao) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text('Converter em Pedido',
                style: TextStyle(
                    color: _kPrimary, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cotacao.referencia,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: _kPrimary)),
                const SizedBox(height: 6),
                _dialogRow('Total', _currencyFmt.format(cotacao.total)),
                _dialogRow(
                  'Itens',
                  '${cotacao.itensProduto.length + cotacao.itensServico.length}',
                ),
                if (cotacao.nomeCliente != null) ...[
                  _dialogRow('Cliente', cotacao.nomeCliente!),
                ],
                const SizedBox(height: 12),
                _infoBox(
                  icon: Icons.swap_horiz,
                  texto: 'Será criado um pedido real. O stock será decrementado pelo servidor.',
                  cor: _kCotacao,
                ),
                const SizedBox(height: 6),
                _infoBox(
                  icon: Icons.wifi_outlined,
                  texto: 'Requer ligação à internet.',
                  cor: Colors.orange,
                ),
              ],
            ),
        actions: [
  TextButton(
    onPressed: () => Navigator.pop(ctx, false),
    child: const Text('Cancelar'),
  ),
  ElevatedButton(
    onPressed: () => Navigator.pop(ctx, true),
    style: ElevatedButton.styleFrom(
      backgroundColor: _kCotacao,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    child: const Text('Converter'),
  ),
],
          ),
        ) ??
        false;
  }

Future<void> _eliminarItemProduto(
  CotacaoModel cotacao,
  CotacaoItemProdutoModel item,
) async{
  if (_operacaoEmAndamento) return;



  final ok = await _confirmarEliminarItem(
    titulo: 'Remover produto',
    mensagem:
        'Deseja remover "${item.nomeProduto ?? 'Produto #${item.idProduto}'}" desta cotação?',
  );

  if (!ok) return;

  setState(() => _operacaoEmAndamento = true);

  try {
    await context.read<CotacaoProvider>().removerItemProduto(
          cotacao.idCotacao,
          item.idItemCotacaoProduto,
        );

    _snack('Produto removido da cotação', Colors.green);
    await _carregar();
  } catch (e) {
    _snack('Erro ao remover produto: $e', _kAccent);
  } finally {
    if (mounted) setState(() => _operacaoEmAndamento = false);
  }
}

Future<void> _eliminarItemServico(
  CotacaoModel cotacao,
  CotacaoItemServicoModel item,
) async{
  if (_operacaoEmAndamento) return;

 

  final ok = await _confirmarEliminarItem(
    titulo: 'Remover serviço',
    mensagem:
        'Deseja remover "${item.nomeServico ?? 'Serviço #${item.idServico}'}" desta cotação?',
  );

  if (!ok) return;

  setState(() => _operacaoEmAndamento = true);

  try {
    await context.read<CotacaoProvider>().removerItemServico(
          cotacao.idCotacao,
          item.idItemCotacaoServico,
        );

    _snack('Serviço removido da cotação', Colors.green);
    await _carregar();
  } catch (e) {
    _snack('Erro ao remover serviço: $e', _kAccent);
  } finally {
    if (mounted) setState(() => _operacaoEmAndamento = false);
  }
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
            style: const TextStyle(
              color: _kPrimary,
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
                backgroundColor: _kAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Remover'),
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
    final provider = context.watch<CotacaoProvider>();
    final lista    = _cotacoesEditaveis(provider.cotacoes);

    return Scaffold(
      backgroundColor: _kBackground,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(provider, lista.length),
          SliverToBoxAdapter(child: _buildBody(provider, lista)),
        ],
      ),
    );
  }

  // ── SliverAppBar ──────────────────────────────────────────────────────────

  Widget _buildAppBar(CotacaoProvider provider, int count) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: _kPrimary,
      foregroundColor: Colors.white,
      expandedHeight: 120,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
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
              colors: [_kPrimary, _kPrimary.withBlue(140)],
            ),
          ),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.request_quote_outlined,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cotações Activas',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    Text(
                      provider.isLoading
                          ? 'A carregar…'
                          : '$count cotação(ões)',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 13),
                    ),
                  ],
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ── Corpo ─────────────────────────────────────────────────────────────────

  Widget _buildBody(CotacaoProvider provider, List<CotacaoModel> lista) {
    if (provider.isLoading) {
      return const SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: _kPrimary),
              SizedBox(height: 16),
              Text('A carregar cotações…',
                  style: TextStyle(color: Colors.grey)),
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
                Icon(Icons.error_outline, size: 64, color: _kAccent),
                const SizedBox(height: 16),
                Text(provider.errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _carregar,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (lista.isEmpty) {
      return SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline,
                  size: 80, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text('Nenhuma cotação activa',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[500])),
              const SizedBox(height: 8),
              Text('Crie uma cotação a partir do catálogo.',
                  style: TextStyle(color: Colors.grey[400])),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _carregar,
      color: _kAccent,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: lista.length,
        itemBuilder: (_, i) => _buildCard(lista[i]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CARD DA COTAÇÃO
  // ══════════════════════════════════════════════════════════════════════════

Widget _buildCard(CotacaoModel cotacao) {
  final totalItens =
      cotacao.itensProduto.length + cotacao.itensServico.length;

  // ← SUBSTITUÍDO: era uma comparação estática, agora reage ao ValueNotifier
  return ValueListenableBuilder<CotacaoModel?>(
    valueListenable: CotacaoAtivaController.instance.cotacaoAtiva,
    builder: (_, cotacaoAtiva, __) {
      final isAtiva = cotacaoAtiva?.idCotacao == cotacao.idCotacao;

      return Card(
        elevation: 0,
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isAtiva ? _kCotacao.withOpacity(0.6) : Colors.grey.shade200,
            width: isAtiva ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _kCotacao.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.request_quote_outlined,
                      color: _kCotacao, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cotacao.referencia,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: _kPrimary)),
                      const SizedBox(height: 3),
                      Text(
                        _formatarData(cotacao.createdAt ?? DateTime.now()),
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                _buildBadgeStatus(cotacao.statusCotacao),
              ]),
              if (cotacao.nomeCliente != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.person_outline, size: 13, color: Colors.grey[500]),
                  const SizedBox(width: 5),
                  Text(cotacao.nomeCliente!,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ]),
              ],
              if (cotacao.validadeAte != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.schedule_outlined, size: 13, color: Colors.grey[500]),
                  const SizedBox(width: 5),
                  Text(
                    'Válida até ${_formatarDataSimples(cotacao.validadeAte!)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ]),
              ],
              const SizedBox(height: 14),
              Divider(height: 1, color: Colors.grey[200]),
              const SizedBox(height: 14),
              if (cotacao.itensProduto.isNotEmpty) ...[
                _sectionLabel(Icons.inventory_2_outlined, 'Produtos'),
                const SizedBox(height: 8),
...cotacao.itensProduto.map(
  (item) => _buildLinhaItemProduto(cotacao, item),
),
              ],
              if (cotacao.itensServico.isNotEmpty) ...[
                const SizedBox(height: 10),
                _sectionLabel(Icons.miscellaneous_services_outlined, 'Serviços'),
                const SizedBox(height: 8),
...cotacao.itensServico.map(
  (item) => _buildLinhaItemServico(cotacao, item),
),
              ],
              if (!cotacao.temItens) ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('Sem itens — adicione produtos ou serviços.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Divider(height: 1, color: Colors.grey[200]),
              const SizedBox(height: 12),
              _buildRodape(cotacao, totalItens),
            ],
          ),
        ),
      );
    },
  );
}

  // ── Badge de status ───────────────────────────────────────────────────────

  Widget _buildBadgeStatus(String status) {
    final config = _statusConfig(status);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config.$1.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: config.$1.withOpacity(0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(config.$2, size: 10, color: config.$1),
        const SizedBox(width: 4),
        Text(config.$3,
            style: TextStyle(
                color: config.$1,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      ]),
    );
  }

  /// (cor, ícone, rótulo) por status
  (Color, IconData, String) _statusConfig(String status) =>
      switch (status) {
        'ABERTA'     => (_kCotacao,      Icons.radio_button_on,  'Aberta'),
        'ENVIADA'    => (Colors.purple,  Icons.send_outlined,    'Enviada'),
        'APROVADA'   => (Colors.green,   Icons.thumb_up_outlined, 'Aprovada'),
        'CONVERTIDA' => (_kPrimary,      Icons.swap_horiz,       'Convertida'),
        'CANCELADA'  => (_kAccent,       Icons.cancel_outlined,  'Cancelada'),
        'EXPIRADA'   => (Colors.grey,    Icons.timer_off_outlined,'Expirada'),
        _            => (Colors.grey,    Icons.help_outline,     status),
      };

  // ── Labels de secção ──────────────────────────────────────────────────────

  Widget _sectionLabel(IconData icon, String texto) {
    return Row(children: [
      Icon(icon, size: 14, color: _kPrimary.withOpacity(0.5)),
      const SizedBox(width: 6),
      Text(texto,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600])),
    ]);
  }

  // ── Linhas de itens ───────────────────────────────────────────────────────

Widget _buildLinhaItemProduto(
  CotacaoModel cotacao,
  CotacaoItemProdutoModel item,
){
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _kPrimary.withOpacity(0.07),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('${item.quantidade}×',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _kPrimary)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(item.nomeProduto ?? 'Produto #${item.idProduto}',
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis),
        ),
     Text(
  _currencyFmt.format(item.subtotal),
  style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: _kPrimary),
),
const SizedBox(width: 6),
IconButton(
  visualDensity: VisualDensity.compact,
  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
  onPressed: () =>
    _eliminarItemProduto(cotacao, item),
),
      ]),
    );
  }

Widget _buildLinhaItemServico(
  CotacaoModel cotacao,
  CotacaoItemServicoModel item,
) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.07),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('${item.quantidade}×',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.nomeServico ?? 'Serviço #${item.idServico}',
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis),
              if (item.observacoes != null &&
                  item.observacoes!.isNotEmpty)
                Text(item.observacoes!,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[500]),
                    overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
   Text(
  _currencyFmt.format(item.subtotal),
  style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: _kPrimary),
),
const SizedBox(width: 6),
IconButton(
  visualDensity: VisualDensity.compact,
  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
  onPressed: () =>
    _eliminarItemServico(cotacao, item),
),
      ]),
    );
  }

  // ── Rodapé do card ────────────────────────────────────────────────────────

  Widget _buildRodape(CotacaoModel cotacao, int totalItens) {
    return Row(children: [
      // Cancelar
      OutlinedButton.icon(
        onPressed: _operacaoEmAndamento
            ? null
            : () => _cancelarCotacao(cotacao),
        icon: const Icon(Icons.close, size: 16),
        label: const Text('Cancelar'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _kAccent,
          side: BorderSide(color: _kAccent),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
      const SizedBox(width: 6),
      // Editar (adicionar itens)
      OutlinedButton.icon(
        onPressed: _operacaoEmAndamento
            ? null
            : () => _editarCotacao(cotacao),
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Itens'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _kCotacao,
          side: BorderSide(color: _kCotacao),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
      const Spacer(),
      // Total
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('$totalItens item(s)',
              style:
                  TextStyle(color: Colors.grey[500], fontSize: 11)),
          Text(
            _currencyFmt.format(cotacao.total),
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _kPrimary),
          ),
        ],
      ),
      const SizedBox(width: 12),
      // Converter em Pedido
      // Converter em Pedido  →  Ver Resumo
ElevatedButton.icon(
  onPressed: _operacaoEmAndamento
      ? null
      : () => _abrirResumo(cotacao),
  icon: const Icon(Icons.person_outline, size: 18),
  label: const Text('Resumo',
      style: TextStyle(fontWeight: FontWeight.bold)),
  style: ElevatedButton.styleFrom(
    backgroundColor: _kCotacao,
    foregroundColor: Colors.white,
    elevation: 2,
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10)),
    padding: const EdgeInsets.symmetric(
        horizontal: 16, vertical: 12),
  ),
),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _infoBox(
      {required IconData icon,
      required String texto,
      required Color cor}) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cor.withOpacity(0.25)),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: cor),
        const SizedBox(width: 8),
        Expanded(
            child: Text(texto,
                style: TextStyle(fontSize: 12, color: cor))),
      ]),
    );
  }

  Widget _dialogRow(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  TextStyle(color: Colors.grey[600], fontSize: 13)),
          Text(valor,
              style: const TextStyle(
                  fontWeight: FontWeight.w500, fontSize: 14)),
        ],
      ),
    );
  }

  String _formatarData(DateTime data) {
    final diff = DateTime.now().difference(data);
    if (diff.inMinutes < 60) return 'Há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Há ${diff.inHours}h';
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')} '
        '${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
  }

  String _formatarDataSimples(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}/'
      '${data.month.toString().padLeft(2, '0')}/'
      '${data.year}';

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

