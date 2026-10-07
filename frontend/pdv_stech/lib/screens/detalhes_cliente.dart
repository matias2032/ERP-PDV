import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:api_compartilhado/api_compartilhado.dart';

// ── Cores STech Engenharia ────────────────────────────────────────────────────
const _kVermelho = Color(0xFFC8102E);
const _kAzul = Color(0xFF1B2A6B);
const _kBranco = Colors.white;
const _kCinzaClaro = Color(0xFFF4F5F7);
const _kCinzaTexto = Color(0xFF6B7280);

class DetalhesClienteScreen extends StatefulWidget {
  final ClienteModel cliente;

  const DetalhesClienteScreen({
    super.key,
    required this.cliente,
  });

  @override
  State<DetalhesClienteScreen> createState() => _DetalhesClienteScreenState();
}

class _DetalhesClienteScreenState extends State<DetalhesClienteScreen> {
  final _currencyFmt = NumberFormat.currency(locale: 'pt_PT', symbol: 'MZN');
  final _dateFmt = DateFormat('dd/MM/yyyy');

  bool _carregando = true;
  bool _gerandoPdf = false;
  String? _erroLocal;

  Map<String, dynamic> _extracto = const {};
  Map<String, dynamic> _extractoDocumental = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _carregar();
    });
  }

  Future<void> _carregar() async {
  if (mounted) {
    setState(() {
      _carregando = true;
      _erroLocal = null;
    });
  }

  try {
    // Carrega extracto documental (facturas e VDs)
    final docProvider = context.read<DocumentoFiscalProvider>();
    await docProvider.carregarExtractoDocumentalCliente(widget.cliente.id);

    // Carrega histórico comercial de crédito
    final pedidoProvider = context.read<PedidoProvider>();
    await pedidoProvider.carregarExtractoCliente(widget.cliente.id);

    if (!mounted) return;

    setState(() {
      _extractoDocumental = docProvider.extractoDocumentalCliente;
      _extracto = pedidoProvider.extractoCliente;
    });
  } catch (e) {
    _erroLocal = e.toString();
  } finally {
    if (mounted) {
      setState(() => _carregando = false);
    }
  }
}

  List<Map<String, dynamic>> get _linhas {
    final raw = _extracto['linhas'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  // Getters do extracto documental
List<Map<String, dynamic>> get _linhasDocumentais {
  final raw = _extractoDocumental['linhas'];
  if (raw is List) {
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  return [];
}

int get _totalDocumentosEmitidos =>
    (_extractoDocumental['totalDocumentos'] as num?)?.toInt() ??
    _linhasDocumentais.length;

double get _somaTotalDocumentos =>
    (_extractoDocumental['somaTotal'] as num?)?.toDouble() ?? 0.0;

  double get _totalDivida => (_extracto['totalDivida'] as num?)?.toDouble() ?? 0;
  double get _totalPago => (_extracto['totalPago'] as num?)?.toDouble() ?? 0;
  double get _saldo => (_extracto['saldo'] as num?)?.toDouble() ?? 0;

  bool get _ehDevedor => _saldo > 0.009;

  String get _situacaoLabel => _ehDevedor ? 'Em dívida' : 'Regular';
  Color get _situacaoCor => _ehDevedor ? _kVermelho : Colors.green;

  int get _quantidadeRegistos => _linhas.length;

int get _totalDocumentos =>
    _linhas.where((l) => l['idDocumentoFacturaCredito'] != null).length;

int get _pedidosPagos =>
    _linhas.where((l) => (l['statusPagamento'] ?? '').toString().toUpperCase() == 'PAGO').length;

int get _pedidosPendentes =>
    _linhas.where((l) {
      final status = (l['statusPagamento'] ?? '').toString().toUpperCase();
      return status == 'PENDENTE' || status == 'PARCIAL';
    }).length;

String get _mensagemSituacao {
  if (_ehDevedor) {
    return 'Cliente devedor: possui saldo pendente e requer acompanhamento comercial.';
  }
  return 'Cliente regular: não possui saldo pendente neste momento.';
}

  Future<void> _abrirDetalhesPedido(Map<String, dynamic> linha) async {
    final idPedido = (linha['idPedido'] as num?)?.toInt();
    if (idPedido == null) return;

    final provider = context.read<PedidoProvider>();
    final pedido = await provider.buscarPorId(idPedido);

    if (!mounted) return;

    if (pedido == null) {
      _snack(
        provider.errorMessage ?? 'Não foi possível abrir o pedido.',
        _kVermelho,
      );
      return;
    }

    await Navigator.of(context).pushNamed(
      '/pedidos_credito/detalhes',
      arguments: pedido,
    );

    if (mounted) {
      await _carregar();
    }
  }

Future<void> _gerarPdf() async {
  if (_gerandoPdf) return;
  setState(() => _gerandoPdf = true);
  try {
    final file = await ExtratoPdfService.instance.gerarExtractoDocumentalCliente(
      cliente: widget.cliente,
      extractoDocumental: _extractoDocumental,
    );
    await ExtratoPdfService.instance.abrirPdf(file);
  } catch (e) {
    if (mounted) {
      _snack('Erro ao gerar/abrir PDF: $e', _kVermelho);
    }
  } finally {
    if (mounted) {
      setState(() => _gerandoPdf = false);
    }
  }
}

  void _snack(String mensagem, Color cor) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: cor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kCinzaClaro,
      appBar: _buildAppBar(),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: _kAzul))
          : _erroLocal != null
              ? _ErroState(
                  erro: _erroLocal!,
                  onRecarregar: _carregar,
                )
              : RefreshIndicator(
                  color: _kAzul,
                  onRefresh: _carregar,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
                    children: [
  _ClienteHeaderCard(cliente: widget.cliente),
  const SizedBox(height: 12),
  _AcoesCard(
    gerandoPdf: _gerandoPdf,
    onGerarPdf: _gerarPdf,
  ),
  const SizedBox(height: 12),
  // ── SECÇÃO PRINCIPAL: extracto documental ──
  _ExtractoDocumentalCard(
    linhas: _linhasDocumentais,
    totalDocumentos: _totalDocumentosEmitidos,
    somaTotal: _somaTotalDocumentos,
    currencyFmt: _currencyFmt,
    dateFmt: _dateFmt,
  ),
  const SizedBox(height: 12),
  // ── SECÇÃO COMPLEMENTAR: histórico comercial ──
  _ResumoFinanceiroCard(
    totalDivida: _totalDivida,
    totalPago: _totalPago,
    saldo: _saldo,
    situacaoLabel: _situacaoLabel,
    situacaoCor: _situacaoCor,
    currencyFmt: _currencyFmt,
    quantidadeRegistos: _quantidadeRegistos,
    pedidosPagos: _pedidosPagos,
    pedidosPendentes: _pedidosPendentes,
    totalDocumentos: _totalDocumentos,
    mensagemSituacao: _mensagemSituacao,
  ),
  const SizedBox(height: 12),
  _HistoricoCard(
    linhas: _linhas,
    currencyFmt: _currencyFmt,
    dateFmt: _dateFmt,
    onAbrirPedido: _abrirDetalhesPedido,
  ),
],
                  ),
                ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _kAzul,
      foregroundColor: _kBranco,
      elevation: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _kVermelho,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.business_center_rounded,
              color: _kBranco,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.cliente.nomeCompleto,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Recarregar',
          onPressed: _carregar,
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Header do cliente
// ═════════════════════════════════════════════════════════════════════════════

class _ClienteHeaderCard extends StatelessWidget {
  final ClienteModel cliente;

  const _ClienteHeaderCard({required this.cliente});

  @override
  Widget build(BuildContext context) {
    return _CardBase(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: _kAzul.withOpacity(0.12),
            child: Text(
              cliente.iniciais,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: _kAzul,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cliente.nomeCompleto,
                  style: const TextStyle(
                    color: _kAzul,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _MiniInfo(
                      icon: Icons.badge_outlined,
                      label: cliente.nuit?.isNotEmpty == true ? cliente.nuit! : 'NUIT: —',
                    ),
                    _MiniInfo(
                      icon: Icons.phone_outlined,
                      label: cliente.contacto?.isNotEmpty == true
                          ? cliente.contacto!
                          : 'Sem contacto',
                    ),
                    _MiniInfo(
                      icon: Icons.email_outlined,
                      label: cliente.email?.isNotEmpty == true
                          ? cliente.email!
                          : 'Sem email',
                    ),
                    _MiniInfo(
                      icon: Icons.location_on_outlined,
                      label: cliente.morada?.isNotEmpty == true
                          ? cliente.morada!
                          : 'Sem morada',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Resumo financeiro
// ═════════════════════════════════════════════════════════════════════════════

class _ResumoFinanceiroCard extends StatelessWidget {
  final double totalDivida;
  final double totalPago;
  final double saldo;
  final String situacaoLabel;
  final Color situacaoCor;
  final NumberFormat currencyFmt;
  final int quantidadeRegistos;
  final int pedidosPagos;
  final int pedidosPendentes;
  final int totalDocumentos;
  final String mensagemSituacao;

  const _ResumoFinanceiroCard({
    required this.totalDivida,
    required this.totalPago,
    required this.saldo,
    required this.situacaoLabel,
    required this.situacaoCor,
    required this.currencyFmt,
    required this.quantidadeRegistos,
    required this.pedidosPagos,
    required this.pedidosPendentes,
    required this.totalDocumentos,
    required this.mensagemSituacao,
  });

@override
Widget build(BuildContext context) {
  return _CardBase(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _SectionTitle(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Situação comercial',
            ),
            const Spacer(),
            _StatusBadge(
              label: situacaoLabel,
              color: situacaoCor,
            ),
          ],
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: _InfoMetric(
                label: 'Total em crédito',
                value: currencyFmt.format(totalDivida),
                icon: Icons.receipt_long_rounded,
                color: _kAzul,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InfoMetric(
                label: 'Total pago',
                value: currencyFmt.format(totalPago),
                icon: Icons.payments_rounded,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InfoMetric(
                label: 'Saldo actual',
                value: currencyFmt.format(saldo),
                icon: Icons.warning_amber_rounded,
                color: saldo > 0 ? _kVermelho : Colors.green,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _InfoMetric(
                label: 'Registos',
                value: '$quantidadeRegistos',
                icon: Icons.format_list_numbered_rounded,
                color: _kAzul,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InfoMetric(
                label: 'Pagos',
                value: '$pedidosPagos',
                icon: Icons.check_circle_outline_rounded,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InfoMetric(
                label: 'Pend./Parc.',
                value: '$pedidosPendentes',
                icon: Icons.schedule_rounded,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InfoMetric(
                label: 'Documentos',
                value: '$totalDocumentos',
                icon: Icons.description_outlined,
                color: _kAzul,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: situacaoCor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: situacaoCor.withOpacity(0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _ehCorDevedor(situacaoCor)
                    ? Icons.warning_amber_rounded
                    : Icons.verified_rounded,
                color: situacaoCor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mensagemSituacao,
                  style: TextStyle(
                    color: situacaoCor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
}

// ═════════════════════════════════════════════════════════════════════════════
// Acções
// ═════════════════════════════════════════════════════════════════════════════

class _AcoesCard extends StatelessWidget {
  final bool gerandoPdf;
  final VoidCallback onGerarPdf;

  const _AcoesCard({
    required this.gerandoPdf,
    required this.onGerarPdf,
  });

  @override
  Widget build(BuildContext context) {
    return _CardBase(
      child: Row(
        children: [
          const Expanded(
            child: _SectionTitle(
              icon: Icons.tune_rounded,
              title: 'Acções',
            ),
          ),
          ElevatedButton.icon(
            onPressed: gerandoPdf ? null : onGerarPdf,
            icon: gerandoPdf
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: Text(gerandoPdf ? 'A preparar...' : 'Gerar PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAzul,
              foregroundColor: _kBranco,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Histórico
// ═════════════════════════════════════════════════════════════════════════════

class _HistoricoCard extends StatelessWidget {
  final List<Map<String, dynamic>> linhas;
  final NumberFormat currencyFmt;
  final DateFormat dateFmt;
  final Future<void> Function(Map<String, dynamic> linha) onAbrirPedido;

  const _HistoricoCard({
    required this.linhas,
    required this.currencyFmt,
    required this.dateFmt,
    required this.onAbrirPedido,
  });

  @override
  Widget build(BuildContext context) {
    return _CardBase(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
     Row(
  children: [
    const _SectionTitle(
      icon: Icons.history_rounded,
      title: 'Histórico comercial',
    ),
    const Spacer(),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _kAzul.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${linhas.length} registo(s)',
        style: const TextStyle(
          color: _kAzul,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  ],
),
          const SizedBox(height: 10),
          if (linhas.isEmpty)
            const _EmptyBox(
              icon: Icons.receipt_long_outlined,
              text: 'Nenhum histórico de crédito encontrado para este cliente.',
            )
          else
            Column(
              children: linhas
                  .map(
                    (linha) => _LinhaHistorico(
                      linha: linha,
                      currencyFmt: currencyFmt,
                      onAbrirPedido: onAbrirPedido,
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _LinhaHistorico extends StatelessWidget {
  final Map<String, dynamic> linha;
  final NumberFormat currencyFmt;
  final Future<void> Function(Map<String, dynamic> linha) onAbrirPedido;

  const _LinhaHistorico({
    required this.linha,
    required this.currencyFmt,
    required this.onAbrirPedido,
  });

  @override
  Widget build(BuildContext context) {
    final referencia = (linha['referencia'] ?? '—').toString();
    final total = (linha['total'] as num?)?.toDouble() ?? 0;
    final valorPago = (linha['valorPago'] as num?)?.toDouble() ?? 0;
    final saldo = (linha['saldo'] as num?)?.toDouble() ?? 0;
    final statusPagamento = (linha['statusPagamento'] ?? '—').toString();
    final idDocumento = linha['idDocumentoFacturaCredito'];
    final corStatus = _statusColor(statusPagamento);
    final idPedido = (linha['idPedido'] ?? '—').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: _kCinzaClaro,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: corStatus.withOpacity(0.10),
            child: Icon(
              Icons.receipt_long_rounded,
              color: corStatus,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          Text(
  referencia,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: const TextStyle(
    color: _kAzul,
    fontSize: 12,
    fontWeight: FontWeight.w700,
  ),
),
const SizedBox(height: 2),
Text(
  'Pedido #$idPedido',
  style: const TextStyle(
    fontSize: 11,
    color: _kCinzaTexto,
  ),
),
const SizedBox(height: 2),
Text(
  idDocumento != null ? 'Doc. #$idDocumento' : 'Documento pendente',
  style: TextStyle(
    fontSize: 11,
    color: idDocumento != null ? _kCinzaTexto : Colors.orange,
  ),
),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: _TextPair(
              label: 'Total',
              value: currencyFmt.format(total),
            ),
          ),
          Expanded(
            flex: 2,
            child: _TextPair(
              label: 'Pago',
              value: currencyFmt.format(valorPago),
              valueColor: Colors.green,
            ),
          ),
          Expanded(
            flex: 2,
            child: _TextPair(
              label: 'Saldo',
              value: currencyFmt.format(saldo),
              valueColor: saldo > 0 ? _kVermelho : Colors.green,
            ),
          ),
          _StatusBadge(
            label: _statusLabel(statusPagamento),
            color: corStatus,
          ),
          const SizedBox(width: 8),
       Tooltip(
  message: 'Abrir detalhe do pedido',
  child: InkWell(
    onTap: () => onAbrirPedido(linha),
    borderRadius: BorderRadius.circular(6),
    child: Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: _kAzul.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(
        Icons.visibility_outlined,
        size: 17,
        color: _kAzul,
      ),
    ),
  ),
),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Subwidgets comuns
// ═════════════════════════════════════════════════════════════════════════════

class _CardBase extends StatelessWidget {
  final Widget child;

  const _CardBase({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _kBranco,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: child,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _kAzul, size: 18),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(
            color: _kAzul,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _InfoMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _InfoMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _kCinzaTexto,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniInfo({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: _kCinzaTexto),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: _kCinzaTexto,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _TextPair extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _TextPair({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _kCinzaTexto,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: valueColor ?? _kAzul,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyBox({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      decoration: BoxDecoration(
        color: _kCinzaClaro,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Icon(icon, color: _kCinzaTexto, size: 34),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(
              color: _kCinzaTexto,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErroState extends StatelessWidget {
  final String erro;
  final Future<void> Function() onRecarregar;

  const _ErroState({
    required this.erro,
    required this.onRecarregar,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: _kVermelho,
              size: 52,
            ),
            const SizedBox(height: 12),
            Text(
              erro,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kVermelho),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRecarregar,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAzul,
                foregroundColor: _kBranco,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Helpers
// ═════════════════════════════════════════════════════════════════════════════


  bool _ehCorDevedor(Color cor) => cor == _kVermelho;
Color _statusColor(String status) {
  switch (status.toUpperCase()) {
    case 'PAGO':
      return Colors.green;
    case 'PARCIAL':
      return _kAzul;
    case 'PENDENTE':
      return _kVermelho;
    default:
      return _kCinzaTexto;
  }
}

String _statusLabel(String status) {
  switch (status.toUpperCase()) {
    case 'PAGO':
      return 'Pago';
    case 'PARCIAL':
      return 'Parcial';
    case 'PENDENTE':
      return 'Pendente';
    default:
      return status;
  }


}

// ═════════════════════════════════════════════════════════════════════════════
// Extracto documental do cliente (SECÇÃO PRINCIPAL)
// ═════════════════════════════════════════════════════════════════════════════

class _ExtractoDocumentalCard extends StatelessWidget {
  final List<Map<String, dynamic>> linhas;
  final int totalDocumentos;
  final double somaTotal;
  final NumberFormat currencyFmt;
  final DateFormat dateFmt;

  const _ExtractoDocumentalCard({
    required this.linhas,
    required this.totalDocumentos,
    required this.somaTotal,
    required this.currencyFmt,
    required this.dateFmt,
  });

  @override
  Widget build(BuildContext context) {
    return _CardBase(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SectionTitle(
                icon: Icons.description_outlined,
                title: 'Extracto Documental',
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _kAzul.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$totalDocumentos documento(s)',
                  style: const TextStyle(
                    color: _kAzul,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (linhas.isEmpty)
            const _EmptyBox(
              icon: Icons.receipt_long_outlined,
              text:
                  'Nenhuma factura ou VD emitida para este cliente.',
            )
          else ...[
            // Cabeçalho da tabela
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: _kAzul,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Expanded(
                      flex: 3,
                      child: Text('Documento',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700))),
                  Expanded(
                      flex: 2,
                      child: Text('Pedido',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700))),
                  Expanded(
                      flex: 2,
                      child: Text('Data',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700))),
                  Expanded(
                      flex: 2,
                      child: Text('Valor',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700))),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Column(
              children: linhas
                  .map((l) => _LinhaDocumental(
                        linha: l,
                        currencyFmt: currencyFmt,
                        dateFmt: dateFmt,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 10),
            // Totais
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kAzul.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kAzul.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total de documentos: $totalDocumentos',
                    style: const TextStyle(
                      color: _kAzul,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    currencyFmt.format(somaTotal),
                    style: const TextStyle(
                      color: _kVermelho,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LinhaDocumental extends StatelessWidget {
  final Map<String, dynamic> linha;
  final NumberFormat currencyFmt;
  final DateFormat dateFmt;

  const _LinhaDocumental({
    required this.linha,
    required this.currencyFmt,
    required this.dateFmt,
  });

  @override
  Widget build(BuildContext context) {
    final referencia = (linha['referencia'] ?? '—').toString();
    final tipo = (linha['tipoDocumento'] ?? '—').toString();
    final refPedido = (linha['referenciaPedido'] ?? '—').toString();
    final emitidoEmStr = linha['emitidoEm']?.toString();
    final emitidoEm = emitidoEmStr != null
        ? DateTime.tryParse(emitidoEmStr)
        : null;
    final valor =
        (linha['valorTotal'] as num?)?.toDouble() ?? 0.0;

    final corTipo = tipo == 'FAT' ? _kAzul : _kVermelho;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _kCinzaClaro,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  referencia,
                  style: const TextStyle(
                    color: _kAzul,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: corTipo.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tipo,
                    style: TextStyle(
                      color: corTipo,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              refPedido,
              style: const TextStyle(
                color: _kCinzaTexto,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              emitidoEm != null ? dateFmt.format(emitidoEm) : '—',
              style: const TextStyle(
                color: _kCinzaTexto,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              currencyFmt.format(valor),
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: _kAzul,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}