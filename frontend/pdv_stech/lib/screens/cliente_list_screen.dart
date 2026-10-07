// lib/features/cliente/screens/cliente_list_screen.dart

import 'package:flutter/material.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:provider/provider.dart';
import '../widgets/app_sidebar.dart';

// ── Cores STech Engenharia ────────────────────────────────────────────────────
const _kVermelho   = Color(0xFFC8102E);
const _kAzul       = Color(0xFF1B2A6B);
const _kBranco     = Colors.white;
const _kCinzaClaro = Color(0xFFF4F5F7);
const _kCinzaTexto = Color(0xFF6B7280);

/// Perfil fixo que esta tela exibe
const int    _kIdPerfilEmpresa   = 1;
const String _kNomePerfilEmpresa = 'Empresa';

// ─────────────────────────────────────────────────────────────────────────────

class ClienteListScreen extends StatefulWidget {
  const ClienteListScreen({super.key});

  @override
  State<ClienteListScreen> createState() => _ClienteListScreenState();
}

class _ClienteListScreenState extends State<ClienteListScreen> {

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Carrega apenas clientes com perfil Empresa
      context.read<ClienteListaProvider>().filtrarPorPerfil(_kIdPerfilEmpresa);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Pesquisa ──────────────────────────────────────────────────────────────

  void _onPesquisar(String termo) {
    final provider = context.read<ClienteListaProvider>();
    if (termo.trim().isEmpty) {
      provider.filtrarPorPerfil(_kIdPerfilEmpresa);
    } else {
      provider.pesquisar(termo.trim());
    }
  }

  void _limparPesquisa() {
    _searchController.clear();
    context.read<ClienteListaProvider>().filtrarPorPerfil(_kIdPerfilEmpresa);
  }

  // ── Diálogo de exclusão ───────────────────────────────────────────────────

