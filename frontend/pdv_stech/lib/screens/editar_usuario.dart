// lib/screens/editar_usuario_screen.dart

import 'package:flutter/material.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';

// ─── Cores ───────────────────────────────────────────────────────────────────
// As antigas constantes (_kPrimary, _kAccent, _kBackground, _kCardBg) e as
// cores Colors.grey/green/red/black87 foram substituídas pelo tema:
//   _kPrimary    → context.cores.marca (texto/ícone)
//                  context.cores.marcaBotao (fundo de botão)
//                  AppColors.azulMarca / azulMarcaEscuro (AppBar e header)
//   _kAccent     → AppColors.vermelhoMarca (fundo de snackbar de erro)
//                  (não era usada no ficheiro original)
//   _kBackground → context.cores.fundo
//   _kCardBg     → context.cores.superficie
//   grey[600]    → context.cores.textoSecundario
//   grey[100]    → claro: grey[100] (inalterado) | escuro: context.cores.fundo
//   black87      → context.cores.textoPrincipal
//   green / red  → context.cores.sucesso / perigo
//
// O HEADER (azul) é escuro nos dois temas, por isso o seu conteúdo (texto
// branco, avatar, badge) permanece fixo.

class EditarUsuarioScreen extends StatefulWidget {
  const EditarUsuarioScreen({super.key});

  @override
  State<EditarUsuarioScreen> createState() => _EditarUsuarioScreenState();
}

