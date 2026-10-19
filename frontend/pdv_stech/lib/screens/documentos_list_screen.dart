// lib/features/documentos/screens/documentos_list_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:api_compartilhado/services/pdf_service.dart';
import '../../../theme/app_theme.dart';
import '../widgets/app_sidebar.dart';
import '../../../screens/devolucao_troca_screen.dart';
import '../../../screens/nota_debito_screen.dart';

// ── Cores ─────────────────────────────────────────────────────────────────────
// As antigas constantes (_kVermelho, _kAzul, _kBranco, _kCinzaClaro,
// _kCinzaTexto) foram substituídas pelo tema:
//   _kAzul       → context.cores.marca (texto/ícone/borda)
//                  context.cores.marcaBotao (fundo de botão/chip/snackbar)
//                  AppColors.azulMarca / azulMarcaEscuro (AppBar)
//   _kVermelho   → AppColors.vermelhoMarca (fundo: FAB, botão, ícone da AppBar),
//                  context.cores.acentoTexto (texto/ícone), context.cores.perigo (erros)
//   _kBranco     → AppColors.branco (sobre azul/vermelho) / context.cores.superficie (fundos)
//   _kCinzaClaro → context.cores.fundo
//   _kCinzaTexto → context.cores.textoSecundario
//   Colors.grey.shade300 → context.cores.borda

// ─────────────────────────────────────────────────────────────────────────────

class DocumentosListScreen extends StatefulWidget {
  const DocumentosListScreen({super.key});

  @override
  State<DocumentosListScreen> createState() => _DocumentosListScreenState();
}