  Future<void> _confirmarExclusao(
      BuildContext ctx, ClienteModel cliente) async {
    final confirma = await showDialog<bool>(
      context: ctx,
      builder: (_) => _DialogoConfirmacao(
        titulo: 'Remover empresa',
        mensagem:
            'Deseja remover a empresa "${cliente.nomeCompleto}"? Esta acção não pode ser desfeita.',
        corBotao: _kVermelho,
        labelBotao: 'Remover',
      ),
    );

    if (confirma == true && ctx.mounted) {
      final exclusaoProvider = ctx.read<ClienteExclusaoProvider>();
      await exclusaoProvider.excluir(cliente.id);

      if (!ctx.mounted) return;

if (exclusaoProvider.sucesso) {
  ctx.read<ClienteListaProvider>().removerLocal(cliente.id);

  await ctx
      .read<ClienteListaProvider>()
      .filtrarPorPerfil(_kIdPerfilEmpresa);

  _mostrarSnack(ctx, '${cliente.nomeCompleto} removido com sucesso.');
  exclusaoProvider.resetar();
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

  // ── Navegação para formulário ─────────────────────────────────────────────

  Future<void> _abrirFormulario({ClienteModel? cliente}) async {
    final resultado = await Navigator.of(context).pushNamed(
      '/clientes/empresa/form',
      arguments: cliente,
    );
    if (resultado == true && mounted) {
      context.read<ClienteListaProvider>().filtrarPorPerfil(_kIdPerfilEmpresa);
    }
  }

  PopupMenuItem<OrdemAlfabetica> _itemOrdem(
  String label,
  OrdemAlfabetica valor,
  OrdemAlfabetica atual,
  IconData icon,
) {
  final ativo = atual == valor;
  return PopupMenuItem(
    value: valor,
    child: Row(
      children: [
        Icon(icon, size: 18, color: ativo ? _kAzul : _kCinzaTexto),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: ativo ? _kAzul : _kCinzaTexto,
            fontWeight: ativo ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
        if (ativo) ...[
          const Spacer(),
          const Icon(Icons.check_rounded, size: 16, color: _kAzul),
        ],
      ],
    ),
  );
}

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kCinzaClaro,
      appBar: _buildAppBar(),
      drawer: const AppSidebar(currentRoute: '/clientes/empresa'),
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
  onEditar: (c) => _abrirFormulario(cliente: c),
  onDetalhes: (c) => Navigator.of(context).pushNamed(
    '/detalhes_cliente',
    arguments: c,
  ),
  onExcluir: (c) => _confirmarExclusao(context, c),
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
          child: const Icon(Icons.business_rounded, color: _kBranco, size: 20),
        ),
        const SizedBox(width: 10),
        const Text(
          'Clientes — Empresas',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0.3),
        ),
      ],
    ),
    actions: [
      IconButton(
        icon: const Icon(Icons.add_business_rounded),
        tooltip: 'Nova Empresa',
        onPressed: () => _abrirFormulario(),
      ),
      // ── Ordenação ──────────────────────────────────────────────────
      Consumer<ClienteListaProvider>(
        builder: (_, p, __) {
          final ativo = p.ordem != OrdemAlfabetica.nenhuma;
          return PopupMenuButton<OrdemAlfabetica>(
            tooltip: 'Ordenar',
            icon: Icon(
              Icons.sort_by_alpha_rounded,
              color: ativo ? Colors.amber : _kBranco,
            ),
            onSelected: p.alterarOrdem,
            itemBuilder: (_) => [
              _itemOrdem('A → Z', OrdemAlfabetica.az,   p.ordem, Icons.arrow_downward_rounded),
              _itemOrdem('Z → A', OrdemAlfabetica.za,   p.ordem, Icons.arrow_upward_rounded),
              _itemOrdem('Padrão', OrdemAlfabetica.nenhuma, p.ordem, Icons.clear_rounded),
            ],
          );
        },
      ),
      // ──────────────────────────────────────────────────────────────
      IconButton(
        icon: const Icon(Icons.refresh_rounded),
        tooltip: 'Recarregar',
        onPressed: () =>
            context.read<ClienteListaProvider>().filtrarPorPerfil(_kIdPerfilEmpresa),
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
                hintText: 'Pesquisar empresa por nome, NUI T ou contacto...',
                hintStyle: const TextStyle(fontSize: 13, color: _kCinzaTexto),
                prefixIcon: const Icon(Icons.search_rounded, color: _kAzul),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: _kCinzaTexto, size: 18),
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
          // Contador de resultados
          Consumer<ClienteListaProvider>(
            builder: (_, p, __) => Text(
              '${p.clientes.length} empresa(s)',
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
  final void Function(ClienteModel) onEditar;
  final void Function(ClienteModel) onDetalhes;
  final Future<void> Function(ClienteModel) onExcluir;

  const _Listagem({
    required this.onEditar,
    required this.onDetalhes,
    required this.onExcluir,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClienteListaProvider>();

    if (provider.carregando) {
      return const Center(child: CircularProgressIndicator(color: _kAzul));
    }

    if (provider.temErro) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: _kVermelho, size: 48),
            const SizedBox(height: 12),
            Text(provider.erro!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _kVermelho)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () =>
                  provider.filtrarPorPerfil(_kIdPerfilEmpresa),
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
              style: ElevatedButton.styleFrom(backgroundColor: _kAzul),
            ),
          ],
        ),
      );
    }

    final lista = provider.clientes;

    if (lista.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.business_outlined, color: _kCinzaTexto, size: 48),
            SizedBox(height: 12),
            Text('Nenhuma empresa encontrada.',
                style: TextStyle(color: _kCinzaTexto)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Cabeçalho da tabela
        Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: _kAzul,
            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: const Row(
            children: [
              SizedBox(width: 44),  // espaço do avatar
              SizedBox(width: 14),
              Expanded(flex: 3,
                  child: Text('Empresa',
                      style: TextStyle(color: Colors.white, fontSize: 12,
                          fontWeight: FontWeight.w700))),
              Expanded(flex: 2,
                  child: Text('NUIT',
                      style: TextStyle(color: Colors.white, fontSize: 12,
                          fontWeight: FontWeight.w700))),
              Expanded(flex: 2,
                  child: Text('Contacto',
                      style: TextStyle(color: Colors.white, fontSize: 12,
                          fontWeight: FontWeight.w700))),
              Expanded(flex: 3,
                  child: Text('Email / Morada',
                      style: TextStyle(color: Colors.white, fontSize: 12,
                          fontWeight: FontWeight.w700))),
              SizedBox(width: 126),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
            itemCount: lista.length,
            itemBuilder: (_, i) => _LinhaCliente(
  cliente: lista[i],
  isAlternate: i.isOdd,
  onEditar: onEditar,
  onDetalhes: onDetalhes,
  onExcluir: onExcluir,
),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Card de Cliente (Empresa)
// ─────────────────────────────────────────────────────────────────────────────



// ─────────────────────────────────────────────────────────────────────────────
//  Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _AvatarEmpresa extends StatelessWidget {
  final String iniciais;
  const _AvatarEmpresa({required this.iniciais});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 26,
      backgroundColor: _kAzul.withOpacity(0.12),
      child: Text(
        iniciais,
        style: const TextStyle(
            fontWeight: FontWeight.w700, color: _kAzul, fontSize: 15),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: _kCinzaTexto),
        const SizedBox(width: 3),
        Text(label,
            style: const TextStyle(fontSize: 12, color: _kCinzaTexto)),
      ],
    );
  }
}

