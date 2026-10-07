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

class FornecedorFormScreen extends StatefulWidget {
  final FornecedorModel? fornecedor;

  const FornecedorFormScreen({
    super.key,
    this.fornecedor,
  });

  @override
  State<FornecedorFormScreen> createState() => _FornecedorFormScreenState();
}

class _FornecedorFormScreenState extends State<FornecedorFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nomeController;
  late final TextEditingController _emailController;
  late final TextEditingController _nuitController;
  late final TextEditingController _contactoController;
  late final TextEditingController _moradaController;

  bool get _isEditMode => widget.fornecedor != null;
  bool _houveAlteracoes = false;

  @override
  void initState() {
    super.initState();

    final f = widget.fornecedor;

    _nomeController     = TextEditingController(text: f?.nome ?? '');
    _emailController    = TextEditingController(text: f?.email ?? '');
    _nuitController     = TextEditingController(text: f?.nuit ?? '');
    _contactoController = TextEditingController(text: f?.contacto ?? '');
    _moradaController   = TextEditingController(text: f?.morada ?? '');
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _nuitController.dispose();
    _contactoController.dispose();
    _moradaController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    final fornecedor = FornecedorModel(
      id: widget.fornecedor?.id,
      nome: _emptyToNull(_nomeController.text),
      email: _emptyToNull(_emailController.text),
      nuit: _emptyToNull(_nuitController.text),
      contacto: _contactoController.text.trim(),
      morada: _emptyToNull(_moradaController.text),
    );

    final provider = context.read<FornecedorProvider>();

    final sucesso = _isEditMode
        ? await provider.editarFornecedor(
            id: widget.fornecedor!.id!,
            fornecedor: fornecedor,
          )
        : await provider.criarFornecedor(fornecedor);

    if (!mounted) return;

    if (sucesso) {
      _houveAlteracoes = true;

      _mostrarSnack(
        _isEditMode
            ? 'Fornecedor actualizado com sucesso.'
            : 'Fornecedor cadastrado com sucesso.',
      );

      Navigator.of(context).pop(true);
    } else {
      _mostrarSnack(
        provider.erro ?? 'Erro ao salvar fornecedor.',
        erro: true,
      );
      provider.limparErro();
    }
  }

  String? _emptyToNull(String value) {
    final texto = value.trim();
    if (texto.isEmpty) return null;
    return texto;
  }

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
                _BannerFornecedor(),
                const SizedBox(height: 16),
                _buildCardIdentificacao(),
                const SizedBox(height: 16),
                _buildCardContacto(),
                const SizedBox(height: 24),
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
            child: const Icon(
              Icons.local_shipping_rounded,
              color: _kBranco,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _isEditMode ? 'Editar Fornecedor' : 'Novo Fornecedor',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _BannerFornecedor() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _kAzul.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kAzul.withOpacity(0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: _kAzul, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Cadastre fornecedores sem perfil. Apenas o telefone/contacto é obrigatório.',
              style: TextStyle(fontSize: 13, color: _kAzul),
            ),
          ),
        ],
      ),
    );
  }

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
            const _TituloSecao(
              icon: Icons.apartment_rounded,
              label: 'Identificação do Fornecedor',
            ),
            const SizedBox(height: 16),

            _Campo(
              controller: _nomeController,
              label: 'Nome / Razão Social',
              hint: 'Ex.: Fornecedor ABC Lda',
              icon: Icons.business_outlined,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),

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
            const _TituloSecao(
              icon: Icons.contact_phone_rounded,
              label: 'Dados de Contacto',
            ),
            const SizedBox(height: 16),

            _Campo(
              controller: _contactoController,
              label: 'Telefone / Contacto *',
              hint: 'Ex.: +258 84 000 0000',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Contacto é obrigatório';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            _Campo(
              controller: _emailController,
              label: 'Email',
              hint: 'fornecedor@empresa.co.mz',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;

                final valido = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                    .hasMatch(v.trim());

                return valido ? null : 'Email inválido';
              },
            ),
            const SizedBox(height: 14),

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
//  Widgets auxiliares
// ─────────────────────────────────────────────────────────────────────────────

class _TituloSecao extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TituloSecao({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _kAzul, size: 20),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _kAzul,
          ),
        ),
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
    final salvando = context.watch<FornecedorProvider>().salvando;

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
          color: _kCinzaTexto.withOpacity(0.6),
          fontSize: 12,
        ),
        prefixIcon: Icon(icon, color: _kAzul, size: 20),
        filled: true,
        fillColor: _kBranco,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 12,
        ),
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
    final salvando = context.watch<FornecedorProvider>().salvando;

    return ElevatedButton.icon(
      onPressed: salvando ? null : onPressed,
      icon: salvando
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _kBranco,
              ),
            )
          : const Icon(Icons.save_rounded),
      label: Text(
        isEditMode ? 'SALVAR ALTERAÇÕES' : 'CADASTRAR FORNECEDOR',
        style: const TextStyle(fontSize: 16, letterSpacing: 0.5),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _kVermelho,
        foregroundColor: _kBranco,
        disabledBackgroundColor: _kVermelho.withOpacity(0.5),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
    );
  }
}