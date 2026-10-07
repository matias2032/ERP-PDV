// lib/features/documentos/screens/documentos_form_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:api_compartilhado/services/pdf_service.dart';

// ── Cores STech Engenharia ────────────────────────────────────────────────────
const _kVermelho   = Color(0xFFC8102E);
const _kAzul       = Color(0xFF1B2A6B);
const _kBranco     = Colors.white;
const _kCinzaClaro = Color(0xFFF4F5F7);
const _kCinzaTexto = Color(0xFF6B7280);

// ─────────────────────────────────────────────────────────────────────────────
//  Periodicidade disponível
// ─────────────────────────────────────────────────────────────────────────────

enum Periodicidade {
  hoje,
  umDia,
  umaSemana,
  quinzeDias,
  umMes,
  tresMeses,
  seisMeses,
  umAno,
}

extension PeriodicidadeExt on Periodicidade {
String get label => switch (this) {
      Periodicidade.hoje      => 'Hoje',
      Periodicidade.umDia      => '1 Dia',
      Periodicidade.umaSemana  => '1 Semana',
      Periodicidade.quinzeDias => '15 Dias',
      Periodicidade.umMes      => '1 Mês',
      Periodicidade.tresMeses  => '3 Meses',
      Periodicidade.seisMeses  => '6 Meses',
      Periodicidade.umAno      => '1 Ano',
    };

Duration get duracao => switch (this) {
      Periodicidade.hoje       => Duration.zero,
      Periodicidade.umDia      => const Duration(days: 1),
      Periodicidade.umaSemana  => const Duration(days: 7),
      Periodicidade.quinzeDias => const Duration(days: 15),
      Periodicidade.umMes      => const Duration(days: 30),
      Periodicidade.tresMeses  => const Duration(days: 90),
      Periodicidade.seisMeses  => const Duration(days: 180),
      Periodicidade.umAno      => const Duration(days: 365),
    };

bool pedidoDentroDoPeriodo(DateTime dataPedido, DateTime agora) {
  if (this == Periodicidade.hoje) {
    return dataPedido.year == agora.year &&
        dataPedido.month == agora.month &&
        dataPedido.day == agora.day;
  }

  final inicio = agora.subtract(duracao);

  return dataPedido.isAfter(inicio) &&
      !dataPedido.isAfter(agora);
}
}

// ─────────────────────────────────────────────────────────────────────────────
//  Tela principal
// ─────────────────────────────────────────────────────────────────────────────

class DocumentosFormScreen extends StatefulWidget {
  const DocumentosFormScreen({super.key});

  @override
  State<DocumentosFormScreen> createState() => _DocumentosFormScreenState();
}

class _DocumentosFormScreenState extends State<DocumentosFormScreen> {
  final _formKey = GlobalKey<FormState>();

  TipoDocumentoModel? _tipoSelecionado;
  ClienteModel?       _clienteSelecionado;
Periodicidade _periodicidade = Periodicidade.hoje;
  List<PedidoModel>   _pedidosFiltrados = [];
  bool _carregandoPedidos = false;
  bool _emitindo          = false;
  bool _houveAlteracoes   = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DocumentoFiscalProvider>().carregarTipos();
      context.read<ClienteListaProvider>().filtrarPorPerfil(1);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LÓGICA DE PEDIDOS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _carregarPedidosFiltrados() async {
  if (_clienteSelecionado == null) return;
  if (_carregandoPedidos) return;

  setState(() {
    _carregandoPedidos = true;
    _pedidosFiltrados  = [];
  });

  try {
    await context.read<PedidoProvider>().listarPorStatus('finalizado');
    if (!mounted) return;

    final provider = context.read<PedidoProvider>();
    if (provider.errorMessage != null) {
      _mostrarSnack('Erro ao carregar pedidos: ${provider.errorMessage}', erro: true);
      return;
    }

    final agora = DateTime.now();
final filtrados = provider.pedidos.where((p) {
  final baseFiltro =
      p.idCliente != null &&
      p.idCliente == _clienteSelecionado!.id &&
      _periodicidade.pedidoDentroDoPeriodo(p.dataPedido, agora);

  if (!baseFiltro) return false;

  // 🔥 NOVA REGRA
  final isRecibo = _tipoSelecionado?.codigo == 'REC';

  if (isRecibo) {
    return p.tipoVenda == 'IMEDIATA';
  }

  return true;
}).toList();

    if (mounted) setState(() => _pedidosFiltrados = filtrados);
  } catch (e) {
    if (mounted) _mostrarSnack('Erro ao carregar pedidos: $e', erro: true);
  } finally {
    if (mounted) setState(() => _carregandoPedidos = false);
  }
}

