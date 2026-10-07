// lib/screens/marca_form_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:api_compartilhado/providers/marca_provider.dart';
import 'package:api_compartilhado/providers/categoria_provider.dart';

// ── Paleta STech ─────────────────────────────────────────────────────────────
const _kVermelho   = Color(0xFFC8102E);
const _kAzul       = Color(0xFF1B2A6B);
const _kBranco     = Colors.white;
const _kCinzaClaro = Color(0xFFF4F5F7);
const _kCinzaTexto = Color(0xFF6B7280);

// ─────────────────────────────────────────────────────────────────────────────

class MarcaFormScreen extends StatefulWidget {
  final MarcaModel? marca;
  const MarcaFormScreen({super.key, this.marca});

  @override
  State<MarcaFormScreen> createState() => _MarcaFormScreenState();
}

class _MarcaFormScreenState extends State<MarcaFormScreen>
    with SingleTickerProviderStateMixin {

  final _formKey                   = GlobalKey<FormState>();
  late final TextEditingController _nomeController;
  late final TabController          _tabController;

  bool get _isEditMode => widget.marca != null;

  // ID da marca depois de salva — liberta a aba de categorias
  int?     _marcaIdSalva;
  Set<int> _categoriasSelecionadas = {};

  // ── Ciclo de vida ─────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController  = TabController(length: 2, vsync: this);
    _nomeController = TextEditingController(
        text: widget.marca?.nomeMarca ?? '');

if (_isEditMode) {
  _marcaIdSalva           = widget.marca!.id;
  _categoriasSelecionadas = Set<int>.from(      // ← carrega estado real
      widget.marca!.categorias.map((c) => c.id)
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
        backgroundColor: erro ? _kVermelho : _kAzul,
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
        backgroundColor: _kCinzaClaro,
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
      backgroundColor: _kAzul,
      foregroundColor: _kBranco,
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
              color: _kVermelho,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.label_rounded, color: _kBranco, size: 20),
          ),
          const SizedBox(width: 10),
          Text(
            _isEditMode ? 'Editar Marca' : 'Nova Marca',
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3),
          ),
        ],
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: _kVermelho,
        labelColor: _kBranco,
        unselectedLabelColor: _kBranco.withOpacity(0.6),
        tabs: const [
          Tab(icon: Icon(Icons.info_outline_rounded),   text: 'Informações'),
          Tab(icon: Icon(Icons.category_outlined),      text: 'Categorias'),
        ],
      ),
    );
  }

  // ── Aba 1: Informações ────────────────────────────────────────────────────

  Widget _buildAbaInformacoes() {
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
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.sync_problem_rounded,
                          color: Colors.orange.shade700, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Esta marca ainda não foi sincronizada com o servidor.',
                          style: TextStyle(
                              fontSize: 13, color: Colors.orange.shade800),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Card dados ─────────────────────────────────────────
              Card(
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
                      _TituloSecao(
                          icon: Icons.label_rounded,
                          label: 'Dados da Marca'),
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
              ),

              // ── Aviso categorias ───────────────────────────────────
              if (_marcaIdSalva == null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline_rounded,
                          color: Colors.blue.shade700, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Salve a marca para poder associar categorias.',
                          style: TextStyle(
                              fontSize: 13, color: Colors.blue.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // ── Botões ─────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: salvando
                          ? null
                          : () => Navigator.pop(context, true),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kCinzaTexto,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
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
                                  color: _kBranco, strokeWidth: 2),
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
                        backgroundColor: _kVermelho,
                        foregroundColor: _kBranco,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
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
    if (_marcaIdSalva == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.save_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('Salve a marca primeiro',
                style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text(
              'Volte à aba "Informações" e clique em Salvar',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Consumer<CategoriaProvider>(
      builder: (_, categoriaProvider, __) {
        if (categoriaProvider.carregando) {
          return const Center(
              child: CircularProgressIndicator(color: _kAzul));
        }

        if (categoriaProvider.categorias.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.category_outlined,
                    size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('Nenhuma categoria cadastrada',
                    style:
                        TextStyle(fontSize: 16, color: Colors.grey[600])),
                const SizedBox(height: 8),
                Text(
                  'Cadastre categorias primeiro para as associar.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
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
                    _TituloSecao(
                        icon: Icons.category_rounded,
                        label: 'Categorias Disponíveis'),
                    const SizedBox(height: 4),
                    Text(
                      'Seleccione as categorias nas quais esta marca pode operar.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const Divider(height: 24),
                    ...categoriaProvider.categorias.map((categoria) {
                      final isSelected =
                          _categoriasSelecionadas.contains(categoria.id);
                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (v) =>
                            _toggleCategoria(categoria.id, v),
                        title: Text(categoria.nomeCategoria,
                            style: const TextStyle(
                                fontSize: 14, color: _kAzul)),
                        subtitle: categoria.descricao != null &&
                                categoria.descricao!.isNotEmpty
                            ? Text(
                                categoria.descricao!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              )
                            : null,
                        secondary: CircleAvatar(
                          backgroundColor: isSelected
                              ? _kAzul
                              : Colors.grey.shade300,
                          child: Text(
                            categoria.nomeCategoria[0].toUpperCase(),
                            style: const TextStyle(
                                color: _kBranco,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        activeColor: _kAzul,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Contador
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kAzul.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kAzul.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      color: _kAzul, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    'Categorias seleccionadas: ${_categoriasSelecionadas.length}',
                    style: const TextStyle(
                        fontSize: 13,
                        color: _kAzul,
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

  // ── Helpers de UI ─────────────────────────────────────────────────────────

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle:
          TextStyle(color: _kCinzaTexto.withOpacity(0.6), fontSize: 12),
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
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kVermelho, width: 1.5),
      ),
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
    return Row(
      children: [
        Icon(icon, color: _kAzul, size: 20),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _kAzul)),
      ],
    );
  }
}