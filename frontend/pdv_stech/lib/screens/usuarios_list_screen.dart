// lib/screens/usuarios_list_screen.dart

import 'package:flutter/material.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:provider/provider.dart';
import '../widgets/app_sidebar.dart';


// ── Cores STech Engenharia ────────────────────────────────────────────────────
const _kVermelho = Color(0xFFC8102E);
const _kAzul = Color(0xFF1B2A6B);
const _kBranco = Colors.white;
const _kCinzaClaro = Color(0xFFF4F5F7);
const _kCinzaTexto = Color(0xFF6B7280);

// ─────────────────────────────────────────────────────────────────────────────

class UsuariosListScreen extends StatefulWidget {
  const UsuariosListScreen({super.key});

  @override
  State<UsuariosListScreen> createState() => _UsuariosListScreenState();
}

class _UsuariosListScreenState extends State<UsuariosListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UsuarioProvider>().carregarUsuarios();
    });
  }

  // ── Diálogos ─────────────────────────────────

  Future<void> _confirmarToggle(
      BuildContext ctx, UsuarioModel usuario) async {
    final acao = usuario.ativo ? 'desactivar' : 'activar';
    final confirma = await showDialog<bool>(
      context: ctx,
      builder: (_) => _DialogoConfirmacao(
        titulo: '${acao[0].toUpperCase()}${acao.substring(1)} usuário',
        mensagem:
            'Deseja $acao o usuário ${usuario.nome}?',
        corBotao: usuario.ativo ? _kVermelho : _kAzul,
        labelBotao: acao[0].toUpperCase() + acao.substring(1),
      ),
    );
    if (confirma == true && ctx.mounted) {
      try {
        await ctx.read<UsuarioProvider>().toggleAtivo(usuario.id);
        if (ctx.mounted) {
          _mostrarSnack(ctx,
              '${usuario.nome} foi ${usuario.ativo ? 'desactivado' : 'activado'} com sucesso.');
        }
      } catch (_) {
        if (ctx.mounted) _mostrarSnack(ctx, 'Erro ao alterar status.', erro: true);
      }
    }
  }

  Future<void> _confirmarReset(
      BuildContext ctx, UsuarioModel usuario) async {
    final confirma = await showDialog<bool>(
      context: ctx,
      builder: (_) => _DialogoConfirmacao(
        titulo: 'Resetar senha',
        mensagem:
            'A senha de ${usuario.nome} será redefinida para 12345678. Confirmar?',
        corBotao: _kVermelho,
        labelBotao: 'Resetar',
      ),
    );
    if (confirma == true && ctx.mounted) {
      try {
        await ctx.read<UsuarioProvider>().resetarSenha(usuario.id);
        if (ctx.mounted) {
          _mostrarSnack(ctx, 'Senha de ${usuario.nome} redefinida para 12345678.');
        }
      } catch (_) {
        if (ctx.mounted) _mostrarSnack(ctx, 'Erro ao resetar senha.', erro: true);
      }
    }
  }

  void _mostrarSnack(BuildContext ctx, String mensagem,
      {bool erro = false}) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: erro ? _kVermelho : _kAzul,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ── Build ─────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kCinzaClaro,
      appBar: _buildAppBar(),
       drawer: const AppSidebar(currentRoute: '/gerenciar_usuarios'),
      body: Column(
        children: [
          _FiltroBarra(),
          const Divider(height: 1),
          Expanded(child: _Listagem(
            onToggle: (u) => _confirmarToggle(context, u),
            onReset: (u) => _confirmarReset(context, u),
          )),
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
            child: const Icon(Icons.people_alt_rounded,
                color: _kBranco, size: 20),
          ),
          const SizedBox(width: 10),
          const Text(
            'Gestão de Usuários',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0.3),
          ),
        ],
      ),

      actions: [

        IconButton(
  icon: const Icon(Icons.person_add_alt_1_rounded),
  tooltip: 'Novo Usuário',
  onPressed: () async {
    final criado = await Navigator.of(context)
        .pushNamed('/usuarios/criar');
    if (criado == true && context.mounted) {
      context.read<UsuarioProvider>().carregarUsuarios();
    }
  },
),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Recarregar',
          onPressed: () => context.read<UsuarioProvider>().carregarUsuarios(),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Barra de Filtro
// ─────────────────────────────────────────────────────────────────────────────

class _FiltroBarra extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UsuarioProvider>();
    final filtro = provider.filtro;

    return Container(
      color: _kBranco,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.filter_list_rounded,
              color: _kAzul, size: 20),
          const SizedBox(width: 8),
          const Text('Filtrar:',
              style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: _kAzul,
                  fontSize: 14)),
          const SizedBox(width: 12),
          _FiltroChip(
            label: 'Todos',
            selecionado: filtro == FiltroStatus.todos,
            onTap: () => provider.setFiltro(FiltroStatus.todos),
          ),
          const SizedBox(width: 8),
          _FiltroChip(
            label: 'Activos',
            selecionado: filtro == FiltroStatus.ativos,
            cor: Colors.green.shade700,
            onTap: () => provider.setFiltro(FiltroStatus.ativos),
          ),
          const SizedBox(width: 8),
          _FiltroChip(
            label: 'Inactivos',
            selecionado: filtro == FiltroStatus.inativos,
            cor: _kVermelho,
            onTap: () => provider.setFiltro(FiltroStatus.inativos),
          ),
          const Spacer(),
          // contador
          Consumer<UsuarioProvider>(
            builder: (_, p, __) => Text(
              '${p.usuariosFiltrados.length} usuário(s)',
              style: const TextStyle(
                  fontSize: 13, color: _kCinzaTexto),
            ),
          ),
        ],
      ),
    );
  }
}

