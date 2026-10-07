// lib/features/cliente/screens/cliente_form_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:provider/provider.dart';

// ── Cores STech Engenharia ────────────────────────────────────────────────────
const _kVermelho   = Color(0xFFC8102E);
const _kAzul       = Color(0xFF1B2A6B);
const _kBranco     = Colors.white;
const _kCinzaClaro = Color(0xFFF4F5F7);
const _kCinzaTexto = Color(0xFF6B7280);

/// Perfil fixo que este formulário usa
const int    _kIdPerfilEmpresa   = 1;
const String _kNomePerfilEmpresa = 'Empresa';

// ─────────────────────────────────────────────────────────────────────────────

class ClienteFormScreen extends StatefulWidget {
  /// Quando não nulo, estamos em modo edição.
  final ClienteModel? cliente;

  const ClienteFormScreen({super.key, this.cliente});

  @override
  State<ClienteFormScreen> createState() => _ClienteFormScreenState();
}

class _ClienteFormScreenState extends State<ClienteFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // ── Controllers ───────────────────────────────────────────────────────────
  late final TextEditingController _nomeController;
  late final TextEditingController _apelidoController;
  late final TextEditingController _emailController;
  late final TextEditingController _nuitController;
  late final TextEditingController _contactoController;
  late final TextEditingController _moradaController;

  // ── Estado ────────────────────────────────────────────────────────────────
  bool get _isEditMode => widget.cliente != null;
  bool _houveAlteracoes = false;

  // ═══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    final c = widget.cliente;
    _nomeController     = TextEditingController(text: c?.nome      ?? '');
    _apelidoController  = TextEditingController(text: c?.apelido   ?? '');
    _emailController    = TextEditingController(text: c?.email     ?? '');
    _nuitController     = TextEditingController(text: c?.nuit      ?? '');
    _contactoController = TextEditingController(text: c?.contacto  ?? '');
    _moradaController   = TextEditingController(text: c?.morada    ?? '');
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _apelidoController.dispose();
    _emailController.dispose();
    _nuitController.dispose();
    _contactoController.dispose();
    _moradaController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SALVAR
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    final dto = ClienteRequestDTO(
      nome:      _nomeController.text.trim().isEmpty      ? null : _nomeController.text.trim(),
      apelido:   _apelidoController.text.trim().isEmpty   ? null : _apelidoController.text.trim(),
      email:     _emailController.text.trim().isEmpty     ? null : _emailController.text.trim(),
      nuit:      _nuitController.text.trim().isEmpty      ? null : _nuitController.text.trim(),
      contacto:  _contactoController.text.trim().isEmpty  ? null : _contactoController.text.trim(),
      morada:    _moradaController.text.trim().isEmpty    ? null : _moradaController.text.trim(),
      idPerfil:  _kIdPerfilEmpresa,
    );

    final formProvider = context.read<ClienteFormProvider>();

    if (_isEditMode) {
      await formProvider.editar(widget.cliente!.id, dto);
    } else {
      await formProvider.criar(dto);
    }

    if (!mounted) return;

    if (formProvider.sucesso) {
      // Atualiza a lista local sem novo request ao servidor
      final salvo = formProvider.salvo!;
      context.read<ClienteListaProvider>().upsertLocal(salvo);

      _mostrarSnack(
        _isEditMode
            ? '${salvo.nomeCompleto} actualizado com sucesso.'
            : '${salvo.nomeCompleto} cadastrado com sucesso.',
      );
      formProvider.resetar();
      _houveAlteracoes = true;
      Navigator.of(context).pop(true);
    } else if (formProvider.temErro) {
      _mostrarSnack(formProvider.erro ?? 'Erro ao salvar.', erro: true);
      formProvider.resetar();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _mostrarSnack(String mensagem, {bool erro = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: erro ? _kVermelho : _kAzul,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _houveAlteracoes);
        return false;
      },
      child: Scaffold(
        backgroundColor: _kCinzaClaro,
        appBar: _buildAppBar(),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Cabeçalho informativo ─────────────────────────────────
                _BannerPerfil(),
                const SizedBox(height: 16),

                // ── Dados de identificação ────────────────────────────────
                _buildCardIdentificacao(),
                const SizedBox(height: 16),

                // ── Dados de contacto ─────────────────────────────────────
                _buildCardContacto(),
                const SizedBox(height: 24),

                // ── Botão salvar ──────────────────────────────────────────
                _BotaoSalvar(
                  isEditMode: _isEditMode,
                  onPressed: _salvar,
                ),
                const SizedBox(height: 16),
              ],
            ),
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
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.pop(context, _houveAlteracoes),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _kVermelho,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.business_rounded,
                color: _kBranco, size: 20),
          ),
          const SizedBox(width: 10),
          Text(
            _isEditMode ? 'Editar Empresa' : 'Nova Empresa',
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }

  // ─── Banner de perfil fixo ─────────────────────────────────────────────────

  Widget _BannerPerfil() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _kAzul.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kAzul.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: _kAzul, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                    fontSize: 13, color: _kAzul),
                children: [
                  const TextSpan(text: 'Este formulário cadastra clientes com perfil '),
                  TextSpan(
                    text: _kNomePerfilEmpresa,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: ' (ID $_kIdPerfilEmpresa) automaticamente.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Card: Identificação ──────────────────────────────────────────────────

  Widget _buildCardIdentificacao() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TituloSecao(
              icon: Icons.apartment_rounded,
              label: 'Identificação da Empresa',
            ),
            const SizedBox(height: 16),

            // Nome + Apelido / Razão social
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Campo(
                    controller: _nomeController,
                    label: 'Nome / Razão Social *',
                    hint: 'Ex.: Acme Lda',
                    icon: Icons.business_outlined,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Campo obrigatório'
                            : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Campo(
                    controller: _apelidoController,
                    label: 'Apelido / Nome Comercial',
                    hint: 'Ex.: Acme',
                    icon: Icons.label_outline_rounded,
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // NUIT
            _Campo(
              controller: _nuitController,
              label: 'NUIT',
              hint: 'Ex.: 400123456',
              icon: Icons.badge_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
              ],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                if (v.trim().length != 9) return 'NUIT deve ter 9 dígitos';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── Card: Contacto ───────────────────────────────────────────────────────

  Widget _buildCardContacto() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TituloSecao(
              icon: Icons.contact_phone_rounded,
              label: 'Dados de Contacto',
            ),
            const SizedBox(height: 16),

            // Email
            _Campo(
              controller: _emailController,
              label: 'Email',
              hint: 'geral@empresa.co.mz',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                    .hasMatch(v.trim());
                return valid ? null : 'Email inválido';
              },
            ),
            const SizedBox(height: 14),

            // Contacto (telefone)
            _Campo(
              controller: _contactoController,
              label: 'Telefone / Contacto',
              hint: 'Ex.: +258 84 000 0000',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),

            // Morada
            _Campo(
              controller: _moradaController,
              label: 'Morada / Endereço',
              hint: 'Ex.: Av. Eduardo Mondlane, 123 — Maputo',
              icon: Icons.location_on_outlined,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Widgets auxiliares do formulário
// ─────────────────────────────────────────────────────────────────────────────

class _TituloSecao extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TituloSecao({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _kAzul, size: 20),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _kAzul)),
      ],
    );
  }
}

