// lib/screens/marca_form_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:api_compartilhado/providers/marca_provider.dart';
import 'package:api_compartilhado/providers/categoria_provider.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────

class MarcaFormScreen extends StatefulWidget {
  final MarcaModel? marca;
  const MarcaFormScreen({super.key, this.marca});

  @override
  State<MarcaFormScreen> createState() => _MarcaFormScreenState();
}

class _MarcaFormScreenState extends State<MarcaFormScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeController;
  late final TabController _tabController;

  bool get _isEditMode => widget.marca != null;

  // ID da marca depois de salva — liberta a aba de categorias
  int? _marcaIdSalva;
  Set<int> _categoriasSelecionadas = {};

  // ── Ciclo de vida ─────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _nomeController =
        TextEditingController(text: widget.marca?.nomeMarca ?? '');

    if (_isEditMode) {
      _marcaIdSalva = widget.marca!.id;
      _categoriasSelecionadas = Set<int>.from(
        // ← carrega estado real
        widget.marca!.categorias.map((c) => c.id),
      );
    }

    // Carrega categorias via Provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoriaProvider>().carregarCategorias();
    });
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ── Salvar ────────────────────────────────────────────────────────────────

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    final dto = MarcaRequestDTO(nomeMarca: _nomeController.text.trim());
    final provider = context.read<MarcaProvider>();

    try {
      final MarcaModel salva;
      if (_isEditMode) {
        salva = await provider.editar(widget.marca!.id, dto);
      } else {
        salva = await provider.criar(dto);
      }

      if (!mounted) return;

      setState(() => _marcaIdSalva = salva.id);

      _snack(_isEditMode
          ? 'Marca actualizada com sucesso.'
          : 'Marca criada com sucesso.');

      // Se foi criação, vai directamente para a aba de categorias
      if (!_isEditMode) _tabController.animateTo(1);
    } catch (e) {
      if (mounted) _snack('Erro ao salvar: $e', erro: true);
    }
  }

  // ── Toggle de categoria ───────────────────────────────────────────────────

  Future<void> _toggleCategoria(int idCategoria, bool? valor) async {
    if (_marcaIdSalva == null) {
      _snack('Salve a marca antes de associar categorias.', erro: true);
      return;
    }

    final provider = context.read<MarcaProvider>();

    try {
      if (valor == true) {
        await provider.associarCategoria(_marcaIdSalva!, idCategoria);
        setState(() => _categoriasSelecionadas.add(idCategoria));
        if (mounted) _snack('Categoria associada.', duracao: 1);
      } else {
        await provider.desassociarCategoria(_marcaIdSalva!, idCategoria);
        setState(() => _categoriasSelecionadas.remove(idCategoria));
        if (mounted) _snack('Categoria desassociada.', duracao: 1);
      }
    } catch (e) {
      if (mounted) _snack('Erro: $e', erro: true);
    }
  }

  void _snack(String msg, {bool erro = false, int duracao = 3}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            erro ? AppColors.vermelhoMarca : context.cores.marcaBotao,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: duracao),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) Navigator.pop(context, true);
      },
      child: Scaffold(
        backgroundColor: context.cores.fundo,
        appBar: _buildAppBar(),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildAbaInformacoes(),
            _buildAbaCategorias(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor:
          context.escuro ? AppColors.azulMarcaEscuro : AppColors.azulMarca,
      foregroundColor: AppColors.branco,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.pop(context, true),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.vermelhoMarca,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.label_rounded,
                color: AppColors.branco, size: 20),
          ),
          const SizedBox(width: 10),
          Text(
            _isEditMode ? 'Editar Marca' : 'Nova Marca',
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0.3),
          ),
        ],
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: AppColors.vermelhoMarca,
        labelColor: AppColors.branco,
        unselectedLabelColor: AppColors.branco.withValues(alpha: 0.6),
        tabs: const [
          Tab(icon: Icon(Icons.info_outline_rounded), text: 'Informações'),
          Tab(icon: Icon(Icons.category_outlined), text: 'Categorias'),
        ],
      ),
    );
  }

  // ── Helpers de UI ─────────────────────────────────────────────────────────

  Widget _caixaInfo({
    required IconData icone,
    required String texto,
    required Color cor,
    EdgeInsets margem = EdgeInsets.zero,
  }) {
    return Container(
      margin: margem,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icone, color: cor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texto, style: TextStyle(fontSize: 13, color: cor)),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    final c = context.cores;
    return Card(
      elevation: 0,
      color: c.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.borda),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  // ── Aba 1: Informações ────────────────────────────────────────────────────

  Widget _buildAbaInformacoes() {
    final c = context.cores;

    return Consumer<MarcaProvider>(
      builder: (_, provider, __) {
        final salvando = provider.carregando;

        return Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Aviso offline se pendente ──────────────────────────
              if (_isEditMode && widget.marca!.isPending)
                _caixaInfo(
                  icone: Icons.sync_problem_rounded,
                  texto:
                      'Esta marca ainda não foi sincronizada com o servidor.',
                  cor: c.aviso,
                  margem: const EdgeInsets.only(bottom: 16),
                ),

              // ── Card dados ─────────────────────────────────────────
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _TituloSecao(
                        icon: Icons.label_rounded, label: 'Dados da Marca'),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nomeController,
                      enabled: !salvando,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDecoration(
                        label: 'Nome da Marca *',
                        hint: 'Ex: Samsung, Apple, Xiaomi...',
                        icon: Icons.business_outlined,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Campo obrigatório';
                        }
                        if (v.trim().length < 2) {
                          return 'Mínimo 2 caracteres';
                        }
                        if (v.trim().length > 100) {
                          return 'Máximo 100 caracteres';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              // ── Aviso categorias ───────────────────────────────────
              if (_marcaIdSalva == null)
                _caixaInfo(
                  icone: Icons.lightbulb_outline_rounded,
                  texto: 'Salve a marca para poder associar categorias.',
                  cor: c.info,
                  margem: const EdgeInsets.only(top: 12),
                ),

              const SizedBox(height: 24),

              // ── Botões ─────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          salvando ? null : () => Navigator.pop(context, true),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.textoSecundario,
                        side: BorderSide(color: c.borda),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: salvando ? null : _salvar,
                      icon: salvando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: AppColors.branco, strokeWidth: 2),
                            )
                          : const Icon(Icons.save_rounded, size: 20),
                      label: Text(
                        salvando
                            ? 'A guardar...'
                            : _isEditMode
                                ? 'Actualizar'
                                : 'Salvar',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.vermelhoMarca,
                        foregroundColor: AppColors.branco,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Aba 2: Categorias ─────────────────────────────────────────────────────

  Widget _buildAbaCategorias() {
    final c = context.cores;

    if (_marcaIdSalva == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.save_outlined, size: 64, color: c.desactivado),
            const SizedBox(height: 16),
            Text('Salve a marca primeiro',
                style: TextStyle(fontSize: 16, color: c.textoSecundario)),
            const SizedBox(height: 8),
            Text(
              'Volte à aba "Informações" e clique em Salvar',
              style: TextStyle(fontSize: 14, color: c.textoSecundario),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Consumer<CategoriaProvider>(
      builder: (_, categoriaProvider, __) {
        if (categoriaProvider.carregando) {
          return Center(child: CircularProgressIndicator(color: c.marca));
        }

        if (categoriaProvider.categorias.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.category_outlined, size: 64, color: c.desactivado),
                const SizedBox(height: 16),
                Text('Nenhuma categoria cadastrada',
                    style: TextStyle(fontSize: 16, color: c.textoSecundario)),
                const SizedBox(height: 8),
                Text(
                  'Cadastre categorias primeiro para as associar.',
                  style: TextStyle(fontSize: 14, color: c.textoSecundario),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _TituloSecao(
                      icon: Icons.category_rounded,
                      label: 'Categorias Disponíveis'),
                  const SizedBox(height: 4),
                  Text(
                    'Seleccione as categorias nas quais esta marca pode operar.',
                    style: TextStyle(fontSize: 12, color: c.textoSecundario),
                  ),
                  const Divider(height: 24),
                  ...categoriaProvider.categorias.map((categoria) {
                    final isSelected =
                        _categoriasSelecionadas.contains(categoria.id);
                    final inicial = categoria.nomeCategoria.isNotEmpty
                        ? categoria.nomeCategoria[0].toUpperCase()
                        : '?';
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (v) => _toggleCategoria(categoria.id, v),
                      title: Text(categoria.nomeCategoria,
                          style: TextStyle(fontSize: 14, color: c.marca)),
                      subtitle: categoria.descricao != null &&
                              categoria.descricao!.isNotEmpty
                          ? Text(
                              categoria.descricao!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12, color: c.textoSecundario),
                            )
                          : null,
                      secondary: CircleAvatar(
                        backgroundColor:
                            isSelected ? c.marcaBotao : c.superficieAlt,
                        child: Text(
                          inicial,
                          style: TextStyle(
                              color: isSelected
                                  ? AppColors.branco
                                  : c.textoSecundario,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      activeColor: c.marcaBotao,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Contador
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.marca.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.marca.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      color: c.marca, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    'Categorias seleccionadas: ${_categoriasSelecionadas.length}',
                    style: TextStyle(
                        fontSize: 13,
                        color: c.marca,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Input ─────────────────────────────────────────────────────────────────

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    final c = context.cores;
    OutlineInputBorder borda(Color cor, [double largura = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cor, width: largura),
        );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle:
          TextStyle(color: c.textoSecundario.withValues(alpha: 0.7), fontSize: 12),
      prefixIcon: Icon(icon, color: c.marca, size: 20),
      filled: true,
      fillColor: c.superficie,
      contentPadding:
          const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      border: borda(c.borda),
      enabledBorder: borda(c.borda),
      focusedBorder: borda(c.marca, 1.5),
      errorBorder: borda(c.acentoTexto),
      focusedErrorBorder: borda(c.acentoTexto, 1.5),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget auxiliar
// ─────────────────────────────────────────────────────────────────────────────

class _TituloSecao extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TituloSecao({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Row(
      children: [
        Icon(icon, color: c.marca, size: 20),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: c.marca)),
      ],
    );
  }
}