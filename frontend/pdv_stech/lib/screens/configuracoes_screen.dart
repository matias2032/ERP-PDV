import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import '../widgets/app_sidebar.dart';
import '../theme/app_theme.dart';

class ConfiguracoesScreen extends StatefulWidget {
  const ConfiguracoesScreen({super.key});
  @override
  State<ConfiguracoesScreen> createState() => _ConfiguracoesScreenState();
}

class _ConfiguracoesScreenState extends State<ConfiguracoesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _empresaCtrl = TextEditingController();
  final _ivaCtrl = TextEditingController();
  String _idioma = 'pt';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = context.read<ConfiguracaoProvider>();
      await p.carregar();
      _preencher(p.configuracao);
    });
  }

  void _preencher(ConfiguracaoModel c) {
    setState(() {
      _empresaCtrl.text = c.nomeEmpresa;
      _ivaCtrl.text = c.ivaPercentual.toString();
      _idioma = c.idioma;
    });
  }

  @override
  void dispose() {
    _empresaCtrl.dispose();
    _ivaCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final p = context.read<ConfiguracaoProvider>();
    final ok = await p.guardar(ConfiguracaoModel(
      idioma: _idioma,
      moeda: 'MZN', // fixo por agora
      nomeEmpresa: _empresaCtrl.text.trim(),
      ivaPercentual: double.parse(_ivaCtrl.text.replaceAll(',', '.')),
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Configurações guardadas' : (p.errorMessage ?? 'Erro ao guardar')),
      backgroundColor: ok ? context.cores.sucesso : AppColors.vermelhoMarca,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final carregando = context.watch<ConfiguracaoProvider>().isLoading;

    return Scaffold(
      backgroundColor: c.fundo,
      drawer: const AppSidebar(currentRoute: '/configuracoes'),
      appBar: AppBar(
        backgroundColor: AppColors.azulMarca,
        foregroundColor: AppColors.branco,
        title: const Text('Configurações gerais'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            color: c.superficie,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: c.borda),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(children: [
                  TextFormField(
                    controller: _empresaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nome da empresa',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _ivaCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'IVA (%)',
                      border: OutlineInputBorder(),
                      helperText:
                          'Aplica-se a produtos/serviços criados ou editados a partir de agora.',
                    ),
                    validator: (v) {
                      final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                      if (n == null || n < 0 || n > 100) return 'Entre 0 e 100';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: _idioma,
                    decoration: const InputDecoration(
                      labelText: 'Idioma',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'pt', child: Text('Português')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                    ],
                    onChanged: (v) => setState(() => _idioma = v ?? 'pt'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    initialValue: 'Metical (MZN)',
                    enabled: false,
                    decoration: const InputDecoration(
                      labelText: 'Moeda',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: carregando ? null : _guardar,
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Guardar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.marcaBotao,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}