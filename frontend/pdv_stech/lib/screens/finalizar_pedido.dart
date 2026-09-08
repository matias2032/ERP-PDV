import 'package:flutter/material.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:api_compartilhado/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';


const _kPrimary    = Color.fromARGB(255, 58, 62, 79);
const _kAccent     = Color(0xFFC8102E);
const _kBackground = Color(0xFFF4F5F7);

class FinalizarPedidoScreen extends StatefulWidget {
  final PedidoModel pedido;
  final ModoFinalizacaoPedido modo;

  const FinalizarPedidoScreen({
    Key? key,
    required this.pedido,
    this.modo = ModoFinalizacaoPedido.normal,
  }) : super(key: key);

  @override
  State<FinalizarPedidoScreen> createState() => _FinalizarPedidoScreenState();
}

enum ModoFinalizacaoPedido {
  normal,
  credito,
}

class _FinalizarPedidoScreenState extends State<FinalizarPedidoScreen> {

  final _currencyFmt = NumberFormat.currency(locale: 'pt_PT', symbol: 'MZN');

  // ── Pagamento ─────────────────────────────────────────────────────────────
  List<TipoPagamentoResponseDTO> _tiposPagamento = [];
  int? _idTipoPagamento;
  final _valorPagoCtrl = TextEditingController();

  double get _valorPago =>
      double.tryParse(_valorPagoCtrl.text.replaceAll(',', '.')) ?? 0.0;
  double get _troco =>
      (_valorPago - widget.pedido.total).clamp(0, double.infinity);
  bool get _emDivida =>
      _valorPago > 0 && _valorPago < widget.pedido.total;

  // ── Cliente ───────────────────────────────────────────────────────────────
  String _tipoCliente = 'singular';
  List<ClienteModel> _empresas = [];
  ClienteModel? _empresaSelecionada;
  final _nomeCtrl    = TextEditingController();
  final _apelidoCtrl = TextEditingController();

  // ── Estado ────────────────────────────────────────────────────────────────
  bool _carregando  = true;
  bool _finalizando = false;
  bool    _clienteBloqueado     = false;
String? _nomeClienteBloqueado;
bool _clienteSingularBloqueado = false;


  bool get _ehDinheiro => _idTipoPagamento == 1;
  bool get _modoCredito => widget.modo == ModoFinalizacaoPedido.credito;

bool get _temEntradaInicial => _valorPago > 0;

double get _saldoCredito {
  final saldo = widget.pedido.total - _valorPago;
  return saldo < 0 ? 0 : saldo;
}

int? get _idClienteFinal {
  // Pedido já confirmado a crédito: o cliente nunca pode mudar.
  if (widget.pedido.ehCredito || widget.pedido.estaEmDivida) {
    return widget.pedido.idCliente;
  }

  if (_clienteBloqueado) {
    return widget.pedido.idCliente;
  }

  return _tipoCliente == 'empresa' ? _empresaSelecionada?.id : null;
}


bool get _podeFinalizar {
  if (_modoCredito) {
    if (_valorPago > widget.pedido.total) return false;

    // Venda a crédito exige cliente cadastrado.
    if (_idClienteFinal == null) return false;

    // Se houver entrada inicial, precisa escolher método de pagamento.
    if (_temEntradaInicial && _idTipoPagamento == null) return false;

    return true;
  }

  // Fluxo normal
  if (_idTipoPagamento == null) return false;
  if (_ehDinheiro && _valorPago < widget.pedido.total) return false;

  return true;
}


@override

void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _carregar();
  });
}


  @override
  void dispose() {
    _valorPagoCtrl.dispose();
    _nomeCtrl.dispose();
    _apelidoCtrl.dispose();
    super.dispose();
  }

  // ── Carregamento — usa Provider para tipos de pagamento ───────────────────

