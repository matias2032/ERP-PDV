// lib/screens/detalhes_usuario_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import '../theme/app_theme.dart';

// ─── Cores ───────────────────────────────────────────────────────────────────
// As antigas constantes (_kVermelho, _kAzul, _kBranco, _kCinzaClaro,
// _kCinzaTexto) e as cores Colors.green/red/grey/orange/teal.* foram
// substituídas pelo tema:
//   _kAzul       → context.cores.marca (texto/ícone)
//                  context.cores.marcaBotao (fundo de snackbar)
//                  AppColors.azulMarca / azulMarcaEscuro (SliverAppBar/hero)
//   _kVermelho   → AppColors.vermelhoMarca (fundo: avatar, badge, botão;
//                  texto branco por cima)
//                  context.cores.acentoTexto (vermelho como texto/ícone/borda)
//   _kBranco     → AppColors.branco (sobre azul/vermelho)
//   _kCinzaClaro → context.cores.fundo
//   _kCinzaTexto → context.cores.textoSecundario
//   green/orange → context.cores.sucesso / aviso (+ Fundo)
//   grey.*       → context.cores.borda / desactivado
//
// O HERO (gradiente azul) é escuro nos dois temas, por isso o seu conteúdo
// (texto branco, avatar vermelho, indicador de status) permanece fixo.

/// Botão "Activar": verde escuro no tema escuro (texto branco com bom contraste).
Color _corAtivar(BuildContext context) =>
    context.escuro ? const Color(0xFF2E7D32) : Colors.green.shade600;

/// Botão "Desactivar": vermelho da marca no tema escuro.
Color _corDesativar(BuildContext context) =>
    context.escuro ? AppColors.vermelhoMarca : Colors.red.shade600;

// ─────────────────────────────────────────────────────────────────────────────

class DetalhesUsuarioScreen extends StatelessWidget {
  const DetalhesUsuarioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Recebe o UsuarioModel via Navigator.arguments
    final usuario =
        ModalRoute.of(context)!.settings.arguments as UsuarioModel;
    final c = context.cores;

