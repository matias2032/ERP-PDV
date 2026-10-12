// lib/screens/categoria_form_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:api_compartilhado/providers/categoria_provider.dart';
import 'package:api_compartilhado/providers/marca_provider.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────

class CategoriaFormScreen extends StatefulWidget {
  final CategoriaModel? categoria;
  const CategoriaFormScreen({super.key, this.categoria});

  @override
  State<CategoriaFormScreen> createState() => _CategoriaFormScreenState();
}

class _CategoriaFormScreenState extends State<CategoriaFormScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeController;
  late final TextEditingController _descricaoController;
  late final TabController _tabController;

  bool get _isEditMode => widget.categoria != null;

  // ID da categoria depois de salva — liberta a aba de marcas
  int? _categoriaIdSalva;

  // Marcas seleccionadas na aba 2
  Set<int> _marcasSelecionadas = {};

  // ── Ciclo de vida ─────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _nomeController =
        TextEditingController(text: widget.categoria?.nomeCategoria ?? '');
    _descricaoController =
        TextEditingController(text: widget.categoria?.descricao ?? '');

    if (_isEditMode) {
      _categoriaIdSalva = widget.categoria!.id;
      _marcasSelecionadas = Set<int>.from(
        widget.categoria!.marcas, // ← carrega estado real
      );
    }

    // Carrega marcas via Provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MarcaProvider>().carregarMarcas();
    });
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ── Salvar ────────────────────────────────────────────────────────────────

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    final dto = CategoriaRequestDTO(
      nomeCategoria: _nomeController.text.trim(),
      descricao: _descricaoController.text.trim().isEmpty
          ? null
          : _descricaoController.text.trim(),
    );

    final provider = context.read<CategoriaProvider>();

    try {
      final CategoriaModel salva;
      if (_isEditMode) {
        salva = await provider.editar(widget.categoria!.id, dto);
      } else {
        salva = await provider.criar(dto);
      }

      if (!mounted) return;

      setState(() => _categoriaIdSalva = salva.id);

      _snack(_isEditMode
          ? 'Categoria actualizada com sucesso.'
          : 'Categoria criada com sucesso.');

      // Se foi criação, vai directamente para a aba de marcas
      if (!_isEditMode) _tabController.animateTo(1);
    } catch (e) {
      if (mounted) _snack('Erro ao salvar: $e', erro: true);
    }
  }

  // ── Toggle de marca ───────────────────────────────────────────────────────

  Future<void> _toggleMarca(int idMarca, bool? valor) async {
    if (_categoriaIdSalva == null) {
      _snack('Salve a categoria antes de associar marcas.', erro: true);
      return;
    }

    final provider = context.read<CategoriaProvider>();

    try {
      if (valor == true) {
        await provider.associarMarca(_categoriaIdSalva!, idMarca);
        setState(() => _marcasSelecionadas.add(idMarca));
        if (mounted) _snack('Marca associada.', duracao: 1);
      } else {
        await provider.desassociarMarca(_categoriaIdSalva!, idMarca);
        setState(() => _marcasSelecionadas.remove(idMarca));
        if (mounted) _snack('Marca desassociada.', duracao: 1);
      }
    } catch (e) {
      if (mounted) _snack('Erro: $e', erro: true);
    }
  }

  void _snack(String msg, {bool erro = false, int duracao = 3}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: AppColors.branco)),
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
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, true);
      },
      child: Scaffold(
        backgroundColor: context.cores.fundo,
        appBar: _buildAppBar(),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildAbaInformacoes(),
            _buildAbaMarcas(),
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
            child: const Icon(Icons.category_rounded,
                color: AppColors.branco, size: 20),
          ),
          const SizedBox(width: 10),
          Text(
            _isEditMode ? 'Editar Categoria' : 'Nova Categoria',
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
          Tab(icon: Icon(Icons.label_outline_rounded), text: 'Marcas'),
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

    return Consumer<CategoriaProvider>(
      builder: (_, provider, __) {
        final salvando = provider.carregando;

        return Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Aviso offline se pendente ──────────────────────────
              if (_isEditMode && widget.categoria!.isPending)
                _caixaInfo(
                  icone: Icons.sync_problem_rounded,
                  texto:
                      'Esta categoria ainda não foi sincronizada com o servidor.',
                  cor: c.aviso,
                  margem: const EdgeInsets.only(bottom: 16),
                ),

              // ── Card dados ─────────────────────────────────────────
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _TituloSecao(
                        icon: Icons.category_rounded,
                        label: 'Dados da Categoria'),
                    const SizedBox(height: 16),

                    // Nome
                    TextFormField(
                      controller: _nomeController,
                      enabled: !salvando,
                      textCapitalization: TextCapitalization.words,
                      style: TextStyle(color: c.textoPrincipal),
                      decoration: _inputDecoration(
                        label: 'Nome da Categoria *',
                        hint: 'Ex: Smartphones, Electrónicos...',
                        icon: Icons.category_outlined,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Campo obrigatório';
                        }
                        if (v.trim().length < 3) {
                          return 'Mínimo 3 caracteres';
                        }
                        if (v.trim().length > 100) {
                          return 'Máximo 100 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Descrição
                    TextFormField(
                      controller: _descricaoController,
                      enabled: !salvando,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(color: c.textoPrincipal),
                      decoration: _inputDecoration(
                        label: 'Descrição (opcional)',
                        hint: 'Descreva esta categoria...',
                        icon: Icons.description_outlined,
                      ),
                      validator: (v) {
                        if (v != null && v.trim().length > 500) {
                          return 'Máximo 500 caracteres';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              // ── Aviso marcas ───────────────────────────────────────
              if (_categoriaIdSalva == null)
                _caixaInfo(
                  icone: Icons.lightbulb_outline_rounded,
                  texto: 'Salve a categoria para poder associar marcas.',
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

  // ── Aba 2: Marcas ─────────────────────────────────────────────────────────

  Widget _buildAbaMarcas() {
    final c = context.cores;

    if (_categoriaIdSalva == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.save_outlined, size: 64, color: c.desactivado),
            const SizedBox(height: 16),
            Text('Salve a categoria primeiro',
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

    return Consumer<MarcaProvider>(
      builder: (_, marcaProvider, __) {
        if (marcaProvider.carregando) {
          return Center(child: CircularProgressIndicator(color: c.marca));
        }

        if (marcaProvider.marcas.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.label_off_rounded, size: 64, color: c.desactivado),
                const SizedBox(height: 16),
                Text('Nenhuma marca cadastrada',
                    style: TextStyle(fontSize: 16, color: c.textoSecundario)),
                const SizedBox(height: 8),
                Text(
                  'Cadastre marcas primeiro para as associar.',
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
                      icon: Icons.label_rounded, label: 'Marcas Permitidas'),
                  const SizedBox(height: 4),
                  Text(
                    'Seleccione as marcas que podem operar nesta categoria.',
                    style: TextStyle(fontSize: 12, color: c.textoSecundario),
                  ),
                  const Divider(height: 24),
                  ...marcaProvider.marcas.map((marca) {
                    final isSelected = _marcasSelecionadas.contains(marca.id);
                    final inicial = marca.nomeMarca.isNotEmpty
                        ? marca.nomeMarca[0].toUpperCase()
                        : '?';
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (v) => _toggleMarca(marca.id, v),
                      title: Text(marca.nomeMarca,
                          style: TextStyle(fontSize: 14, color: c.marca)),
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
                    'Marcas seleccionadas: ${_marcasSelecionadas.length}',
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
      hintStyle: TextStyle(
          color: c.textoSecundario.withValues(alpha: 0.7), fontSize: 12),
      prefixIcon: Icon(icon, color: c.marca, size: 20),
      filled: true,
      fillColor: c.superficie,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
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