class _DocumentosListScreenState extends State<DocumentosListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _termoPesquisa = '';
  String? _filtroTipo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DocumentoFiscalProvider>().carregarTodos();
      context.read<DocumentoFiscalProvider>().carregarTipos();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Filtros ───────────────────────────────────────────────────────────────

  List<DocumentoFiscalModel> _aplicarFiltros(List<DocumentoFiscalModel> todos) {
    var lista = todos;

    // 🔥 NOVO FILTRO INTELIGENTE
    lista = lista.where((d) {
      final isRecibo = d.tipoDocumento.codigo == 'REC';

      // esconder recibos de crédito
      if (isRecibo && d.tipoVenda == 'CREDITO') {
        return false;
      }

      return true;
    }).toList();
    if (_filtroTipo != null) {
      lista = lista.where((d) => d.tipoDocumento.codigo == _filtroTipo).toList();
    }
    if (_termoPesquisa.isNotEmpty) {
      final termo = _termoPesquisa.toLowerCase();
      lista = lista.where((d) {
        return d.referencia.toLowerCase().contains(termo) ||
            d.nomeUsuario.toLowerCase().contains(termo) ||
            d.codigoAt.toLowerCase().contains(termo);
      }).toList();
    }
    return lista;
  }

  // ── Gerar PDF a partir da listagem ───────────────────────────────────────
  //
  // Fluxo:
  //   1. Busca o PedidoModel pelo idPedido do documento (via API)
  //   2. Busca o ClienteModel pelo idCliente do pedido (via ClienteListaProvider)
  //   3. Resolve o nome do tipo de pagamento via PedidoService
  //   4. Gera o PDF

  Future<void> _gerarPdf(DocumentoFiscalModel doc) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('A preparar PDF…', style: TextStyle(color: Colors.white)),
          ],
        ),
        backgroundColor: context.cores.marcaBotao,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 30),
      ),
    );

    try {
      final codigo = doc.tipoDocumento.codigo;

      // Notas de Crédito/Débito têm uma estrutura própria (motivo, valor
      // creditado/debitado, itens devolvidos) — nunca a estrutura de
      // FAT/VD (tabela de itens do pedido inteiro + IVA + dados bancários).
      if (codigo == 'NCR' || codigo == 'NDB') {
        await _gerarPdfNotaRetificativa(doc);
        return;
      }

      // 1. Buscar o pedido pelo id.
      final pedido =
          await context.read<PedidoProvider>().buscarPorId(doc.idPedido);
      if (!mounted) return;
      if (pedido == null) throw Exception('Pedido não encontrado');

      // 2. Buscar o cliente
      ClienteModel? cliente;
      if (pedido.idCliente != null) {
        try {
          final clienteProvider = context.read<ClienteListaProvider>();
          final encontrado = clienteProvider.clientes
              .cast<ClienteModel?>()
              .firstWhere(
                (c) => c?.id == pedido.idCliente,
                orElse: () => null,
              );
          if (encontrado != null) {
            cliente = encontrado;
          } else {
            await clienteProvider.filtrarPorPerfil(1);
            if (!mounted) return;
            cliente = context
                .read<ClienteListaProvider>()
                .clientes
                .cast<ClienteModel?>()
                .firstWhere(
                  (c) => c?.id == pedido.idCliente,
                  orElse: () => null,
                );
          }
        } catch (_) {}
      }

      // 3. Resolver tipo de pagamento
      String nomeTipoPag = 'Dinheiro em espécie';
      try {
        await context.read<PedidoProvider>().carregarTiposPagamento();
        if (!mounted) return;
        final tipos = context.read<PedidoProvider>().tiposPagamento;
        final match = tipos.cast<TipoPagamentoResponseDTO?>().firstWhere(
          (t) => t?.idTipoPagamento == pedido.idTipoPagamento,
          orElse: () => null,
        );
        if (match != null) nomeTipoPag = match.tipoPagamento;
      } catch (_) {}

      // 4. ClienteModel mínimo se não encontrado
      cliente ??= ClienteModel(
        id:         pedido.idCliente ?? 0,
        nome:       pedido.idCliente != null
            ? 'Cliente #${pedido.idCliente}'
            : 'Cliente',
        apelido:    'Avulso',
        idPerfil:   1,
        nomePerfil: 'Sem perfil',
      );

      // 5. Gerar PDF
      final pdfService = PdfService();
      final pdfDoc = DocumentoPdfModel.deApiModelMultiplos(
        apiModel:      doc,
        pedidos:       [pedido],
        cliente:       cliente,
        tipoPagamento: nomeTipoPag,
      );

      final arquivo = await pdfService.gerarDocumentoFiscal(
        pdfDoc,
        documentoFiscal: doc,
      );
      if (mounted) ScaffoldMessenger.of(context).clearSnackBars();
      await pdfService.abrirPdf(arquivo);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        _mostrarSnack('Erro ao gerar PDF: $e', erro: true);
      }
    }
  }

  /// Gera o PDF de uma Nota de Crédito/Débito reabrindo dados persistidos
  /// no próprio documento (valorTotalEmissao = valor creditado/debitado,
  /// snapshotConteudo = itens devolvidos, motivoRetificacao = motivo) —
  /// nunca lendo o pedido ao vivo, que já pode ter mudado desde a emissão.
  ///
  /// Busca a factura (FAT/VD) de origem, o pedido e o cliente, tal como a
  /// DevolucaoTrocaScreen faz, para que o PDF gerado aqui fique idêntico
  /// ao gerado logo após a devolução.
  Future<void> _gerarPdfNotaRetificativa(DocumentoFiscalModel doc) async {
    final itens = <ItemNotaRetificativaModel>[];
    if (doc.snapshotConteudo != null && doc.snapshotConteudo!.trim().isNotEmpty) {
      try {
        final json = jsonDecode(doc.snapshotConteudo!) as Map<String, dynamic>;
        final lista = json['itensDevolvidos'] as List<dynamic>? ?? [];
        for (final i in lista) {
          final m = i as Map<String, dynamic>;
          itens.add(ItemNotaRetificativaModel(
            descricao: (m['descricao'] ?? '').toString(),
            quantidade: (m['quantidade'] as num?)?.toInt() ?? 0,
            precoUnitario: (m['precoUnitario'] as num?)?.toDouble() ?? 0,
          ));
        }
      } catch (_) {
        // snapshot ausente/corrompido — segue sem itens (ex: ERRO_PREENCHIMENTO)
      }
    }

    // 1. Localizar a factura (FAT/VD) de origem entre os documentos do
    //    mesmo pedido — é o mesmo pedido que gerou tanto a factura como
    //    esta nota retificativa.
    final documentosDoPedido = await context
        .read<DocumentoFiscalProvider>()
        .buscarDocumentosPorPedido(doc.idPedido);

    final DocumentoFiscalModel? factura = documentosDoPedido
        .cast<DocumentoFiscalModel?>()
        .firstWhere(
          (d) =>
              d != null &&
              (d.tipoDocumento.codigo == 'FAT' || d.tipoDocumento.codigo == 'VD'),
          orElse: () => null,
        );

    final referenciaDocumentoOrigem =
        factura?.referencia ?? 'Pedido #${doc.idPedido}';

    // 2. Buscar o pedido — dá acesso à referência do pedido e aos dados
    //    de cliente singular, tal como na tela de devolução.
    PedidoModel? pedido;
    try {
      pedido = await context.read<PedidoProvider>().buscarPorId(doc.idPedido);
    } catch (_) {}

    // 3. Buscar o cliente cadastrado, se aplicável.
    ClienteModel? cliente;
    if (pedido?.idCliente != null) {
      try {
        final clienteProvider = context.read<ClienteListaProvider>();
        var encontrado = clienteProvider.clientes
            .cast<ClienteModel?>()
            .firstWhere((c) => c?.id == pedido!.idCliente, orElse: () => null);
        if (encontrado == null) {
          await clienteProvider.filtrarPorPerfil(1);
          if (!mounted) return;
          encontrado = context
              .read<ClienteListaProvider>()
              .clientes
              .cast<ClienteModel?>()
              .firstWhere((c) => c?.id == pedido!.idCliente, orElse: () => null);
        }
        cliente = encontrado;
      } catch (_) {}
    }

    final nomeSingular = [
      pedido?.nomeClienteSingular,
      pedido?.apelidoClienteSingular,
    ].where((v) => v != null && v.trim().isNotEmpty).join(' ').trim();

    final pdfDoc = NotaRetificativaPdfModel(
      tipo: doc.tipoDocumento.codigo == 'NCR'
          ? TipoDocumentoPdf.notaCredito
          : TipoDocumentoPdf.notaDebito,
      referencia: doc.referencia,
      codigoAT: doc.codigoAt,
      dataEmissao: doc.emitidoEm,
      referenciaDocumentoOrigem: referenciaDocumentoOrigem,
      referenciaPedidoOrigem: pedido?.referencia,
      motivo: doc.motivoRetificacao ?? 'OUTRO',
      valor: doc.valorTotalEmissao ?? 0,
      cliente: cliente,
      nomeClienteSingular: nomeSingular.isNotEmpty ? pedido?.nomeClienteSingular : null,
      apelidoClienteSingular:
          nomeSingular.isNotEmpty ? pedido?.apelidoClienteSingular : null,
      itensDevolvidos: itens,
    );

    final arquivo = await PdfService.instance.gerarNotaRetificativa(pdfDoc);
    if (mounted) ScaffoldMessenger.of(context).clearSnackBars();
    await PdfService.instance.abrirPdf(arquivo);
  }

  // ── Anular documento ──────────────────────────────────────────────────────

  Future<void> _confirmarAnulacao(DocumentoFiscalModel doc) async {
    final motivoController = TextEditingController();

    final confirma = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoAnulacao(
        referencia: doc.referencia,
        motivoController: motivoController,
      ),
    );

    if (confirma == true && mounted) {
      final motivo = motivoController.text.trim();
      if (motivo.isEmpty) {
        _mostrarSnack('Motivo de anulação é obrigatório.', erro: true);
        return;
      }

      try {
        await context.read<DocumentoFiscalProvider>().anular(
              id: doc.id,
              motivoAnulacao: motivo,
            );
        if (mounted) {
          _mostrarSnack('Documento ${doc.referencia} anulado.');
          await context.read<DocumentoFiscalProvider>().carregarTodos();
        }
      } catch (_) {
        if (mounted) {
          _mostrarSnack(
            context.read<DocumentoFiscalProvider>().erro ?? 'Erro ao anular.',
            erro: true,
          );
        }
      }
    }
  }

  Future<void> _abrirDevolucao(DocumentoFiscalModel doc) async {
    final resultado = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(
        builder: (_) => DevolucaoTrocaScreen(
          idPedido: doc.idPedido,
          idDocumentoOrigem: doc.id,
          documentoOrigem: doc,
        ),
      ),
    );

    if (resultado != null && mounted) {
      await context.read<DocumentoFiscalProvider>().carregarTodos();
    }
  }

  //  ── NOTA DE DÉBITO — desativado ──────────────────────────────────────────
  //   Future<void> _abrirNotaDebito(DocumentoFiscalModel doc) async {
  //     final resultado = await Navigator.of(context).push<dynamic>(
  //       MaterialPageRoute(
  //         builder: (_) => NotaDebitoScreen(
  //           idDocumentoOrigem: doc.id,
  //           referenciaDocumento: doc.referencia,
  //         ),
  //       ),
  //     );

  //     if (resultado != null && mounted) {
  //       await context.read<DocumentoFiscalProvider>().carregarTodos();
  //     }
  //   }

  /// Fundo colorido FIXO + texto branco explícito: sem isso, no tema escuro
  /// o texto herdaria `textoPrincipal` (claro) e perderia contraste.
  void _mostrarSnack(String mensagem, {bool erro = false}) {
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

  // ── Navegar para formulário ───────────────────────────────────────────────

  Future<void> _abrirFormulario() async {
    final resultado =
        await Navigator.of(context).pushNamed('/cadastrar_documentos');
    if (resultado == true && mounted) {
      context.read<DocumentoFiscalProvider>().carregarTodos();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.cores;

    return Scaffold(
      backgroundColor: c.fundo,
      appBar: _buildAppBar(),
      drawer: const AppSidebar(currentRoute: '/gerenciar_documentos'),
      body: Column(
        children: [
          _BarraFiltros(
            searchController: _searchController,
            termoPesquisa: _termoPesquisa,
            filtroTipo: _filtroTipo,
            onPesquisar: (v) => setState(() => _termoPesquisa = v),
            onLimparPesquisa: () {
              _searchController.clear();
              setState(() => _termoPesquisa = '');
            },
            onFiltroTipo: (v) => setState(() => _filtroTipo = v),
          ),
          const Divider(height: 1),
          Expanded(
            child: _Listagem(
              aplicarFiltros: _aplicarFiltros,
              onGerarPdf: _gerarPdf,
              onAnular: _confirmarAnulacao,
              onDevolver: _abrirDevolucao,
              // onNotaDebito: _abrirNotaDebito,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirFormulario,
        backgroundColor: AppColors.vermelhoMarca,
        foregroundColor: AppColors.branco,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo Documento',
            style: TextStyle(fontWeight: FontWeight.w600)),
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
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.vermelhoMarca,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.receipt_long_rounded,
                color: AppColors.branco, size: 20),
          ),
          const SizedBox(width: 10),
          const Text(
            'Documentos Fiscais',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Recarregar',
          onPressed: () =>
              context.read<DocumentoFiscalProvider>().carregarTodos(),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Barra de Filtros
// ─────────────────────────────────────────────────────────────────────────────

class _BarraFiltros extends StatelessWidget {
  final TextEditingController searchController;
  final String termoPesquisa;
  final String? filtroTipo;
  final ValueChanged<String> onPesquisar;
  final VoidCallback onLimparPesquisa;
  final ValueChanged<String?> onFiltroTipo;

  const _BarraFiltros({
    required this.searchController,
    required this.termoPesquisa,
    required this.filtroTipo,
    required this.onPesquisar,
    required this.onLimparPesquisa,
    required this.onFiltroTipo,
  });

  static const _tipos = [
    (codigo: 'FAT', label: 'Factura'),
    (codigo: 'REC', label: 'Recibo'),
    (codigo: 'VD', label: 'Venda a Dinheiro'),
    // (codigo: 'NCO', label: 'Nota de compra'),
    (codigo: 'NE', label: 'Nota de Entrega'),
    (codigo: 'NCR', label: 'Nota de Crédito'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.cores;

    return Container(
      color: c.superficie,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  onChanged: onPesquisar,
                  decoration: InputDecoration(
                    hintText:
                        'Pesquisar por referência, utilizador ou código AT...',
                    hintStyle:
                        TextStyle(fontSize: 13, color: c.textoSecundario),
                    prefixIcon: Icon(Icons.search_rounded, color: c.marca),
                    suffixIcon: termoPesquisa.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close_rounded,
                                color: c.textoSecundario, size: 18),
                            onPressed: onLimparPesquisa,
                          )
                        : null,
                    filled: true,
                    fillColor: c.fundo,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Consumer<DocumentoFiscalProvider>(
                builder: (_, p, __) {
                  final total = p.documentos.length;
                  return Text(
                    '$total doc(s)',
                    style:
                        TextStyle(fontSize: 13, color: c.textoSecundario),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ChipFiltro(
                  label: 'Todos',
                  activo: filtroTipo == null,
                  onTap: () => onFiltroTipo(null),
                ),
                const SizedBox(width: 6),
                ..._tipos.map((t) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _ChipFiltro(
                        label: t.label,
                        activo: filtroTipo == t.codigo,
                        onTap: () => onFiltroTipo(t.codigo),
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipFiltro extends StatelessWidget {
  final String label;
  final bool activo;
  final VoidCallback onTap;

  const _ChipFiltro({
    required this.label,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cores;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: activo ? c.marcaBotao : c.fundo,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: activo ? c.marcaBotao : c.borda),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: activo ? FontWeight.w600 : FontWeight.normal,
            color: activo ? AppColors.branco : c.textoSecundario,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Listagem
// ─────────────────────────────────────────────────────────────────────────────

class _Listagem extends StatelessWidget {
  final List<DocumentoFiscalModel> Function(List<DocumentoFiscalModel>)
      aplicarFiltros;
  final Future<void> Function(DocumentoFiscalModel) onGerarPdf;
  final Future<void> Function(DocumentoFiscalModel) onAnular;
  final Future<void> Function(DocumentoFiscalModel) onDevolver;
  // final Future<void> Function(DocumentoFiscalModel) onNotaDebito;

  const _Listagem({
    required this.aplicarFiltros,
    required this.onGerarPdf,
    required this.onAnular,
    required this.onDevolver,
    // required this.onNotaDebito,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DocumentoFiscalProvider>();
    final c = context.cores;

    if (provider.carregando) {
      return Center(child: CircularProgressIndicator(color: c.marca));
    }

    if (provider.erro != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: c.perigo, size: 48),
            const SizedBox(height: 12),
            Text(provider.erro!,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.perigo)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => provider.carregarTodos(),
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.marcaBotao,
                foregroundColor: AppColors.branco,
              ),
            ),
          ],
        ),
      );
    }

    final lista = aplicarFiltros(provider.documentos);

    if (lista.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, color: c.desactivado, size: 48),
            const SizedBox(height: 12),
            Text('Nenhum documento encontrado.',
                style: TextStyle(color: c.textoSecundario)),
          ],
        ),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth > 800) {
        return _GradeDocumentos(
          documentos: lista,
          onGerarPdf: onGerarPdf,
          onAnular: onAnular,
          onDevolver: onDevolver,
          // onNotaDebito: onNotaDebito,
        );
      }
      return _ListaDocumentos(
        documentos: lista,
        onGerarPdf: onGerarPdf,
        onAnular: onAnular,
        onDevolver: onDevolver,
        // onNotaDebito: onNotaDebito,
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Card de Documento
// ─────────────────────────────────────────────────────────────────────────────

class _CardDocumento extends StatelessWidget {
  final DocumentoFiscalModel doc;
  final Future<void> Function(DocumentoFiscalModel) onGerarPdf;
  final Future<void> Function(DocumentoFiscalModel) onAnular;
  final Future<void> Function(DocumentoFiscalModel) onDevolver;
  // final Future<void> Function(DocumentoFiscalModel) onNotaDebito;

  const _CardDocumento({
    required this.doc,
    required this.onGerarPdf,
    required this.onAnular,
    required this.onDevolver,
    // required this.onNotaDebito,
  });

  /// Menu de Nota de Crédito/Débito só aparece para FAT/VD ainda válidos
  /// (não anulados). Documentos NCR/NDB ou já anulados não mostram a opção.
  bool get _podeDevolver =>
      !doc.anulado &&
      (doc.tipoDocumento.codigo == 'FAT' || doc.tipoDocumento.codigo == 'VD');

  /// Cor de cada tipo de documento. No tema claro mantém os tons originais;
  /// no escuro usa tons claros (os originais, escuros, não teriam contraste
  /// sobre a superfície escura).
  Color _corTipo(BuildContext context) {
    final c = context.cores;
    final escuro = context.escuro;
    return switch (doc.tipoDocumento.codigo) {
      'FAT' => escuro ? c.sucesso : const Color(0xFF0D6E3D),
      'REC' => escuro ? c.aviso : const Color(0xFF7B3F00),
      'VD' => escuro ? const Color(0xFFA5D6A7) : const Color(0xFF4CAF50),
      _ => c.textoSecundario,
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final anulado = doc.anulado;
    final corTipo = _corTipo(context);
    final alphaFundo = context.escuro ? 0.16 : 0.1;

    return Card(
      elevation: 0,
      color: c.superficie,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: anulado
              ? c.acentoTexto.withValues(alpha: 0.35)
              : c.borda,
          width: 1,
        ),
      ),
      child: Opacity(
        opacity: anulado ? 0.6 : 1.0,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Badge do tipo ──────────────────────────────────────────
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: corTipo.withValues(alpha: alphaFundo),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: corTipo.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      doc.tipoDocumento.codigo,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: corTipo,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Icon(_iconeTipo(doc.tipoDocumento.codigo),
                        color: corTipo, size: 18),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // ── Informações ────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            doc.referencia,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: anulado ? c.textoSecundario : c.marca,
                              decoration: anulado
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        if (anulado)
                          _BadgeAnulado()
                        else
                          _BadgeTipo(
                              label: doc.tipoDocumento.nome,
                              cor: corTipo),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        _InfoChip(
                            icon: Icons.person_outline_rounded,
                            label: doc.nomeUsuario),
                        _InfoChip(
                            icon: Icons.shopping_bag_outlined,
                            label: 'Pedido #${doc.idPedido}'),
                        _InfoChip(
                            icon: Icons.calendar_today_outlined,
                            label: _formatarData(doc.emitidoEm)),
                      ],
                    ),
                    if (anulado && doc.motivoAnulacao != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.block_rounded,
                              size: 12, color: c.acentoTexto),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Motivo: ${doc.motivoAnulacao}',
                              style: TextStyle(
                                  fontSize: 11, color: c.acentoTexto),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // ── Acções ─────────────────────────────────────────────────
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: anulado ? 'Gerar PDF anulado' : 'Gerar PDF',
                    child: IconButton(
                      icon: const Icon(Icons.picture_as_pdf_rounded),
                      color: c.marca,
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onGerarPdf(doc),
                    ),
                  ),
                  if (!anulado)
                    Tooltip(
                      message: 'Anular documento',
                      child: IconButton(
                        icon: const Icon(Icons.block_rounded),
                        color: c.acentoTexto,
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onAnular(doc),
                      ),
                    ),
                  if (_podeDevolver)
                    PopupMenuButton<String>(
                      tooltip: 'Devolução / Nota de Crédito',
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.more_vert_rounded,
                          color: c.textoSecundario, size: 20),
                      onSelected: (opcao) {
                        if (opcao == 'devolver') {
                          onDevolver(doc);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'devolver',
                          child: Text('Devolver / Anular (Nota de Crédito)'),
                        ),
                        // PopupMenuItem( // NOTA DE DÉBITO — desativado
                        //   value: 'nota_debito',
                        //   child: Text('Emitir Nota de Débito'),
                        // ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconeTipo(String codigo) {
    return switch (codigo) {
      'FAT' => Icons.receipt_rounded,
      'REC' => Icons.payments_rounded,
      // 'NCO' => Icons.note_alt_rounded,
      'VD' => Icons.attach_money_rounded,
      'NE' => Icons.note_alt_rounded,
      _ => Icons.description_rounded,
    };
  }

  String _formatarData(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _BadgeAnulado extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.acentoTexto.withValues(alpha: context.escuro ? 0.16 : 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.acentoTexto.withValues(alpha: 0.4)),
      ),
      child: Text(
        'ANULADO',
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: c.acentoTexto,
            letterSpacing: 0.5),
      ),
    );
  }
}

class _BadgeTipo extends StatelessWidget {
  final String label;
  final Color cor;
  const _BadgeTipo({required this.label, required this.cor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: context.escuro ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 11, color: cor, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c.textoSecundario),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 12, color: c.textoSecundario)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Layouts lista / grade
// ─────────────────────────────────────────────────────────────────────────────

class _ListaDocumentos extends StatelessWidget {
  final List<DocumentoFiscalModel> documentos;
  final Future<void> Function(DocumentoFiscalModel) onGerarPdf;
  final Future<void> Function(DocumentoFiscalModel) onAnular;
  final Future<void> Function(DocumentoFiscalModel) onDevolver;
  // final Future<void> Function(DocumentoFiscalModel) onNotaDebito;

  const _ListaDocumentos({
    required this.documentos,
    required this.onGerarPdf,
    required this.onAnular,
    required this.onDevolver,
    // required this.onNotaDebito,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: documentos.length,
      itemBuilder: (_, i) => _CardDocumento(
        doc: documentos[i],
        onGerarPdf: onGerarPdf,
        onAnular: onAnular,
        onDevolver: onDevolver,
        // onNotaDebito: onNotaDebito,
      ),
    );
  }
}

class _GradeDocumentos extends StatelessWidget {
  final List<DocumentoFiscalModel> documentos;
  final Future<void> Function(DocumentoFiscalModel) onGerarPdf;
  final Future<void> Function(DocumentoFiscalModel) onAnular;
  final Future<void> Function(DocumentoFiscalModel) onDevolver;
  // final Future<void> Function(DocumentoFiscalModel) onNotaDebito;

  const _GradeDocumentos({
    required this.documentos,
    required this.onGerarPdf,
    required this.onAnular,
    required this.onDevolver,
    // required this.onNotaDebito,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 680,
          mainAxisExtent: 156,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: documentos.length,
        itemBuilder: (_, i) => _CardDocumento(
          doc: documentos[i],
          onGerarPdf: onGerarPdf,
          onAnular: onAnular,
          onDevolver: onDevolver,
          // onNotaDebito: onNotaDebito,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Diálogo de Anulação
// ─────────────────────────────────────────────────────────────────────────────

class _DialogoAnulacao extends StatelessWidget {
  final String referencia;
  final TextEditingController motivoController;

  const _DialogoAnulacao({
    required this.referencia,
    required this.motivoController,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cores;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(
        children: [
          Icon(Icons.block_rounded, color: c.acentoTexto, size: 22),
          const SizedBox(width: 8),
          Text('Anular Documento',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: c.marca, fontSize: 17)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 13, color: c.textoSecundario),
              children: [
                const TextSpan(text: 'Anular o documento '),
                TextSpan(
                  text: referencia,
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: c.marca),
                ),
                const TextSpan(
                    text: '? Esta acção não pode ser revertida.\n\n'),
              ],
            ),
          ),
          TextField(
            controller: motivoController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Motivo da anulação *',
              hintText: 'Ex.: Documento emitido com erro...',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: c.marca, width: 1.5),
              ),
            ),
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
          icon: const Icon(Icons.block_rounded, size: 16),
          label: const Text('Anular'),
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