Future<void> _carregar() async {
  try {
    await context.read<PedidoProvider>().carregarTiposPagamento();
  } catch (_) {}

  try {
    await context.read<ClienteListaProvider>().filtrarPorPerfil(1);
  } catch (_) {}

  if (!mounted) return;

  final pedidoProvider = context.read<PedidoProvider>();
  final clienteProvider = context.read<ClienteListaProvider>();

  ClienteModel? clienteDoPedido;

  if (widget.pedido.idCliente != null) {
    try {
      clienteDoPedido = clienteProvider.clientes.firstWhere(
        (c) => c.id == widget.pedido.idCliente,
      );
    } catch (_) {
      clienteDoPedido = null;
    }
  }

  setState(() {
    _tiposPagamento = pedidoProvider.tiposPagamento;
    _empresas = clienteProvider.clientes;

    _idTipoPagamento = _tiposPagamento.isNotEmpty
        ? _tiposPagamento.first.idTipoPagamento
        : null;

    final pedidoJaCredito =
        widget.pedido.ehCredito || widget.pedido.estaEmDivida;

    if (_modoCredito) {
      _tipoCliente = 'empresa';
      _valorPagoCtrl.text = '0.00';

      if (pedidoJaCredito) {
        _clienteBloqueado = true;

        if (clienteDoPedido != null) {
          _empresaSelecionada = clienteDoPedido;
          _nomeClienteBloqueado = clienteDoPedido.nomeCompleto;
        } else if (widget.pedido.idCliente != null) {
          _nomeClienteBloqueado = 'Cliente #${widget.pedido.idCliente}';
        }
      }
    } else if (!_ehDinheiro && _idTipoPagamento != null) {
      _valorPagoCtrl.text = widget.pedido.total.toStringAsFixed(2);
    }

    final nomeSingular = widget.pedido.nomeClienteSingular?.trim();
    final apelidoSingular = widget.pedido.apelidoClienteSingular?.trim();

    final temClienteSingular = widget.pedido.idCliente == null &&
        ((nomeSingular != null && nomeSingular.isNotEmpty) ||
            (apelidoSingular != null && apelidoSingular.isNotEmpty));

    if (!_modoCredito) {
      _clienteBloqueado = widget.pedido.idCliente != null;
      _clienteSingularBloqueado = temClienteSingular;

      _nomeClienteBloqueado = clienteDoPedido?.nomeCompleto ??
          (widget.pedido.idCliente != null
              ? 'Cliente #${widget.pedido.idCliente}'
              : null);

      if (temClienteSingular) {
        _tipoCliente = 'singular';
        _nomeCtrl.text = nomeSingular ?? '';
        _apelidoCtrl.text = apelidoSingular ?? '';
      }
    }

    _carregando = false;
  });
}


  // ── Finalizar via Provider ────────────────────────────────────────────────

