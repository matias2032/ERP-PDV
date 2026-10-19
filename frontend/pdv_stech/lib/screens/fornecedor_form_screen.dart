// lib/screens/fornecedor_form_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';

// ─── Cores ───────────────────────────────────────────────────────────────────
// As antigas constantes (_kVermelho, _kAzul, _kBranco, _kCinzaClaro,
// _kCinzaTexto) foram substituídas pelo tema:
//   _kAzul       → context.cores.marca (texto/ícone/borda)
//                  context.cores.marcaBotao (fundo de snackbar/botão azul)
//                  AppColors.azulMarca / azulMarcaEscuro (AppBar)
//   _kVermelho   → AppColors.vermelhoMarca (fundo: botão, snackbar, ícone;
//                  texto branco por cima)
//                  context.cores.acentoTexto (vermelho como borda de erro)
//   _kBranco     → AppColors.branco (texto/ícone sobre azul/vermelho)
//                  context.cores.superficie (fundo dos campos)
//   _kCinzaClaro → context.cores.fundo
//   _kCinzaTexto → context.cores.textoSecundario
//   grey.shade200 (borda dos cards)  → context.cores.borda
//   grey.shade300 (borda dos campos) → claro: grey.shade300 (inalterado)
//                                      escuro: colorScheme.outline do tema

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

  /// Fundo colorido FIXO + texto branco explícito: sem isso, no tema escuro
  /// o texto herdaria `textoPrincipal` (claro) e perderia contraste.
  void _mostrarSnack(String mensagem, {bool erro = false}) {
    if (!mounted) return;

    final c = context.cores;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mensagem,
          style: const TextStyle(color: AppColors.branco),
        ),
        backgroundColor: erro
            ? AppColors.vermelhoMarca
            : (context.escuro ? c.marcaBotao : AppColors.azulMarca),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _houveAlteracoes);
        return false;
      },
      child: Scaffold(
        backgroundColor: c.fundo,
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
      // Mesmo critério da AppBar do tema escuro (azulMarcaEscuro).
      backgroundColor:
          context.escuro ? AppColors.azulMarcaEscuro : AppColors.azulMarca,
      foregroundColor: AppColors.branco,
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
              color: AppColors.vermelhoMarca,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.local_shipping_rounded,
              color: AppColors.branco,
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
    final c = context.cores;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.marca.withValues(alpha: context.escuro ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: c.marca.withValues(alpha: context.escuro ? 0.30 : 0.20),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: c.marca, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Cadastre fornecedores sem perfil. Apenas o telefone/contacto é obrigatório.',
              style: TextStyle(fontSize: 13, color: c.marca),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardIdentificacao() {
    final c = context.cores;

    return Card(
      elevation: 0,
      color: c.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.borda),
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
    final c = context.cores;

    return Card(
      elevation: 0,
      color: c.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.borda),
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
    final c = context.cores;

    return Row(
      children: [
        Icon(icon, color: c.marca, size: 20),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: c.marca,
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
    final c = context.cores;

    // Claro: mantém o cinza original. Escuro: usa o `outline` do tema
    // (contraste 3.7:1 sobre a superfície).
    final bordaCampo = context.escuro
        ? Theme.of(context).colorScheme.outline
        : Colors.grey.shade300;

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
          color: c.textoSecundario.withValues(alpha: 0.6),
          fontSize: 12,
        ),
        prefixIcon: Icon(icon, color: c.marca, size: 20),
        filled: true,
        fillColor: c.superficie,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: bordaCampo),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: bordaCampo),
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
                color: AppColors.branco,
              ),
            )
          : const Icon(Icons.save_rounded),
      label: Text(
        isEditMode ? 'SALVAR ALTERAÇÕES' : 'CADASTRAR FORNECEDOR',
        style: const TextStyle(fontSize: 16, letterSpacing: 0.5),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.vermelhoMarca,
        foregroundColor: AppColors.branco,
        disabledBackgroundColor:
            AppColors.vermelhoMarca.withValues(alpha: 0.5),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
    );
  }
}