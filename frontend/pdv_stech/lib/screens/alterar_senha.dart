// lib/screens/alterar_senha_screen.dart

import 'package:flutter/material.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';

// ─── Cores ───────────────────────────────────────────────────────────────────
// As antigas constantes (_kPrimary, _kAccent, _kBackground, _kCardBg — nenhuma
// delas era usada) e as cores hardcoded (Color.fromARGB, Colors.grey/blue/red/
// green.*) foram substituídas pelo tema:
//   azul 1B2A6B  → context.cores.marcaBotao (fundo de botão)
//                  AppColors.azulMarca / azulMarcaEscuro (AppBar e header)
//   vermelho     → AppColors.vermelhoMarca (fundo de snackbar de erro)
//                  context.cores.acentoTexto (texto/ícone do erro)
//   Colors.red   → AppColors.vermelhoMarca (snackbar)
//   Colors.green → verde fixo 0xFF2E7D32 (snackbar; texto branco por cima)
//   blue.*       → context.cores.infoFundo / info
//   red.shade50  → context.cores.perigoFundo
//   grey[50]     → context.cores.superficieAlt (campos e card de requisitos)
//   grey[300]    → context.cores.borda
//   grey[600/700]→ context.cores.textoSecundario
//
// O HEADER (azul) é escuro nos dois temas, por isso o seu conteúdo (ícone e
// textos brancos) permanece fixo.

class AlterarSenhaScreen extends StatefulWidget {
  const AlterarSenhaScreen({super.key});

  @override
  State<AlterarSenhaScreen> createState() => _AlterarSenhaScreenState();
}

class _AlterarSenhaScreenState extends State<AlterarSenhaScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _senhaAtualController = TextEditingController();
  final TextEditingController _novaSenhaController = TextEditingController();
  final TextEditingController _confirmacaoSenhaController =
      TextEditingController();

  bool _obscureSenhaAtual = true;
  bool _obscureNovaSenha = true;
  bool _obscureConfirmacao = true;





  @override
  void dispose() {
    _senhaAtualController.dispose();
    _novaSenhaController.dispose();
    _confirmacaoSenhaController.dispose();
    super.dispose();
  }

