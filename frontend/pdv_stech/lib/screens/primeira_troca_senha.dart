// lib/screens/primeira_troca_senha.dart

import 'package:flutter/material.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import '../theme/app_theme.dart';

// ─── Cores ───────────────────────────────────────────────────────────────────
// As antigas constantes (_navy, _red, _bg, _border) e as cores hardcoded
// (Colors.white, 0xFF111827, 0xFF9CA3AF, 0xFFEEF2FF…) foram substituídas
// pelo tema:
//   _navy   → AppColors.azulMarca / azulMarcaEscuro (header)
//             context.cores.marcaBotao (avatar do chip)
//             context.cores.marca (borda de foco, textos/ícones azuis)
//   _red    → AppColors.vermelhoMarca (fundo: botão, snackbar, badge)
//             context.cores.acentoTexto (vermelho como texto/borda/barra)
//   _bg     → context.cores.fundo
//   _border → context.cores.borda (divisores, barra inativa, chip)
//             _bordaCampo() (borda dos campos)
//   Colors.white (cards) → context.cores.superficie
//   0xFF111827 / 0xFF374151 → context.cores.textoPrincipal
//   0xFF6B7280              → context.cores.textoSecundario
//   verde / âmbar           → context.cores.sucesso / aviso (tema escuro)
//   caixa de requisitos     → claro: cores índigo originais | escuro: marca
//
// O HEADER (azul) é escuro nos dois temas, por isso o seu conteúdo (badge,
// título e subtítulo) permanece fixo.

/// Borda dos campos. Claro: cinza-azulado original.
/// Escuro: `outline` do tema (contraste 3.7:1 sobre a superfície).
Color _bordaCampo(BuildContext context) => context.escuro
    ? Theme.of(context).colorScheme.outline
    : const Color(0xFFE2E5ED);

class PrimeiraTrocaSenhaScreen extends StatefulWidget {
  const PrimeiraTrocaSenhaScreen({super.key});

  @override
  State<PrimeiraTrocaSenhaScreen> createState() =>
      _PrimeiraTrocaSenhaScreenState();
}

