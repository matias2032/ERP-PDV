// lib/screens/produto_form_screen.dart

import 'dart:io';

// import 'package:cross_file/cross_file.dart';        // [IMAGENS] desactivado
// import 'package:desktop_drop/desktop_drop.dart';    // [IMAGENS] desactivado
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:image_picker/image_picker.dart';    // [IMAGENS] desactivado
import 'package:provider/provider.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
// import 'package:api_compartilhado/api_config.dart'; // [IMAGENS] desactivado
import 'package:api_compartilhado/providers/produto_provider.dart';
import 'package:api_compartilhado/providers/marca_provider.dart';
import 'package:api_compartilhado/providers/categoria_provider.dart';

// ── Paleta STech ─────────────────────────────────────────────────────────────
const _kVermelho   = Color(0xFFC8102E);
const _kAzul       = Color(0xFF1B2A6B);
const _kBranco     = Colors.white;
const _kCinzaClaro = Color(0xFFF4F5F7);

// ─────────────────────────────────────────────────────────────────────────────

class ProdutoFormScreen extends StatefulWidget {
  final ProdutoModel? produto;
  const ProdutoFormScreen({super.key, this.produto});

  @override
  State<ProdutoFormScreen> createState() => _ProdutoFormScreenState();
}

class _ProdutoFormScreenState extends State<ProdutoFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // ── Controllers ────────────────────────────────────────────────────────────
  late TextEditingController _nomeController;
  late TextEditingController _descricaoController;
  late TextEditingController _precoController;
  late TextEditingController _precoPromoController;
  late TextEditingController _estoqueController;

  // ── Estado geral ───────────────────────────────────────────────────────────
  bool _isSaving        = false;
  bool _houveAlteracoes = false;
  bool get _isEditMode  => widget.produto != null;

  // ── Selecções de marca / categoria ────────────────────────────────────────
  List<int> _marcasSelecionadas     = [];
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

  void _initControllers() {
    _nomeController = TextEditingController(
        text: widget.produto?.nomeProduto ?? '');
    _descricaoController = TextEditingController(
        text: widget.produto?.descricao ?? '');
    _precoController = TextEditingController(
        text: widget.produto?.preco.toStringAsFixed(2) ?? '');
    _precoPromoController = TextEditingController(
        text: widget.produto?.precoPromocional?.toStringAsFixed(2) ?? '');
    _estoqueController = TextEditingController(
        text: widget.produto?.quantidadeEstoque.toString() ?? '0');

    if (_isEditMode) {
      _marcasSelecionadas     = List.from(widget.produto?.marcas     ?? []);
      _categoriasSelecionadas = List.from(widget.produto?.categorias ?? []);
    }
  }

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
  //             child: const Text('Remover',
  //                 style: TextStyle(color: Colors.red))),
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
      final preco = double.parse(
          _precoController.text.trim().replaceAll(',', '.'));
      double? precoPromo;
      if (_precoPromoController.text.trim().isNotEmpty) {
        precoPromo = double.parse(
            _precoPromoController.text.trim().replaceAll(',', '.'));
      }

      final dto = ProdutoRequestModel(
        nomeProduto:       _nomeController.text.trim(),
        descricao:         _descricaoController.text.trim().isEmpty
            ? null
            : _descricaoController.text.trim(),
        preco:             preco,
        quantidadeEstoque: int.parse(_estoqueController.text.trim()),
        precoPromocional:  precoPromo,
        categorias:        _categoriasSelecionadas,
        marcas:            _marcasSelecionadas,
      );

      final provider    = context.read<ProdutoProvider>();
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

      _mostrarSucesso(
          _isEditMode ? 'Produto actualizado com sucesso.' : 'Produto criado com sucesso.');

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
    final marcaProvider     = context.watch<MarcaProvider>();
    final categoriaProvider = context.watch<CategoriaProvider>();
    final dadosCarregando   =
        marcaProvider.carregando || categoriaProvider.carregando;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) Navigator.pop(context, _houveAlteracoes);
      },
      child: Scaffold(
        backgroundColor: _kCinzaClaro,
        appBar: AppBar(
          title: Text(_isEditMode ? 'Editar Produto' : 'Novo Produto'),
          backgroundColor: _kAzul,
          foregroundColor: _kBranco,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context, _houveAlteracoes),
          ),
        ),
        body: dadosCarregando
            ? const Center(child: CircularProgressIndicator(color: _kAzul))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildCardDadosBasicos(),
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
                                    strokeWidth: 2, color: _kBranco))
                            : const Icon(Icons.save_rounded),
                        label: Text(
                          _isEditMode ? 'SALVAR ALTERAÇÕES' : 'CRIAR PRODUTO',
                          style: const TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kVermelho,
                          foregroundColor: _kBranco,
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

  // ─── Card dados básicos ───────────────────────────────────────────────────

  Widget _buildCardDadosBasicos() {
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
            const Text('Dados do Produto',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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

            // Preço + Estoque
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _precoController,
                    enabled: !_isSaving,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Preço *',
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
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly
                    ],
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

            // Preço promocional
            TextFormField(
              controller: _precoPromoController,
              enabled: !_isSaving,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Preço Promocional (Opcional)',
                prefixText: 'MZN ',
                prefixIcon:
                    const Icon(Icons.local_offer_outlined, color: Colors.orange),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.orange[50],
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
      ),
    );
  }
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
  return Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: Colors.grey.shade200),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Marca *',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            _categoriasSelecionadas.isEmpty
                ? 'Selecione uma marca.'
                : 'Apenas marcas associadas à categoria selecionada estão activas.',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),

          if (marcas.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'Nenhuma marca disponível.',
                style: TextStyle(color: Colors.orange),
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
                  selectedColor: _kAzul.withOpacity(0.15),
                  checkmarkColor: _kAzul,
                  disabledColor: Colors.grey.shade200,
                  labelStyle: TextStyle(
                    color: permitida || sel ? _kAzul : Colors.grey,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),

          if (_categoriasSelecionadas.isNotEmpty) ...[
            const SizedBox(height: 10),
            _AvisoFiltroProduto(
              icon: Icons.filter_alt_outlined,
              texto:
                  'Filtro activo: marcas limitadas pela categoria seleccionada.',
            ),
          ],
        ],
      ),
    ),
  );
}

  // ─── Categorias ───────────────────────────────────────────────────────────