Future<void> _finalizar() async {
  if (_finalizando) {
    debugPrint('⏭️ FinalizacaoScreen._finalizar — já está finalizando, ignorado');
    return;
  }

  debugPrint('════════════════════════════════════════════════════');
  debugPrint('🧾 FinalizacaoScreen._finalizar — início');
  debugPrint('🆔 idPedido: ${widget.pedido.idPedido}');
  debugPrint('📌 referencia: ${widget.pedido.referencia}');
  debugPrint('💰 totalPedido: ${widget.pedido.total}');
  debugPrint('💳 idTipoPagamento: $_idTipoPagamento');
  debugPrint('💵 ehDinheiro: $_ehDinheiro');
  debugPrint('💵 valorPagoDigitado: $_valorPago');
  debugPrint('💳 modoCredito: $_modoCredito');
  debugPrint('🔒 clienteBloqueado: $_clienteBloqueado');
  debugPrint('👤 tipoCliente: $_tipoCliente');
  debugPrint('🏢 empresaSelecionada.id: ${_empresaSelecionada?.id}');
  debugPrint('🏢 empresaSelecionada.nome: ${_empresaSelecionada?.nomeCompleto}');
  debugPrint('👤 nomeCtrl.text: "${_nomeCtrl.text}"');
  debugPrint('👤 apelidoCtrl.text: "${_apelidoCtrl.text}"');
  debugPrint('👤 widget.pedido.idCliente: ${widget.pedido.idCliente}');
  debugPrint('👤 widget.pedido.nomeClienteSingular: "${widget.pedido.nomeClienteSingular}"');
  debugPrint('👤 widget.pedido.apelidoClienteSingular: "${widget.pedido.apelidoClienteSingular}"');
  debugPrint('════════════════════════════════════════════════════');

  if (_modoCredito) {
    debugPrint('➡️ FinalizacaoScreen._finalizar — redirecionando para _finalizarCredito()');
    return _finalizarCredito();
  }

  if (_idTipoPagamento == null) {
    debugPrint('⚠️ FinalizacaoScreen._finalizar — tipo de pagamento não seleccionado');
    return _snack('Seleccione o tipo de pagamento', Colors.orange);
  }

  if (_ehDinheiro && _valorPago < widget.pedido.total) {
    debugPrint(
      '⚠️ FinalizacaoScreen._finalizar — valor insuficiente: recebido=$_valorPago total=${widget.pedido.total}',
    );
    return _snack('O valor recebido é insuficiente', Colors.orange);
  }

  if (!_clienteBloqueado &&
      _tipoCliente == 'empresa' &&
      _empresaSelecionada == null) {
    debugPrint('⚠️ FinalizacaoScreen._finalizar — empresa não seleccionada');
    return _snack('Seleccione a empresa', Colors.orange);
  }

  setState(() => _finalizando = true);

  final idClienteFinal = _clienteBloqueado
      ? widget.pedido.idCliente
      : (_tipoCliente == 'empresa' ? _empresaSelecionada?.id : null);

final usarClienteSingular =
    !_clienteBloqueado && _tipoCliente == 'singular';

final nomeSingularFinal = usarClienteSingular
    ? _nomeCtrl.text.trim().nullIfEmpty
    : null;

final apelidoSingularFinal = usarClienteSingular
    ? _apelidoCtrl.text.trim().nullIfEmpty
    : null;

  final valorPagoFinal = _ehDinheiro ? _valorPago : widget.pedido.total;

  debugPrint('════════════════════════════════════════════════════');
  debugPrint('📦 FinalizacaoScreen._finalizar — DTO calculado');
  debugPrint('🆔 idPedido: ${widget.pedido.idPedido}');
  debugPrint('💳 idTipoPagamento: $_idTipoPagamento');
  debugPrint('💰 valorPagoFinal: $valorPagoFinal');
  debugPrint('👤 idClienteFinal: $idClienteFinal');
  debugPrint('👤 nomeSingularFinal: "$nomeSingularFinal"');
  debugPrint('👤 apelidoSingularFinal: "$apelidoSingularFinal"');
  debugPrint('🔒 clienteBloqueado: $_clienteBloqueado');
  debugPrint('👤 tipoCliente: $_tipoCliente');
  debugPrint('════════════════════════════════════════════════════');

  try {
    final dto = FinalizarPedidoRequestModel(
      idTipoPagamento: _idTipoPagamento!,
      valorPago: valorPagoFinal,
      idCliente: idClienteFinal,
      nomeClienteSingular: nomeSingularFinal,
      apelidoClienteSingular: apelidoSingularFinal,
    );

    debugPrint('🚀 FinalizacaoScreen._finalizar — chamando PedidoProvider.finalizarPedido');
    debugPrint('📦 dto.idTipoPagamento: ${dto.idTipoPagamento}');
    debugPrint('📦 dto.valorPago: ${dto.valorPago}');
    debugPrint('📦 dto.idCliente: ${dto.idCliente}');
    debugPrint('📦 dto.nomeClienteSingular: "${dto.nomeClienteSingular}"');
    debugPrint('📦 dto.apelidoClienteSingular: "${dto.apelidoClienteSingular}"');

    await context.read<PedidoProvider>().finalizarPedido(
          widget.pedido.idPedido,
          dto,
        );

    if (!mounted) {
      debugPrint('⏭️ FinalizacaoScreen._finalizar — widget desmontado após finalizar');
      return;
    }

    final provider = context.read<PedidoProvider>();

    debugPrint('════════════════════════════════════════════════════');
    debugPrint('📥 FinalizacaoScreen._finalizar — retorno do PedidoProvider');
    debugPrint('📌 provider.status: ${provider.status}');
    debugPrint('❌ provider.errorMessage: ${provider.errorMessage}');
    debugPrint('════════════════════════════════════════════════════');

    if (provider.errorMessage == null) {
      debugPrint('✅ FinalizacaoScreen._finalizar — pedido finalizado com sucesso');
      debugPrint('🧹 FinalizacaoScreen._finalizar — limpando PedidoAtivoController');

      PedidoAtivoController.instance.limpar();

      debugPrint('↩️ FinalizacaoScreen._finalizar — fechando tela com resultado true');
      Navigator.pop(context, true);
    } else {
      debugPrint(
        '❌ FinalizacaoScreen._finalizar — erro vindo do provider: ${provider.errorMessage}',
      );
      _snack('Erro: ${provider.errorMessage}', _kAccent);
    }
  } catch (e, s) {
    debugPrint('❌ FinalizacaoScreen._finalizar — exception inesperada: $e');
    debugPrint('$s');

    if (mounted) {
      _snack('Erro ao finalizar pedido: $e', _kAccent);
    }
  } finally {
    if (mounted) {
      debugPrint('🏁 FinalizacaoScreen._finalizar — fim, _finalizando=false');
      setState(() => _finalizando = false);
    }
  }
}

