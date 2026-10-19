// lib/screens/usuarios_list_screen.dart

import 'package:flutter/material.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:provider/provider.dart';
import '../widgets/app_sidebar.dart';
import '../theme/app_theme.dart';

// ─── Cores ───────────────────────────────────────────────────────────────────
// As antigas constantes (_kVermelho, _kAzul, _kBranco, _kCinzaClaro,
// _kCinzaTexto) e as cores Colors.green/red/grey.* foram substituídas pelo tema:
//   _kAzul       → context.cores.marca (texto/ícone/borda)
//                  context.cores.marcaBotao (fundo de botão/chip/snackbar)
//                  AppColors.azulMarca / azulMarcaEscuro (AppBar)
//   _kVermelho   → AppColors.vermelhoMarca (fundo: snackbar, ícone da AppBar;
//                  texto branco por cima)
//                  context.cores.acentoTexto (vermelho como texto/ícone)
//   _kBranco     → AppColors.branco (sobre azul/vermelho)
//                  context.cores.superficie (barra de filtro)
//   _kCinzaClaro → context.cores.fundo
//   _kCinzaTexto → context.cores.textoSecundario
//   green.*      → context.cores.sucesso / sucessoFundo
//   red.shade50  → context.cores.perigoFundo
//   grey.*       → context.cores.borda / desactivado

// Fundo FIXO do chip "Activos" (texto branco por cima, nos dois temas).
const _kVerdeChip = Color(0xFF388E3C);

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
        corBotao: usuario.ativo
            ? AppColors.vermelhoMarca
            : ctx.cores.marcaBotao,
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
        corBotao: AppColors.vermelhoMarca,
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

  /// Fundo colorido FIXO + texto branco explícito: sem isso, no tema escuro
  /// o texto herdaria `textoPrincipal` (claro) e perderia contraste.
  void _mostrarSnack(BuildContext ctx, String mensagem,
      {bool erro = false}) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(
          mensagem,
          style: const TextStyle(color: AppColors.branco),
        ),
        backgroundColor:
            erro ? AppColors.vermelhoMarca : ctx.cores.marcaBotao,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ── Build ─────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.cores;

    return Scaffold(
      backgroundColor: c.fundo,
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
            child: const Icon(Icons.people_alt_rounded,
                color: AppColors.branco, size: 20),
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
    final c = context.cores;
    final provider = context.watch<UsuarioProvider>();
    final filtro = provider.filtro;

    return Container(
      color: c.superficie,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.filter_list_rounded,
              color: c.marca, size: 20),
          const SizedBox(width: 8),
          Text('Filtrar:',
              style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: c.marca,
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
            cor: _kVerdeChip,
            onTap: () => provider.setFiltro(FiltroStatus.ativos),
          ),
          const SizedBox(width: 8),
          _FiltroChip(
            label: 'Inactivos',
            selecionado: filtro == FiltroStatus.inativos,
            cor: AppColors.vermelhoMarca,
            onTap: () => provider.setFiltro(FiltroStatus.inativos),
          ),
          const Spacer(),
          // contador
          Consumer<UsuarioProvider>(
            builder: (_, p, __) => Text(
              '${p.usuariosFiltrados.length} usuário(s)',
              style: TextStyle(
                  fontSize: 13, color: c.textoSecundario),
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

  /// Fundo quando seleccionado (texto branco por cima). Se nulo, usa
  /// `marcaBotao` do tema.
  final Color? cor;
  final VoidCallback onTap;

  const _FiltroChip({
    required this.label,
    required this.selecionado,
    required this.onTap,
    this.cor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final corSelecionado = cor ?? c.marcaBotao;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selecionado ? corSelecionado : c.fundo,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selecionado ? corSelecionado : c.borda),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight:
                selecionado ? FontWeight.w600 : FontWeight.w400,
            color: selecionado ? AppColors.branco : c.textoSecundario,
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
    final c = context.cores;
    final provider = context.watch<UsuarioProvider>();

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
            Text(provider.erro!,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.acentoTexto)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => provider.carregarUsuarios(),
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

    final lista = provider.usuariosFiltrados;

    if (lista.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, color: c.textoSecundario, size: 48),
            const SizedBox(height: 12),
            Text('Nenhum usuário encontrado.',
                style: TextStyle(color: c.textoSecundario)),
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
    final c = context.cores;
    final initials = _iniciais(usuario.nome);
    final ativo = usuario.ativo;

    return Card(
      elevation: 0,
      color: c.superficie,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: ativo
              ? c.sucesso.withValues(alpha: 0.45)
              : c.borda,
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
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: c.marca)),
                  const SizedBox(height: 2),
                  Text(usuario.email,
                      style: TextStyle(
                          fontSize: 13, color: c.textoSecundario)),
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
                    // Claro: valores originais. Escuro: verde do tema.
                    activeColor:
                        context.escuro ? c.sucesso : Colors.green.shade600,
                    activeTrackColor: context.escuro
                        ? c.sucesso.withValues(alpha: 0.40)
                        : null,
                    inactiveThumbColor:
                        context.escuro ? c.textoSecundario : Colors.grey,
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
                color: c.acentoTexto,
                iconSize: 22,
                onPressed: () => onReset(usuario),
              ),
            ),
            // Seta para detalhes
            Tooltip(
              message: 'Ver detalhes',
              child: IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                color: c.marca,
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
    final c = context.cores;

    return Stack(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor:
              c.marca.withValues(alpha: context.escuro ? 0.18 : 0.12),
          child: Text(initials,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: c.marca,
                  fontSize: 15)),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: ativo ? c.sucesso : c.desactivado,
              shape: BoxShape.circle,
              // Mesma cor do card, para o "recorte" do indicador.
              border: Border.all(color: c.superficie, width: 2),
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
    final c = context.cores;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ativo ? c.sucessoFundo : c.perigoFundo,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: ativo
                ? c.sucesso.withValues(alpha: 0.45)
                : c.perigo.withValues(alpha: 0.35)),
      ),
      child: Text(
        ativo ? 'Activo' : 'Inactivo',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: ativo ? c.sucesso : c.acentoTexto,
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
          child: Text('Cancelar',
              style: TextStyle(color: c.textoSecundario)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: corBotao,
            foregroundColor: AppColors.branco,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(labelBotao),
        ),
      ],
    );
  }
}