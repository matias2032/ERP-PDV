// lib/screens/tela_login.dart

import 'package:flutter/material.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:flutter/material.dart';  // já existe
import 'package:api_compartilhado/api_compartilhado.dart';  // já existe
import 'package:api_compartilhado/core/database/daos/usuario_dao.dart'; // ← NOVO


// ──────────────────────────────────────────────
// Paleta STech
// ──────────────────────────────────────────────
const _navy   = Color.fromARGB(255, 58, 62, 79);
const _red    = Color.fromARGB(255, 200, 16, 46);
const _bg     = Color.fromARGB(255, 244, 245, 247);
const _border = Color(0xFFE2E5ED);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _credencialCtrl = TextEditingController();
  final _passwordCtrl   = TextEditingController();
  final _authService    = ServicoAutenticacao();

  bool _isLoading      = false;
  bool _obscurePass    = true;
  String _errorMessage = '';

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
  }

  @override
  void dispose() {
    _credencialCtrl.dispose();
    _passwordCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ── lógica ──────────────────────────────────
Future<void> _handleLogin() async {
  final credencial = _credencialCtrl.text.trim();
  final password   = _passwordCtrl.text;

  if (credencial.isEmpty || password.isEmpty) {
    setState(() => _errorMessage = 'Preencha todos os campos.');
    return;
  }

  setState(() { _isLoading = true; _errorMessage = ''; });

  if (ConnectivityService.instance.isOnline) {
    try {
      final result = await _authService.login(credencial, password);

      switch (result.status) {
        case StatusAutenticacao.primeiraSenha:
          if (result.usuario != null) {
            SessaoService.instance.iniciar(result.usuario!);
            await _guardarSessaoLocal(result.usuario!);
          }
          if (mounted) Navigator.of(context).pushReplacementNamed('/primeira_troca_senha');
          return;

        case StatusAutenticacao.sucesso:
          if (result.usuario != null) {
            SessaoService.instance.iniciar(result.usuario!);
            await _guardarSessaoLocal(result.usuario!);
          }
          if (mounted) Navigator.of(context).pushReplacementNamed('/dashboard');
          return;

        case StatusAutenticacao.credenciaisInvalidas:
          // Credenciais erradas → não tentar offline (evita bypass de segurança)
          setState(() {
            _errorMessage = result.mensagem ?? 'Credencial ou senha incorrectos.';
            _isLoading    = false;
          });
          return;

        default:
          // Erro de servidor → tenta offline com cache
          debugPrint('⚠️ Servidor respondeu com erro — tentando offline: ${result.mensagem}');
      }
    } catch (e) {
      debugPrint('⚠️ Login HTTP lançou excepção: $e');
      // Cai no fallback offline abaixo
    }
  }

  // Offline ou HTTP falhou por razão técnica (não por credenciais erradas)
  await _tentarLoginOffline(credencial);
}
Future<void> _guardarSessaoLocal(UsuarioModel usuario) async {
  try {
    await UsuarioDao().upsert(usuario.toLocalDb());
  } catch (e) {
    debugPrint('⚠️ Não foi possível guardar sessão local: $e');
  }
}

Future<void> _tentarLoginOffline(String credencial) async {
  try {
    final rows = await UsuarioDao().getAll();
    final cred = credencial.toLowerCase().trim();

    Map<String, dynamic> match = {};
for (final r in rows) {
  final email    = (r['email']    as String? ?? '').toLowerCase();
  final apelido  = (r['apelido'] as String? ?? '').toLowerCase();
  final telefone = (r['telefone'] as String? ?? '').toLowerCase();
  final synced   = (r['sync_status'] as String? ?? '') == 'synced';

  if ((email == cred || apelido == cred || telefone == cred) && synced) {
    match = r;
    break;
  }
}

    if (match.isEmpty) {
      setState(() {
        _errorMessage = ConnectivityService.instance.isOnline
            ? 'Utilizador não encontrado.'
            : 'Sem ligação e nenhuma sessão guardada para este utilizador.\n'
              'Ligue-se à internet para o primeiro acesso.';
        _isLoading = false;
      });
      return;
    }

    SessaoService.instance.iniciarOffline(UsuarioModel.fromLocalDb(match));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Expanded(child: Text(
              'Modo offline — sessão guardada. Sincroniza quando a ligação voltar.',
              style: TextStyle(fontSize: 12),
            )),
          ]),
          backgroundColor: Color(0xFF92400E),
          duration: Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pushReplacementNamed('/dashboard');
    }
  } catch (e) {
    setState(() {
      _errorMessage = 'Erro ao verificar credenciais locais: $e';
      _isLoading    = false;
    });
  }
}

  // ── UI ──────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                child: Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 4),
                    _buildCard(),
                  ],
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
      padding: const EdgeInsets.fromLTRB(32, 36, 32, 48),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // logo mark
Container(
  width: 100,
  height: 100,
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(.10),
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: Colors.white.withOpacity(.25), width: 2),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(.25),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ],
  ),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: Image.asset(
      'assets/icon/app_icon.png',
      width: 100,
      height: 100,
      fit: BoxFit.contain,   // contain em vez de cover — preserva margens do ícone
    ),
  ),
),
const SizedBox(height: 20),

          const Text(
            'ERP & PDV STech',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: .3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Acesso ao sistema de gestão',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(.5),
              letterSpacing: .4,
            ),
          ),
        ],
      ),
    );
  }

  // ── card de formulário ───────────────────────
  Widget _buildCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildField(
            label:      'Credencial',
            hint:       'E-mail, telefone ou apelido',
            controller: _credencialCtrl,
            icon:       Icons.person_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            onSubmitted: (_) => _handleLogin(),
          ),
          const SizedBox(height: 16),
          _buildField(
            label:      'Senha',
            hint:       'Digite a sua senha',
            controller: _passwordCtrl,
            icon:       Icons.lock_outline_rounded,
            obscure:    _obscurePass,
            suffix: IconButton(
              icon: Icon(
                _obscurePass
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
                color: const Color(0xFF9CA3AF),
              ),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
            ),
            onSubmitted: (_) => _handleLogin(),
          ),
          if (_errorMessage.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildErrorBanner(),
          ],
          const SizedBox(height: 22),
          _buildLoginButton(),
        ],
      ),
    );
  }

  // ── campo de input ───────────────────────────
  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
    ValueChanged<String>? onSubmitted,
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
        TextField(
          controller:   controller,
          obscureText:  obscure,
          keyboardType: keyboardType,
          onSubmitted:  onSubmitted,
          style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
          decoration: InputDecoration(
            hintText:        hint,
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
            prefixIcon:      Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
            suffixIcon:      suffix,
            filled:          true,
            fillColor:       const Color(0xFFF8F9FB),
            contentPadding:  const EdgeInsets.symmetric(vertical: 14),
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
          ),
        ),
      ],
    );
  }

  // ── banner de erro ───────────────────────────
  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 16, color: Color(0xFFC8102E)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF991B1B),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── botão principal ──────────────────────────
  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: _navy,
          disabledBackgroundColor: _navy.withOpacity(.6),
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
                  Text(
                    'Entrar',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 17),
                ],
              ),
      ),
    );
  }
}

