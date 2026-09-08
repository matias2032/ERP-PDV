// lib/widgets/app_sidebar.dart

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'dart:io';

const _kVermelho  = Color(0xFFC8102E);
const _kAzul      = Color(0xFF3A3E4F);
const _kBranco    = Colors.white;
const _kCinzaTexto = Color(0xFF6B7280);

// ─────────────────────────────────────────────────────────────────────────────
// Modelo de item de menu
// ─────────────────────────────────────────────────────────────────────────────

class _MenuItem {
  final IconData icon;
  final String title;
  final String route;
  final int badge;
  final Color badgeColor;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.route,
    this.badge = 0,
    this.badgeColor = _kVermelho,
  });
}

class _MenuGroup {
  final IconData        icon;
  final String          title;
  final List<_MenuItem> items;

  const _MenuGroup({
    required this.icon,
    required this.title,
    required this.items,
  });
}

// ─────────────────────────────────────────────────────────────────────────────

class AppSidebar extends StatefulWidget {
  final String currentRoute;

  const AppSidebar({super.key, required this.currentRoute});

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar>
    with SingleTickerProviderStateMixin {

  // ── Animação do menu de utilizador ───────────────────────────────
  bool _showUserMenu = false;
  late AnimationController _animController;
  late Animation<double>   _rotationAnim;

  // ── Grupos expandidos ─────────────────────────────────────────────
  final Set<String> _expandidos = {};

  // ── Badge pedidos abertos ─────────────────────────────────────────
  final _pedidoService  = PedidoService();
final _cotacaoService = CotacaoService();

int _pedidosAbertos = 0;
int _pedidosEmDivida = 0;
int _cotacoesAbertas = 0;
int _cotacoesProntas = 0;
  // ─────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _rotationAnim = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

_carregarPedidosAbertos();
_carregarPedidosEmDivida();
_carregarCotacoes();

PedidoAtivoController.instance.pedidoAtivo.addListener(() {
  _carregarPedidosAbertos();
  _carregarPedidosEmDivida();
  PedidoAtivoController.instance.pedidoAtivo.addListener(_onPedidoAtivoChanged);
});

CotacaoAtivaController.instance.cotacaoAtiva
    .addListener(_carregarCotacoes);

    // Expande automaticamente o grupo da rota activa
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _expandirGrupoActivo();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
PedidoAtivoController.instance.pedidoAtivo.removeListener(() {
  _carregarPedidosAbertos();
  _carregarPedidosEmDivida();
PedidoAtivoController.instance.pedidoAtivo.removeListener(_onPedidoAtivoChanged);
});
    super.dispose();
  }

  void _onPedidoAtivoChanged() {
  _carregarPedidosAbertos();
  _carregarPedidosEmDivida();
}



  Future<void> _carregarPedidosAbertos() async {
    try {
      final total = await _pedidoService.contarPedidosAbertos();
      if (mounted) setState(() => _pedidosAbertos = total);
    } catch (_) {}
  }

  Future<void> _carregarPedidosEmDivida() async {
  try {
    final pedidos = await _pedidoService.listarEmDivida();

    final total = pedidos
        .where((p) =>
            p.estaEmDivida &&
            p.ehCredito &&
            !p.pagamentoPago &&
            !p.estaFinalizado)
        .length;

    if (mounted) {
      setState(() => _pedidosEmDivida = total);
    }
  } catch (_) {}
}

  Future<void> _carregarCotacoes() async {
  try {
    final abertas = await _cotacaoService.listarPorStatus('ABERTA');
    final prontas = await _cotacaoService.listarPorStatus('PRONTA');

    var totalAbertas = abertas.length;

    final cotacaoAtiva = CotacaoAtivaController.instance.cotacaoAtiva.value;

    final ativaJaEstaNaLista = cotacaoAtiva == null
        ? true
        : abertas.any((c) => c.idCotacao == cotacaoAtiva.idCotacao);

    if (cotacaoAtiva != null &&
        cotacaoAtiva.estaAberta &&
        !ativaJaEstaNaLista) {
      totalAbertas++;
    }

    if (mounted) {
      setState(() {
        _cotacoesAbertas = totalAbertas;
        _cotacoesProntas = prontas.length;
      });
    }
  } catch (_) {}
}