class _BadgePerfil extends StatelessWidget {
  final String perfil;
  const _BadgePerfil({required this.perfil});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _kAzul.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(perfil,
          style: const TextStyle(
              fontSize: 11, color: _kAzul, fontWeight: FontWeight.w500)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Layouts: lista (mobile) e grade (desktop/tablet)
// ─────────────────────────────────────────────────────────────────────────────


// ─────────────────────────────────────────────────────────────────────────────
//  Diálogo de Confirmação reutilizável
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
      title: Text(titulo,
          style: const TextStyle(
              fontWeight: FontWeight.w700, color: _kAzul, fontSize: 17)),
      content: Text(mensagem,
          style: const TextStyle(fontSize: 14, color: _kCinzaTexto)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child:
              const Text('Cancelar', style: TextStyle(color: _kCinzaTexto)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: corBotao,
            foregroundColor: _kBranco,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(labelBotao),
        ),
      ],
    );
  }

  
}
class _LinhaCliente extends StatelessWidget {
  const _LinhaCliente({
    required this.cliente,
    required this.isAlternate,
    required this.onEditar,
    required this.onDetalhes,
    required this.onExcluir,
  });

  final ClienteModel cliente;
  final bool isAlternate;
  final void Function(ClienteModel) onEditar;
  final void Function(ClienteModel) onDetalhes;
  final Future<void> Function(ClienteModel) onExcluir;

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
            // Avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: _kAzul.withOpacity(0.12),
              child: Text(
                cliente.iniciais,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _kAzul,
                    fontSize: 12),
              ),
            ),
            const SizedBox(width: 14),

            // Nome + perfil
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cliente.nomeCompleto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _kAzul,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: _kAzul.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      cliente.nomePerfil,
                      style: const TextStyle(
                          fontSize: 10,
                          color: _kAzul,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

            // NUIT
            Expanded(
              flex: 2,
              child: Text(
                cliente.nuit?.isNotEmpty == true
                    ? cliente.nuit!
                    : '—',
                style: const TextStyle(
                    fontSize: 12, color: _kCinzaTexto),
              ),
            ),

            // Contacto
            Expanded(
              flex: 2,
              child: Row(children: [
                if (cliente.contacto?.isNotEmpty == true) ...[
                  const Icon(Icons.phone_outlined,
                      size: 13, color: _kCinzaTexto),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      cliente.contacto!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: _kCinzaTexto),
                    ),
                  ),
                ] else
                  const Text('—',
                      style: TextStyle(
                          fontSize: 12, color: _kCinzaTexto)),
              ]),
            ),

            // Email / Morada
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (cliente.email?.isNotEmpty == true)
                    Row(children: [
                      const Icon(Icons.email_outlined,
                          size: 12, color: _kCinzaTexto),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          cliente.email!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: _kCinzaTexto),
                        ),
                      ),
                    ]),
                  if (cliente.morada?.isNotEmpty == true)
                    Row(children: [
                      const Icon(Icons.location_on_outlined,
                          size: 12, color: _kCinzaTexto),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          cliente.morada!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: _kCinzaTexto),
                        ),
                      ),
                    ]),
                  if ((cliente.email == null || cliente.email!.isEmpty) &&
                      (cliente.morada == null || cliente.morada!.isEmpty))
                    const Text('—',
                        style: TextStyle(
                            fontSize: 12, color: _kCinzaTexto)),
                ],
              ),
            ),

            // Ações
            SizedBox(
  width: 126,
  child: Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      Tooltip(
        message: 'Detalhes',
        child: InkWell(
          onTap: () => onDetalhes(cliente),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.visibility_outlined,
              size: 16,
              color: Colors.green,
            ),
          ),
        ),
      ),
      const SizedBox(width: 6),
      Tooltip(
        message: 'Editar',
        child: InkWell(
          onTap: () => onEditar(cliente),
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
          onTap: () => onExcluir(cliente),
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