Future<void> _finalizarCredito() async {
  if (_idClienteFinal == null) {
    return _snack('Seleccione um cliente cadastrado para venda a crédito.', Colors.orange);
  }
  if (_valorPago > widget.pedido.total) {
    return _snack('A entrada inicial não pode ser maior que o total.', Colors.orange);
  }
  if (_temEntradaInicial && _idTipoPagamento == null) {
    return _snack('Seleccione o método de pagamento da entrada.', Colors.orange);
  }

  setState(() => _finalizando = true);

  try {
    final provider = context.read<PedidoProvider>();

    PedidoModel? pedidoCredito;

    // Se o pedido já é crédito (retry após falha parcial), não declarar de novo
if (widget.pedido.ehCredito || widget.pedido.estaEmDivida) {
  pedidoCredito = widget.pedido;
} else {
      pedidoCredito = await provider.declararCredito(
        widget.pedido.idPedido,
DeclararCreditoRequestModel(
  modalidadeCredito: 'SEM_PARCELAS',
  idUsuario: SessaoService.instance.idUsuario,
  idCliente: _idClienteFinal,
  nomeClienteSingular: null,
  apelidoClienteSingular: null,
  dataVencimento: null,
  observacoesCredito: null,
),
      );
    }

    if (pedidoCredito == null || provider.errorMessage != null) {
      throw Exception(provider.errorMessage ?? 'Não foi possível declarar crédito.');
    }

    if (_temEntradaInicial) {
      await provider.registarPagamentoCredito(
        widget.pedido.idPedido,
        RegistarPagamentoCreditoRequestModel(
          idTipoPagamento: _idTipoPagamento!,
          idUsuario: SessaoService.instance.idUsuario,
          valorPago: _valorPago,
          observacoes: 'Entrada inicial na venda a crédito',
        ),
      );

      if (provider.errorMessage != null) {
        throw Exception(provider.errorMessage);
      }
    }

if (!mounted) return;

final pedidoFinal = pedidoCredito ?? widget.pedido;


PedidoAtivoController.instance.limpar();
context.read<PedidoProvider>().limparPedidoActual();

Navigator.pop(context, true);
  } catch (e) {
    if (mounted) _snack('Erro ao finalizar a crédito: $e', _kAccent);
  } finally {
    if (mounted) setState(() => _finalizando = false);
  }
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

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackground,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: _carregando
                ? const SizedBox(
                    height: 300,
                    child: Center(
                        child: CircularProgressIndicator(color: _kPrimary)))
                : Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
_buildResumoCard(),
const SizedBox(height: 10),
_buildClienteCard(),
const SizedBox(height: 10),

if (_modoCredito) ...[
  _buildEntradaCreditoCard(),
  const SizedBox(height: 10),
  if (_temEntradaInicial) _buildPagamentoCard(),
  if (_temEntradaInicial) const SizedBox(height: 10),
  _buildSaldoCreditoCard(),
] else ...[
  _buildPagamentoCard(),
  const SizedBox(height: 10),
  if (_ehDinheiro) _buildTrocoCard(),
],

const SizedBox(height: 16),
_buildBotao(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 110,
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
Text(_modoCredito ? 'Finalizar a Crédito' : 'Finalizar Pedido',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    Text(widget.pedido.referencia,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 12)),
                  ],
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Resumo ───────────────────────────────────────────────────────────────

  Widget _buildResumoCard() {
    return _card(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _secLabel(Icons.receipt_outlined, 'Resumo'),
        const SizedBox(height: 8),
        ...widget.pedido.itensProduto
            .map((i) => _linhaItem('${i.quantidade}× ${i.nomeProduto}', i.subtotal)),
        ...widget.pedido.itensServico
            .map((i) => _linhaItem(
                '${i.quantidade}× ${i.nomeServico ?? 'Serviço'}', i.subtotal)),
        const Divider(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Total',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: _kPrimary)),
          Text(_currencyFmt.format(widget.pedido.total),
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: _kPrimary)),
        ]),
      ],
    ));
  }

  // ─── Cliente ──────────────────────────────────────────────────────────────