Future<void> _alterarSenha() async {

  if (!_formKey.currentState!.validate()) return;

  // Fundo colorido FIXO + texto branco explícito: sem isso, no tema escuro
  // o texto herdaria `textoPrincipal` (claro) e perderia contraste.
  if (_novaSenhaController.text != _confirmacaoSenhaController.text) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'A nova senha e a confirmação não coincidem.',
          style: TextStyle(color: AppColors.branco),
        ),
        backgroundColor: AppColors.vermelhoMarca,
      ),
    );
    return;
  }

  final usuario = SessaoService.instance.usuarioAtual;
  if (usuario == null) return;

  final dto = AlterarSenhaDTO(
    senhaAtual: _senhaAtualController.text,
    novaSenha:  _novaSenhaController.text,
  );

  try {
    await context.read<UsuarioProvider>().alterarSenha(usuario.id, dto);
  } catch (_) {}

  if (!mounted) return;

  final provider = context.read<UsuarioProvider>();
  if (provider.erro == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Senha alterada com sucesso! Você será deslogado.',
          style: TextStyle(color: AppColors.branco),
        ),
        backgroundColor: Color(0xFF2E7D32),
        duration: Duration(seconds: 2),
      ),
    );
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      SessaoService.instance.limparSessao();
      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
    }
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          provider.erro!,
          style: const TextStyle(color: AppColors.branco),
        ),
        backgroundColor: AppColors.vermelhoMarca,
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final escuro = context.escuro;
    final provider = context.watch<UsuarioProvider>();
    final isLoading = provider.carregando;

    // Mesmo critério da AppBar do tema escuro (azulMarcaEscuro).
    final corTopo = escuro ? AppColors.azulMarcaEscuro : AppColors.azulMarca;

    return Scaffold(
      backgroundColor: c.fundo,
      appBar: AppBar(
        title: const Text('Alterar Senha'),
        backgroundColor: corTopo,
        foregroundColor: AppColors.branco,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header decorativo
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: corTopo,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              padding: const EdgeInsets.only(bottom: 40, top: 20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_reset,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Segurança da Conta',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mantenha sua senha sempre segura',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Formulário
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Info card
                    Card(
                      elevation: 0,
                      color: c.infoFundo,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: c.info),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Para sua segurança, você não poderá usar senhas anteriormente utilizadas.',
                                style: TextStyle(
                                  color: escuro
                                      ? c.info
                                      : Colors.blue.shade900,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Mensagem de erro
                    if (provider.erro != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: c.perigoFundo,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: escuro
                                ? c.perigo.withValues(alpha: 0.4)
                                : Colors.red.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: escuro
                                    ? c.acentoTexto
                                    : const Color.fromARGB(255, 20, 32, 82)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                provider.erro!,
                                style: TextStyle(
                                  color: c.acentoTexto,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Senha Atual
                    Text(
                      'Senha Atual',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: c.textoSecundario),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _senhaAtualController,
                      obscureText: _obscureSenhaAtual,
                      decoration: InputDecoration(
                        hintText: 'Digite sua senha atual',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureSenhaAtual
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setState(
                              () => _obscureSenhaAtual = !_obscureSenhaAtual),
                        ),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: c.superficieAlt,
                      ),
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Por favor, insira a senha atual.'
                          : null,
                    ),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(child: Divider(color: c.borda)),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          child: Text('Nova Senha',
                              style: TextStyle(
                                  color: c.textoSecundario,
                                  fontWeight: FontWeight.w500)),
                        ),
                        Expanded(child: Divider(color: c.borda)),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Nova Senha
                    Text(
                      'Nova Senha',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: c.textoSecundario),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _novaSenhaController,
                      obscureText: _obscureNovaSenha,
                      decoration: InputDecoration(
                        hintText: 'Digite a nova senha',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureNovaSenha
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setState(
                              () => _obscureNovaSenha = !_obscureNovaSenha),
                        ),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: c.superficieAlt,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, insira a nova senha.';
                        }
                        if (value.length < 6) {
                          return 'A senha deve ter pelo menos 6 caracteres.';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Confirmação
                    Text(
                      'Confirmar Nova Senha',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: c.textoSecundario),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _confirmacaoSenhaController,
                      obscureText: _obscureConfirmacao,
                      decoration: InputDecoration(
                        hintText: 'Confirme a nova senha',
                        prefixIcon: const Icon(Icons.lock_clock),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirmacao
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setState(
                              () => _obscureConfirmacao = !_obscureConfirmacao),
                        ),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: c.superficieAlt,
                      ),
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Por favor, confirme a nova senha.'
                          : null,
                    ),

                    const SizedBox(height: 30),

                    // Requisitos
                    Card(
                      elevation: 0,
                      color: c.superficieAlt,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: c.borda),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Requisitos da Senha:',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: c.textoSecundario),
                            ),
                            const SizedBox(height: 12),
                            _buildRequirement('Mínimo de 6 caracteres'),
                            _buildRequirement(
                                'Diferente de senhas anteriores'),
                            _buildRequirement(
                                'Nova senha e confirmação devem ser iguais'),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    ElevatedButton(
                      onPressed: isLoading ? null : _alterarSenha,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: c.marcaBotao,
                        foregroundColor: AppColors.branco,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'ALTERAR SENHA',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                    ),

                    const SizedBox(height: 16),

                    TextButton(
                      onPressed:
                          isLoading ? null : () => Navigator.of(context).pop(),
                      child: Text('Cancelar',
                          style: TextStyle(
                              fontSize: 16, color: c.textoSecundario)),
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

  Widget _buildRequirement(String text) {
    final c = context.cores;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, size: 18, color: c.textoSecundario),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 13, color: c.textoSecundario)),
          ),
        ],
      ),
    );
  }
}