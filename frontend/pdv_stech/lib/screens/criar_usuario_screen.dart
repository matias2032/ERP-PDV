// lib/screens/criar_usuario_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import '../theme/app_theme.dart';

// ─── Cores ───────────────────────────────────────────────────────────────────
// As antigas constantes (_kVermelho, _kAzul, _kBranco, _kCinzaClaro,
// _kCinzaTexto) e as cores Colors.grey.* foram substituídas pelo tema:
//   _kAzul       → context.cores.marca (texto/ícone/borda)
//                  context.cores.marcaBotao (fundo de botão/snackbar)
//                  AppColors.azulMarca / azulMarcaEscuro (AppBar)
//   _kVermelho   → AppColors.vermelhoMarca (fundo: ícone da AppBar, snackbar;
//                  texto branco por cima)
//                  context.cores.acentoTexto (vermelho como texto/ícone/borda)
//   _kBranco     → AppColors.branco (sobre azul/vermelho)
//   _kCinzaClaro → context.cores.fundo (fundo dos campos e da tela)
//   _kCinzaTexto → context.cores.textoSecundario
//   grey.shade200 (card/divisor)     → context.cores.borda
//   grey.shade300 (borda dos campos) → claro: grey.shade300 (inalterado)
//                                      escuro: colorScheme.outline do tema
//   aviso âmbar  → claro: cores originais | escuro: context.cores.aviso(+Fundo)

/// Borda dos campos/botões outlined. Claro: cinza original.
/// Escuro: `outline` do tema (contraste 3.7:1 sobre a superfície).
Color _bordaCampo(BuildContext context) => context.escuro
    ? Theme.of(context).colorScheme.outline
    : Colors.grey.shade300;

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

  /// Fundo colorido FIXO + texto branco explícito: sem isso, no tema escuro
  /// o texto herdaria `textoPrincipal` (claro) e perderia contraste.
  void _snack(String msg, {bool erro = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: AppColors.branco)),
        backgroundColor:
            erro ? AppColors.vermelhoMarca : context.cores.marcaBotao,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
      // Mesmo critério da AppBar do tema escuro (azulMarcaEscuro).
      backgroundColor:
          context.escuro ? AppColors.azulMarcaEscuro : AppColors.azulMarca,
      foregroundColor: AppColors.branco,
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
              color: AppColors.vermelhoMarca,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.person_add_alt_1_rounded,
                color: AppColors.branco, size: 20),
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
    final c = context.cores;

    return Card(
      elevation: 0,
      color: c.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.borda),
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
                  ? Center(
                      child: CircularProgressIndicator(color: c.marca))
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
                        foregroundColor: c.textoSecundario,
                        side: BorderSide(color: _bordaCampo(context)),
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
                                  color: AppColors.branco, strokeWidth: 2))
                          : const Icon(Icons.save_rounded, size: 20),
                      label: Text(
                        _salvando ? 'A guardar...' : 'Criar Usuário',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.marcaBotao,
                        foregroundColor: AppColors.branco,
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
    final c = context.cores;

    return Row(
      children: [
        Icon(icon, color: c.acentoTexto, size: 20),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: c.marca,
                letterSpacing: 0.4)),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: c.borda)),
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
    final c = context.cores;
    final borda = _bordaCampo(context);

    return TextFormField(
      controller: ctrl,
      keyboardType: tipo,
      validator: validator,
      style: TextStyle(fontSize: 14, color: c.marca),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(
          color: context.escuro
              ? c.textoSecundario.withValues(alpha: 0.7)
              : Colors.grey.shade400,
          fontSize: 13,
        ),
        labelStyle: TextStyle(color: c.textoSecundario, fontSize: 13),
        prefixIcon: Icon(icon, color: c.marca, size: 20),
        filled: true,
        fillColor: c.fundo,
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
    final c = context.cores;
    final borda = _bordaCampo(context);

    return DropdownButtonFormField<_PerfilOption>(
      value: selecionado,
      hint: Text('Seleccione um perfil',
          style: TextStyle(color: c.textoSecundario, fontSize: 13)),
      isExpanded: true,
      decoration: InputDecoration(
        prefixIcon:
            Icon(Icons.shield_outlined, color: c.marca, size: 20),
        filled: true,
        fillColor: c.fundo,
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      items: perfis
          .map((p) => DropdownMenuItem(
                value: p,
                child: Text(p.nome,
                    style: TextStyle(fontSize: 14, color: c.marca)),
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
    final c = context.cores;
    final escuro = context.escuro;

    // Claro: cores âmbar originais. Escuro: aviso do tema (contraste > 8:1).
    final corTexto = escuro ? c.aviso : const Color(0xFF92400E);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: escuro ? c.avisoFundo : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: escuro
              ? c.aviso.withValues(alpha: 0.5)
              : const Color(0xFFFFCC02),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded,
              color: escuro ? c.aviso : const Color(0xFFF59E0B), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Senha inicial automática',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: corTexto,
                      fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'A senha "12345678" será atribuída automaticamente. '
                  'O usuário será obrigado a alterá-la no primeiro login.',
                  style: TextStyle(
                      color: corTexto, fontSize: 12, height: 1.5),
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