class _PrimeiraTrocaSenhaScreenState extends State<PrimeiraTrocaSenhaScreen>
    with SingleTickerProviderStateMixin {
  final _formKey             = GlobalKey<FormState>();
  final _novaSenhaCtrl       = TextEditingController();
  final _confirmarSenhaCtrl  = TextEditingController();

  bool _obscureNova      = true;
  bool _obscureConfirmar = true;
  bool _isLoading        = false;

  // força da senha: 0-4
  int _strength = 0;

  late final AnimationController _animCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, .08),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
    _novaSenhaCtrl.addListener(_calcStrength);
  }

  @override
  void dispose() {
    _novaSenhaCtrl.removeListener(_calcStrength);
    _novaSenhaCtrl.dispose();
    _confirmarSenhaCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ── força da senha ───────────────────────────
  void _calcStrength() {
    final v = _novaSenhaCtrl.text;
    int s = 0;
    if (v.length >= 8)                          s++;
    if (RegExp(r'[A-Z]').hasMatch(v))           s++;
    if (RegExp(r'[0-9]').hasMatch(v))           s++;
    if (RegExp(r'[!@#\$%^&*()_+]').hasMatch(v)) s++;
    setState(() => _strength = s);
  }

  String get _strengthLabel {
    switch (_strength) {
      case 0:
      case 1: return 'Fraca';
      case 2: return 'Razoável';
      case 3: return 'Boa';
      case 4: return 'Excelente';
      default: return '';
    }
  }

  Color get _strengthColor {
    final c = context.cores;
    final escuro = context.escuro;

    switch (_strength) {
      case 0:
      case 1: return c.acentoTexto;
      case 2: return escuro ? c.aviso : const Color(0xFFF59E0B);
      case 3:
      case 4: return escuro ? c.sucesso : const Color(0xFF10B981);
      default: return c.borda;
    }
  }

  // ── troca de senha ───────────────────────────
  Future<void> _trocarSenha() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final usuario = SessaoService.instance.usuario;   // ✅ getter correcto
      if (usuario == null) throw Exception('Sessão inválida.');

      final sucesso = await ServicoAutenticacao()
          .trocarPrimeiraSenha(usuario.id, _novaSenhaCtrl.text); // ✅ .id

      if (!sucesso) throw Exception('Falha ao actualizar a senha.');

      // Fundo colorido FIXO + texto branco explícito: sem isso, no tema
      // escuro o texto herdaria `textoPrincipal` (claro) e perderia contraste.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Senha alterada com sucesso. Faça login novamente.',
              style: TextStyle(color: AppColors.branco),
            ),
            backgroundColor: Color(0xFF2E7D32),
            duration: Duration(seconds: 2),
          ),
        );
        await Future.delayed(const Duration(seconds: 2));
        SessaoService.instance.encerrar();              // ✅ método correcto
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erro: $e',
              style: const TextStyle(color: AppColors.branco),
            ),
            backgroundColor: AppColors.vermelhoMarca,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── UI ──────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final usuario = SessaoService.instance.usuario;     // ✅ getter correcto

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: c.fundo,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildHeader(),
                        _buildUserChip(usuario),
                        _buildFormCard(usuario),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── cabeçalho ───────────────────────────────
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(32, 30, 32, 52),
      decoration: BoxDecoration(
        // Mesmo critério da AppBar do tema escuro (azulMarcaEscuro).
        color: context.escuro ? AppColors.azulMarcaEscuro : AppColors.azulMarca,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // badge de aviso
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.vermelhoMarca.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.vermelhoMarca.withValues(alpha: .3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 12, color: Colors.red.shade200),
                const SizedBox(width: 5),
                Text(
                  'ACÇÃO OBRIGATÓRIA',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.red.shade200,
                    letterSpacing: .6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Definir nova senha',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Por segurança, crie uma senha pessoal',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: .5),
            ),
          ),
        ],
      ),
    );
  }

  // ── chip do utilizador (sobreposto) ──────────
  Widget _buildUserChip(usuario) {
    final c = context.cores;
    final iniciais = _initials(usuario?.nome, usuario?.apelido);
    return Transform.translate(
      offset: const Offset(0, -20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: c.superficie,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.borda),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.marcaBotao,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    iniciais,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    usuario?.nome ?? 'Utilizador',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.textoPrincipal,
                    ),
                  ),
                  Text(
                    usuario?.nomePerfil ?? '',
                    style: TextStyle(
                      fontSize: 11,
                      color: c.textoSecundario,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── formulário ───────────────────────────────
  Widget _buildFormCard(usuario) {
    final c = context.cores;

    return Transform.translate(
      offset: const Offset(0, -12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        decoration: BoxDecoration(
          color: c.superficie,
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPasswordField(
              label:      'Nova senha',
              controller: _novaSenhaCtrl,
              obscure:    _obscureNova,
              onToggle:   () => setState(() => _obscureNova = !_obscureNova),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Digite a nova senha.';
                if (v.length < 8) return 'Mínimo 8 caracteres.';
                if (v == '12345678') return 'Não utilize a senha padrão.';
                return null;
              },
            ),
            // barra de força
            const SizedBox(height: 8),
            _buildStrengthBar(),
            const SizedBox(height: 16),
            _buildPasswordField(
              label:      'Confirmar senha',
              controller: _confirmarSenhaCtrl,
              obscure:    _obscureConfirmar,
              onToggle:   () => setState(
                  () => _obscureConfirmar = !_obscureConfirmar),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Confirme a nova senha.';
                if (v != _novaSenhaCtrl.text) return 'As senhas não coincidem.';
                return null;
              },
            ),
            const SizedBox(height: 18),
            _buildRequirements(),
            const SizedBox(height: 20),
            _buildConfirmButton(),
          ],
        ),
      ),
    );
  }

  // ── campo senha com toggle ───────────────────
  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
    FormFieldValidator<String>? validator,
  }) {
    final c = context.cores;
    final borda = _bordaCampo(context);

    // Claro: cinza original. Escuro: textoSecundario (legível sobre o campo).
    final cinzaIcone =
        context.escuro ? c.textoSecundario : const Color(0xFF9CA3AF);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: c.textoPrincipal,
            letterSpacing: .5,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller:  controller,
          obscureText: obscure,
          validator:   validator,
          style: TextStyle(fontSize: 14, color: c.textoPrincipal),
          decoration: InputDecoration(
            hintText:  'Mínimo 8 caracteres',
            hintStyle: TextStyle(color: cinzaIcone, fontSize: 13),
            prefixIcon: Icon(
                Icons.lock_outline_rounded,
                size: 18,
                color: cinzaIcone),
            suffixIcon: IconButton(
              icon: Icon(
                obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
                color: cinzaIcone,
              ),
              onPressed: onToggle,
            ),
            filled:         true,
            fillColor:      c.superficieAlt,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borda),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borda),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: c.marca, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: c.acentoTexto),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: c.acentoTexto, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // ── barra de força ───────────────────────────
  Widget _buildStrengthBar() {
    final c = context.cores;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          children: List.generate(4, (i) {
            final active = i < _strength;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(left: i == 0 ? 0 : 4),
                height: 3,
                decoration: BoxDecoration(
                  color: active ? _strengthColor : c.borda,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        if (_novaSenhaCtrl.text.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            _strengthLabel,
            style: TextStyle(
              fontSize: 10,
              color: _strengthColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  // ── caixa de requisitos ──────────────────────
  Widget _buildRequirements() {
    final c = context.cores;
    final escuro = context.escuro;
    final senha = _novaSenhaCtrl.text;

    // Claro: índigo original. Escuro: marca do tema.
    final corTitulo = escuro ? c.marca : const Color(0xFF3730A3);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: escuro ? c.marca.withValues(alpha: 0.12) : const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: escuro
              ? c.marca.withValues(alpha: 0.30)
              : const Color(0xFFC7D2FE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 13, color: corTitulo),
              const SizedBox(width: 5),
              Text(
                'Requisitos',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: corTitulo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          _reqItem('Mínimo 8 caracteres',     senha.length >= 8),
          _reqItem('Diferente da senha padrão', senha != '12345678'),
          _reqItem(
            'As senhas coincidem',
            senha.isNotEmpty &&
                senha == _confirmarSenhaCtrl.text,
          ),
        ],
      ),
    );
  }

  Widget _reqItem(String text, bool ok) {
    final c = context.cores;
    final escuro = context.escuro;

    final corIconeOk = escuro ? c.sucesso : const Color(0xFF10B981);
    final corIconePendente = escuro ? c.marca : const Color(0xFF6366F1);
    final corTextoOk = escuro ? c.sucesso : const Color(0xFF065F46);
    final corTextoPendente = escuro ? c.textoSecundario : const Color(0xFF4338CA);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_outline_rounded
               : Icons.radio_button_unchecked_rounded,
            size: 13,
            color: ok ? corIconeOk : corIconePendente,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: ok ? corTextoOk : corTextoPendente,
            ),
          ),
        ],
      ),
    );
  }

  // ── botão confirmar ──────────────────────────
  Widget _buildConfirmButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _trocarSenha,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.vermelhoMarca,
          disabledBackgroundColor:
              AppColors.vermelhoMarca.withValues(alpha: .6),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Confirmar nova senha',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
      ),
    );
  }

  // ── utilitários ─────────────────────────────
  String _initials(String? nome, String? apelido) {
    final n = nome?.isNotEmpty == true ? nome![0].toUpperCase() : '';
    final a = apelido?.isNotEmpty == true ? apelido![0].toUpperCase() : '';
    return '$n$a'.isEmpty ? '?' : '$n$a';
  }
}