class _FiltroChip extends StatelessWidget {
  final String label;
  final bool selecionado;
  final Color cor;
  final VoidCallback onTap;

  const _FiltroChip({
    required this.label,
    required this.selecionado,
    required this.onTap,
    this.cor = _kAzul,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selecionado ? cor : _kCinzaClaro,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selecionado ? cor : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight:
                selecionado ? FontWeight.w600 : FontWeight.w400,
            color: selecionado ? _kBranco : _kCinzaTexto,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Listagem
// ─────────────────────────────────────────────────────────────────────────────

class _Listagem extends StatelessWidget {
  final Future<void> Function(UsuarioModel) onToggle;
  final Future<void> Function(UsuarioModel) onReset;

  const _Listagem({required this.onToggle, required this.onReset});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UsuarioProvider>();

    if (provider.carregando) {
      return const Center(
        child: CircularProgressIndicator(color: _kAzul),
      );
    }

    if (provider.erro != null) {
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
              onPressed: () => provider.carregarUsuarios(),
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
              style: ElevatedButton.styleFrom(backgroundColor: _kAzul),
            ),
          ],
        ),
      );
    }

    final lista = provider.usuariosFiltrados;

    if (lista.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, color: _kCinzaTexto, size: 48),
            SizedBox(height: 12),
            Text('Nenhum usuário encontrado.',
                style: TextStyle(color: _kCinzaTexto)),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Grade para desktop/tablet, lista para mobile
        if (constraints.maxWidth > 700) {
          return _GradeUsuarios(
              usuarios: lista, onToggle: onToggle, onReset: onReset);
        }
        return _ListaUsuarios(
            usuarios: lista, onToggle: onToggle, onReset: onReset);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Card de Usuário
// ─────────────────────────────────────────────────────────────────────────────

class _CardUsuario extends StatelessWidget {
  final UsuarioModel usuario;
  final Future<void> Function(UsuarioModel) onToggle;
  final Future<void> Function(UsuarioModel) onReset;

  const _CardUsuario({
    required this.usuario,
    required this.onToggle,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final initials = _iniciais(usuario.nome);
    final ativo = usuario.ativo;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: ativo
              ? Colors.green.shade200
              : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Avatar
            _Avatar(initials: initials, ativo: ativo),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(usuario.nome,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: _kAzul)),
                  const SizedBox(height: 2),
                  Text(usuario.email,
                      style: const TextStyle(
                          fontSize: 13, color: _kCinzaTexto)),
                  const SizedBox(height: 4),
                  _BadgePerfil(perfil: usuario.nomePerfil),
                ],
              ),
            ),
            // Toggle switch
            Column(
              children: [
                _BadgeStatus(ativo: ativo),
                const SizedBox(height: 6),
                Transform.scale(
                  scale: 0.85,
                  child: Switch(
                    value: ativo,
                    activeColor: Colors.green.shade600,
                    inactiveThumbColor: Colors.grey,
                    onChanged: (_) => onToggle(usuario),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            // Botão reset senha
            Tooltip(
              message: 'Resetar senha',
              child: IconButton(
                icon: const Icon(Icons.lock_reset_rounded),
                color: _kVermelho,
                iconSize: 22,
                onPressed: () => onReset(usuario),
              ),
            ),
            // Seta para detalhes
            Tooltip(
              message: 'Ver detalhes',
              child: IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                color: _kAzul,
                iconSize: 24,
                onPressed: () => Navigator.of(context)
                    .pushNamed('/usuarios/detalhes', arguments: usuario),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _iniciais(String nome) {
    final partes = nome.trim().split(' ');
    if (partes.length >= 2) {
      return '${partes.first[0]}${partes.last[0]}'.toUpperCase();
    }
    return nome.substring(0, nome.length >= 2 ? 2 : 1).toUpperCase();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String initials;
  final bool ativo;
  const _Avatar({required this.initials, required this.ativo});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: _kAzul.withOpacity(0.12),
          child: Text(initials,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _kAzul,
                  fontSize: 15)),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: ativo ? Colors.green.shade500 : Colors.grey.shade400,
              shape: BoxShape.circle,
              border: Border.all(color: _kBranco, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _BadgeStatus extends StatelessWidget {
  final bool ativo;
  const _BadgeStatus({required this.ativo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ativo
            ? Colors.green.shade50
            : Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: ativo ? Colors.green.shade300 : Colors.red.shade200),
      ),
      child: Text(
        ativo ? 'Activo' : 'Inactivo',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: ativo ? Colors.green.shade700 : _kVermelho,
        ),
      ),
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

class _ListaUsuarios extends StatelessWidget {
  final List<UsuarioModel> usuarios;
  final Future<void> Function(UsuarioModel) onToggle;
  final Future<void> Function(UsuarioModel) onReset;

  const _ListaUsuarios(
      {required this.usuarios,
      required this.onToggle,
      required this.onReset});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: usuarios.length,
      itemBuilder: (_, i) => _CardUsuario(
        usuario: usuarios[i],
        onToggle: onToggle,
        onReset: onReset,
      ),
    );
  }
}

class _GradeUsuarios extends StatelessWidget {
  final List<UsuarioModel> usuarios;
  final Future<void> Function(UsuarioModel) onToggle;
  final Future<void> Function(UsuarioModel) onReset;

  const _GradeUsuarios(
      {required this.usuarios,
      required this.onToggle,
      required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 560,
          mainAxisExtent: 110,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: usuarios.length,
        itemBuilder: (_, i) => _CardUsuario(
          usuario: usuarios[i],
          onToggle: onToggle,
          onReset: onReset,
        ),
      ),
    );
  }
}

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
          child: const Text('Cancelar',
              style: TextStyle(color: _kCinzaTexto)),
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