    return Scaffold(
      backgroundColor: c.fundo,
      body: CustomScrollView(
        slivers: [
          _HeroAppBar(usuario: usuario),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 20),
                _CardDadosGerais(usuario: usuario),
                const SizedBox(height: 16),
                _CardStatus(usuario: usuario),
                const SizedBox(height: 16),
                _CardProdutividade(usuario: usuario),
                const SizedBox(height: 16),
                _CardSeguranca(usuario: usuario),
                const SizedBox(height: 32),
                _BotoesAcao(usuario: usuario),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Hero AppBar
// ─────────────────────────────────────────────────────────────────────────────

class _HeroAppBar extends StatelessWidget {
  final UsuarioModel usuario;
  const _HeroAppBar({required this.usuario});

  @override
  Widget build(BuildContext context) {
    final initials = _iniciais(usuario.nome);

    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      // Mesmo critério da AppBar do tema escuro (azulMarcaEscuro).
      backgroundColor:
          context.escuro ? AppColors.azulMarcaEscuro : AppColors.azulMarca,
      foregroundColor: AppColors.branco,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () => Navigator.of(context).pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Fundo gradiente
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: context.escuro
                      ? const [AppColors.azulMarcaEscuro, Color(0xFF080C26)]
                      : const [Color(0xFF1B2A6B), Color(0xFF0D1A45)],
                ),
              ),
            ),
            // Padrão decorativo
            Positioned(
              right: -40,
              top: -40,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.vermelhoMarca.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              left: -20,
              bottom: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.branco.withValues(alpha: 0.04),
                ),
              ),
            ),
            // Conteúdo
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Avatar grande
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: AppColors.vermelhoMarca,
                          child: Text(
                            initials,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.branco,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: usuario.ativo
                                  ? Colors.green.shade400
                                  : Colors.grey.shade400,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.branco, width: 2.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            usuario.nome,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.branco,
                              letterSpacing: 0.2,
                            ),
                          ),
                          if (usuario.apelido != null &&
                              usuario.apelido!.isNotEmpty)
                            Text(
                              '@${usuario.apelido}',
                              style: TextStyle(
                                fontSize: 13,
                                color:
                                    AppColors.branco.withValues(alpha: 0.65),
                              ),
                            ),
                          const SizedBox(height: 6),
                          _BadgePerfil(perfil: usuario.nomePerfil),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _iniciais(String nome) {
    final p = nome.trim().split(' ');
    if (p.length >= 2) {
      return '${p.first[0]}${p.last[0]}'.toUpperCase();
    }
    return nome.substring(0, nome.length >= 2 ? 2 : 1).toUpperCase();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Cards
// ─────────────────────────────────────────────────────────────────────────────

class _CardDadosGerais extends StatelessWidget {
  final UsuarioModel usuario;
  const _CardDadosGerais({required this.usuario});

  @override
  Widget build(BuildContext context) {
    return _Card(
      titulo: 'Dados Gerais',
      icon: Icons.person_outline_rounded,
      children: [
        _ItemInfo(
            icon: Icons.badge_outlined,
            label: 'ID',
            valor: '#${usuario.id}'),
        _ItemInfo(
            icon: Icons.person_rounded,
            label: 'Nome',
            valor: usuario.nome),
        if (usuario.apelido != null && usuario.apelido!.isNotEmpty)
          _ItemInfo(
              icon: Icons.short_text_rounded,
              label: 'Apelido',
              valor: usuario.apelido!),
        _ItemInfo(
            icon: Icons.email_outlined,
            label: 'E-mail',
            valor: usuario.email),
        // telefone — mostrado se disponível
        if ((usuario as dynamic).telefone != null)
          _ItemInfo(
              icon: Icons.phone_outlined,
              label: 'Telefone',
              valor: (usuario as dynamic).telefone as String),
        _ItemInfo(
            icon: Icons.calendar_today_outlined,
            label: 'Registado em',
            valor: _formatarData(usuario.criadoEm)),
        _ItemInfo(
            icon: Icons.update_rounded,
            label: 'Última actualização',
            valor: _formatarData(usuario.atualizadoEm)),
      ],
    );
  }

  String _formatarData(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _CardStatus extends StatelessWidget {
  final UsuarioModel usuario;
  const _CardStatus({required this.usuario});

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final ativo = usuario.ativo;

    return _Card(
      titulo: 'Status da Conta',
      icon: Icons.toggle_on_outlined,
      children: [
        Row(
          children: [
            Expanded(
              child: _StatBox(
                cor: ativo ? c.sucesso : c.textoSecundario,
                fundo: ativo ? c.sucessoFundo : c.borda,
                icone: ativo
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                titulo: ativo ? 'Activo' : 'Inactivo',
                descricao: ativo
                    ? 'Pode aceder ao sistema'
                    : 'Acesso bloqueado',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatBox(
                cor: c.marca,
                fundo: c.marca.withValues(alpha: context.escuro ? 0.12 : 0.06),
                icone: Icons.shield_outlined,
                titulo: usuario.nomePerfil,
                descricao: 'Perfil de acesso',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CardProdutividade extends StatelessWidget {
  final UsuarioModel usuario;
  const _CardProdutividade({required this.usuario});

  @override
  Widget build(BuildContext context) {
    final c = context.cores;

    // Métricas fictícias — substituir por dados reais da API quando disponível
    final totalVendas   = 0;
    final vendasHoje    = 0;
    final ticketMedio   = 0.0;

    return _Card(
      titulo: 'Produtividade',
      icon: Icons.bar_chart_rounded,
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricaBox(
                icone: Icons.receipt_long_rounded,
                valor: '$totalVendas',
                label: 'Vendas totais',
                cor: c.marca,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricaBox(
                icone: Icons.today_rounded,
                valor: '$vendasHoje',
                label: 'Vendas hoje',
                cor: context.escuro
                    ? Colors.teal.shade300
                    : Colors.teal.shade600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricaBox(
                icone: Icons.attach_money_rounded,
                valor: 'MT ${ticketMedio.toStringAsFixed(0)}',
                label: 'Ticket médio',
                cor: context.escuro ? c.aviso : Colors.orange.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.fundo,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: c.textoSecundario, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'As métricas de produtividade serão carregadas '
                  'automaticamente quando o histórico de vendas '
                  'deste usuário estiver disponível.',
                  style: TextStyle(
                      fontSize: 12,
                      color: c.textoSecundario,
                      height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CardSeguranca extends StatelessWidget {
  final UsuarioModel usuario;
  const _CardSeguranca({required this.usuario});

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final escuro = context.escuro;

    // primeiraSenha pode estar no model (se campo adicionado)
    final bool primeiraSenha =
        (usuario as dynamic).primeiraSenha as bool? ?? false;

    return _Card(
      titulo: 'Segurança',
      icon: Icons.security_rounded,
      children: [
        _ItemInfo(
          icon: Icons.lock_outline_rounded,
          label: 'Estado da senha',
          valor: primeiraSenha ? 'Aguarda troca (senha padrão)' : 'Personalizada',
          corValor: primeiraSenha ? c.aviso : c.sucesso,
        ),
        const SizedBox(height: 8),
        if (primeiraSenha)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: escuro ? c.avisoFundo : const Color(0xFFFFF3CD),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: escuro
                    ? c.aviso.withValues(alpha: 0.5)
                    : const Color(0xFFFFCC02),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: escuro ? c.aviso : const Color(0xFFF59E0B),
                    size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Este usuário ainda não alterou a senha inicial. '
                    'Será solicitada a troca no próximo login.',
                    style: TextStyle(
                        fontSize: 12,
                        color: escuro ? c.aviso : Colors.orange.shade900,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _BotoesAcao extends StatelessWidget {
  final UsuarioModel usuario;
  const _BotoesAcao({required this.usuario});

  @override
  Widget build(BuildContext context) {
    final c = context.cores;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Toggle activo/inactivo
        ElevatedButton.icon(
          onPressed: () => _confirmarToggle(context),
          icon: Icon(
            usuario.ativo
                ? Icons.block_rounded
                : Icons.check_circle_outline_rounded,
            size: 20,
          ),
          label: Text(
            usuario.ativo ? 'Desactivar Usuário' : 'Activar Usuário',
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 15),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                usuario.ativo ? _corDesativar(context) : _corAtivar(context),
            foregroundColor: AppColors.branco,
            padding: const EdgeInsets.symmetric(vertical: 14),
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),
        // Reset senha
        OutlinedButton.icon(
          onPressed: () => _confirmarReset(context),
          icon: const Icon(Icons.lock_reset_rounded, size: 20),
          label: const Text(
            'Resetar Senha para Padrão',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: c.acentoTexto,
            side: BorderSide(color: c.acentoTexto),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmarToggle(BuildContext ctx) async {
    final acao = usuario.ativo ? 'desactivar' : 'activar';
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => _Dialogo(
        titulo: '${acao[0].toUpperCase()}${acao.substring(1)} usuário',
        mensagem: 'Tem certeza que deseja $acao ${usuario.nome}?',
        corBotao: usuario.ativo ? _corDesativar(ctx) : _corAtivar(ctx),
        label: acao[0].toUpperCase() + acao.substring(1),
      ),
    );
    if (ok == true && ctx.mounted) {
      await ctx.read<UsuarioProvider>().toggleAtivo(usuario.id);
      if (ctx.mounted) Navigator.of(ctx).pop();
    }
  }

  Future<void> _confirmarReset(BuildContext ctx) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => const _Dialogo(
        titulo: 'Resetar senha',
        mensagem:
            'A senha será redefinida para "12345678". O usuário precisará '
            'alterá-la no próximo login. Confirmar?',
        corBotao: AppColors.vermelhoMarca,
        label: 'Resetar',
      ),
    );
    if (ok == true && ctx.mounted) {
      await ctx.read<UsuarioProvider>().resetarSenha(usuario.id);
      if (ctx.mounted) {
        // Texto branco explícito: no tema escuro herdaria `textoPrincipal`.
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: const Text(
              'Senha redefinida com sucesso.',
              style: TextStyle(color: AppColors.branco),
            ),
            backgroundColor: ctx.cores.marcaBotao,
          ),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Componentes reutilizáveis
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final String titulo;
  final IconData icon;
  final List<Widget> children;

  const _Card({
    required this.titulo,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cores;

    return Card(
      elevation: 0,
      color: c.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: c.borda),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: c.acentoTexto, size: 18),
                const SizedBox(width: 8),
                Text(titulo,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: c.marca,
                      letterSpacing: 0.4,
                    )),
                const SizedBox(width: 10),
                Expanded(child: Divider(color: c.borda)),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ItemInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final String valor;
  final Color? corValor;

  const _ItemInfo({
    required this.icon,
    required this.label,
    required this.valor,
    this.corValor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cores;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: c.textoSecundario, size: 17),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 13, color: c.textoSecundario),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: corValor ?? c.marca,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final Color cor;
  final Color fundo;
  final IconData icone;
  final String titulo;
  final String descricao;

  const _StatBox({
    required this.cor,
    required this.fundo,
    required this.icone,
    required this.titulo,
    required this.descricao,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cores;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icone, color: cor, size: 28),
          const SizedBox(height: 8),
          Text(titulo,
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: cor, fontSize: 14)),
          const SizedBox(height: 2),
          Text(descricao,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11, color: c.textoSecundario)),
        ],
      ),
    );
  }
}

class _MetricaBox extends StatelessWidget {
  final IconData icone;
  final String valor;
  final String label;
  final Color cor;

  const _MetricaBox({
    required this.icone,
    required this.valor,
    required this.label,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cores;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: context.escuro ? 0.14 : 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icone, color: cor, size: 22),
          const SizedBox(height: 8),
          Text(valor,
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: cor,
                  fontSize: 16)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11, color: c.textoSecundario)),
        ],
      ),
    );
  }
}

/// Usado apenas sobre o hero (gradiente azul escuro nos dois temas),
/// por isso permanece com cores fixas.
class _BadgePerfil extends StatelessWidget {
  final String perfil;
  const _BadgePerfil({required this.perfil});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.vermelhoMarca.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        perfil,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.branco,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _Dialogo extends StatelessWidget {
  final String titulo;
  final String mensagem;
  final Color corBotao;
  final String label;

  const _Dialogo({
    required this.titulo,
    required this.mensagem,
    required this.corBotao,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cores;

    return AlertDialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
          child: Text(label),
        ),
      ],
    );
  }
}