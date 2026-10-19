// lib/features/cliente/screens/cliente_list_screen.dart

import 'package:flutter/material.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_sidebar.dart';

// ─── Cores ───────────────────────────────────────────────────────────────────
// As antigas constantes foram substituídas pelo tema:
//   _kAzul        → context.cores.marca (texto/ícone/borda)
//                   context.cores.marcaBotao (fundo de botão)
//                   AppColors.azulMarca / azulMarcaEscuro (AppBar, cabeçalho da tabela)
//   _kVermelho    → AppColors.vermelhoMarca (FUNDO: ícone da AppBar, botão do diálogo)
//                   context.cores.acentoTexto (vermelho como texto/ícone)
//                   context.cores.perigo (mensagem de erro de carregamento)
//   _kBranco      → context.cores.superficie (fundo) / AppColors.branco (sobre marca)
//   _kCinzaClaro  → context.cores.fundo
//   _kCinzaTexto  → context.cores.textoSecundario
//   Colors.green  → context.cores.sucesso
//   0xFFF0F2FA    → context.cores.linhaAlternada
//   0xFFE8EAF0    → context.cores.borda
//
// NOTA: ajusta o import do tema ao caminho real deste ficheiro
// (ex.: '../../../theme/app_theme.dart' se estiver em lib/features/cliente/screens/).

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
        corBotao: AppColors.vermelhoMarca,
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
    final c = context.cores;
    final ativo = atual == valor;
    return PopupMenuItem(
      value: valor,
      child: Row(
        children: [
          Icon(icon, size: 18, color: ativo ? c.marca : c.textoSecundario),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: ativo ? c.marca : c.textoSecundario,
              fontWeight: ativo ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
          if (ativo) ...[
            const Spacer(),
            Icon(Icons.check_rounded, size: 16, color: c.marca),
          ],
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.cores;

    return Scaffold(
      backgroundColor: c.fundo,
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
            child: const Icon(Icons.business_rounded,
                color: AppColors.branco, size: 20),
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
                color: ativo ? Colors.amber : AppColors.branco,
              ),
              onSelected: p.alterarOrdem,
              itemBuilder: (_) => [
                _itemOrdem('A → Z', OrdemAlfabetica.az, p.ordem,
                    Icons.arrow_downward_rounded),
                _itemOrdem('Z → A', OrdemAlfabetica.za, p.ordem,
                    Icons.arrow_upward_rounded),
                _itemOrdem('Padrão', OrdemAlfabetica.nenhuma, p.ordem,
                    Icons.clear_rounded),
              ],
            );
          },
        ),
        // ──────────────────────────────────────────────────────────────
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Recarregar',
          onPressed: () => context
              .read<ClienteListaProvider>()
              .filtrarPorPerfil(_kIdPerfilEmpresa),
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
                hintText: 'Pesquisar empresa por nome, NUI T ou contacto...',
                hintStyle: TextStyle(fontSize: 13, color: c.textoSecundario),
                prefixIcon: Icon(Icons.search_rounded, color: c.marca),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: c.textoSecundario, size: 18),
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
          // Contador de resultados
          Consumer<ClienteListaProvider>(
            builder: (_, p, __) => Text(
              '${p.clientes.length} empresa(s)',
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
    final c = context.cores;
    final provider = context.watch<ClienteListaProvider>();

    if (provider.carregando) {
      return Center(child: CircularProgressIndicator(color: c.marca));
    }

    if (provider.temErro) {
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
              onPressed: () => provider.filtrarPorPerfil(_kIdPerfilEmpresa),
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

    final lista = provider.clientes;

    if (lista.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.business_outlined, color: c.textoSecundario, size: 48),
            const SizedBox(height: 12),
            Text('Nenhuma empresa encontrada.',
                style: TextStyle(color: c.textoSecundario)),
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
          decoration: BoxDecoration(
            color: context.escuro
                ? AppColors.azulMarcaEscuro
                : AppColors.azulMarca,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(10)),
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
    final c = context.cores;

    return CircleAvatar(
      radius: 26,
      backgroundColor: c.marca.withValues(alpha: context.escuro ? 0.18 : 0.12),
      child: Text(
        iniciais,
        style:
            TextStyle(fontWeight: FontWeight.w700, color: c.marca, fontSize: 15),
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

class _BadgePerfil extends StatelessWidget {
  final String perfil;
  const _BadgePerfil({required this.perfil});

  @override
  Widget build(BuildContext context) {
    final c = context.cores;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.marca.withValues(alpha: context.escuro ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(perfil,
          style: TextStyle(
              fontSize: 11, color: c.marca, fontWeight: FontWeight.w500)),
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
            // Avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: c.marca.withValues(alpha: escuro ? 0.18 : 0.12),
              child: Text(
                cliente.iniciais,
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: c.marca, fontSize: 12),
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
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.marca,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: c.marca.withValues(alpha: escuro ? 0.15 : 0.07),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      cliente.nomePerfil,
                      style: TextStyle(
                          fontSize: 10,
                          color: c.marca,
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
                cliente.nuit?.isNotEmpty == true ? cliente.nuit! : '—',
                style: TextStyle(fontSize: 12, color: c.textoSecundario),
              ),
            ),

            // Contacto
            Expanded(
              flex: 2,
              child: Row(children: [
                if (cliente.contacto?.isNotEmpty == true) ...[
                  Icon(Icons.phone_outlined,
                      size: 13, color: c.textoSecundario),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      cliente.contacto!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: c.textoSecundario),
                    ),
                  ),
                ] else
                  Text('—',
                      style:
                          TextStyle(fontSize: 12, color: c.textoSecundario)),
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
                      Icon(Icons.email_outlined,
                          size: 12, color: c.textoSecundario),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          cliente.email!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11, color: c.textoSecundario),
                        ),
                      ),
                    ]),
                  if (cliente.morada?.isNotEmpty == true)
                    Row(children: [
                      Icon(Icons.location_on_outlined,
                          size: 12, color: c.textoSecundario),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          cliente.morada!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11, color: c.textoSecundario),
                        ),
                      ),
                    ]),
                  if ((cliente.email == null || cliente.email!.isEmpty) &&
                      (cliente.morada == null || cliente.morada!.isEmpty))
                    Text('—',
                        style:
                            TextStyle(fontSize: 12, color: c.textoSecundario)),
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
                          color: c.sucesso.withValues(alpha: alphaAccao),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.visibility_outlined,
                          size: 16,
                          color: c.sucesso,
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
                      onTap: () => onExcluir(cliente),
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