// lib/features/documentos/screens/documentos_form_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:api_compartilhado/services/pdf_service.dart';
import '../../../theme/app_theme.dart';

// ── Cores ─────────────────────────────────────────────────────────────────────
// As antigas constantes (_kVermelho, _kAzul, _kBranco, _kCinzaClaro,
// _kCinzaTexto) foram substituídas pelo tema:
//   _kAzul       → context.cores.marca (texto/ícone/borda)
//                  context.cores.marcaBotao (fundo de botão/cartão seleccionado/snackbar)
//                  AppColors.azulMarca / azulMarcaEscuro (AppBar)
//   _kVermelho   → AppColors.vermelhoMarca (fundo: botão, chip activo, ícone da AppBar),
//                  context.cores.acentoTexto (texto/ícone), context.cores.perigo (erro de campo)
//   _kBranco     → AppColors.branco (sobre azul/vermelho) / context.cores.superficie (fundos)
//   _kCinzaClaro → context.cores.fundo
//   _kCinzaTexto → context.cores.textoSecundario
//   Colors.orange → context.cores.aviso | Colors.grey.shade200/300 → context.cores.borda

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
        Periodicidade.hoje       => 'Hoje',
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

  /// Fundo colorido FIXO + texto branco explícito: sem isso, no tema escuro
  /// o texto herdaria `textoPrincipal` (claro) e perderia contraste.
  void _mostrarSnack(String mensagem, {bool erro = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem, style: const TextStyle(color: Colors.white)),
        backgroundColor:
            erro ? AppColors.vermelhoMarca : context.cores.marcaBotao,
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
    final cores = context.cores;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _houveAlteracoes);
        return false;
      },
      child: Scaffold(
        backgroundColor: cores.fundo,
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
      // Mesmo critério da AppBar do tema escuro (azulMarcaEscuro).
      backgroundColor:
          context.escuro ? AppColors.azulMarcaEscuro : AppColors.azulMarca,
      foregroundColor: AppColors.branco,
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
              color: AppColors.vermelhoMarca,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.post_add_rounded,
                color: AppColors.branco, size: 20),
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
    final cores = context.cores;

    return _CardSecao(
      icon: Icons.description_rounded,
      titulo: 'Tipo de Documento',
      filho: Consumer<DocumentoFiscalProvider>(
        builder: (_, provider, __) {
          if (provider.carregando) {
            return Center(
                child: CircularProgressIndicator(color: cores.marca));
          }
          // Notas de Crédito/Débito têm fluxo próprio (ligadas a uma factura
          // de origem) e nunca devem aparecer como opção de emissão directa
          // a partir de um pedido.
          final tipos = provider.tipos
              .where((t) =>
                  t.codigo != 'NCR' && t.codigo != 'NDB' && t.codigo != 'NDE')
              .toList();
          if (tipos.isEmpty) {
            return Text('Nenhum tipo disponível.',
                style: TextStyle(color: cores.textoSecundario));
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
                    color: seleccionado ? cores.marcaBotao : cores.superficie,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: seleccionado ? cores.marcaBotao : cores.borda,
                      width: seleccionado ? 1.5 : 1,
                    ),
                    boxShadow: seleccionado
                        ? [
                            BoxShadow(
                              color: cores.marcaBotao.withValues(alpha: 0.2),
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
                        color: seleccionado ? AppColors.branco : cores.marca,
                        size: 26,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tipo.prefixo,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: seleccionado ? AppColors.branco : cores.marca,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tipo.nome,
                        style: TextStyle(
                          fontSize: 11,
                          color: seleccionado
                              ? AppColors.branco.withValues(alpha: 0.85)
                              : cores.textoSecundario,
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
    final cores = context.cores;

    return _CardSecao(
      icon: Icons.business_rounded,
      titulo: 'Cliente',
      filho: Consumer<ClienteListaProvider>(
        builder: (_, provider, __) {
          if (provider.carregando) {
            return Center(
                child: CircularProgressIndicator(color: cores.marca));
          }
          final clientes = provider.clientes;
          return DropdownButtonFormField<ClienteModel>(
            value: _clienteSelecionado,
            hint: Text('Seleccione o cliente',
                style: TextStyle(color: cores.textoSecundario, fontSize: 13)),
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
    final cores = context.cores;

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
                    color: activo ? AppColors.vermelhoMarca : cores.superficie,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: activo ? AppColors.vermelhoMarca : cores.borda,
                    ),
                    boxShadow: activo
                        ? [
                            BoxShadow(
                              color: AppColors.vermelhoMarca
                                  .withValues(alpha: 0.2),
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
                      color: activo ? AppColors.branco : cores.textoSecundario,
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
    final cores = context.cores;
    final alphaFundo = context.escuro ? 0.14 : 0.07;

    return _CardSecao(
      icon: Icons.shopping_bag_outlined,
      titulo: 'Pedidos Incluídos',
      subtitulo: _clienteSelecionado == null
          ? 'Seleccione o cliente e o período para ver os pedidos.'
          : null,
      filho: _carregandoPedidos
          ? Center(
              child: Padding(
              padding: const EdgeInsets.all(16),
              child: CircularProgressIndicator(color: cores.marca),
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
                              color: cores.aviso.withValues(
                                  alpha: context.escuro ? 0.16 : 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    size: 16, color: cores.aviso),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Apenas pedidos imediatos podem gerar recibos.',
                                    style: TextStyle(
                                        fontSize: 12, color: cores.aviso),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: cores.marca.withValues(alpha: alphaFundo),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline,
                                  color: cores.marca, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                '${_pedidosFiltrados.length} pedido(s) encontrado(s) — '
                                'será gerado 1 documento unificado.',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: cores.marca,
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
    final cores = context.cores;
    // Borda de campo com contraste suficiente no tema escuro (mesmo valor
    // usado no inputDecorationTheme/outline do tema escuro).
    final bordaCampo = BorderSide(
      color: context.escuro ? const Color(0xFF6B7499) : cores.borda,
    );

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: cores.textoSecundario, fontSize: 13),
      prefixIcon: Icon(icon, color: cores.marca, size: 20),
      filled: true,
      fillColor: cores.superficie,
      contentPadding:
          const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: bordaCampo,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: bordaCampo,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: cores.marca, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: cores.perigo),
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
    final c = context.cores;
    return Card(
      elevation: 0,
      color: c.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.borda),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: c.marca, size: 20),
                const SizedBox(width: 8),
                Text(titulo,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: c.marca)),
              ],
            ),
            if (subtitulo != null) ...[
              const SizedBox(height: 6),
              Text(subtitulo!,
                  style: TextStyle(fontSize: 12, color: c.textoSecundario)),
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
    final c = context.cores;
    final data    = pedido.dataPedido;
    final dataStr = '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/'
        '${data.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.fundo,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.borda),
      ),
      child: Row(
        children: [
          Icon(Icons.receipt_outlined, size: 16, color: c.marca),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Pedido #${pedido.idPedido}  ·  Ref: ${pedido.referencia}',
              style: TextStyle(
                  fontSize: 13,
                  color: c.marca,
                  fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Text(dataStr,
              style: TextStyle(fontSize: 11, color: c.textoSecundario)),
          const SizedBox(width: 12),
          Text(
            'MZN ${pedido.total.toStringAsFixed(2)}',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: c.acentoTexto),
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
    final c = context.cores;
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
        color: c.acentoTexto.withValues(alpha: context.escuro ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.acentoTexto.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_month_outlined,
              size: 14, color: c.acentoTexto),
          const SizedBox(width: 6),
          Text(
            textoPeriodo,
            style: TextStyle(
              fontSize: 12,
              color: c.acentoTexto,
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
    final c = context.cores;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: c.textoSecundario, size: 36),
            const SizedBox(height: 8),
            Text(mensagem,
                style: TextStyle(color: c.textoSecundario, fontSize: 13)),
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
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.branco),
            )
          : const Icon(Icons.send_rounded),
      label: Text(
        emitindo ? 'A emitir...' : 'EMITIR DOCUMENTOS',
        style: const TextStyle(fontSize: 16, letterSpacing: 0.5),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.vermelhoMarca,
        foregroundColor: AppColors.branco,
        disabledBackgroundColor:
            AppColors.vermelhoMarca.withValues(alpha: 0.4),
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
    final c = context.cores;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(
        children: [
          Icon(Icons.send_rounded, color: c.marca, size: 22),
          const SizedBox(width: 8),
          Text('Confirmar Emissão',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: c.marca, fontSize: 17)),
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
          Text(
            'Todos os pedidos serão agrupados num único documento. Esta acção não pode ser desfeita.',
            style: TextStyle(fontSize: 12, color: c.textoSecundario),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Cancelar', style: TextStyle(color: c.textoSecundario)),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.check_rounded, size: 16),
          label: const Text('Emitir'),
          style: ElevatedButton.styleFrom(
            backgroundColor: c.marcaBotao,
            foregroundColor: AppColors.branco,
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
    final c = context.cores;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(
        children: [
          Icon(Icons.picture_as_pdf_rounded, color: c.acentoTexto, size: 22),
          const SizedBox(width: 8),
          Text('Gerar PDFs',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: c.marca, fontSize: 17)),
        ],
      ),
      content: Text(
        '$totalDocs documento(s) emitido(s).\nDeseja gerar e abrir os PDFs agora?',
        style: TextStyle(fontSize: 13, color: c.textoSecundario),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Agora não',
              style: TextStyle(color: c.textoSecundario)),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.download_rounded, size: 16),
          label: const Text('Gerar PDFs'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.vermelhoMarca,
            foregroundColor: AppColors.branco,
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
    final c = context.cores;
    return Row(
      children: [
        Text(label,
            style: TextStyle(fontSize: 13, color: c.textoSecundario)),
        const SizedBox(width: 6),
        Text(
          valor,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: destaque ? c.acentoTexto : c.marca,
          ),
        ),
      ],
    );
  }
}