// lib/screens/devolucao_troca_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:api_compartilhado/api_config.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

// ─── Paleta (igual às telas de pedidos) ───────────────────────────────────────
const _kPrimary = Color(0xFF1B2A6B);
const _kAccent = Color(0xFFC8102E);
const _kBackground = Color(0xFFF4F5F7);
const _kSuccess = Color(0xFF2E7D32);

/// Estado local de seleção de um item (produto ou serviço) para devolução.
class _SelecaoItem {
  bool selecionado;
  int quantidade;

  _SelecaoItem({this.selecionado = false, this.quantidade = 1});
}

class DevolucaoTrocaScreen extends StatefulWidget {
  /// Pedido de origem (obrigatório).
  final int idPedido;

  /// Documento fiscal (FAT/VD) de origem sobre o qual a Nota de Crédito
  /// será emitida (obrigatório).
  final int idDocumentoOrigem;

  /// Se o chamador já tiver o pedido carregado, pode passá-lo aqui para
  /// evitar uma nova busca. Caso contrário, a tela busca por [idPedido].
  final PedidoModel? pedidoInicial;

  /// Dados do documento fiscal de origem, usados apenas para exibir
  /// contexto no cabeçalho (referência da factura). Opcional.
  final DocumentoFiscalModel? documentoOrigem;

  const DevolucaoTrocaScreen({
    super.key,
    required this.idPedido,
    required this.idDocumentoOrigem,
    this.pedidoInicial,
    this.documentoOrigem,
  });

  @override
  State<DevolucaoTrocaScreen> createState() => _DevolucaoTrocaScreenState();
}

class _DevolucaoTrocaScreenState extends State<DevolucaoTrocaScreen> {
  final _currencyFmt = NumberFormat.currency(locale: 'pt_PT', symbol: 'MZN');
  final _obsCtrl = TextEditingController();

  bool _carregando = true;
  bool _enviando = false;
  String? _erroCarregamento;

  PedidoModel? _pedido;
  String? _motivo; // ERRO_PREENCHIMENTO | DEVOLUCAO | TROCA_PRODUTO
  ClienteModel? _clienteCadastrado;

  final Map<int, _SelecaoItem> _selecaoProduto = {};
  final Map<int, _SelecaoItem> _selecaoServico = {};