  // ─────────────────────────────────────────────────────────────────────────
  // RESOLVER TIPO DE PAGAMENTO
  // ─────────────────────────────────────────────────────────────────────────

  /// Usa PedidoService directamente para evitar conflito de tipos entre
  /// TipoPagamentoResponseDTO (do PedidoService) e TipoPagamentoModel
  /// (do PedidoProvider).  Retorna o nome ou um fallback.
Future<String> _resolverNomeTipoPagamento(int idTipoPagamento) async {
  try {
    await context.read<PedidoProvider>().carregarTiposPagamento();
    if (!mounted) return 'Dinheiro em espécie';
    final tipos = context.read<PedidoProvider>().tiposPagamento;
    final match = tipos.cast<TipoPagamentoResponseDTO?>().firstWhere(
      (t) => t?.idTipoPagamento == idTipoPagamento,
      orElse: () => null,
    );
    return match?.tipoPagamento ?? 'Dinheiro em espécie';
  } catch (_) {
    return 'Dinheiro em espécie';
  }
}
  // ─────────────────────────────────────────────────────────────────────────
  // EMITIR DOCUMENTOS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _emitir() async {
    if (!_formKey.currentState!.validate()) return;
    if (_tipoSelecionado == null) {
      _mostrarSnack('Seleccione o tipo de documento.', erro: true); return;
    }
    if (_clienteSelecionado == null) {
      _mostrarSnack('Seleccione o cliente.', erro: true); return;
    }
    if (_pedidosFiltrados.isEmpty) {
      _mostrarSnack('Nenhum pedido finalizado encontrado no período.', erro: true);
      return;
    }

    final docProvider = context.read<DocumentoFiscalProvider>();
    final idUsuario   = SessaoService.instance.idUsuario;

    if (idUsuario == 0) {
      _mostrarSnack('Sessão inválida. Por favor faça login novamente.', erro: true);
      return;
    }

