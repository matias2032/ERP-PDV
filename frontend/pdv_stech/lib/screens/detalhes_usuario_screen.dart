// lib/screens/detalhes_usuario_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:api_compartilhado/api_compartilhado.dart';

// ── Paleta STech ────────────────────────────────────────────────────────────
const _kVermelho   = Color(0xFFC8102E);
const _kAzul       = Color(0xFF1B2A6B);
const _kBranco     = Colors.white;
const _kCinzaClaro = Color(0xFFF4F5F7);
const _kCinzaTexto = Color(0xFF6B7280);

// ─────────────────────────────────────────────────────────────────────────────

class DetalhesUsuarioScreen extends StatelessWidget {
  const DetalhesUsuarioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Recebe o UsuarioModel via Navigator.arguments
    final usuario =
        ModalRoute.of(context)!.settings.arguments as UsuarioModel;

    return Scaffold(
      backgroundColor: _kCinzaClaro,
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
      backgroundColor: _kAzul,
      foregroundColor: _kBranco,
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
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1B2A6B), Color(0xFF0D1A45)],
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
                  color: _kVermelho.withOpacity(0.08),
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
                  color: _kBranco.withOpacity(0.04),
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
                          backgroundColor: _kVermelho,
                          child: Text(
                            initials,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: _kBranco,
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
                              border:
                                  Border.all(color: _kBranco, width: 2.5),
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
                              color: _kBranco,
                              letterSpacing: 0.2,
                            ),
                          ),
                          if (usuario.apelido != null &&
                              usuario.apelido!.isNotEmpty)
                            Text(
                              '@${usuario.apelido}',
                              style: TextStyle(
                                fontSize: 13,
                                color: _kBranco.withOpacity(0.65),
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
    final ativo = usuario.ativo;

    return _Card(
      titulo: 'Status da Conta',
      icon: Icons.toggle_on_outlined,
      children: [
        Row(
          children: [
            Expanded(
              child: _StatBox(
                cor: ativo ? Colors.green.shade600 : Colors.grey.shade500,
                fundo: ativo
                    ? Colors.green.shade50
                    : Colors.grey.shade100,
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
                cor: _kAzul,
                fundo: _kAzul.withOpacity(0.06),
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
                cor: _kAzul,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricaBox(
                icone: Icons.today_rounded,
                valor: '$vendasHoje',
                label: 'Vendas hoje',
                cor: Colors.teal.shade600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricaBox(
                icone: Icons.attach_money_rounded,
                valor: 'MT ${ticketMedio.toStringAsFixed(0)}',
                label: 'Ticket médio',
                cor: Colors.orange.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _kCinzaClaro,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: _kCinzaTexto, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'As métricas de produtividade serão carregadas '
                  'automaticamente quando o histórico de vendas '
                  'deste usuário estiver disponível.',
                  style: TextStyle(
                      fontSize: 12,
                      color: _kCinzaTexto,
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
          corValor: primeiraSenha ? Colors.orange.shade700 : Colors.green.shade700,
        ),
        const SizedBox(height: 8),
        if (primeiraSenha)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3CD),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFCC02)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFF59E0B), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Este usuário ainda não alterou a senha inicial. '
                    'Será solicitada a troca no próximo login.',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade900,
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
            backgroundColor: usuario.ativo
                ? Colors.red.shade600
                : Colors.green.shade600,
            foregroundColor: _kBranco,
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
            foregroundColor: _kVermelho,
            side: const BorderSide(color: _kVermelho),
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
        corBotao: usuario.ativo ? _kVermelho : Colors.green.shade600,
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
        corBotao: _kVermelho,
        label: 'Resetar',
      ),
    );
    if (ok == true && ctx.mounted) {
      await ctx.read<UsuarioProvider>().resetarSenha(usuario.id);
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Senha redefinida com sucesso.'),
            backgroundColor: _kAzul,
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
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: _kVermelho, size: 18),
                const SizedBox(width: 8),
                Text(titulo,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kAzul,
                      letterSpacing: 0.4,
                    )),
                const SizedBox(width: 10),
                Expanded(child: Divider(color: Colors.grey.shade200)),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _kCinzaTexto, size: 17),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 13, color: _kCinzaTexto),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: corValor ?? _kAzul,
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
              style: const TextStyle(
                  fontSize: 11, color: _kCinzaTexto)),
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.07),
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
              style: const TextStyle(
                  fontSize: 11, color: _kCinzaTexto)),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _kVermelho.withOpacity(0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        perfil,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _kBranco,
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
    return AlertDialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
          child: Text(label),
        ),
      ],
    );
  }
}