Widget _buildClienteCard() {
  if (_modoCredito && !_clienteBloqueado) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _secLabel(Icons.person_outline, 'Cliente cadastrado'),
          const SizedBox(height: 10),
          _buildEmpresaSelector(),
          const SizedBox(height: 8),
          _infoBox(
            icon: Icons.info_outline,
            texto:
                'Venda a crédito exige cliente cadastrado para permitir extracto, pagamentos e cobranças.',
            cor: _kPrimary,
          ),
        ],
      ),
    );
  }

  if (_clienteBloqueado) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _secLabel(Icons.person_outline, 'Cliente'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _kPrimary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kPrimary.withOpacity(0.15)),
                  ),
                  child: Text(
                    _nomeClienteBloqueado ?? '—',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _kPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              if (!_modoCredito &&
                  !widget.pedido.ehCredito &&
                  !widget.pedido.estaEmDivida)
                TextButton.icon(
                  onPressed: () => setState(() => _clienteBloqueado = false),
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: const Text(
                    'Alterar',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(foregroundColor: _kPrimary),
                ),
            ],
          ),
        ],
      ),
    );
  }

  return _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _secLabel(Icons.person_outline, 'Cliente'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _toggleBtn('singular', Icons.person_outline, 'Singular'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _toggleBtn('empresa', Icons.business, 'Empresa'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_tipoCliente == 'empresa')
          _buildEmpresaSelector()
        else
          _buildSingularFields(),
      ],
    ),
  );
}

  Widget _toggleBtn(String tipo, IconData icon, String label) {
    final sel = _tipoCliente == tipo;
    return GestureDetector(
   onTap: () => setState(() {
  _tipoCliente = tipo;
  _empresaSelecionada = null;

  if (tipo == 'empresa') {
    _clienteSingularBloqueado = false;
  }
}),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: sel ? _kPrimary : Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? _kPrimary : Colors.grey.shade300),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 15, color: sel ? Colors.white : Colors.grey[600]),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: sel ? Colors.white : Colors.grey[600])),
        ]),
      ),
    );
  }

  Widget _buildEmpresaSelector() {
    if (_empresas.isEmpty) {
      return _infoBox(
        key: const ValueKey('sem-empresas'),
        icon: Icons.info_outline,
        texto: 'Nenhuma empresa cadastrada.',
        cor: Colors.orange,
      );
    }
    return DropdownButtonFormField<ClienteModel>(
      key: const ValueKey('dropdown-empresa'),
      value: _empresaSelecionada,
      decoration: _inputDecoration('Seleccionar empresa…'),
      items: _empresas
          .map((e) => DropdownMenuItem(
                value: e,
                child: Text(e.nomeCompleto,
                    style: const TextStyle(fontSize: 13)),
              ))
          .toList(),
      onChanged: (v) => setState(() => _empresaSelecionada = v),
    );
  }


