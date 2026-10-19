import 'package:flutter/material.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:provider/provider.dart';
import '/widgets/app_sidebar.dart';
import '/theme/app_theme.dart';

// ─── Cores ───────────────────────────────────────────────────────────────────
// As antigas constantes foram substituídas pelo tema:
//   _kAzul        → context.cores.marca (texto/ícone/borda)
//                   context.cores.marcaBotao (fundo de botão / snackbar de sucesso)
//                   AppColors.azulMarca / azulMarcaEscuro (AppBar, cabeçalho da tabela)
//   _kVermelho    → AppColors.vermelhoMarca (FUNDO: ícone da AppBar, botão do diálogo,
//                   snackbar de erro)
//                   context.cores.acentoTexto (vermelho como texto/ícone)
//                   context.cores.perigo (mensagem de erro de carregamento)
//   _kBranco      → context.cores.superficie (fundo) / AppColors.branco (sobre marca)
//   _kCinzaClaro  → context.cores.fundo
//   _kCinzaTexto  → context.cores.textoSecundario
//   0xFFF0F2FA    → context.cores.linhaAlternada
//   0xFFE8EAF0    → context.cores.borda
//
// NOTA: ajusta o import do tema ao caminho real (mesmo estilo do import do
// app_sidebar acima).

class FornecedorListScreen extends StatefulWidget {
  const FornecedorListScreen({super.key});

  @override
  State<FornecedorListScreen> createState() => _FornecedorListScreenState();
}