  void _expandirGrupoActivo() {
  for (final grupo in _grupos(
  _pedidosAbertos,
  _pedidosEmDivida,
  _cotacoesAbertas,
  _cotacoesProntas,
)) {
      for (final item in grupo.items) {
        if (item.route == widget.currentRoute) {
          setState(() => _expandidos.add(grupo.title));
          return;
        }
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Definição dos grupos (recebe pedidosAbertos para badge)
  // ─────────────────────────────────────────────────────────────────

List<_MenuGroup> _grupos(
  int pedidosAbertos,
  int pedidosEmDivida,
  int cotacoesAbertas,
  int cotacoesProntas,
) => [
  _MenuGroup(
    icon: Icons.point_of_sale_rounded,
    title: 'Vendas',
    items: [
      _MenuItem(
        icon: Icons.storefront_rounded,
        title: 'Balcão de Vendas',
        route: '/catalogo',
        badge: pedidosAbertos,
      ),
      _MenuItem(
        icon: Icons.task_alt_rounded,
        title: 'Pedidos Finalizados',
        route: '/pedidos_finalizados',
      ),
_MenuItem(
  icon: Icons.account_balance_wallet_rounded,
  title: 'Pedidos à Crédito',
  route: '/pedidos_credito',
  badge: pedidosEmDivida,
  badgeColor: Colors.amber,
),
      _MenuItem(
        icon: Icons.receipt_long_rounded,
        title: 'Facturação',
        route: '/gerenciar_documentos',
      ),
      _MenuItem(
        icon: Icons.analytics_rounded,
        title: 'Extractos',
        route: '/gerenciar_extractos',
      ),
    ],
  ),

_MenuGroup(
  icon: Icons.payments_rounded,
  title: 'Despesas',
  items: [
    _MenuItem(
      icon: Icons.request_quote_rounded,
      title: 'Ver Despesas',
      route: '/gerenciar_despesas',
    ),
    _MenuItem(
      icon: Icons.delete_sweep_rounded,
      title: 'Despesas Excluídas',
      route: '/despesas_excluidas',
    ),
  ],
),

_MenuGroup(
  icon: Icons.assignment_rounded,
  title: 'Cotações',
  items: [
    // Badge das cotações abertas anexado à rota Criar Cotação
    _MenuItem(
      icon: Icons.post_add_rounded,
      title: 'Criar Cotação',
      route: '/criar_cotacao',
      badge: cotacoesAbertas,
    ),

    // Badge das cotações prontas — permanece até mudar de estado
    _MenuItem(
      icon: Icons.fact_check_rounded,
      title: 'Cotações Prontas',
      route: '/cotacoes_prontas',
      badge: cotacoesProntas,
    ),

    _MenuItem(
      icon: Icons.manage_search_rounded,
      title: 'Histórico de Cotações',
      route: '/historico_cotacoes',
    ),
  ],
),

  _MenuGroup(
    icon: Icons.groups_rounded,
    title: 'Clientes',
    items: [
      _MenuItem(
        icon: Icons.apartment_rounded,
        title: 'Empresas',
        route: '/gerenciar_clientes',
      ),
    ],
  ),

  _MenuGroup(
    icon: Icons.handshake_rounded,
    title: 'Fornecedores',
    items: [
      _MenuItem(
        icon: Icons.local_shipping_rounded,
        title: 'Fornecedores',
        route: '/gerenciar_fornecedores',
      ),
    ],
  ),

  _MenuGroup(
    icon: Icons.warehouse_rounded,
    title: 'Inventário',
    items: [
      _MenuItem(
        icon: Icons.inventory_2_rounded,
        title: 'Produtos',
        route: '/gerenciar_produtos',
      ),
      _MenuItem(
        icon: Icons.category_rounded,
        title: 'Categorias',
        route: '/gerenciar_categorias',
      ),
      _MenuItem(
        icon: Icons.sell_rounded,
        title: 'Marcas',
        route: '/gerenciar_marcas',
      ),
    ],
  ),

  _MenuGroup(
    icon: Icons.engineering_rounded,
    title: 'Serviços',
    items: [
      _MenuItem(
        icon: Icons.design_services_rounded,
        title: 'Gestão de Serviços',
        route: '/gerenciar_servicos',
      ),
    ],
  ),

  _MenuGroup(
    icon: Icons.admin_panel_settings_rounded,
    title: 'Administração',
    items: [
      _MenuItem(
        icon: Icons.manage_accounts_rounded,
        title: 'Utilizadores',
        route: '/gerenciar_usuarios',
      ),
      if (!Platform.isAndroid && !Platform.isIOS)
        _MenuItem(
          icon: Icons.print_rounded,
          title: 'Impressora',
          route: '/configuracoes_impressora',
        ),
    ],
  ),
];

  // ─────────────────────────────────────────────────────────────────
  // Build principal
  // ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final usuario = SessaoService.instance.usuario;
    if (usuario == null) return const SizedBox.shrink();

 final gruposBase = _grupos(
  _pedidosAbertos,
  _pedidosEmDivida,
  _cotacoesAbertas,
  _cotacoesProntas,
);

final grupos = usuario.isAdmin
    ? gruposBase
    : gruposBase
        .where((g) =>
            g.title == 'Vendas' ||
            g.title == 'Cotações' ||
            g.title == 'Despesas')
        .toList();

    return Drawer(
      child: Column(
        children: [
          // ── Cabeçalho ────────────────────────────────────────────
          _buildHeader(usuario),

          // ── Lista de itens ───────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // Painel de Controle — sempre visível
                _buildItemSimples(
                  icon:  Icons.dashboard_rounded,
                  title: 'Painel de Controle',
                  route: '/dashboard',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Divider(height: 1),
                ),
                // Grupos expansíveis
                ...grupos.map((g) => _buildGrupo(g)),
              ],
            ),
          ),

          // ── Secção do utilizador ─────────────────────────────────
          _buildUserSection(usuario),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Header
  // ─────────────────────────────────────────────────────────────────

Widget _buildHeader(usuario) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF3A3E4F), Color.fromARGB(255, 18, 19, 24)],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Hero(
          tag: 'user_avatar_${usuario.id}',
          child: CircleAvatar(
            radius: 30,
              backgroundColor: _kBranco,
              child: Text(
                usuario.nome[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 28,
                  color: _kAzul,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${usuario.nome} ${usuario.apelido}',
            style: const TextStyle(
              color: _kBranco,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _kBranco.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              usuario.nomePerfil,
              style: const TextStyle(
                color: _kBranco, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Item simples (sem grupo)
  // ─────────────────────────────────────────────────────────────────

  Widget _buildItemSimples({
    required IconData icon,
    required String   title,
    required String   route,
  }) {
    final sel = widget.currentRoute == route;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: ListTile(
        dense: true,
        leading: Icon(icon,
            size: 22, color: sel ? _kVermelho : Colors.grey[700]),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: sel ? _kAzul : Colors.black87,
            fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
        selected: sel,
        selectedTileColor: _kAzul.withOpacity(0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: () {
          Navigator.pop(context);
          if (!sel) Navigator.pushReplacementNamed(context, route);
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Grupo expansível
  // ─────────────────────────────────────────────────────────────────

  Widget _buildGrupo(_MenuGroup grupo) {
    final expandido   = _expandidos.contains(grupo.title);
    final temActivo   = grupo.items.any((i) => i.route == widget.currentRoute);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Cabeçalho do grupo ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() {
              if (expandido) {
                _expandidos.remove(grupo.title);
              } else {
                _expandidos.add(grupo.title);
              }
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: temActivo
                    ? _kAzul.withOpacity(0.06)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    grupo.icon,
                    size: 22,
                    color: temActivo ? _kVermelho : Colors.grey[700],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      grupo.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: temActivo
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: temActivo ? _kAzul : Colors.black87,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expandido ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 20,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Sub-itens ───────────────────────────────────────────────
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: expandido
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: Column(
            children: grupo.items.map(_buildSubItem).toList(),
          ),
          secondChild: const SizedBox.shrink(),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Sub-item (indentado)
  // ─────────────────────────────────────────────────────────────────

  Widget _buildSubItem(_MenuItem item) {
    final sel = widget.currentRoute == item.route;

    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 8, top: 1, bottom: 1),
      child: ListTile(
        dense: true,
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(item.icon,
                size: 20, color: sel ? _kVermelho : Colors.grey[600]),
            if (item.badge > 0)
              Positioned(
                top: -5,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
  color: item.badgeColor,
  shape: BoxShape.circle,
),
                  child: Text(
                    item.badge > 99 ? '99+' : '${item.badge}',
                    style: const TextStyle(
                        color: _kBranco,
                        fontSize: 9,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          item.title,
          style: TextStyle(
            fontSize: 13,
            color: sel ? _kAzul : Colors.black87,
            fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
        selected: sel,
        selectedTileColor: _kAzul.withOpacity(0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: () {
          Navigator.pop(context);
          if (!sel) Navigator.pushReplacementNamed(context, item.route);
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Secção do utilizador (fundo do drawer)
  // ─────────────────────────────────────────────────────────────────

  Widget _buildUserSection(usuario) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Menu expansível de acções do utilizador
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: Alignment.bottomCenter,
            child: _showUserMenu
                ? Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                          bottom: BorderSide(color: Colors.grey[300]!)),
                    ),
                    child: Column(
                      children: [
                        _buildUserMenuItem(
                          icon:  Icons.person_rounded,
                          title: 'Alterar Dados',
                          color: Colors.blue,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/editar_usuario');
                          },
                        ),
                        Divider(height: 1, color: Colors.grey[200]),
                        _buildUserMenuItem(
                          icon:  Icons.lock_rounded,
                          title: 'Alterar Senha',
                          color: Colors.orange,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/alterar_senha');
                          },
                        ),
                        Divider(height: 1, color: Colors.grey[200]),
                        _buildUserMenuItem(
                          icon:  Icons.logout_rounded,
                          title: 'Sair',
                          color: Colors.red,
                          onTap: () => _confirmarLogout(context),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // Botão do utilizador
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _showUserMenu = !_showUserMenu;
                  _showUserMenu
                      ? _animController.forward()
                      : _animController.reverse();
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: _kAzul,
                      child: Text(
                        usuario.nome[0].toUpperCase(),
                        style: const TextStyle(
                          color: _kBranco,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${usuario.nome} ${usuario.apelido}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            usuario.email,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    RotationTransition(
                      turns: _rotationAnim,
                      child: Icon(Icons.expand_less_rounded,
                          color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserMenuItem({
    required IconData    icon,
    required String      title,
    required Color       color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color, size: 20),
      title: Text(
        title,
        style: TextStyle(
          color: title == 'Sair' ? Colors.red : Colors.black87,
          fontSize: 13,
        ),
      ),
      dense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      onTap: onTap,
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Logout
  // ─────────────────────────────────────────────────────────────────

  Future<void> _confirmarLogout(BuildContext context) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.red),
            SizedBox(width: 12),
            Text('Confirmar Saída'),
          ],
        ),
        content:
            const Text('Tem certeza que deseja sair da sua conta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      SessaoService.instance.encerrar();
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/', (route) => false);
    }
  }
}