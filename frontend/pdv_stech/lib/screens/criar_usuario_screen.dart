// lib/screens/criar_usuario_screen.dart

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

class CriarUsuarioScreen extends StatefulWidget {
  const CriarUsuarioScreen({super.key});

  @override
  State<CriarUsuarioScreen> createState() => _CriarUsuarioScreenState();
}

class _CriarUsuarioScreenState extends State<CriarUsuarioScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _nomeCtrl       = TextEditingController();
  final _apelidoCtrl    = TextEditingController();
  final _emailCtrl      = TextEditingController();
  final _telefoneCtrl   = TextEditingController();

  // Perfis disponíveis — carregados da API
  List<_PerfilOption> _perfis      = [];
  _PerfilOption?      _perfilSelecionado;
  bool                _carregandoPerfis = true;
  bool                _salvando         = false;

  @override
  void initState() {
    super.initState();
    _carregarPerfis();
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _apelidoCtrl.dispose();
    _emailCtrl.dispose();
    _telefoneCtrl.dispose();
    super.dispose();
  }

  // ── Carrega perfis da API ─────────────────────────────────────────────────

  Future<void> _carregarPerfis() async {
    try {
      final uri = Uri.parse(ApiConfig.perfisUrl);
      final http  = context.read<UsuarioProvider>();
      // Usa o service directamente para não poluir o provider de usuários
      final response = await Future.value(<_PerfilOption>[
        // fallback enquanto não há PerfilService: lista estática
            const _PerfilOption(id: 2, nome: 'Gerente'),
        const _PerfilOption(id: 3, nome: 'Funcionário'),
      ]);
      if (mounted) {
        setState(() {
          _perfis           = response;
          _carregandoPerfis = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _carregandoPerfis = false);
    }
  }

  // ── Submissão ─────────────────────────────────────────────────────────────

Future<void> _salvar() async {
  if (!_formKey.currentState!.validate()) return;
  if (_perfilSelecionado == null) {
    _snack('Seleccione um perfil.', erro: true);
    return;
  }

  setState(() => _salvando = true);

  try {
    final dto = UsuarioRequestDTO(
      nome:      _nomeCtrl.text.trim(),
      apelido:   _apelidoCtrl.text.trim().isEmpty ? null : _apelidoCtrl.text.trim(),
      email:     _emailCtrl.text.trim(),
      telefone:  _telefoneCtrl.text.trim().isEmpty ? null : _telefoneCtrl.text.trim(),
      idPerfil:  _perfilSelecionado!.id,
    );

    await context.read<UsuarioProvider>().criarUsuario(dto);

    if (mounted) {
      _snack('Usuário criado! Senha inicial: 12345678');
      Navigator.of(context).pop(true);
    }
  } catch (e) {
    if (mounted) _snack('Erro: $e', erro: true);
  } finally {
    if (mounted) setState(() => _salvando = false);
  }
}

  void _snack(String msg, {bool erro = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: erro ? _kVermelho : _kAzul,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kCinzaClaro,
      appBar: _buildAppBar(),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: _buildFormCard(),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _kAzul,
      foregroundColor: _kBranco,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _kVermelho,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.person_add_alt_1_rounded,
                color: _kBranco, size: 20),
          ),
          const SizedBox(width: 10),
          const Text(
            'Novo Usuário',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Cabeçalho do card ───────────────────────────────
              _SectionHeader(
                icon: Icons.badge_rounded,
                label: 'Dados Pessoais',
              ),
              const SizedBox(height: 20),

              // Nome
              _Campo(
                ctrl: _nomeCtrl,
                label: 'Nome completo',
                hint: 'Ex: João Manuel',
                icon: Icons.person_outline_rounded,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'O nome é obrigatório'
                    : null,
              ),
              const SizedBox(height: 16),

              // Apelido
              _Campo(
                ctrl: _apelidoCtrl,
                label: 'Apelido (opcional)',
                hint: 'Ex: JM',
                icon: Icons.short_text_rounded,
              ),
              const SizedBox(height: 16),

              // Email
              _Campo(
                ctrl: _emailCtrl,
                label: 'E-mail',
                hint: 'exemplo@stech.co.mz',
                icon: Icons.email_outlined,
                tipo: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'O e-mail é obrigatório';
                  if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$').hasMatch(v.trim())) {
                    return 'E-mail inválido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Telefone
              _Campo(
                ctrl: _telefoneCtrl,
                label: 'Telefone (opcional)',
                hint: '+258 8x xxx xxxx',
                icon: Icons.phone_outlined,
                tipo: TextInputType.phone,
              ),
              const SizedBox(height: 24),

              // ── Perfil ──────────────────────────────────────────
              _SectionHeader(
                icon: Icons.shield_outlined,
                label: 'Perfil de Acesso',
              ),
              const SizedBox(height: 16),

              _carregandoPerfis
                  ? const Center(
                      child: CircularProgressIndicator(color: _kAzul))
                  : _DropdownPerfil(
                      perfis: _perfis,
                      selecionado: _perfilSelecionado,
                      onChanged: (p) =>
                          setState(() => _perfilSelecionado = p),
                    ),

              const SizedBox(height: 24),

              // ── Aviso senha padrão ──────────────────────────────
              _AvisoSenhaPadrao(),

              const SizedBox(height: 28),

              // ── Botões ──────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _salvando
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kCinzaTexto,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancelar',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _salvando ? null : _salvar,
                      icon: _salvando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: _kBranco, strokeWidth: 2))
                          : const Icon(Icons.save_rounded, size: 20),
                      label: Text(
                        _salvando ? 'A guardar...' : 'Criar Usuário',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kAzul,
                        foregroundColor: _kBranco,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
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
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _kVermelho, size: 20),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _kAzul,
                letterSpacing: 0.4)),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: Colors.grey.shade200)),
      ],
    );
  }
}