    final confirma = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoConfirmacaoEmissao(
        tipoNome:      _tipoSelecionado!.nome,
        nomeCliente:   _clienteSelecionado!.nomeCompleto,
        periodicidade: _periodicidade.label,
        totalPedidos:  _pedidosFiltrados.length,
      ),
    );
    if (confirma != true || !mounted) return;

    setState(() => _emitindo = true);

    // Captura cópias locais ANTES de qualquer await / pop
    final pedidosParaPdf = List<PedidoModel>.from(_pedidosFiltrados);
    final clienteParaPdf = _clienteSelecionado!;

    try {
      final ids = _pedidosFiltrados.map((p) => p.idPedido).toList();

      final doc = await docProvider.emitirMultiplos(
        idsPedido:  ids,
        codigoTipo: _tipoSelecionado!.codigo,
        idUsuario:  idUsuario,
        codigoAt:   FiscalConstants.codigoAT,
      );

      if (!mounted) return;
      setState(() => _emitindo = false);

      if (doc != null) {
        _houveAlteracoes = true;
        _mostrarSnack('Documento ${doc.referencia} emitido com sucesso.');

        final gerarPdf = await showDialog<bool>(
          context: context,
          builder: (_) => _DialogoGerarPdf(totalDocs: 1),
        );

        // Pop ANTES de gerar o PDF para não bloquear a navegação
        if (mounted) Navigator.of(context).pop(true);

        // PDF gerado com cópias locais — independente do estado da screen
        if (gerarPdf == true) {
          await _gerarPdfComDados(doc, pedidosParaPdf, clienteParaPdf);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _emitindo = false);
        _mostrarSnack('Erro na emissão: $e', erro: true);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GERAR PDF (com dados já em memória — usado após emissão)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _gerarPdfComDados(
    DocumentoFiscalModel apiDoc,
    List<PedidoModel> pedidos,
    ClienteModel cliente,
  ) async {
    final pdfService = PdfService();

    // FIX: usa PedidoService directamente para evitar o conflito de tipos
    // (TipoPagamentoResponseDTO vs TipoPagamentoModel)
    final nomeTipoPag =
        await _resolverNomeTipoPagamento(pedidos.first.idTipoPagamento);

    try {
      final pdfDoc = DocumentoPdfModel.deApiModelMultiplos(
        apiModel:      apiDoc,
        pedidos:       pedidos,
        cliente:       cliente,
        tipoPagamento: nomeTipoPag,
      );

      final arquivo = await pdfService.gerarDocumentoFiscal(pdfDoc);
      await pdfService.abrirPdf(arquivo);
    } catch (e) {
      debugPrint('Erro ao gerar PDF: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  void _mostrarSnack(String mensagem, {bool erro = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: erro ? _kVermelho : _kAzul,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _houveAlteracoes);
        return false;
      },
      child: Scaffold(
        backgroundColor: _kCinzaClaro,
        appBar: _buildAppBar(),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCardTipoDocumento(),
                const SizedBox(height: 16),
                _buildCardCliente(),
                const SizedBox(height: 16),
                _buildCardPeriodicidade(),
                const SizedBox(height: 16),
                _buildCardResumoPedidos(),
                const SizedBox(height: 24),
                _BotaoEmitir(
                  emitindo: _emitindo,
                  habilitado: _tipoSelecionado != null &&
                      _clienteSelecionado != null &&
                      _pedidosFiltrados.isNotEmpty,
                  onPressed: _emitir,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _kAzul,
      foregroundColor: _kBranco,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.pop(context, _houveAlteracoes),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _kVermelho,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.post_add_rounded, color: _kBranco, size: 20),
          ),
          const SizedBox(width: 10),
          const Text(
            'Emitir Documento Fiscal',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }

  // ── Card 1 — Tipo de Documento ────────────────────────────────────────────

Widget _buildCardTipoDocumento() {
    return _CardSecao(
      icon: Icons.description_rounded,
      titulo: 'Tipo de Documento',
      filho: Consumer<DocumentoFiscalProvider>(
        builder: (_, provider, __) {
          if (provider.carregando) {
            return const Center(child: CircularProgressIndicator(color: _kAzul));
          }
          // Notas de Crédito/Débito têm fluxo próprio (ligadas a uma factura
          // de origem) e nunca devem aparecer como opção de emissão directa
          // a partir de um pedido.
final tipos = provider.tipos
    .where((t) => t.codigo != 'NCR' && t.codigo != 'NDB' && t.codigo != 'NDE')
    .toList();
          if (tipos.isEmpty) {
            return const Text('Nenhum tipo disponível.',
                style: TextStyle(color: _kCinzaTexto));
          }
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: tipos.map((tipo) {
              final seleccionado = _tipoSelecionado?.id == tipo.id;
              return GestureDetector(

                
onTap: () {
  setState(() => _tipoSelecionado = tipo);
  _carregarPedidosFiltrados(); // 🔥 importante
},
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: seleccionado ? _kAzul : _kBranco,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: seleccionado ? _kAzul : Colors.grey.shade300,
                      width: seleccionado ? 1.5 : 1,
                    ),
                    boxShadow: seleccionado
                        ? [
                            BoxShadow(
                              color: _kAzul.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _iconeTipo(tipo.codigo),
                        color: seleccionado ? _kBranco : _kAzul,
                        size: 26,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tipo.prefixo,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: seleccionado ? _kBranco : _kAzul,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tipo.nome,
                        style: TextStyle(
                          fontSize: 11,
                          color: seleccionado
                              ? _kBranco.withOpacity(0.85)
                              : _kCinzaTexto,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  // ── Card 2 — Cliente ──────────────────────────────────────────────────────

  Widget _buildCardCliente() {
    return _CardSecao(
      icon: Icons.business_rounded,
      titulo: 'Cliente',
      filho: Consumer<ClienteListaProvider>(
        builder: (_, provider, __) {
          if (provider.carregando) {
            return const Center(child: CircularProgressIndicator(color: _kAzul));
          }
          final clientes = provider.clientes;
          return DropdownButtonFormField<ClienteModel>(
            value: _clienteSelecionado,
            hint: const Text('Seleccione o cliente',
                style: TextStyle(color: _kCinzaTexto, fontSize: 13)),
            isExpanded: true,
            decoration:
                _inputDecoration(hint: '', icon: Icons.business_outlined),
            items: clientes
                .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(
                        c.nomeCompleto,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ))
                .toList(),
            onChanged: (c) {
              setState(() {
                _clienteSelecionado = c;
                _pedidosFiltrados   = [];
              });
              _carregarPedidosFiltrados();
            },
            validator: (v) => v == null ? 'Seleccione um cliente' : null,
          );
        },
      ),
    );
  }

  // ── Card 3 — Periodicidade ────────────────────────────────────────────────

  Widget _buildCardPeriodicidade() {
    return _CardSecao(
      icon: Icons.date_range_rounded,
      titulo: 'Período dos Pedidos',
      subtitulo:
          'Serão incluídos todos os pedidos finalizados do cliente dentro deste período.',
      filho: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: Periodicidade.values.map((p) {
              final activo = _periodicidade == p;
              return GestureDetector(
                onTap: () {
                  setState(() => _periodicidade = p);
                  _carregarPedidosFiltrados();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: activo ? _kVermelho : _kBranco,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: activo ? _kVermelho : Colors.grey.shade300,
                    ),
                    boxShadow: activo
                        ? [
                            BoxShadow(
                              color: _kVermelho.withOpacity(0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Text(
                    p.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          activo ? FontWeight.w700 : FontWeight.normal,
                      color: activo ? _kBranco : _kCinzaTexto,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_clienteSelecionado != null) ...[
            const SizedBox(height: 10),
            _InfoPeriodo(periodicidade: _periodicidade),
          ],
        ],
      ),
    );
  }

  // ── Card 4 — Resumo de pedidos encontrados ────────────────────────────────

  Widget _buildCardResumoPedidos() {
    return _CardSecao(
      icon: Icons.shopping_bag_outlined,
      titulo: 'Pedidos Incluídos',
      subtitulo: _clienteSelecionado == null
          ? 'Seleccione o cliente e o período para ver os pedidos.'
          : null,
      filho: _carregandoPedidos
          ? const Center(
              child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: _kAzul),
            ))
          : _clienteSelecionado == null
              ? const _EstadoVazio(
                  icon: Icons.inbox_outlined,
                  mensagem: 'Nenhum cliente seleccionado.',
                )
              : _pedidosFiltrados.isEmpty
                  ? const _EstadoVazio(
                      icon: Icons.search_off_rounded,
                      mensagem:
                          'Nenhum pedido finalizado encontrado no período.',
                    )
                  : Column(

                    
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        if (_tipoSelecionado?.codigo == 'REC')
  Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.orange.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: const [
        Icon(Icons.info_outline, size: 16, color: Colors.orange),
        SizedBox(width: 6),
        Expanded(
          child: Text(
            'Apenas pedidos imediatos podem gerar recibos.',
            style: TextStyle(fontSize: 12, color: Colors.orange),
          ),
        ),
      ],
    ),
  ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _kAzul.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline,
                                  color: _kAzul, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                '${_pedidosFiltrados.length} pedido(s) encontrado(s) — '
                                'será gerado 1 documento unificado.',
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: _kAzul,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        ..._pedidosFiltrados
                            .map((p) => _LinhaResumoPedido(pedido: p))
                            .toList(),
                      ],
                    ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  IconData _iconeTipo(String codigo) => switch (codigo) {
        'FAT' => Icons.receipt_rounded,
        'REC' => Icons.payments_rounded,
        // 'NCO' => Icons.note_alt_rounded,
        'VD' => Icons.attach_money_rounded,
        'NE' => Icons.note_alt_rounded,
        _ => Icons.description_rounded,
      };

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _kCinzaTexto, fontSize: 13),
      prefixIcon: Icon(icon, color: _kAzul, size: 20),
      filled: true,
      fillColor: _kBranco,
      contentPadding:
          const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kAzul, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kVermelho),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Widgets auxiliares
// ─────────────────────────────────────────────────────────────────────────────

class _CardSecao extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String? subtitulo;
  final Widget filho;

  const _CardSecao({
    required this.icon,
    required this.titulo,
    required this.filho,
    this.subtitulo,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: _kAzul, size: 20),
                const SizedBox(width: 8),
                Text(titulo,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _kAzul)),
              ],
            ),
            if (subtitulo != null) ...[
              const SizedBox(height: 6),
              Text(subtitulo!,
                  style:
                      const TextStyle(fontSize: 12, color: _kCinzaTexto)),
            ],
            const SizedBox(height: 14),
            filho,
          ],
        ),
      ),
    );
  }
}

class _LinhaResumoPedido extends StatelessWidget {
  final PedidoModel pedido;
  const _LinhaResumoPedido({required this.pedido});

  @override
  Widget build(BuildContext context) {
    final data    = pedido.dataPedido;
    final dataStr = '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/'
        '${data.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _kCinzaClaro,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_outlined, size: 16, color: _kAzul),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Pedido #${pedido.idPedido}  ·  Ref: ${pedido.referencia}',
              style: const TextStyle(
                  fontSize: 13,
                  color: _kAzul,
                  fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Text(dataStr,
              style: const TextStyle(fontSize: 11, color: _kCinzaTexto)),
          const SizedBox(width: 12),
          Text(
            'MZN ${pedido.total.toStringAsFixed(2)}',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _kVermelho),
          ),
        ],
      ),
    );
  }
}

class _InfoPeriodo extends StatelessWidget {
  final Periodicidade periodicidade;
  const _InfoPeriodo({required this.periodicidade});

@override
Widget build(BuildContext context) {
  final agora = DateTime.now();

  String fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';

  final textoPeriodo = periodicidade == Periodicidade.hoje
      ? 'Hoje (${fmt(agora)})'
      : 'Período: ${fmt(agora.subtract(periodicidade.duracao))} → ${fmt(agora)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _kVermelho.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kVermelho.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month_outlined,
              size: 14, color: _kVermelho),
          const SizedBox(width: 6),
    Text(
  textoPeriodo,
  style: const TextStyle(
    fontSize: 12,
    color: _kVermelho,
    fontWeight: FontWeight.w500,
  ),
),
        ],
      ),
    );
  }
}