Widget _buildSingularFields() {
  final bloqueado = _clienteSingularBloqueado;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _textField(
              _nomeCtrl,
              'Nome (opcional)',
              enabled: !bloqueado,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _textField(
              _apelidoCtrl,
              'Apelido (opcional)',
              enabled: !bloqueado,
            ),
          ),
          if (bloqueado) ...[
            const SizedBox(width: 6),
            Container(
              height: 42,
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kPrimary.withOpacity(0.20)),
              ),
              child: IconButton(
                tooltip: 'Editar cliente',
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: _kPrimary,
                ),
                onPressed: () {
                  setState(() {
                    _clienteSingularBloqueado = false;
                  });
                },
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 5),
      Row(
        children: [
          Icon(Icons.info_outline, size: 11, color: Colors.grey[400]),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              bloqueado
                  ? 'Cliente vindo da cotação. Clique no lápis para editar.'
                  : 'Cliente não será cadastrado na base de dados.',
              style: TextStyle(fontSize: 10, color: Colors.grey[400]),
            ),
          ),
        ],
      ),
    ],
  );
}

  // ─── Pagamento ────────────────────────────────────────────────────────────

  Color _corPagamento(int id) {
    switch (id) {
      case 1: return const Color(0xFF2E7D32);
      case 2: return const Color(0xFF1565C0);
      
      case 3: return const Color(0xFFE53935);
      case 4: return const Color(0xFFFF8C00);
      default: return _kPrimary;
    }
  }

  Widget _buildEntradaCreditoCard() {
  return _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _secLabel(Icons.account_balance_wallet_outlined, 'Entrada inicial'),
        const SizedBox(height: 10),
        TextField(
          controller: _valorPagoCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _kPrimary,
          ),
          decoration: _inputDecoration('0.00').copyWith(
            labelText: 'Valor pago agora (opcional)',
            labelStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
            prefixText: 'MZN  ',
            prefixStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        _infoBox(
          icon: Icons.info_outline,
          texto: 'Deixe 0 caso o cliente não pague nenhuma entrada agora.',
          cor: _kPrimary,
        ),
      ],
    ),
  );
}

  Widget _buildPagamentoCard() {
    return _card(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
_secLabel(
  Icons.payment_outlined,
  _modoCredito ? 'Método de pagamento da entrada' : 'Pagamento',
),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _tiposPagamento.map((t) {
            final sel = _idTipoPagamento == t.idTipoPagamento;
            final cor = _corPagamento(t.idTipoPagamento);
            return GestureDetector(
              onTap: () => setState(() {
                _idTipoPagamento = t.idTipoPagamento;
                if (!_modoCredito && !_ehDinheiro) {
  _valorPagoCtrl.text = widget.pedido.total.toStringAsFixed(2);
}
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: sel ? cor.withOpacity(0.10) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: sel
                        ? cor.withOpacity(0.65)
                        : Colors.grey.shade300,
                    width: sel ? 1.6 : 1.0,
                  ),
                  boxShadow: sel
                      ? [
                          BoxShadow(
                              color: cor.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 3))
                        ]
                      : null,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    t.idTipoPagamento == 1
                        ? Icons.payments_rounded
                        : t.idTipoPagamento == 2
                            ? Icons.credit_card_rounded
                            : t.idTipoPagamento == 3
                                ? Icons.phone_android_rounded
                                : Icons.account_balance_wallet_rounded,
                    size: 15,
                    color: sel ? cor : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(t.tipoPagamento,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: sel ? cor : Colors.grey[700])),
                  if (sel) ...[
                    const SizedBox(width: 5),
                    Icon(Icons.check_circle_rounded,
                        size: 13, color: cor),
                  ],
                ]),
              ),
            );
          }).toList(),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