class _Campo extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType tipo;
  final String? Function(String?)? validator;

  const _Campo({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.icon,
    this.tipo = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      keyboardType: tipo,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: _kAzul),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        labelStyle: const TextStyle(color: _kCinzaTexto, fontSize: 13),
        prefixIcon: Icon(icon, color: _kAzul, size: 20),
        filled: true,
        fillColor: _kCinzaClaro,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kAzul, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kVermelho),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

class _DropdownPerfil extends StatelessWidget {
  final List<_PerfilOption> perfis;
  final _PerfilOption? selecionado;
  final ValueChanged<_PerfilOption?> onChanged;

  const _DropdownPerfil({
    required this.perfis,
    required this.selecionado,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<_PerfilOption>(
      value: selecionado,
      hint: const Text('Seleccione um perfil',
          style: TextStyle(color: _kCinzaTexto, fontSize: 13)),
      isExpanded: true,
      decoration: InputDecoration(
        prefixIcon:
            const Icon(Icons.shield_outlined, color: _kAzul, size: 20),
        filled: true,
        fillColor: _kCinzaClaro,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kAzul, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      items: perfis
          .map((p) => DropdownMenuItem(
                value: p,
                child: Text(p.nome,
                    style:
                        const TextStyle(fontSize: 14, color: _kAzul)),
              ))
          .toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? 'Seleccione um perfil' : null,
    );
  }
}

class _AvisoSenhaPadrao extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFCC02)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline_rounded,
              color: Color(0xFFF59E0B), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Senha inicial automática',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF92400E),
                      fontSize: 13),
                ),
                SizedBox(height: 4),
                Text(
                  'A senha "12345678" será atribuída automaticamente. '
                  'O usuário será obrigado a alterá-la no primeiro login.',
                  style: TextStyle(
                      color: Color(0xFF92400E), fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Modelo auxiliar de perfil (até PerfilService existir)
// ─────────────────────────────────────────────────────────────────────────────

class _PerfilOption {
  final int id;
  final String nome;
  const _PerfilOption({required this.id, required this.nome});

  @override
  bool operator ==(Object other) =>
      other is _PerfilOption && other.id == id;

  @override
  int get hashCode => id.hashCode;
}