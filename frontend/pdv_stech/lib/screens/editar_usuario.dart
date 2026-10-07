import 'package:flutter/material.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:provider/provider.dart';

const _kPrimary    = Color.fromARGB(255, 27, 42, 107);
const _kAccent     = Color.fromARGB(255, 200, 16, 46);
const _kBackground = Color(0xFFF4F5F7);
const _kCardBg     = Colors.white;

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dados atualizados com sucesso! Você será deslogado.'),
          backgroundColor: Colors.green,
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
          content: Text('Erro ao atualizar dados: ${provider.erro}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Dados'),
        backgroundColor: _kPrimary,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // ── Header com avatar ──────────────────────────────
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: _kPrimary,
                      borderRadius: BorderRadius.only(
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
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color:      Colors.black.withOpacity(0.2),
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
                                color:      _kPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${usuario?.nome ?? ''} ${usuario?.apelido ?? ''}',
                          style: const TextStyle(
                            color:      Colors.white,
                            fontSize:   24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color:        Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            usuario?.nomePerfil ?? 'Usuário',
                            style: const TextStyle(
                              color:      Colors.white,
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
                                decoration: InputDecoration(
                                  labelText:  'Email',
                                  prefixIcon: const Icon(Icons.email),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled:    true,
                                  fillColor: _isModoEdicao
                                      ? Colors.white
                                      : Colors.grey[100],
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
                                decoration: InputDecoration(
                                  labelText:  'Telefone',
                                  prefixIcon: const Icon(Icons.phone),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled:    true,
                                  fillColor: _isModoEdicao
                                      ? Colors.white
                                      : Colors.grey[100],
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
                                    ? Colors.green
                                    : Colors.red,
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
                                    icon:  const Icon(Icons.close,
                                        color: Colors.grey),
                                    label: const Text('Cancelar',
                                        style: TextStyle(
                                            fontSize: 16,
                                            color:    Colors.grey)),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      side:  const BorderSide(color: Colors.grey),
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
                                              color:       Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.save,
                                            color: Colors.white),
                                    label: Text(
                                      isSaving ? 'Salvando...' : 'Salvar Alterações',
                                      style: const TextStyle(
                                        fontSize:   16,
                                        fontWeight: FontWeight.bold,
                                        color:      Colors.white,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      backgroundColor: _kPrimary,
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
                                color:        _kPrimary,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color:      _kPrimary.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset:     const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    setState(() => _isModoEdicao = true),
                                icon: const Icon(Icons.edit,
                                    color: Colors.white, size: 24),
                                label: const Text(
                                  'Editar Meus Dados',
                                  style: TextStyle(
                                    fontSize:      18,
                                    fontWeight:    FontWeight.bold,
                                    color:         Colors.white,
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: _kPrimary, size: 24),
                const SizedBox(width: 12),
                Text(title,
                    style: const TextStyle(
                        fontSize:   18,
                        fontWeight: FontWeight.bold,
                        color:      _kPrimary)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize:   14,
                    color:      Colors.grey[600],
                    fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width:   double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:        Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(value,
              style: TextStyle(
                  fontSize:   16,
                  color:      valueColor ?? Colors.black87,
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