class _EditarUsuarioScreenState extends State<EditarUsuarioScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nomeController     = TextEditingController();
  final TextEditingController _apelidoController  = TextEditingController();
  final TextEditingController _emailController    = TextEditingController();
  final TextEditingController _telefoneController = TextEditingController();

  bool _isModoEdicao   = false;
  bool _controllersPreenchidos = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UsuarioProvider>().carregarUsuarios();
    });
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _apelidoController.dispose();
    _emailController.dispose();
    _telefoneController.dispose();
    super.dispose();
  }

  void _preencherControllers(UsuarioModel u) {
    _nomeController.text     = u.nome;
    _apelidoController.text  = u.apelido ?? '';
    _emailController.text    = u.email;
    _telefoneController.text = u.telefone ?? '';
    _controllersPreenchidos  = true;
  }

  Future<void> _salvarAlteracoes(UsuarioModel usuario) async {
    if (!_formKey.currentState!.validate()) return;

    final dto = UsuarioRequestDTO(
      nome:     usuario.nome,
      apelido:  usuario.apelido,
      email:    _emailController.text.trim(),
      telefone: _telefoneController.text.trim().isNotEmpty
          ? _telefoneController.text.trim()
          : null,
      idPerfil: usuario.idPerfil,
    );

    try {
      await context.read<UsuarioProvider>().atualizarUsuario(usuario.id, dto);
    } catch (_) {}

    if (!mounted) return;

    final provider = context.read<UsuarioProvider>();
    if (provider.erro == null) {
      // Fundo colorido FIXO + texto branco explícito: sem isso, no tema
      // escuro o texto herdaria `textoPrincipal` (claro) e perderia contraste.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Dados atualizados com sucesso! Você será deslogado.',
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
            'Erro ao atualizar dados: ${provider.erro}',
            style: const TextStyle(color: AppColors.branco),
          ),
          backgroundColor: AppColors.vermelhoMarca,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c         = context.cores;
    final escuro    = context.escuro;
    final provider  = context.watch<UsuarioProvider>();
    final sessaoId  = SessaoService.instance.usuarioAtual?.id;
    final usuario   = provider.usuarios
        .where((u) => u.id == sessaoId)
        .firstOrNull;

    // Preenche os controllers uma única vez quando o utilizador fica disponível
    if (usuario != null && !_controllersPreenchidos) {
      _preencherControllers(usuario);
    }

    final isLoading = provider.carregando;
    final isSaving  = provider.carregando;

    // Mesmo critério da AppBar do tema escuro (azulMarcaEscuro).
    final corTopo = escuro ? AppColors.azulMarcaEscuro : AppColors.azulMarca;

    // Fundo dos campos desabilitados / somente leitura.
    final fundoSomenteLeitura = escuro ? c.fundo : Colors.grey[100];

    // Texto dos campos desabilitados: no escuro, o padrão (onSurface a 38%)
    // fica pouco legível; usa textoSecundario.
    final estiloDesabilitado = (!_isModoEdicao && escuro)
        ? TextStyle(color: c.textoSecundario)
        : null;

    return Scaffold(
      backgroundColor: c.fundo,
      appBar: AppBar(
        title: const Text('Meus Dados'),
        backgroundColor: corTopo,
        foregroundColor: AppColors.branco,
        elevation: 0,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: c.marca))
          : SingleChildScrollView(
              child: Column(
                children: [
                  // ── Header com avatar ──────────────────────────────
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: corTopo,
                      borderRadius: const BorderRadius.only(
                        bottomLeft:  Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                    ),
                    padding: const EdgeInsets.only(bottom: 30),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: escuro ? c.superficieAlt : AppColors.branco,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color:      Colors.black.withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset:     const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor:
                                const Color.fromARGB(255, 174, 189, 255),
                            child: Text(
                              usuario?.nome.substring(0, 1).toUpperCase() ?? 'U',
                              style: const TextStyle(
                                fontSize:   40,
                                fontWeight: FontWeight.bold,
                                color:      AppColors.azulMarca,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${usuario?.nome ?? ''} ${usuario?.apelido ?? ''}',
                          style: const TextStyle(
                            color:      AppColors.branco,
                            fontSize:   24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color:        AppColors.branco.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            usuario?.nomePerfil ?? 'Usuário',
                            style: const TextStyle(
                              color:      AppColors.branco,
                              fontSize:   14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Formulário ─────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Informações Básicas (read-only)
                          _buildInfoCard(
                            title: 'Informações Básicas',
                            icon:  Icons.person_outline,
                            children: [
                              _buildReadOnlyField(
                                label: 'Nome',
                                value: usuario?.nome ?? '',
                                icon:  Icons.person,
                              ),
                              const SizedBox(height: 16),
                              _buildReadOnlyField(
                                label: 'Apelido',
                                value: usuario?.apelido ?? '',
                                icon:  Icons.badge,
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Informações de Contato (editável)
                          _buildInfoCard(
                            title: 'Informações de Contato',
                            icon:  Icons.contact_phone,
                            children: [
                              TextFormField(
                                controller: _emailController,
                                enabled:    _isModoEdicao,
                                style:      estiloDesabilitado,
                                decoration: InputDecoration(
                                  labelText:  'Email',
                                  prefixIcon: const Icon(Icons.email),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled:    true,
                                  fillColor: _isModoEdicao
                                      ? c.superficie
                                      : fundoSomenteLeitura,
                                ),
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Por favor, insira o email.';
                                  }
                                  if (!value.contains('@')) {
                                    return 'Insira um email válido.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _telefoneController,
                                enabled:    _isModoEdicao,
                                style:      estiloDesabilitado,
                                decoration: InputDecoration(
                                  labelText:  'Telefone',
                                  prefixIcon: const Icon(Icons.phone),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled:    true,
                                  fillColor: _isModoEdicao
                                      ? c.superficie
                                      : fundoSomenteLeitura,
                                ),
                                keyboardType: TextInputType.phone,
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Informações da Conta (read-only)
                          _buildInfoCard(
                            title: 'Informações da Conta',
                            icon:  Icons.info_outline,
                            children: [
                              _buildReadOnlyField(
                                label: 'Data de Cadastro',
                                value: _formatarData(usuario?.criadoEm),
                                icon:  Icons.calendar_today,
                              ),
                              const SizedBox(height: 16),
                              _buildReadOnlyField(
                                label:      'Status',
                                value:      (usuario?.ativo ?? false) ? 'Ativo' : 'Inativo',
                                icon:       Icons.check_circle,
                                valueColor: (usuario?.ativo ?? false)
                                    ? c.sucesso
                                    : c.perigo,
                              ),
                            ],
                          ),

                          const SizedBox(height: 30),

                          // ── Botões ───────────────────────────────
                          if (_isModoEdicao) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: isSaving
                                        ? null
                                        : () {
                                            setState(() {
                                              _isModoEdicao = false;
                                              _emailController.text =
                                                  usuario?.email ?? '';
                                              _telefoneController.text =
                                                  usuario?.telefone ?? '';
                                            });
                                          },
                                    icon:  Icon(Icons.close,
                                        color: c.textoSecundario),
                                    label: Text('Cancelar',
                                        style: TextStyle(
                                            fontSize: 16,
                                            color:    c.textoSecundario)),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      side:  BorderSide(color: c.textoSecundario),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: isSaving || usuario == null
                                        ? null
                                        : () => _salvarAlteracoes(usuario),
                                    icon: isSaving
                                        ? const SizedBox(
                                            height: 20,
                                            width:  20,
                                            child:  CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color:       AppColors.branco,
                                            ),
                                          )
                                        : const Icon(Icons.save,
                                            color: AppColors.branco),
                                    label: Text(
                                      isSaving ? 'Salvando...' : 'Salvar Alterações',
                                      style: const TextStyle(
                                        fontSize:   16,
                                        fontWeight: FontWeight.bold,
                                        color:      AppColors.branco,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      backgroundColor: c.marcaBotao,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            Container(
                              decoration: BoxDecoration(
                                color:        c.marcaBotao,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color:      c.marcaBotao.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset:     const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    setState(() => _isModoEdicao = true),
                                icon: const Icon(Icons.edit,
                                    color: AppColors.branco, size: 24),
                                label: const Text(
                                  'Editar Meus Dados',
                                  style: TextStyle(
                                    fontSize:      18,
                                    fontWeight:    FontWeight.bold,
                                    color:         AppColors.branco,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 18),
                                  backgroundColor: Colors.transparent,
                                  shadowColor:     Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ── Helpers de UI ────────────────────────────────────────────────

  Widget _buildInfoCard({
    required String       title,
    required IconData     icon,
    required List<Widget> children,
  }) {
    final c = context.cores;

    return Card(
      elevation: 2,
      color: c.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        // No escuro a sombra não é visível: a borda separa o card do fundo.
        side: BorderSide(
          color: context.escuro ? c.borda : Colors.transparent,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: c.marca, size: 24),
                const SizedBox(width: 12),
                Text(title,
                    style: TextStyle(
                        fontSize:   18,
                        fontWeight: FontWeight.bold,
                        color:      c.marca)),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
    Color? valueColor,
  }) {
    final c = context.cores;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: c.textoSecundario),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize:   14,
                    color:      c.textoSecundario,
                    fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width:   double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:        context.escuro ? c.fundo : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(value,
              style: TextStyle(
                  fontSize:   16,
                  color:      valueColor ?? c.textoPrincipal,
                  fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  String _formatarData(DateTime? data) {
    if (data == null) return '';
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/'
        '${data.year}';
  }
}