class _FornecedorListScreenState extends State<FornecedorListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FornecedorProvider>().carregarFornecedores();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Pesquisa ──────────────────────────────────────────────────────────────

  void _onPesquisar(String termo) {
    final provider = context.read<FornecedorProvider>();

    if (termo.trim().isEmpty) {
      provider.carregarFornecedores();
    } else {
      provider.pesquisarFornecedores(termo.trim());
    }
  }

  void _limparPesquisa() {
    _searchController.clear();
    context.read<FornecedorProvider>().carregarFornecedores();
  }

  // ── Navegação ─────────────────────────────────────────────────────────────

  Future<void> _abrirFormulario({FornecedorModel? fornecedor}) async {
    final resultado = await Navigator.of(context).pushNamed(
      '/cadastrar_fornecedores',
      arguments: fornecedor,
    );

    if (resultado == true && mounted) {
      context.read<FornecedorProvider>().carregarFornecedores();
    }
  }

  // ── Exclusão ──────────────────────────────────────────────────────────────

  Future<void> _confirmarExclusao(
    BuildContext ctx,
    FornecedorModel fornecedor,
  ) async {
    final nome = _nomeFornecedor(fornecedor);

    final confirma = await showDialog<bool>(
      context: ctx,
      builder: (_) => _DialogoConfirmacao(
        titulo: 'Remover fornecedor',
        mensagem:
            'Deseja remover o fornecedor "$nome"? Esta acção não pode ser desfeita.',
        corBotao: AppColors.vermelhoMarca,
        labelBotao: 'Remover',
      ),
    );

    if (confirma == true && ctx.mounted) {
      final provider = ctx.read<FornecedorProvider>();

      final id = fornecedor.id;
      if (id == null) {
        _mostrarSnack(ctx, 'Fornecedor sem ID válido.', erro: true);
        return;
      }

      final sucesso = await provider.excluirFornecedor(id);

      if (!ctx.mounted) return;

      if (sucesso) {
        _mostrarSnack(ctx, '$nome removido com sucesso.');
      } else {
        _mostrarSnack(
          ctx,
          provider.erro ?? 'Erro ao remover fornecedor.',
          erro: true,
        );
        provider.limparErro();
      }
    }
  }

  /// Fundo colorido FIXO + texto branco explícito: sem isso, no tema escuro
  /// o texto herdaria `textoPrincipal` (claro) e perderia contraste.
  void _mostrarSnack(BuildContext ctx, String mensagem, {bool erro = false}) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(mensagem, style: const TextStyle(color: Colors.white)),
        backgroundColor: erro ? AppColors.vermelhoMarca : ctx.cores.marcaBotao,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String _nomeFornecedor(FornecedorModel f) {
    final nome = f.nome?.trim();
    if (nome != null && nome.isNotEmpty) return nome;
    return f.contacto.trim().isNotEmpty ? f.contacto.trim() : 'Fornecedor';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.cores;

    return Scaffold(
      backgroundColor: c.fundo,
      appBar: _buildAppBar(),
      drawer: const AppSidebar(currentRoute: '/gerenciar_fornecedores'),
      body: Column(
        children: [
          _BarraPesquisa(
            controller: _searchController,
            onChanged: _onPesquisar,
            onLimpar: _limparPesquisa,
          ),
          const Divider(height: 1),
          Expanded(
            child: _Listagem(
              onEditar: (f) => _abrirFormulario(fornecedor: f),
              onExcluir: (f) => _confirmarExclusao(context, f),
            ),
          ),
        ],
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
            child: const Icon(
              Icons.local_shipping_rounded,
              color: AppColors.branco,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Fornecedores',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.add_business_rounded),
          tooltip: 'Novo Fornecedor',
          onPressed: () => _abrirFormulario(),
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Recarregar',
          onPressed: () =>
              context.read<FornecedorProvider>().carregarFornecedores(),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Barra de Pesquisa
// ─────────────────────────────────────────────────────────────────────────────

class _BarraPesquisa extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onLimpar;

  const _BarraPesquisa({
    required this.controller,
    required this.onChanged,
    required this.onLimpar,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cores;

    return Container(
      color: c.superficie,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: 'Pesquisar fornecedor por nome, NUIT ou contacto...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: c.textoSecundario,
                ),
                prefixIcon: Icon(Icons.search_rounded, color: c.marca),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: c.textoSecundario,
                          size: 18,
                        ),
                        onPressed: onLimpar,
                      )
                    : null,
                filled: true,
                fillColor: c.fundo,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Consumer<FornecedorProvider>(
            builder: (_, p, __) => Text(
              '${p.fornecedores.length} fornecedor(es)',
              style: TextStyle(fontSize: 13, color: c.textoSecundario),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Listagem
// ─────────────────────────────────────────────────────────────────────────────

class _Listagem extends StatelessWidget {
  final void Function(FornecedorModel) onEditar;
  final Future<void> Function(FornecedorModel) onExcluir;

  const _Listagem({
    required this.onEditar,
    required this.onExcluir,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final provider = context.watch<FornecedorProvider>();

    if (provider.carregando) {
      return Center(
        child: CircularProgressIndicator(color: c.marca),
      );
    }

    if (provider.temErro) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: c.perigo, size: 48),
            const SizedBox(height: 12),
            Text(
              provider.erro!,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.perigo),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: provider.carregarFornecedores,
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

    final lista = provider.fornecedores;

    if (lista.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_shipping_outlined,
                color: c.textoSecundario, size: 48),
            const SizedBox(height: 12),
            Text(
              'Nenhum fornecedor encontrado.',
              style: TextStyle(color: c.textoSecundario),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: context.escuro
                ? AppColors.azulMarcaEscuro
                : AppColors.azulMarca,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: const Row(
            children: [
              SizedBox(width: 44),
              SizedBox(width: 14),
              Expanded(
                flex: 3,
                child: Text(
                  'Fornecedor',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'NUIT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Contacto',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Email / Morada',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(width: 90),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
            itemCount: lista.length,
            itemBuilder: (_, i) => _LinhaFornecedor(
              fornecedor: lista[i],
              isAlternate: i.isOdd,
              onEditar: onEditar,
              onExcluir: onExcluir,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Linha de fornecedor
// ─────────────────────────────────────────────────────────────────────────────

class _LinhaFornecedor extends StatelessWidget {
  final FornecedorModel fornecedor;
  final bool isAlternate;
  final void Function(FornecedorModel) onEditar;
  final Future<void> Function(FornecedorModel) onExcluir;

  const _LinhaFornecedor({
    required this.fornecedor,
    required this.isAlternate,
    required this.onEditar,
    required this.onExcluir,
  });

  String get _nome {
    final nome = fornecedor.nome?.trim();
    if (nome != null && nome.isNotEmpty) return nome;
    return fornecedor.contacto.trim().isNotEmpty
        ? fornecedor.contacto.trim()
        : 'Fornecedor';
  }

  String get _iniciais {
    final partes = _nome
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();

    if (partes.isEmpty) return 'F';
    if (partes.length == 1) return partes.first[0].toUpperCase();

    return '${partes.first[0]}${partes.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final escuro = context.escuro;

    // Fundo translúcido dos botões de acção: mais forte no tema escuro.
    final alphaAccao = escuro ? 0.15 : 0.08;

    return Container(
      decoration: BoxDecoration(
        color: isAlternate ? c.linhaAlternada : c.superficie,
        border: Border(
          bottom: BorderSide(color: c.borda),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: c.marca.withValues(alpha: escuro ? 0.18 : 0.12),
              child: Text(
                _iniciais,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: c.marca,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 14),

            Expanded(
              flex: 3,
              child: Text(
                _nome,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.marca,
                ),
              ),
            ),

            Expanded(
              flex: 2,
              child: Text(
                fornecedor.nuit?.isNotEmpty == true ? fornecedor.nuit! : '—',
                style: TextStyle(fontSize: 12, color: c.textoSecundario),
              ),
            ),

            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Icon(
                    Icons.phone_outlined,
                    size: 13,
                    color: c.textoSecundario,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      fornecedor.contacto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: c.textoSecundario,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (fornecedor.email?.isNotEmpty == true)
                    Row(
                      children: [
                        Icon(
                          Icons.email_outlined,
                          size: 12,
                          color: c.textoSecundario,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            fornecedor.email!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: c.textoSecundario,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (fornecedor.morada?.isNotEmpty == true)
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: c.textoSecundario,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            fornecedor.morada!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: c.textoSecundario,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if ((fornecedor.email == null || fornecedor.email!.isEmpty) &&
                      (fornecedor.morada == null || fornecedor.morada!.isEmpty))
                    Text(
                      '—',
                      style: TextStyle(fontSize: 12, color: c.textoSecundario),
                    ),
                ],
              ),
            ),

            SizedBox(
              width: 90,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Tooltip(
                    message: 'Editar',
                    child: InkWell(
                      onTap: () => onEditar(fornecedor),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: c.marca.withValues(alpha: alphaAccao),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.edit_rounded,
                          size: 16,
                          color: c.marca,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Remover',
                    child: InkWell(
                      onTap: () => onExcluir(fornecedor),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: c.acentoTexto.withValues(alpha: alphaAccao),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                          color: c.acentoTexto,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Diálogo de Confirmação
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
      title: Text(
        titulo,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: c.marca,
          fontSize: 17,
        ),
      ),
      content: Text(
        mensagem,
        style: TextStyle(fontSize: 14, color: c.textoSecundario),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Cancelar',
            style: TextStyle(color: c.textoSecundario),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: corBotao,
            foregroundColor: AppColors.branco,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(labelBotao),
        ),
      ],
    );
  }
}