// lib/screens/produto_form_screen.dart

// import 'dart:io';                                   // [IMAGENS] desactivado
// import 'package:cross_file/cross_file.dart';        // [IMAGENS] desactivado
// import 'package:desktop_drop/desktop_drop.dart';    // [IMAGENS] desactivado
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:image_picker/image_picker.dart';    // [IMAGENS] desactivado
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
// import 'package:api_compartilhado/api_config.dart'; // [IMAGENS] desactivado
import 'package:api_compartilhado/providers/produto_provider.dart';
import 'package:api_compartilhado/providers/marca_provider.dart';
import 'package:api_compartilhado/providers/categoria_provider.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────

class ProdutoFormScreen extends StatefulWidget {
  final ProdutoModel? produto;
  const ProdutoFormScreen({super.key, this.produto});

  @override
  State<ProdutoFormScreen> createState() => _ProdutoFormScreenState();
}

class _ProdutoFormScreenState extends State<ProdutoFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _currencyFmt = NumberFormat.currency(locale: 'pt_PT', symbol: 'MZN');

  // ── Controllers ────────────────────────────────────────────────────────────
  late TextEditingController _nomeController;
  late TextEditingController _descricaoController;
  late TextEditingController _precoController; // preço BASE (sem IVA)
  late TextEditingController _precoPromoController;
  late TextEditingController _estoqueController;

  // ── Estado geral ───────────────────────────────────────────────────────────
  bool _isSaving = false;
  bool _houveAlteracoes = false;
  bool get _isEditMode => widget.produto != null;

  // ── IVA ────────────────────────────────────────────────────────────────────
  /// IVA vigente (configuração do sistema).
  double get _ivaPct => ConfiguracaoService.instance.ivaPercentual;

  // ── Selecções de marca / categoria ────────────────────────────────────────
  List<int> _marcasSelecionadas = [];
  List<int> _categoriasSelecionadas = [];

  // ── [IMAGENS] Estado de imagens — desactivado temporariamente ─────────────
  // List<ProdutoImagemModel> _imagensExistentes = [];
  // List<File>               _novasImagens      = [];
  // bool                     _isLoadingImagens  = false;
  // bool                     _isDragging        = false;
  // final ImagePicker        _picker            = ImagePicker();
  // ─────────────────────────────────────────────────────────────────────────

  // ═══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _initControllers();

    // Recalcula o resumo do IVA enquanto o utilizador digita.
    _precoController.addListener(_aoMudarPreco);
    _precoPromoController.addListener(_aoMudarPreco);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MarcaProvider>().carregarMarcas();
      context.read<CategoriaProvider>().carregarCategorias();

      // [IMAGENS] Carregamento de imagens existentes desactivado
      // if (_isEditMode) _carregarImagensExistentes();
    });
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    _precoController.dispose();
    _precoPromoController.dispose();
    _estoqueController.dispose();
    super.dispose();
  }

  void _aoMudarPreco() {
    if (mounted) setState(() {});
  }

  void _initControllers() {
    _nomeController =
        TextEditingController(text: widget.produto?.nomeProduto ?? '');
    _descricaoController =
        TextEditingController(text: widget.produto?.descricao ?? '');
    // O formulário edita o preço BASE (sem IVA); o preço final é calculado.
    _precoController = TextEditingController(
        text: widget.produto?.precoSemIva.toStringAsFixed(2) ?? '');
    _precoPromoController = TextEditingController(
        text: widget.produto?.precoPromocional?.toStringAsFixed(2) ?? '');
    _estoqueController = TextEditingController(
        text: widget.produto?.quantidadeEstoque.toString() ?? '0');

    if (_isEditMode) {
      _marcasSelecionadas = List.from(widget.produto?.marcas ?? []);
      _categoriasSelecionadas = List.from(widget.produto?.categorias ?? []);
    }
  }

  double? _lerValor(TextEditingController c) {
    final t = c.text.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  String _fmtPct(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  // ═══════════════════════════════════════════════════════════════════════════
  // SELECÇÃO DE MARCA / CATEGORIA
  // ═══════════════════════════════════════════════════════════════════════════

  void _onMarcaSelecionada(
    int idMarca,
    bool selecionado,
    List<MarcaModel> marcas,
    List<CategoriaModel> categorias,
  ) {
    setState(() {
      if (selecionado) {
        _marcasSelecionadas = [idMarca];

        // Se já havia categoria escolhida, valida se ela pertence à marca.
        if (_categoriasSelecionadas.isNotEmpty) {
          final idCategoriaAtual = _categoriasSelecionadas.first;

          final marca = marcas.firstWhere(
            (m) => m.id == idMarca,
            orElse: () => marcas.first,
          );

          final categoriaValida = marca.categorias.any(
            (c) => c.id == idCategoriaAtual,
          );

          if (!categoriaValida) {
            _categoriasSelecionadas.clear();
          }
        }
      } else {
        _marcasSelecionadas.clear();
      }
    });
  }

  void _onCategoriaSelecionada(
    int idCategoria,
    bool selecionado,
    List<MarcaModel> marcas,
    List<CategoriaModel> categorias,
  ) {
    setState(() {
      if (selecionado) {
        _categoriasSelecionadas = [idCategoria];

        // Se já havia marca escolhida, valida se ela pertence à categoria.
        if (_marcasSelecionadas.isNotEmpty) {
          final idMarcaAtual = _marcasSelecionadas.first;

          final categoria = categorias.firstWhere(
            (c) => c.id == idCategoria,
            orElse: () => categorias.first,
          );

          final marcaValida = categoria.marcas.contains(idMarcaAtual);

          if (!marcaValida) {
            _marcasSelecionadas.clear();
          }
        }
      } else {
        _categoriasSelecionadas.clear();
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // [IMAGENS] Métodos de imagem — desactivados temporariamente
  // ═══════════════════════════════════════════════════════════════════════════

  // Future<void> _carregarImagensExistentes() async {
  //   if (widget.produto?.idProduto == null) return;
  //   setState(() => _isLoadingImagens = true);
  //   try {
  //     await context.read<ProdutoProvider>().carregarImagens(
  //           widget.produto!.idProduto,
  //         );
  //     setState(() {
  //       _imagensExistentes =
  //           List.from(context.read<ProdutoProvider>().imagens);
  //       _isLoadingImagens = false;
  //     });
  //   } catch (e) {
  //     setState(() => _isLoadingImagens = false);
  //     debugPrint('Erro ao carregar imagens: $e');
  //   }
  // }

  // Future<void> _selecionarImagem() async {
  //   try {
  //     final XFile? img = await _picker.pickImage(
  //         source: ImageSource.gallery,
  //         maxWidth: 1920,
  //         maxHeight: 1920,
  //         imageQuality: 85);
  //     if (img != null) setState(() => _novasImagens.add(File(img.path)));
  //   } catch (e) {
  //     _mostrarErro('Erro ao selecionar imagem: $e');
  //   }
  // }

  // Future<void> _tirarFoto() async {
  //   try {
  //     final XFile? foto = await _picker.pickImage(
  //         source: ImageSource.camera,
  //         maxWidth: 1920,
  //         maxHeight: 1920,
  //         imageQuality: 85);
  //     if (foto != null) setState(() => _novasImagens.add(File(foto.path)));
  //   } catch (e) {
  //     _mostrarErro('Erro ao tirar foto: $e');
  //   }
  // }

  // Future<void> _processarArquivosArrastados(List<XFile> files) async {
  //   final validas = <File>[];
  //   for (final f in files) {
  //     final ext = f.path.toLowerCase();
  //     if (ext.endsWith('.jpg') ||
  //         ext.endsWith('.jpeg') ||
  //         ext.endsWith('.png') ||
  //         ext.endsWith('.gif') ||
  //         ext.endsWith('.webp') ||
  //         ext.endsWith('.jfif')) {
  //       validas.add(File(f.path));
  //     }
  //   }
  //   if (validas.isEmpty) {
  //     _mostrarErro('Nenhuma imagem válida. Use JPG, PNG, GIF, JFIF ou WEBP.');
  //     return;
  //   }
  //   setState(() => _novasImagens.addAll(validas));
  //   _mostrarSucesso('${validas.length} imagem(ns) adicionada(s)');
  // }

  // void _removerNovaImagem(int index) =>
  //     setState(() => _novasImagens.removeAt(index));

  // Future<void> _removerImagemExistente(ProdutoImagemModel imagem) async {
  //   final confirmar = await showDialog<bool>(
  //     context: context,
  //     builder: (_) => AlertDialog(
  //       title: const Text('Confirmar'),
  //       content: const Text('Deseja realmente remover esta imagem?'),
  //       actions: [
  //         TextButton(
  //             onPressed: () => Navigator.pop(context, false),
  //             child: const Text('Cancelar')),
  //         TextButton(
  //             onPressed: () => Navigator.pop(context, true),
  //             child: Text('Remover',
  //                 style: TextStyle(color: context.cores.perigo))),
  //       ],
  //     ),
  //   );
  //   if (confirmar == true && imagem.idImagem != null) {
  //     final sucesso = await context
  //         .read<ProdutoProvider>()
  //         .removerImagem(imagem.idImagem!);
  //     if (sucesso && mounted) {
  //       setState(() => _imagensExistentes
  //           .removeWhere((img) => img.idImagem == imagem.idImagem));
  //       _mostrarSucesso('Imagem removida');
  //     } else if (mounted) {
  //       _mostrarErro('Erro ao remover imagem');
  //     }
  //   }
  // }

  // Future<void> _definirImagemPrincipal(ProdutoImagemModel imagem) async {
  //   if (widget.produto?.idProduto == null || imagem.idImagem == null) return;
  //   final sucesso = await context
  //       .read<ProdutoProvider>()
  //       .definirImagemPrincipal(
  //           widget.produto!.idProduto, imagem.idImagem!);
  //   if (sucesso && mounted) {
  //     await _carregarImagensExistentes();
  //     _mostrarSucesso('Imagem principal definida');
  //   } else if (mounted) {
  //     _mostrarErro('Erro ao definir imagem principal');
  //   }
  // }

  // ═══════════════════════════════════════════════════════════════════════════
  // SALVAR
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_marcasSelecionadas.isEmpty) {
      _mostrarErro('Selecione pelo menos uma marca');
      return;
    }
    if (_categoriasSelecionadas.isEmpty) {
      _mostrarErro('Selecione pelo menos uma categoria');
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Preço BASE (sem IVA). O preço final é calculado pelo backend / repositório.
      final precoSemIva =
          double.parse(_precoController.text.trim().replaceAll(',', '.'));
      double? precoPromo;
      if (_precoPromoController.text.trim().isNotEmpty) {
        precoPromo = double.parse(
            _precoPromoController.text.trim().replaceAll(',', '.'));
      }

      final dto = ProdutoRequestModel(
        nomeProduto: _nomeController.text.trim(),
        descricao: _descricaoController.text.trim().isEmpty
            ? null
            : _descricaoController.text.trim(),
        precoSemIva: precoSemIva,
        quantidadeEstoque: int.parse(_estoqueController.text.trim()),
        precoPromocional: precoPromo,
        categorias: _categoriasSelecionadas,
        marcas: _marcasSelecionadas,
      );

      final provider = context.read<ProdutoProvider>();
      ProdutoModel? salvo;

      if (_isEditMode) {
        salvo = await provider.atualizar(widget.produto!.idProduto, dto);
      } else {
        salvo = await provider.criar(dto);
      }

      if (!mounted) return;

      if (salvo == null) {
        _mostrarErro(provider.errorMessage ?? 'Erro ao salvar produto');
        return;
      }

      // [IMAGENS] Upload de novas imagens desactivado temporariamente
      // if (_novasImagens.isNotEmpty) {
      //   for (int i = 0; i < _novasImagens.length; i++) {
      //     await provider.adicionarImagem(
      //       idProduto:        salvo.idProduto,
      //       imagemFile:       _novasImagens[i],
      //       nomeArquivo:      _novasImagens[i].path.split('/').last,
      //       imagemPrincipal:
      //           (i == 0 && _imagensExistentes.isEmpty) ? 1 : 0,
      //     );
      //   }
      // }

      _mostrarSucesso(_isEditMode
          ? 'Produto actualizado com sucesso.'
          : 'Produto criado com sucesso.');

      _houveAlteracoes = true;
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _mostrarErro('Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    final marcaProvider = context.watch<MarcaProvider>();
    final categoriaProvider = context.watch<CategoriaProvider>();
    final dadosCarregando =
        marcaProvider.carregando || categoriaProvider.carregando;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) Navigator.pop(context, _houveAlteracoes);
      },
      child: Scaffold(
        backgroundColor: cores.fundo,
        appBar: AppBar(
          title: Text(_isEditMode ? 'Editar Produto' : 'Novo Produto'),
          backgroundColor:
              context.escuro ? AppColors.azulMarcaEscuro : AppColors.azulMarca,
          foregroundColor: AppColors.branco,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context, _houveAlteracoes),
          ),
        ),
        body: dadosCarregando
            ? Center(child: CircularProgressIndicator(color: cores.marca))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildCardDadosBasicos(),
                      const SizedBox(height: 16),
                      _buildCardIva(),
                      const SizedBox(height: 16),
                      _buildSecaoMarcas(
                        marcaProvider.marcas,
                        categoriaProvider.categorias,
                      ),
                      const SizedBox(height: 16),
                      _buildSecaoCategorias(
                        categoriaProvider.categorias,
                        marcaProvider.marcas,
                      ),
                      const SizedBox(height: 16),
                      _buildSecaoImagensDesativada(), // [IMAGENS] placeholder
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _salvar,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.branco))
                            : const Icon(Icons.save_rounded),
                        label: Text(
                          _isEditMode ? 'SALVAR ALTERAÇÕES' : 'CRIAR PRODUTO',
                          style: const TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.vermelhoMarca,
                          foregroundColor: AppColors.branco,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // ─── Helpers de UI ────────────────────────────────────────────────────────

  Widget _card({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    final c = context.cores;
    return Card(
      elevation: 0,
      color: c.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.borda),
      ),
      child: Padding(padding: padding, child: child),
    );
  }

  Widget _cabecalho(IconData icone, String titulo, {Widget? trailing}) {
    final c = context.cores;
    return Row(children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: c.marca.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icone, color: c.marca, size: 16),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(titulo,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: c.marca)),
      ),
      if (trailing != null) trailing,
    ]);
  }

  Widget _caixaInfo({
    required IconData icone,
    required String texto,
    required Color cor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cor.withValues(alpha: 0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icone, size: 15, color: cor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(texto, style: TextStyle(fontSize: 12, color: cor)),
        ),
      ]),
    );
  }

  Widget _linhaValor(
    String label,
    String valor, {
    bool destaque = false,
    Color? cor,
  }) {
    final c = context.cores;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: destaque ? 14 : 13,
                  fontWeight: destaque ? FontWeight.bold : FontWeight.normal,
                  color: destaque ? c.textoPrincipal : c.textoSecundario)),
          Text(valor,
              style: TextStyle(
                  fontSize: destaque ? 17 : 13,
                  fontWeight: destaque ? FontWeight.bold : FontWeight.w600,
                  color: cor ?? (destaque ? c.marca : c.textoPrincipal))),
        ],
      ),
    );
  }

  // ─── Card dados básicos ───────────────────────────────────────────────────

  Widget _buildCardDadosBasicos() {
    final c = context.cores;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cabecalho(Icons.inventory_2_outlined, 'Dados do Produto'),
          const Divider(height: 24),

          // Nome
          TextFormField(
            controller: _nomeController,
            enabled: !_isSaving,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nome do Produto *',
              prefixIcon: Icon(Icons.inventory_2_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Obrigatório' : null,
          ),
          const SizedBox(height: 16),

          // Preço base (sem IVA) + Estoque
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _precoController,
                  enabled: !_isSaving,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Preço sem IVA *',
                    prefixText: 'MZN ',
                    border: OutlineInputBorder(),
                  ),
                  validator: _validarPreco,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _estoqueController,
                  enabled: !_isSaving,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Estoque *',
                    prefixIcon: Icon(Icons.layers_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: _validarEstoque,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Preço promocional (valor final, com IVA — como o PDV vende)
          TextFormField(
            controller: _precoPromoController,
            enabled: !_isSaving,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Preço Promocional c/ IVA (Opcional)',
              prefixText: 'MZN ',
              prefixIcon: Icon(Icons.local_offer_outlined, color: c.aviso),
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: c.avisoFundo,
            ),
            validator: (v) {
              if (v != null && v.trim().isNotEmpty) return _validarPreco(v);
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Descrição
          TextFormField(
            controller: _descricaoController,
            enabled: !_isSaving,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Descrição',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.description_outlined),
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── IVA e preço final ────────────────────────────────────────────────────

  Widget _buildCardIva() {
    final c = context.cores;
    final iva = _ivaPct;

    final double? base = _lerValor(_precoController);
    final double? promo = _lerValor(_precoPromoController);

    final double? precoFinal =
        (base != null && base >= 0) ? IvaUtil.comIva(base, iva) : null;
    final double? valorIva = precoFinal != null ? precoFinal - base! : null;

    final bool temPromo = promo != null && promo > 0;
    final bool promoAcima =
        temPromo && precoFinal != null && promo >= precoFinal;
    final double? descontoPct = (temPromo && precoFinal != null && precoFinal > 0 && !promoAcima)
        ? (1 - promo / precoFinal) * 100
        : null;

    // Em edição: o produto foi gravado com outro IVA que não o vigente.
    final bool ivaDifere = _isEditMode &&
        (widget.produto!.ivaAplicado - iva).abs() > 0.001;

    String fmt(double? v) => v == null ? '—' : _currencyFmt.format(v);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cabecalho(
            Icons.receipt_long_outlined,
            'IVA e Preço Final',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: c.marca.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: c.marca.withValues(alpha: 0.18)),
              ),
              child: Text('IVA ${_fmtPct(iva)}%',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: c.marca)),
            ),
          ),
          const Divider(height: 24),
          _caixaInfo(
            icone: Icons.info_outline,
            texto:
                'O preço introduzido é o valor BASE (sem IVA). O preço de venda '
                'ao cliente é calculado automaticamente com o IVA em vigor '
                '(${_fmtPct(iva)}%).',
            cor: c.info,
          ),
          const SizedBox(height: 12),
          _linhaValor('Preço base (sem IVA)', fmt(base != null && base >= 0 ? base : null)),
          _linhaValor('IVA (${_fmtPct(iva)}%)', fmt(valorIva)),
          Divider(height: 16, color: c.borda),
          _linhaValor('Preço final (com IVA)', fmt(precoFinal), destaque: true),
          if (temPromo) ...[
            const SizedBox(height: 4),
            _linhaValor(
              'Preço promocional (com IVA)',
              fmt(promo),
              cor: c.acentoTexto,
            ),
            if (descontoPct != null)
              _linhaValor(
                'Desconto face ao preço final',
                '-${descontoPct.toStringAsFixed(1)}%',
                cor: c.sucesso,
              ),
          ],
          if (promoAcima) ...[
            const SizedBox(height: 10),
            _caixaInfo(
              icone: Icons.warning_amber_rounded,
              texto:
                  'O preço promocional é igual ou superior ao preço final '
                  '(${fmt(precoFinal)}). Verifique se é intencional.',
              cor: c.aviso,
            ),
          ],
          if (ivaDifere) ...[
            const SizedBox(height: 10),
            _caixaInfo(
              icone: Icons.update_rounded,
              texto:
                  'Este produto foi gravado com IVA de '
                  '${_fmtPct(widget.produto!.ivaAplicado)}%. Ao guardar, será '
                  'recalculado com o IVA actual (${_fmtPct(iva)}%).',
              cor: c.aviso,
            ),
          ],
        ],
      ),
    );
  }

  // ─── Regras marca ↔ categoria ─────────────────────────────────────────────

  bool _marcaPermitida(MarcaModel marca, List<CategoriaModel> categorias) {
    // Se nenhuma categoria foi escolhida, todas as marcas ficam disponíveis.
    if (_categoriasSelecionadas.isEmpty) return true;

    final idCategoriaSelecionada = _categoriasSelecionadas.first;

    // Regra principal: a marca precisa estar associada à categoria seleccionada.
    return marca.categorias.any((c) => c.id == idCategoriaSelecionada);
  }

  bool _categoriaPermitida(CategoriaModel categoria, List<MarcaModel> marcas) {
    // Se nenhuma marca foi escolhida, todas as categorias ficam disponíveis.
    if (_marcasSelecionadas.isEmpty) return true;

    final idMarcaSelecionada = _marcasSelecionadas.first;

    // Regra principal: a categoria precisa estar associada à marca seleccionada.
    return categoria.marcas.contains(idMarcaSelecionada);
  }

  // ─── Marcas ───────────────────────────────────────────────────────────────

  Widget _buildSecaoMarcas(
    List<MarcaModel> marcas,
    List<CategoriaModel> categorias,
  ) {
    final c = context.cores;
    return _card(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Marca *',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: c.marca),
          ),
          const SizedBox(height: 4),
          Text(
            _categoriasSelecionadas.isEmpty
                ? 'Selecione uma marca.'
                : 'Apenas marcas associadas à categoria selecionada estão activas.',
            style: TextStyle(fontSize: 12, color: c.textoSecundario),
          ),
          const SizedBox(height: 8),
          if (marcas.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Nenhuma marca disponível.',
                style: TextStyle(color: c.aviso),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: marcas.map((marca) {
                final sel = _marcasSelecionadas.contains(marca.id);
                final permitida = _marcaPermitida(marca, categorias);

                return FilterChip(
                  label: Text(marca.nomeMarca),
                  selected: sel,
                  onSelected: permitida
                      ? (v) => _onMarcaSelecionada(
                            marca.id,
                            v,
                            marcas,
                            categorias,
                          )
                      : null,
                  selectedColor: c.marca.withValues(alpha: 0.15),
                  checkmarkColor: c.marca,
                  disabledColor: c.superficieAlt,
                  labelStyle: TextStyle(
                    color: permitida || sel ? c.marca : c.desactivado,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
          if (_categoriasSelecionadas.isNotEmpty) ...[
            const SizedBox(height: 10),
            const _AvisoFiltroProduto(
              icon: Icons.filter_alt_outlined,
              texto:
                  'Filtro activo: marcas limitadas pela categoria seleccionada.',
            ),
          ],
        ],
      ),
    );
  }

  // ─── Categorias ───────────────────────────────────────────────────────────

  Widget _buildSecaoCategorias(
    List<CategoriaModel> categorias,
    List<MarcaModel> marcas,
  ) {
    final c = context.cores;
    return _card(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Categoria *',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: c.marca),
          ),
          const SizedBox(height: 4),
          Text(
            _marcasSelecionadas.isEmpty
                ? 'Selecione uma categoria.'
                : 'Apenas categorias associadas à marca selecionada estão activas.',
            style: TextStyle(fontSize: 12, color: c.textoSecundario),
          ),
          const SizedBox(height: 8),
          if (categorias.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Nenhuma categoria disponível.',
                style: TextStyle(color: c.aviso),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: categorias.map((cat) {
                final sel = _categoriasSelecionadas.contains(cat.id);
                final permitida = _categoriaPermitida(cat, marcas);

                return FilterChip(
                  label: Text(cat.nomeCategoria),
                  selected: sel,
                  onSelected: permitida
                      ? (v) => _onCategoriaSelecionada(
                            cat.id,
                            v,
                            marcas,
                            categorias,
                          )
                      : null,
                  selectedColor: c.marca.withValues(alpha: 0.15),
                  checkmarkColor: c.marca,
                  disabledColor: c.superficieAlt,
                  labelStyle: TextStyle(
                    color: permitida || sel ? c.marca : c.desactivado,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
          if (_marcasSelecionadas.isNotEmpty) ...[
            const SizedBox(height: 10),
            const _AvisoFiltroProduto(
              icon: Icons.filter_alt_outlined,
              texto:
                  'Filtro activo: categorias limitadas pela marca seleccionada.',
            ),
          ],
        ],
      ),
    );
  }

  // ─── [IMAGENS] Placeholder — secção desactivada ───────────────────────────
  //
  // A secção de imagens está temporariamente desactivada.
  // Para reativar, substituir este método por _buildSecaoImagens()
  // e descomentar todos os blocos marcados com [IMAGENS].
  //
  Widget _buildSecaoImagensDesativada() {
    final c = context.cores;
    return _card(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.superficieAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.photo_library_outlined,
              color: c.desactivado,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Imagens do Produto',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.textoSecundario,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Funcionalidade disponível em breve.',
                  style: TextStyle(fontSize: 12, color: c.desactivado),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: c.superficieAlt,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Em breve',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: c.textoSecundario,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // [IMAGENS] _buildSecaoImagens — desactivado temporariamente
  // (ao reactivar, trocar Colors.blue[...] por context.cores.info/infoFundo
  //  e _kAzul/_kBranco por context.cores.marca / AppColors.branco)
  // ═══════════════════════════════════════════════════════════════════════════

  // Widget _buildSecaoImagens() {
  //   return DropTarget(
  //     onDragDone: (details) async {
  //       setState(() => _isDragging = false);
  //       await _processarArquivosArrastados(details.files);
  //     },
  //     onDragEntered: (_) => setState(() => _isDragging = true),
  //     onDragExited:  (_) => setState(() => _isDragging = false),
  //     child: Card(
  //       elevation: _isDragging ? 8 : 0,
  //       color: _isDragging ? context.cores.infoFundo : context.cores.superficie,
  //       shape: RoundedRectangleBorder(
  //         borderRadius: BorderRadius.circular(12),
  //         side: _isDragging
  //             ? BorderSide(color: context.cores.info, width: 3)
  //             : BorderSide(color: context.cores.borda),
  //       ),
  //       child: Padding(
  //         padding: const EdgeInsets.all(12),
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             Row(
  //               mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //               children: [
  //                 const Text('Imagens (Opcional)',
  //                     style: TextStyle(
  //                         fontSize: 16, fontWeight: FontWeight.bold)),
  //                 Row(
  //                   children: [
  //                     IconButton(
  //                         icon: const Icon(Icons.camera_alt_outlined),
  //                         onPressed: _tirarFoto,
  //                         tooltip: 'Tirar foto'),
  //                     IconButton(
  //                         icon: const Icon(Icons.photo_library_outlined),
  //                         onPressed: _selecionarImagem,
  //                         tooltip: 'Escolher da galeria'),
  //                   ],
  //                 ),
  //               ],
  //             ),
  //
  //             if (!_isDragging) ...[
  //               const SizedBox(height: 4),
  //               Container(
  //                 padding: const EdgeInsets.all(8),
  //                 decoration: BoxDecoration(
  //                   color: context.cores.infoFundo,
  //                   borderRadius: BorderRadius.circular(8),
  //                   border: Border.all(
  //                       color: context.cores.info.withValues(alpha: 0.4)),
  //                 ),
  //                 child: Row(
  //                   children: [
  //                     Icon(Icons.upload_file_outlined,
  //                         size: 16, color: context.cores.info),
  //                     const SizedBox(width: 8),
  //                     Expanded(
  //                       child: Text(
  //                         'Arraste imagens do explorador de ficheiros para cá.',
  //                         style: TextStyle(
  //                             fontSize: 12, color: context.cores.info),
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //             ],
  //
  //             if (_isDragging) ...[
  //               const SizedBox(height: 12),
  //               Container(
  //                 height: 120,
  //                 decoration: BoxDecoration(
  //                   color: context.cores.infoFundo,
  //                   borderRadius: BorderRadius.circular(12),
  //                   border: Border.all(color: context.cores.info, width: 2),
  //                 ),
  //                 child: Center(
  //                   child: Column(
  //                     mainAxisAlignment: MainAxisAlignment.center,
  //                     children: [
  //                       Icon(Icons.cloud_upload_outlined,
  //                           size: 48, color: context.cores.info),
  //                       const SizedBox(height: 8),
  //                       Text('Solte as imagens aqui',
  //                           style: TextStyle(
  //                               fontSize: 16,
  //                               fontWeight: FontWeight.bold,
  //                               color: context.cores.info)),
  //                     ],
  //                   ),
  //                 ),
  //               ),
  //             ],
  //
  //             const SizedBox(height: 12),
  //
  //             if (_isLoadingImagens)
  //               Center(child: CircularProgressIndicator(color: context.cores.marca))
  //             else if (_imagensExistentes.isNotEmpty) ...[
  //               const Text('Imagens guardadas:',
  //                   style: TextStyle(fontWeight: FontWeight.w500)),
  //               const SizedBox(height: 8),
  //               SizedBox(
  //                 height: 120,
  //                 child: ListView.builder(
  //                   scrollDirection: Axis.horizontal,
  //                   itemCount: _imagensExistentes.length,
  //                   itemBuilder: (_, i) =>
  //                       _buildImagemExistente(_imagensExistentes[i]),
  //                 ),
  //               ),
  //               const SizedBox(height: 12),
  //             ],
  //
  //             if (_novasImagens.isNotEmpty) ...[
  //               const Text('Novas imagens:',
  //                   style: TextStyle(fontWeight: FontWeight.w500)),
  //               const SizedBox(height: 8),
  //               SizedBox(
  //                 height: 120,
  //                 child: ListView.builder(
  //                   scrollDirection: Axis.horizontal,
  //                   itemCount: _novasImagens.length,
  //                   itemBuilder: (_, i) =>
  //                       _buildNovaImagem(_novasImagens[i], i),
  //                 ),
  //               ),
  //             ],
  //
  //             if (_imagensExistentes.isEmpty &&
  //                 _novasImagens.isEmpty &&
  //                 !_isDragging)
  //               Center(
  //                 child: Padding(
  //                   padding: const EdgeInsets.all(24),
  //                   child: Column(
  //                     children: [
  //                       Icon(Icons.add_photo_alternate_outlined,
  //                           size: 48, color: context.cores.desactivado),
  //                       const SizedBox(height: 8),
  //                       Text('Nenhuma imagem adicionada',
  //                           style: TextStyle(
  //                               color: context.cores.textoSecundario)),
  //                       const SizedBox(height: 4),
  //                       Text(
  //                         'Arraste imagens ou clique nos botões acima.',
  //                         style: TextStyle(
  //                             fontSize: 12,
  //                             color: context.cores.textoSecundario),
  //                       ),
  //                     ],
  //                   ),
  //                 ),
  //               ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }

  // Widget _buildImagemExistente(ProdutoImagemModel imagem) {
  //   final bool isPrincipal = imagem.imagemPrincipal == 1;
  //   return Container(
  //     margin: const EdgeInsets.only(right: 8),
  //     width: 120,
  //     decoration: BoxDecoration(
  //       border: Border.all(
  //         color: isPrincipal ? context.cores.info : context.cores.borda,
  //         width: isPrincipal ? 3 : 1,
  //       ),
  //       borderRadius: BorderRadius.circular(8),
  //     ),
  //     child: Stack(
  //       children: [
  //         ClipRRect(
  //           borderRadius: BorderRadius.circular(8),
  //           child: Image.network(
  //             '${ApiConfig.baseUrl}${imagem.caminhoImagem}',
  //             width: 120,
  //             height: 120,
  //             fit: BoxFit.cover,
  //             errorBuilder: (_, __, ___) => Container(
  //               color: context.cores.superficieAlt,
  //               child: const Icon(Icons.broken_image, size: 48),
  //             ),
  //           ),
  //         ),
  //         if (isPrincipal)
  //           Positioned(
  //             top: 4,
  //             left: 4,
  //             child: Container(
  //               padding: const EdgeInsets.all(4),
  //               decoration: BoxDecoration(
  //                   color: Colors.blue,
  //                   borderRadius: BorderRadius.circular(4)),
  //               child: const Text('PRINCIPAL',
  //                   style: TextStyle(
  //                       color: Colors.white,
  //                       fontSize: 10,
  //                       fontWeight: FontWeight.bold)),
  //             ),
  //           ),
  //         Positioned(
  //           top: 4,
  //           right: 4,
  //           child: PopupMenuButton(
  //             icon: const Icon(Icons.more_vert, color: Colors.white),
  //             itemBuilder: (_) => [
  //               if (!isPrincipal)
  //                 PopupMenuItem(
  //                   child: const Text('Definir como principal'),
  //                   onTap: () => Future.delayed(Duration.zero,
  //                       () => _definirImagemPrincipal(imagem)),
  //                 ),
  //               PopupMenuItem(
  //                 child: Text('Remover',
  //                     style: TextStyle(color: context.cores.perigo)),
  //                 onTap: () => Future.delayed(Duration.zero,
  //                     () => _removerImagemExistente(imagem)),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildNovaImagem(File imagem, int index) {
  //   final bool isNovaPrincipal = index == 0 && _imagensExistentes.isEmpty;
  //   return Container(
  //     margin: const EdgeInsets.only(right: 8),
  //     width: 120,
  //     child: Stack(
  //       children: [
  //         ClipRRect(
  //           borderRadius: BorderRadius.circular(8),
  //           child: Image.file(imagem,
  //               width: 120, height: 120, fit: BoxFit.cover),
  //         ),
  //         if (isNovaPrincipal)
  //           Positioned(
  //             top: 4,
  //             left: 4,
  //             child: Container(
  //               padding: const EdgeInsets.all(4),
  //               decoration: BoxDecoration(
  //                   color: Colors.green,
  //                   borderRadius: BorderRadius.circular(4)),
  //               child: const Text('NOVA PRINCIPAL',
  //                   style: TextStyle(
  //                       color: Colors.white,
  //                       fontSize: 10,
  //                       fontWeight: FontWeight.bold)),
  //             ),
  //           ),
  //         Positioned(
  //           top: 4,
  //           right: 4,
  //           child: GestureDetector(
  //             onTap: () => _removerNovaImagem(index),
  //             child: Container(
  //               decoration: const BoxDecoration(
  //                   color: Colors.black54, shape: BoxShape.circle),
  //               child: const Icon(Icons.close,
  //                   color: Colors.white, size: 20),
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // ─── Validadores ──────────────────────────────────────────────────────────

  String? _validarPreco(String? v) {
    if (v == null || v.trim().isEmpty) return 'Obrigatório';
    final p = double.tryParse(v.replaceAll(',', '.'));
    if (p == null || p < 0) return 'Valor inválido';
    return null;
  }

  String? _validarEstoque(String? v) {
    if (v == null || v.trim().isEmpty) return 'Obrigatório';
    final p = int.tryParse(v);
    if (p == null || p < 0) return 'Número inteiro inválido';
    return null;
  }

  // ─── Snackbars ────────────────────────────────────────────────────────────

  void _mostrarSucesso(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating));
  }

  void _mostrarErro(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.vermelhoMarca,
        behavior: SnackBarBehavior.floating));
  }
}

class _AvisoFiltroProduto extends StatelessWidget {
  final IconData icon;
  final String texto;

  const _AvisoFiltroProduto({
    required this.icon,
    required this.texto,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.marca.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.marca.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: c.marca),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 12,
                color: c.marca,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}