Widget _buildSecaoCategorias(
  List<CategoriaModel> categorias,
  List<MarcaModel> marcas,
) {
  return Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: Colors.grey.shade200),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Categoria *',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            _marcasSelecionadas.isEmpty
                ? 'Selecione uma categoria.'
                : 'Apenas categorias associadas à marca selecionada estão activas.',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),

          if (categorias.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'Nenhuma categoria disponível.',
                style: TextStyle(color: Colors.orange),
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
                  selectedColor: _kAzul.withOpacity(0.15),
                  checkmarkColor: _kAzul,
                  disabledColor: Colors.grey.shade200,
                  labelStyle: TextStyle(
                    color: permitida || sel ? _kAzul : Colors.grey,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),

          if (_marcasSelecionadas.isNotEmpty) ...[
            const SizedBox(height: 10),
            _AvisoFiltroProduto(
              icon: Icons.filter_alt_outlined,
              texto:
                  'Filtro activo: categorias limitadas pela marca seleccionada.',
            ),
          ],
        ],
      ),
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
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.photo_library_outlined,
                color: Colors.grey.shade400,
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
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Funcionalidade disponível em breve.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Em breve',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // [IMAGENS] _buildSecaoImagens — desactivado temporariamente
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
  //       color: _isDragging ? Colors.blue[50] : null,
  //       shape: RoundedRectangleBorder(
  //         borderRadius: BorderRadius.circular(12),
  //         side: _isDragging
  //             ? const BorderSide(color: Colors.blue, width: 3)
  //             : BorderSide(color: Colors.grey.shade200),
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
  //                   color: Colors.blue[50],
  //                   borderRadius: BorderRadius.circular(8),
  //                   border: Border.all(color: Colors.blue[200]!),
  //                 ),
  //                 child: Row(
  //                   children: [
  //                     Icon(Icons.upload_file_outlined,
  //                         size: 16, color: Colors.blue[700]),
  //                     const SizedBox(width: 8),
  //                     Expanded(
  //                       child: Text(
  //                         'Arraste imagens do explorador de ficheiros para cá.',
  //                         style: TextStyle(
  //                             fontSize: 12, color: Colors.blue[900]),
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
  //                   color: Colors.blue[100],
  //                   borderRadius: BorderRadius.circular(12),
  //                   border: Border.all(color: Colors.blue, width: 2),
  //                 ),
  //                 child: Center(
  //                   child: Column(
  //                     mainAxisAlignment: MainAxisAlignment.center,
  //                     children: [
  //                       Icon(Icons.cloud_upload_outlined,
  //                           size: 48, color: Colors.blue[700]),
  //                       const SizedBox(height: 8),
  //                       Text('Solte as imagens aqui',
  //                           style: TextStyle(
  //                               fontSize: 16,
  //                               fontWeight: FontWeight.bold,
  //                               color: Colors.blue[900])),
  //                     ],
  //                   ),
  //                 ),
  //               ),
  //             ],
  //
  //             const SizedBox(height: 12),
  //
  //             if (_isLoadingImagens)
  //               const Center(child: CircularProgressIndicator(color: _kAzul))
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
  //                           size: 48, color: Colors.grey[400]),
  //                       const SizedBox(height: 8),
  //                       Text('Nenhuma imagem adicionada',
  //                           style: TextStyle(color: Colors.grey[600])),
  //                       const SizedBox(height: 4),
  //                       Text(
  //                         'Arraste imagens ou clique nos botões acima.',
  //                         style: TextStyle(
  //                             fontSize: 12, color: Colors.grey[500]),
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
  //         color: isPrincipal ? Colors.blue : Colors.grey[300]!,
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
  //               color: Colors.grey[300],
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
  //                       color: _kBranco,
  //                       fontSize: 10,
  //                       fontWeight: FontWeight.bold)),
  //             ),
  //           ),
  //         Positioned(
  //           top: 4,
  //           right: 4,
  //           child: PopupMenuButton(
  //             icon: const Icon(Icons.more_vert, color: _kBranco),
  //             itemBuilder: (_) => [
  //               if (!isPrincipal)
  //                 PopupMenuItem(
  //                   child: const Text('Definir como principal'),
  //                   onTap: () => Future.delayed(Duration.zero,
  //                       () => _definirImagemPrincipal(imagem)),
  //                 ),
  //               PopupMenuItem(
  //                 child: const Text('Remover',
  //                     style: TextStyle(color: Colors.red)),
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
  //                       color: _kBranco,
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
  //                   color: _kBranco, size: 20),
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
        backgroundColor: _kVermelho,
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
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _kAzul.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kAzul.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _kAzul),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: 12,
                color: _kAzul,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}