  DevolucaoResponseModel? _resultado;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregar());
  }

  @override
  void dispose() {
    _obsCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════
  // CARREGAMENTO
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _carregar() async {
    if (widget.pedidoInicial != null) {
      setState(() {
        _pedido = widget.pedidoInicial;
        _carregando = false;
      });
      _prepararSelecoes();
      return;
    }

    setState(() {
      _carregando = true;
      _erroCarregamento = null;
    });

    final pedido =
        await context.read<PedidoProvider>().buscarPorId(widget.idPedido);

    if (!mounted) return;

    if (pedido == null) {
      setState(() {
        _carregando = false;
        _erroCarregamento = context.read<PedidoProvider>().errorMessage ??
            'Não foi possível carregar o pedido.';
      });
      return;
    }

    setState(() {
      _pedido = pedido;
      _carregando = false;
    });
    _prepararSelecoes();
    unawaited(_carregarClienteSeAplicavel());
  }

  /// Carrega o ClienteModel completo (cliente cadastrado) para exibição
  /// no PDF da Nota de Crédito. Se o pedido não tiver idCliente (cliente
  /// singular/avulso), não faz nada — o nome singular já vem no PedidoModel.
  Future<void> _carregarClienteSeAplicavel() async {
    final idCliente = _pedido?.idCliente;
    if (idCliente == null) return;

    try {
final cliente = await ClienteService(
  baseUrl: ApiConfig.baseUrl,
  httpClient: http.Client(), // <--- Passando uma nova instância de Client
).buscarPorId(idCliente);
      if (!mounted) return;
      setState(() => _clienteCadastrado = cliente);
    } catch (e) {
      // Não bloqueia o fluxo de devolução por causa disto — o PDF
      // simplesmente não mostrará os dados completos do cliente.
      debugPrint('⚠️ DevolucaoTrocaScreen — falha ao carregar cliente: $e');
    }
  }

  void _prepararSelecoes() {
    _selecaoProduto.clear();
    _selecaoServico.clear();
    final pedido = _pedido;
    if (pedido == null) return;

    for (final item in pedido.itensProduto) {
      _selecaoProduto[item.idItemPedido] = _SelecaoItem(quantidade: 1);
    }
    for (final item in pedido.itensServico) {
      _selecaoServico[item.idItemServico] = _SelecaoItem(quantidade: 1);
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // CÁLCULO DO VALOR A CREDITAR
  // ══════════════════════════════════════════════════════════════════════

  double get _valorACreditar {
    final pedido = _pedido;
    if (pedido == null) return 0;

    if (_motivo == 'ERRO_PREENCHIMENTO') {
      return pedido.total;
    }

    double soma = 0;
    for (final item in pedido.itensProduto) {
      final sel = _selecaoProduto[item.idItemPedido];
      if (sel != null && sel.selecionado) {
        soma += item.precoUnitario * sel.quantidade;
      }
    }
    for (final item in pedido.itensServico) {
      final sel = _selecaoServico[item.idItemServico];
      if (sel != null && sel.selecionado) {
        soma += item.precoUnitario * sel.quantidade;
      }
    }
    return soma;
  }

  bool get _temItemSelecionado {
    return _selecaoProduto.values.any((s) => s.selecionado) ||
        _selecaoServico.values.any((s) => s.selecionado);
  }

  bool get _podeConfirmar {
    if (_motivo == null) return false;
    if (_motivo == 'ERRO_PREENCHIMENTO') return true;
    return _temItemSelecionado;
  }

  // ══════════════════════════════════════════════════════════════════════
  // AÇÕES
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _confirmar() async {
    if (_enviando || !_podeConfirmar || _pedido == null) return;

    if (_motivo == 'ERRO_PREENCHIMENTO') {
      final ok = await _confirmarAnulacaoTotal();
      if (!ok) return;
    }

    setState(() => _enviando = true);

    final itens = <ItemDevolvidoModel>[];
    if (_motivo != 'ERRO_PREENCHIMENTO') {
      _selecaoProduto.forEach((idItem, sel) {
        if (sel.selecionado && sel.quantidade > 0) {
          itens.add(
            ItemDevolvidoModel(idItemPedido: idItem, quantidade: sel.quantidade),
          );
        }
      });
      _selecaoServico.forEach((idItem, sel) {
        if (sel.selecionado && sel.quantidade > 0) {
          itens.add(
            ItemDevolvidoModel(
                idItemServico: idItem, quantidade: sel.quantidade),
          );
        }
      });
    }

    final dto = DevolucaoRequestModel(
      idDocumentoOrigem: widget.idDocumentoOrigem,
      motivo: _motivo!,
      idUsuario: SessaoService.instance.idUsuario,
      codigoAt: FiscalConstants.codigoAT,
      itensDevolvidos: itens,
      observacoes: _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
    );

    final resultado = await context
        .read<PedidoProvider>()
        .processarDevolucaoOuTroca(widget.idPedido, dto);

    if (!mounted) return;

    setState(() => _enviando = false);

    if (resultado != null) {
      setState(() => _resultado = resultado);
    } else {
      final erro = context.read<PedidoProvider>().errorMessage ??
          'Erro ao processar devolução/anulação.';
      _snack(erro, _kAccent);
    }
  }


Future<void> _gerarPdfNotaCredito(DevolucaoResponseModel r) async {
    try {
      // DevolucaoResponseModel não traz codigoAt/emitidoEm — busca o
      // documento fiscal completo para poder montar o PDF correctamente.
      final documentoNota = await context
          .read<DocumentoFiscalProvider>()
          .buscarPorId(r.idNotaCredito);

      if (documentoNota == null) {
        _snack('Não foi possível carregar os dados da nota emitida.', _kAccent);
        return;
      }

      final pedido = _pedido;
      final itensDevolvidos = <ItemNotaRetificativaModel>[];

      if (_motivo != 'ERRO_PREENCHIMENTO' && pedido != null) {
        for (final item in pedido.itensProduto) {
          final sel = _selecaoProduto[item.idItemPedido];
          if (sel != null && sel.selecionado) {
            itensDevolvidos.add(ItemNotaRetificativaModel(
              descricao: item.nomeProduto,
              quantidade: sel.quantidade,
              precoUnitario: item.precoUnitario,
            ));
          }
        }
        for (final item in pedido.itensServico) {
          final sel = _selecaoServico[item.idItemServico];
          if (sel != null && sel.selecionado) {
            itensDevolvidos.add(ItemNotaRetificativaModel(
              descricao: item.nomeServico ?? 'Serviço #${item.idServico}',
              quantidade: sel.quantidade,
              precoUnitario: item.precoUnitario,
            ));
          }
        }
      }

      final nomeSingular = [
        pedido?.nomeClienteSingular,
        pedido?.apelidoClienteSingular,
      ].where((v) => v != null && v.trim().isNotEmpty).join(' ').trim();

final pdfDoc = NotaRetificativaPdfModel.deDevolucaoResponse(
        devolucao: r,
        documentoNota: documentoNota,
        referenciaDocumentoOrigem:
            widget.documentoOrigem?.referencia ?? 'Documento #${widget.idDocumentoOrigem}',
        referenciaPedidoOrigem: pedido?.referencia,
        cliente: _clienteCadastrado,
        nomeClienteSingular: nomeSingular.isNotEmpty ? pedido?.nomeClienteSingular : null,
        apelidoClienteSingular: nomeSingular.isNotEmpty ? pedido?.apelidoClienteSingular : null,
        observacoes: _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
        itensDevolvidos: itensDevolvidos,
      );

      final file = await PdfService.instance.gerarNotaRetificativa(pdfDoc);
      await PdfService.instance.abrirPdf(file);
    } catch (e) {
      _snack('Erro ao gerar PDF: $e', _kAccent);
    }
  }

  
  Future<bool> _confirmarAnulacaoTotal() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: _kAccent),
                SizedBox(width: 8),
                Text(
                  'Anular factura',
                  style: TextStyle(color: _kPrimary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Text(
              'Esta operação vai anular totalmente a factura de origem e '
              'creditar o valor total do pedido (${_currencyFmt.format(_pedido?.total ?? 0)}). '
              'Esta acção não pode ser revertida. Deseja continuar?',
              style: const TextStyle(fontSize: 13),
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
                child: const Text('Anular e Creditar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _irParaCriarPedidoTroca() async {
    // NOTA (decisão pendente): não foi possível confirmar se a tela de
    // criação de pedido de produtos aceita um cliente inicial como
    // argumento, pois esse ficheiro não foi fornecido nesta tarefa.
    // Por segurança, navega-se para lá sem pré-preencher o cliente.
    PedidoAtivoController.instance.limpar();
    context.read<PedidoProvider>().limparPedidoActual();

    await Navigator.pushNamed(context, '/catalogo');

    if (!mounted) return;
    Navigator.pop(context, _resultado);
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

  // ══════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackground,
      appBar: AppBar(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Devolução / Anulação',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator(color: _kPrimary));
    }

    if (_erroCarregamento != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: _kAccent, size: 52),
              const SizedBox(height: 12),
              Text(_erroCarregamento!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _kAccent)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _carregar,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
                style: ElevatedButton.styleFrom(backgroundColor: _kPrimary),
              ),
            ],
          ),
        ),
      );
    }

    if (_resultado != null) {
      return _buildResultado();
    }

    final pedido = _pedido!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        _buildCabecalho(pedido),
        const SizedBox(height: 14),
        _buildSeletorMotivo(),
        const SizedBox(height: 14),
        if (_motivo == 'ERRO_PREENCHIMENTO') _buildResumoAnulacaoTotal(pedido),
        if (_motivo == 'DEVOLUCAO' || _motivo == 'TROCA_PRODUTO')
          _buildListaItens(pedido),
        if (_motivo != null) ...[
          const SizedBox(height: 14),
          _buildObservacoes(),
          const SizedBox(height: 14),
          _buildResumoValor(),
          const SizedBox(height: 20),
          _buildBotaoConfirmar(),
        ],
      ],
    );
  }

  // ─── Cabeçalho ─────────────────────────────────────────────────────────

  Widget _buildCabecalho(PedidoModel pedido) {
    final nomeSingular = [
      pedido.nomeClienteSingular,
      pedido.apelidoClienteSingular,
    ].where((v) => v != null && v.trim().isNotEmpty).join(' ').trim();

    final clienteLabel = nomeSingular.isNotEmpty
        ? nomeSingular
        : (pedido.idCliente != null
            ? 'Cliente #${pedido.idCliente}'
            : 'Cliente avulso');

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _kPrimary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.receipt_long_rounded,
                      color: _kPrimary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pedido.referencia,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: _kPrimary,
                        ),
                      ),
                      if (widget.documentoOrigem != null)
                        Text(
                          'Factura: ${widget.documentoOrigem!.referencia}',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                    ],
                  ),
                ),
                Text(
                  _currencyFmt.format(pedido.total),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _kPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.person_outline_rounded,
                    size: 15, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  clienteLabel,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Seletor de motivo ─────────────────────────────────────────────────

  Widget _buildSeletorMotivo() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text(
                'Motivo',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: _kPrimary,
                ),
              ),
            ),
            RadioListTile<String>(
              value: 'ERRO_PREENCHIMENTO',
              groupValue: _motivo,
              activeColor: _kPrimary,
              title: const Text('Erro de preenchimento',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: const Text(
                'Anula a factura totalmente. Não mexe em stock.',
                style: TextStyle(fontSize: 11),
              ),
              onChanged: (v) => setState(() => _motivo = v),
            ),
            RadioListTile<String>(
              value: 'DEVOLUCAO',
              groupValue: _motivo,
              activeColor: _kPrimary,
              title: const Text('Devolução',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: const Text(
                'Devolve item(ns) ao stock. A factura permanece válida.',
                style: TextStyle(fontSize: 11),
              ),
              onChanged: (v) => setState(() => _motivo = v),
            ),
            RadioListTile<String>(
              value: 'TROCA_PRODUTO',
              groupValue: _motivo,
              activeColor: _kPrimary,
              title: const Text('Troca de produto',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: const Text(
                'Devolve o item antigo; o novo pedido é criado à parte.',
                style: TextStyle(fontSize: 11),
              ),
              onChanged: (v) => setState(() => _motivo = v),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Resumo de anulação total ──────────────────────────────────────────

  Widget _buildResumoAnulacaoTotal(PedidoModel pedido) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kAccent.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kAccent.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: _kAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'A factura ${widget.documentoOrigem?.referencia ?? '#${widget.idDocumentoOrigem}'} '
              'será anulada totalmente e o valor de ${_currencyFmt.format(pedido.total)} '
              'será creditado. O stock não será alterado.',
              style: const TextStyle(fontSize: 13, color: _kAccent, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Lista de itens (devolução / troca) ───────────────────────────────

  Widget _buildListaItens(PedidoModel pedido) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selecione os itens a devolver',
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13, color: _kPrimary),
            ),
            const SizedBox(height: 8),
            if (pedido.itensProduto.isEmpty && pedido.itensServico.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Este pedido não tem itens.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            ...pedido.itensProduto.map(
              (item) => _buildLinhaItemProduto(item),
            ),
            ...pedido.itensServico.map(
              (item) => _buildLinhaItemServico(item),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinhaItemProduto(ItemPedidoModel item) {
    final sel = _selecaoProduto[item.idItemPedido]!;

    return _LinhaItemDevolucao(
      titulo: item.nomeProduto,
      precoUnitario: item.precoUnitario,
      quantidadeMaxima: item.quantidade,
      selecionado: sel.selecionado,
      quantidade: sel.quantidade,
      currencyFmt: _currencyFmt,
      onSelecionarChanged: (v) => setState(() => sel.selecionado = v),
      onQuantidadeChanged: (q) => setState(() => sel.quantidade = q),
    );
  }

  Widget _buildLinhaItemServico(ItemPedidoServicoModel item) {
    final sel = _selecaoServico[item.idItemServico]!;

    return _LinhaItemDevolucao(
      titulo: item.nomeServico ?? 'Serviço #${item.idServico}',
      precoUnitario: item.precoUnitario,
      quantidadeMaxima: item.quantidade,
      selecionado: sel.selecionado,
      quantidade: sel.quantidade,
      currencyFmt: _currencyFmt,
      onSelecionarChanged: (v) => setState(() => sel.selecionado = v),
      onQuantidadeChanged: (q) => setState(() => sel.quantidade = q),
    );
  }

  // ─── Observações ───────────────────────────────────────────────────────

  Widget _buildObservacoes() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Observações (opcional)',
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13, color: _kPrimary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _obsCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Detalhes adicionais sobre a devolução...',
                filled: true,
                fillColor: _kBackground,
                contentPadding: const EdgeInsets.all(10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Resumo do valor a creditar ────────────────────────────────────────

  Widget _buildResumoValor() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _kPrimary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Valor a creditar',
              style: TextStyle(fontSize: 13, color: _kPrimary)),
          Text(
            _currencyFmt.format(_valorACreditar),
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: _kPrimary),
          ),
        ],
      ),
    );
  }

  // ─── Botão confirmar ───────────────────────────────────────────────────

  Widget _buildBotaoConfirmar() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: (!_podeConfirmar || _enviando) ? null : _confirmar,
        icon: _enviando
            ? const SizedBox(
                width: 18,
                height: 18,
                child:
                    CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.check_circle_outline_rounded),
        label: Text(_enviando ? 'A processar...' : 'Confirmar'),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              _motivo == 'ERRO_PREENCHIMENTO' ? _kAccent : _kPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // ─── Resultado pós-sucesso ─────────────────────────────────────────────

  Widget _buildResultado() {
    final r = _resultado!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: _kSuccess, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Nota de Crédito emitida',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold, color: _kPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              r.referenciaNotaCredito,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: _kPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Valor creditado: ${_currencyFmt.format(r.valorCreditado)}',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _gerarPdfNotaCredito(r),
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                label: const Text('Gerar PDF'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kAccent,
                  side: const BorderSide(color: _kAccent),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_motivo == 'TROCA_PRODUTO') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _irParaCriarPedidoTroca,
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  label: const Text('Criar pedido com novo produto'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, r),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kPrimary,
                  side: const BorderSide(color: _kPrimary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Concluir'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class DevolucaoTrocaArgs {
  final int idPedido;
  final int idDocumentoOrigem;
  final PedidoModel? pedidoInicial;
  final DocumentoFiscalModel? documentoOrigem;

  const DevolucaoTrocaArgs({
    required this.idPedido,
    required this.idDocumentoOrigem,
    this.pedidoInicial,
    this.documentoOrigem,
  });
}
// ─────────────────────────────────────────────────────────────────────────────
// Linha reutilizável de item (checkbox + stepper de quantidade)
// ─────────────────────────────────────────────────────────────────────────────

class _LinhaItemDevolucao extends StatelessWidget {
  final String titulo;
  final double precoUnitario;
  final int quantidadeMaxima;
  final bool selecionado;
  final int quantidade;
  final NumberFormat currencyFmt;
  final ValueChanged<bool> onSelecionarChanged;
  final ValueChanged<int> onQuantidadeChanged;

  const _LinhaItemDevolucao({
    required this.titulo,
    required this.precoUnitario,
    required this.quantidadeMaxima,
    required this.selecionado,
    required this.quantidade,
    required this.currencyFmt,
    required this.onSelecionarChanged,
    required this.onQuantidadeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: selecionado ? _kPrimary.withOpacity(0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selecionado
              ? _kPrimary.withOpacity(0.25)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: selecionado,
            activeColor: _kPrimary,
            onChanged: (v) => onSelecionarChanged(v ?? false),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${currencyFmt.format(precoUnitario)} × qtd (máx. $quantidadeMaxima)',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          if (selecionado) ...[
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.remove_circle_outline, size: 20),
              color: _kPrimary,
              onPressed: quantidade > 1
                  ? () => onQuantidadeChanged(quantidade - 1)
                  : null,
            ),
            Text(
              '$quantidade',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.add_circle_outline, size: 20),
              color: _kPrimary,
              onPressed: quantidade < quantidadeMaxima
                  ? () => onQuantidadeChanged(quantidade + 1)
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}