// lib/screens/categorias_list_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'categoria_form_screen.dart';
import '../widgets/app_sidebar.dart';
import '../theme/app_theme.dart';
import 'package:api_compartilhado/providers/categoria_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────

class CategoriasListScreen extends StatefulWidget {
  const CategoriasListScreen({super.key});

  @override
  State<CategoriasListScreen> createState() => _CategoriasListScreenState();
}

class _CategoriasListScreenState extends State<CategoriasListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoriaProvider>().carregarCategorias();
    });
  }

  // ── Acções ────────────────────────────────────────────────────────────────

  Future<void> _deletarCategoria(CategoriaModel categoria) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoConfirmacao(
        titulo: 'Confirmar Exclusão',
        mensagem:
            'Deseja realmente excluir a categoria "${categoria.nomeCategoria}"?\n\n'
            'Os produtos associados NÃO serão excluídos.',
        corBotao: AppColors.vermelhoMarca,
        labelBotao: 'Excluir',
      ),
    );

    if (confirmar == true && mounted) {
      try {
        await context.read<CategoriaProvider>().excluir(categoria.id);
        if (mounted) {
          _snack('Categoria "${categoria.nomeCategoria}" excluída.');
        }
      } catch (e) {
        if (mounted) _snack('Erro ao excluir: $e', erro: true);
      }
    }
  }

  Future<void> _navegarParaFormulario({CategoriaModel? categoria}) async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CategoriaFormScreen(categoria: categoria),
      ),
    );
    if (resultado == true && mounted) {
      context.read<CategoriaProvider>().carregarCategorias();
    }
  }

  void _snack(String msg, {bool erro = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: erro ? AppColors.vermelhoMarca : context.cores.marcaBotao,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cores.fundo,
      appBar: _buildAppBar(),
      drawer: const AppSidebar(currentRoute: '/gerenciar_categorias'),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navegarParaFormulario(),
        backgroundColor: context.cores.marcaBotao,
        foregroundColor: AppColors.branco,
        icon: const Icon(Icons.add),
        label: const Text('Nova Categoria'),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
            child: const Icon(Icons.category_rounded,
                color: AppColors.branco, size: 20),
          ),
          const SizedBox(width: 10),
          const Text(
            'Categorias',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0.3),
          ),
        ],
      ),
      actions: [
        Consumer<CategoriaProvider>(
          builder: (_, p, __) => IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Recarregar',
            onPressed: p.carregando ? null : p.carregarCategorias,
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBody() {
    final c = context.cores;
    final provider = context.watch<CategoriaProvider>();

    if (provider.carregando) {
      return Center(
        child: CircularProgressIndicator(color: c.marca),
      );
    }

    if (provider.erro != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: c.acentoTexto, size: 48),
            const SizedBox(height: 12),
            Text(
              provider.erro!,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.acentoTexto),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: provider.carregarCategorias,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar Novamente'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: c.marcaBotao,
                  foregroundColor: AppColors.branco),
            ),
          ],
        ),
      );
    }

    if (provider.categorias.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.category_outlined, size: 64, color: c.desactivado),
            const SizedBox(height: 16),
            Text('Nenhuma categoria cadastrada',
                style: TextStyle(fontSize: 16, color: c.textoSecundario)),
            const SizedBox(height: 8),
            Text('Toque no botão + para adicionar',
                style: TextStyle(fontSize: 14, color: c.textoSecundario)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: c.marca,
      onRefresh: () async => provider.carregarCategorias(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
        itemCount: provider.categorias.length,
        itemBuilder: (_, i) => _buildCategoriaCard(provider.categorias[i]),
      ),
    );
  }

  Widget _buildCategoriaCard(CategoriaModel categoria) {
    final c = context.cores;
    final inicial = categoria.nomeCategoria.isNotEmpty
        ? categoria.nomeCategoria[0].toUpperCase()
        : '?';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      elevation: 0,
      color: c.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.borda),
      ),
      child: ExpansionTile(
        iconColor: c.marca,
        collapsedIconColor: c.textoSecundario,
        leading: CircleAvatar(
          backgroundColor: c.marca.withValues(alpha: 0.12),
          child: Text(
            inicial,
            style: TextStyle(color: c.marca, fontWeight: FontWeight.w700),
          ),
        ),
        title: Text(
          categoria.nomeCategoria,
          style: TextStyle(
              fontWeight: FontWeight.w600, color: c.marca, fontSize: 14),
        ),
        subtitle: categoria.descricao != null &&
                categoria.descricao!.isNotEmpty
            ? Text(
                categoria.descricao!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: c.textoSecundario),
              )
            : Text(
                'Sem descrição',
                style: TextStyle(
                    fontSize: 12,
                    color: c.textoSecundario,
                    fontStyle: FontStyle.italic),
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Badge sync pendente
            if (categoria.isPending)
              Container(
                margin: const EdgeInsets.only(right: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: c.avisoFundo,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: c.aviso.withValues(alpha: 0.6)),
                ),
                child: Text(
                  'Pendente',
                  style: TextStyle(
                      fontSize: 10,
                      color: c.aviso,
                      fontWeight: FontWeight.w600),
                ),
              ),
            IconButton(
              icon: Icon(Icons.edit_rounded, color: c.marca, size: 20),
              tooltip: 'Editar',
              onPressed: () => _navegarParaFormulario(categoria: categoria),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded,
                  color: c.acentoTexto, size: 20),
              tooltip: 'Excluir',
              onPressed: () => _deletarCategoria(categoria),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 14, color: c.textoSecundario),
                    const SizedBox(width: 6),
                    Text(
                      'ID: ${categoria.id}',
                      style:
                          TextStyle(fontSize: 12, color: c.textoSecundario),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.sync_rounded,
                        size: 14, color: c.textoSecundario),
                    const SizedBox(width: 6),
                    Text(
                      categoria.syncStatus,
                      style:
                          TextStyle(fontSize: 12, color: c.textoSecundario),
                    ),
                  ],
                ),
                if (categoria.descricao != null &&
                    categoria.descricao!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    categoria.descricao!,
                    style: TextStyle(fontSize: 13, color: c.textoSecundario),
                  ),
                ],
                const SizedBox(height: 12),

                _TituloAssociacoes(
                  icon: Icons.label_outline_rounded,
                  label: 'Marcas associadas',
                  total: categoria.marcas.length,
                ),

                const SizedBox(height: 8),

                if (categoria.marcas.isEmpty)
                  Text(
                    'Nenhuma marca associada.',
                    style: TextStyle(
                      fontSize: 12,
                      color: c.textoSecundario,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: categoria.marcas.map((idMarca) {
                      return Chip(
                        avatar: Icon(
                          Icons.label_rounded,
                          size: 14,
                          color: c.marca,
                        ),
                        label: Text(
                          'Marca #$idMarca',
                          style: TextStyle(
                              fontSize: 12, color: c.textoPrincipal),
                        ),
                        backgroundColor: c.marca.withValues(alpha: 0.06),
                        side: BorderSide(color: c.marca.withValues(alpha: 0.18)),
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () =>
                          _navegarParaFormulario(categoria: categoria),
                      icon: const Icon(Icons.label_outline_rounded, size: 16),
                      label: const Text('Gerir Marcas'),
                      style: TextButton.styleFrom(foregroundColor: c.marca),
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

// ─────────────────────────────────────────────────────────────────────────────
// Diálogo de Confirmação
// ─────────────────────────────────────────────────────────────────────────────

class _DialogoConfirmacao extends StatelessWidget {
  final String titulo;
  final String mensagem;
  final Color corBotao;
  final String labelBotao;

  const _DialogoConfirmacao({
    required this.titulo,
    required this.mensagem,
    required this.corBotao,
    required this.labelBotao,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(titulo,
          style: TextStyle(
              fontWeight: FontWeight.w700, color: c.marca, fontSize: 17)),
      content: Text(mensagem,
          style: TextStyle(fontSize: 14, color: c.textoSecundario)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Cancelar', style: TextStyle(color: c.textoSecundario)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: corBotao,
            foregroundColor: AppColors.branco,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(labelBotao),
        ),
      ],
    );
  }
}

class _TituloAssociacoes extends StatelessWidget {
  final IconData icon;
  final String label;
  final int total;

  const _TituloAssociacoes({
    required this.icon,
    required this.label,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Row(
      children: [
        Icon(icon, size: 15, color: c.marca),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: c.marca,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: c.marca.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$total',
            style: TextStyle(
              fontSize: 11,
              color: c.marca,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}