class _EstadoVazio extends StatelessWidget {
  final IconData icon;
  final String mensagem;
  const _EstadoVazio({required this.icon, required this.mensagem});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _kCinzaTexto, size: 36),
            const SizedBox(height: 8),
            Text(mensagem,
                style:
                    const TextStyle(color: _kCinzaTexto, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Botão Emitir
// ─────────────────────────────────────────────────────────────────────────────

class _BotaoEmitir extends StatelessWidget {
  final bool emitindo;
  final bool habilitado;
  final VoidCallback onPressed;

  const _BotaoEmitir({
    required this.emitindo,
    required this.habilitado,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: (emitindo || !habilitado) ? null : onPressed,
      icon: emitindo
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: _kBranco),
            )
          : const Icon(Icons.send_rounded),
      label: Text(
        emitindo ? 'A emitir...' : 'EMITIR DOCUMENTOS',
        style: const TextStyle(fontSize: 16, letterSpacing: 0.5),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _kVermelho,
        foregroundColor: _kBranco,
        disabledBackgroundColor: _kVermelho.withOpacity(0.4),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Diálogos
// ─────────────────────────────────────────────────────────────────────────────

class _DialogoConfirmacaoEmissao extends StatelessWidget {
  final String tipoNome;
  final String nomeCliente;
  final String periodicidade;
  final int totalPedidos;

  const _DialogoConfirmacaoEmissao({
    required this.tipoNome,
    required this.nomeCliente,
    required this.periodicidade,
    required this.totalPedidos,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(
        children: const [
          Icon(Icons.send_rounded, color: _kAzul, size: 22),
          SizedBox(width: 8),
          Text('Confirmar Emissão',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: _kAzul, fontSize: 17)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LinhaInfo(label: 'Tipo:', valor: tipoNome),
          const SizedBox(height: 6),
          _LinhaInfo(label: 'Cliente:', valor: nomeCliente),
          const SizedBox(height: 6),
          _LinhaInfo(label: 'Período:', valor: periodicidade),
          const SizedBox(height: 6),
         _LinhaInfo(
  label: 'Documentos a emitir:',
  valor: '1',
  destaque: true,
),
          const SizedBox(height: 12),
       const Text(
  'Todos os pedidos serão agrupados num único documento. Esta acção não pode ser desfeita.',
  style: TextStyle(fontSize: 12, color: _kCinzaTexto),
),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child:
              const Text('Cancelar', style: TextStyle(color: _kCinzaTexto)),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.check_rounded, size: 16),
          label: const Text('Emitir'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kAzul,
            foregroundColor: _kBranco,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}

class _DialogoGerarPdf extends StatelessWidget {
  final int totalDocs;
  const _DialogoGerarPdf({required this.totalDocs});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(
        children: const [
          Icon(Icons.picture_as_pdf_rounded, color: _kVermelho, size: 22),
          SizedBox(width: 8),
          Text('Gerar PDFs',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: _kAzul, fontSize: 17)),
        ],
      ),
      content: Text(
        '$totalDocs documento(s) emitido(s).\nDeseja gerar e abrir os PDFs agora?',
        style: const TextStyle(fontSize: 13, color: _kCinzaTexto),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Agora não',
              style: TextStyle(color: _kCinzaTexto)),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.download_rounded, size: 16),
          label: const Text('Gerar PDFs'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kVermelho,
            foregroundColor: _kBranco,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}

class _LinhaInfo extends StatelessWidget {
  final String label;
  final String valor;
  final bool destaque;

  const _LinhaInfo({
    required this.label,
    required this.valor,
    this.destaque = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: _kCinzaTexto)),
        const SizedBox(width: 6),
        Text(
          valor,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: destaque ? _kVermelho : _kAzul,
          ),
        ),
      ],
    );
  }
}