class _Campo extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;
  final int maxLines;

  const _Campo({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    // Lê o provider para desabilitar durante salvamento
    final salvando =
        context.watch<ClienteFormProvider>().salvando;

    return TextFormField(
      controller: controller,
      enabled: !salvando,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(
            color: _kCinzaTexto.withOpacity(0.6), fontSize: 12),
        prefixIcon: Icon(icon, color: _kAzul, size: 20),
        filled: true,
        fillColor: _kBranco,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
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
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kVermelho, width: 1.5),
        ),
      ),
    );
  }
}

class _BotaoSalvar extends StatelessWidget {
  final bool isEditMode;
  final VoidCallback onPressed;

  const _BotaoSalvar({
    required this.isEditMode,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final salvando = context.watch<ClienteFormProvider>().salvando;

    return ElevatedButton.icon(
      onPressed: salvando ? null : onPressed,
      icon: salvando
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: _kBranco),
            )
          : const Icon(Icons.save_rounded),
      label: Text(
        isEditMode ? 'SALVAR ALTERAÇÕES' : 'CADASTRAR EMPRESA',
        style: const TextStyle(fontSize: 16, letterSpacing: 0.5),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _kVermelho,
        foregroundColor: _kBranco,
        disabledBackgroundColor: _kVermelho.withOpacity(0.5),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );
  }
}