child: (!_modoCredito && _ehDinheiro)
    ? Column(children: [
        const SizedBox(height: 12),
        TextField(
          controller: _valorPagoCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _kPrimary,
          ),
          decoration: _inputDecoration('0.00').copyWith(
            labelText: 'Valor recebido',
            labelStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
            prefixText: 'MZN  ',
            prefixStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ])
    : const SizedBox.shrink(),
        ),
      ],
    ));
  }

  // ─── Troco / Dívida ───────────────────────────────────────────────────────

  Widget _buildTrocoCard() {
    final cor = _emDivida ? _kAccent : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Icon(
                _emDivida
                    ? Icons.warning_amber_outlined
                    : Icons.change_circle_outlined,
                color: cor,
                size: 18),
            const SizedBox(width: 8),
            Text(_emDivida ? 'Em dívida' : 'Troco',
                style: TextStyle(
                    color: cor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ]),
          Text(
            _currencyFmt.format(
                _emDivida ? widget.pedido.total - _valorPago : _troco),
            style: TextStyle(
                color: cor, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildSaldoCreditoCard() {
  final cor = _saldoCredito <= 0 ? Colors.green : _kAccent;

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      color: cor.withOpacity(0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: cor.withOpacity(0.25)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          Icon(Icons.pending_actions_outlined, color: cor, size: 18),
          const SizedBox(width: 8),
          Text(
            'Saldo em dívida',
            style: TextStyle(
              color: cor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ]),
        Text(
          _currencyFmt.format(_saldoCredito),
          style: TextStyle(
            color: cor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    ),
  );
}

  // ─── Botão ────────────────────────────────────────────────────────────────

Widget _buildBotao() {
  final activo = _podeFinalizar && !_finalizando;

  String texto;
  if (_finalizando) {
    texto = _modoCredito ? 'A confirmar crédito…' : 'A finalizar…';
  } else if (activo) {
    texto = _modoCredito ? 'Confirmar Venda a Crédito' : 'Confirmar Finalização';
  } else if (_modoCredito && _idClienteFinal == null) {
    texto = 'Seleccione um cliente cadastrado';
  } else if (_modoCredito && _valorPago > widget.pedido.total) {
    texto = 'Entrada maior que o total';
  } else if (_idTipoPagamento == null) {
    texto = 'Seleccione o método de pagamento';
  } else {
    texto = _modoCredito ? 'Verifique os dados do crédito' : 'Valor recebido insuficiente';
  }

  return SizedBox(
    width: double.infinity,
    height: 50,
    child: ElevatedButton.icon(
      onPressed: activo ? _finalizar : null,
      icon: _finalizando
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(
              activo
                  ? (_modoCredito
                      ? Icons.assignment_turned_in_outlined
                      : Icons.check_circle_outline)
                  : Icons.lock_outline_rounded,
            ),
      label: Text(
        texto,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        overflow: TextOverflow.ellipsis,
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: activo ? _kPrimary : Colors.grey[300],
        foregroundColor: activo ? Colors.white : Colors.grey[600],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: activo ? 3 : 0,
      ),
    ),
  );
}

  // ─── Utilitários de UI ────────────────────────────────────────────────────

  Widget _card({required Widget child}) => Card(
        elevation: 0,
        color: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(padding: const EdgeInsets.all(12), child: child),
      );

  Widget _secLabel(IconData icon, String texto) => Row(children: [
        Icon(icon, size: 14, color: _kPrimary),
        const SizedBox(width: 6),
        Text(texto,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: _kPrimary)),
      ]);

  Widget _linhaItem(String nome, double subtotal) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
                child: Text(nome,
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    overflow: TextOverflow.ellipsis)),
            Text(_currencyFmt.format(subtotal),
                style: const TextStyle(fontSize: 12, color: _kPrimary)),
          ],
        ),
      );

Widget _textField(
  TextEditingController ctrl,
  String hint, {
  bool enabled = true,
}) =>
    TextField(
      controller: ctrl,
      enabled: enabled,
      style: TextStyle(
        fontSize: 13,
        color: enabled ? Colors.black87 : _kPrimary,
        fontWeight: enabled ? FontWeight.normal : FontWeight.w600,
      ),
      decoration: _inputDecoration(hint).copyWith(
        fillColor: enabled ? _kBackground : _kPrimary.withOpacity(0.05),
        suffixIcon: enabled
            ? null
            : const Icon(
                Icons.lock_outline_rounded,
                size: 15,
                color: _kPrimary,
              ),
      ),
    );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
        filled: true,
        fillColor: _kBackground,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: _kPrimary.withOpacity(0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: _kPrimary.withOpacity(0.15)),
        ),
      );

  Widget _infoBox({
    Key? key,
    required IconData icon,
    required String texto,
    required Color cor,
  }) =>
      Container(
        key: key,
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: cor.withOpacity(0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cor.withOpacity(0.25)),
        ),
        child: Row(children: [
          Icon(icon, size: 14, color: cor),
          const SizedBox(width: 7),
          Expanded(
              child: Text(texto,
                  style: TextStyle(fontSize: 11, color: cor))),
        ]),
      );
}

extension _Str on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}