import 'package:flutter/material.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:provider/provider.dart';
import '/widgets/app_sidebar.dart';

// ── Cores STech Engenharia ────────────────────────────────────────────────────
const _kVermelho   = Color(0xFFC8102E);
const _kAzul       = Color(0xFF1B2A6B);
const _kBranco     = Colors.white;
const _kCinzaClaro = Color(0xFFF4F5F7);
const _kCinzaTexto = Color(0xFF6B7280);

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
        corBotao: _kVermelho,
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

  void _mostrarSnack(BuildContext ctx, String mensagem, {bool erro = false}) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: erro ? _kVermelho : _kAzul,
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
    return Scaffold(
      backgroundColor: _kCinzaClaro,
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
      backgroundColor: _kAzul,
      foregroundColor: _kBranco,
      elevation: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _kVermelho,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.local_shipping_rounded,
              color: _kBranco,
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
    return Container(
      color: _kBranco,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: 'Pesquisar fornecedor por nome, NUIT ou contacto...',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: _kCinzaTexto,
                ),
                prefixIcon: const Icon(Icons.search_rounded, color: _kAzul),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: _kCinzaTexto,
                          size: 18,
                        ),
                        onPressed: onLimpar,
                      )
                    : null,
                filled: true,
                fillColor: _kCinzaClaro,
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
              style: const TextStyle(fontSize: 13, color: _kCinzaTexto),
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
    final provider = context.watch<FornecedorProvider>();

    if (provider.carregando) {
      return const Center(
        child: CircularProgressIndicator(color: _kAzul),
      );
    }

    if (provider.temErro) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: _kVermelho, size: 48),
            const SizedBox(height: 12),
            Text(
              provider.erro!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kVermelho),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: provider.carregarFornecedores,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
              style: ElevatedButton.styleFrom(backgroundColor: _kAzul),
            ),
          ],
        ),
      );
    }

    final lista = provider.fornecedores;

    if (lista.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_shipping_outlined, color: _kCinzaTexto, size: 48),
            SizedBox(height: 12),
            Text(
              'Nenhum fornecedor encontrado.',
              style: TextStyle(color: _kCinzaTexto),
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
          decoration: const BoxDecoration(
            color: _kAzul,
            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
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
    return Container(
      decoration: BoxDecoration(
        color: isAlternate ? const Color(0xFFF0F2FA) : Colors.white,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE8EAF0)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _kAzul.withOpacity(0.12),
              child: Text(
                _iniciais,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _kAzul,
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
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _kAzul,
                ),
              ),
            ),

            Expanded(
              flex: 2,
              child: Text(
                fornecedor.nuit?.isNotEmpty == true ? fornecedor.nuit! : '—',
                style: const TextStyle(fontSize: 12, color: _kCinzaTexto),
              ),
            ),

            Expanded(
              flex: 2,
              child: Row(
                children: [
                  const Icon(
                    Icons.phone_outlined,
                    size: 13,
                    color: _kCinzaTexto,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      fornecedor.contacto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _kCinzaTexto,
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
                        const Icon(
                          Icons.email_outlined,
                          size: 12,
                          color: _kCinzaTexto,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            fornecedor.email!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: _kCinzaTexto,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (fornecedor.morada?.isNotEmpty == true)
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: _kCinzaTexto,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            fornecedor.morada!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: _kCinzaTexto,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if ((fornecedor.email == null || fornecedor.email!.isEmpty) &&
                      (fornecedor.morada == null || fornecedor.morada!.isEmpty))
                    const Text(
                      '—',
                      style: TextStyle(fontSize: 12, color: _kCinzaTexto),
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
                          color: _kAzul.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          size: 16,
                          color: _kAzul,
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
                          color: _kVermelho.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                          color: _kVermelho,
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
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        titulo,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: _kAzul,
          fontSize: 17,
        ),
      ),
      content: Text(
        mensagem,
        style: const TextStyle(fontSize: 14, color: _kCinzaTexto),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: _kCinzaTexto),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: corBotao,
            foregroundColor: _kBranco,
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