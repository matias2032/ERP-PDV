// lib/screens/primeira_troca_senha.dart

import 'package:flutter/material.dart';
import 'package:api_compartilhado/api_compartilhado.dart';


// ──────────────────────────────────────────────
// Paleta STech
// ──────────────────────────────────────────────
const _navy   = Color(0xFF1B2A6B);
const _red    = Color(0xFFC8102E);
const _bg     = Color(0xFFF4F5F7);
const _border = Color(0xFFE2E5ED);

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
    switch (_strength) {
      case 0:
      case 1: return _red;
      case 2: return const Color(0xFFF59E0B);
      case 3:
      case 4: return const Color(0xFF10B981);
      default: return _border;
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Senha alterada com sucesso. Faça login novamente.'),
            backgroundColor: Color(0xFF10B981),
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
            content: Text('Erro: $e'),
            backgroundColor: _red,
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
    final usuario = SessaoService.instance.usuario;     // ✅ getter correcto

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: _bg,
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
        color: _navy,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // badge de aviso
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _red.withOpacity(.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _red.withOpacity(.3)),
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
              color: Colors.white.withOpacity(.5),
            ),
          ),
        ],
      ),
    );
  }

  // ── chip do utilizador (sobreposto) ──────────
  Widget _buildUserChip(usuario) {
    final iniciais = _initials(usuario?.nome, usuario?.apelido);
    return Transform.translate(
      offset: const Offset(0, -20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _navy,
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
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  Text(
                    usuario?.nomePerfil ?? '',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
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
    return Transform.translate(
      offset: const Offset(0, -12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
            letterSpacing: .5,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller:  controller,
          obscureText: obscure,
          validator:   validator,
          style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
          decoration: InputDecoration(
            hintText:  'Mínimo 8 caracteres',
            hintStyle: const TextStyle(
                color: Color(0xFF9CA3AF), fontSize: 13),
            prefixIcon: const Icon(
                Icons.lock_outline_rounded,
                size: 18,
                color: Color(0xFF9CA3AF)),
            suffixIcon: IconButton(
              icon: Icon(
                obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
                color: const Color(0xFF9CA3AF),
              ),
              onPressed: onToggle,
            ),
            filled:         true,
            fillColor:      const Color(0xFFF8F9FB),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _navy, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _red, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // ── barra de força ───────────────────────────
  Widget _buildStrengthBar() {
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
                  color: active ? _strengthColor : _border,
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
    final senha = _novaSenhaCtrl.text;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined,
                  size: 13, color: Color(0xFF3730A3)),
              SizedBox(width: 5),
              Text(
                'Requisitos',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3730A3),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_outline_rounded
               : Icons.radio_button_unchecked_rounded,
            size: 13,
            color: ok ? const Color(0xFF10B981) : const Color(0xFF6366F1),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: ok ? const Color(0xFF065F46) : const Color(0xFF4338CA),
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
          backgroundColor: _red,
          disabledBackgroundColor: _red.withOpacity(.6),
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