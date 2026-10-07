import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:provider/provider.dart';

const _kVermelho = Color(0xFFC8102E);
const _kAzul = Color(0xFF1B2A6B);
const _kBranco = Colors.white;
const _kCinzaClaro = Color(0xFFF4F5F7);
const _kCinzaTexto = Color(0xFF6B7280);

class DespesaFormScreen extends StatefulWidget {
  final DespesaModel? despesa;

  const DespesaFormScreen({
    super.key,
    this.despesa,
  });

  @override
  State<DespesaFormScreen> createState() => _DespesaFormScreenState();
}

class _DespesaFormScreenState extends State<DespesaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  int? _idTipoDespesaSelecionado;
TipoDespesaModel? _tipoDespesaSelecionadoCache;

  late final TextEditingController _descricaoController;
  late final TextEditingController _valorController;

int? _idFornecedorSelecionado;
FornecedorModel? _fornecedorSelecionadoCache;

  bool get _isEditMode => widget.despesa != null;
  bool _houveAlteracoes = false;


  @override
void initState() {
  super.initState();

  final d = widget.despesa;

  _descricaoController = TextEditingController(text: d?.descricao ?? '');
  _valorController = TextEditingController(
    text: d != null ? d.valorGasto.toStringAsFixed(2) : '',
  );

  _idFornecedorSelecionado = d?.idFornecedor;
  _idTipoDespesaSelecionado = d?.idTipoDespesa;

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final fornecedorProvider = context.read<FornecedorProvider>();
    final despesaProvider = context.read<DespesaProvider>();

    await fornecedorProvider.carregarFornecedores();
    await despesaProvider.carregarTiposDespesa();

    if (!mounted) return;

    FornecedorModel? fornecedor;
    if (d?.idFornecedor != null) {
      for (final item in fornecedorProvider.fornecedores) {
        if (item.id == d!.idFornecedor) {
          fornecedor = item;
          break;
        }
      }
    }

    TipoDespesaModel? tipoDespesa;
    if (d?.idTipoDespesa != null) {
      for (final item in despesaProvider.tiposDespesa) {
        if (item.idTipoDespesa == d!.idTipoDespesa) {
          tipoDespesa = item;
          break;
        }
      }
    }

    setState(() {
      _idFornecedorSelecionado = fornecedor?.id ?? d?.idFornecedor;
      _fornecedorSelecionadoCache = fornecedor;

      _idTipoDespesaSelecionado =
          tipoDespesa?.idTipoDespesa ?? d?.idTipoDespesa;
      _tipoDespesaSelecionadoCache = tipoDespesa;
    });
  });
}

  @override
  void dispose() {
    _descricaoController.dispose();
    _valorController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    final valor = double.tryParse(
      _valorController.text.trim().replaceAll(',', '.'),
    );

    if (valor == null || valor <= 0) {
      _mostrarSnack('Informe um valor válido.', erro: true);
      return;
    }

final despesa = DespesaModel(
  idDespesa: widget.despesa?.idDespesa,
  idFornecedor: _idFornecedorSelecionado,
  nomeFornecedor: _fornecedorSelecionadoCache?.nome,
  nuitFornecedor: _fornecedorSelecionadoCache?.nuit,
  idTipoDespesa: _idTipoDespesaSelecionado,
  nomeTipoDespesa: _tipoDespesaSelecionadoCache?.nomeDespesa,
  descricao: _descricaoController.text.trim(),
  valorGasto: valor,
  dataDespesa: widget.despesa?.dataDespesa,
);

    final provider = context.read<DespesaProvider>();

    final sucesso = _isEditMode
        ? await provider.editarDespesa(
            id: widget.despesa!.idDespesa!,
            despesa: despesa,
          )
        : await provider.criarDespesa(despesa);

    if (!mounted) return;

    if (sucesso) {
      _houveAlteracoes = true;

      _mostrarSnack(
        _isEditMode
            ? 'Despesa actualizada com sucesso.'
            : 'Despesa cadastrada com sucesso.',
      );

final despesaSalva = provider.ultimaDespesaSalva;

Navigator.of(context).pop(despesaSalva ?? true);
    } else {
      _mostrarSnack(
        provider.erro ?? 'Erro ao salvar despesa.',
        erro: true,
      );
      provider.limparErro();
    }
  }

  Future<void> _abrirCadastroRapidoFornecedor() async {
    final criado = await showDialog<FornecedorModel>(
      context: context,
      builder: (_) => const _DialogNovoFornecedor(),
    );

    if (criado == null || !mounted) return;

await context.read<FornecedorProvider>().carregarFornecedores();

if (!mounted) return;

setState(() {
  _idFornecedorSelecionado = criado.id;
  _fornecedorSelecionadoCache = criado;
});
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
                _BannerDespesa(),
                const SizedBox(height: 16),
                _buildCardFornecedor(),
                const SizedBox(height: 16),
                _buildCardDespesa(),
                const SizedBox(height: 24),
                _BotaoSalvar(
                  isEditMode: _isEditMode,
                  onPressed: _salvar,
                ),
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
              Icons.payments_rounded,
              color: _kBranco,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _isEditMode ? 'Editar Despesa' : 'Nova Despesa',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _BannerDespesa() {
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
'Escolha o tipo da despesa e, se necessário, associe-a a um fornecedor existente.',
              style: TextStyle(fontSize: 13, color: _kAzul),
            ),
          ),
        ],
      ),
    );
  }

Widget _buildCardFornecedor() {
  return Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: Colors.grey.shade200),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Consumer<FornecedorProvider>(
        builder: (_, provider, __) {
          final fornecedoresUnicos = <int, FornecedorModel>{};

          for (final fornecedor in provider.fornecedores) {
            final id = fornecedor.id;

            if (id != null && id > 0) {
              fornecedoresUnicos[id] = fornecedor;
            }
          }

          final fornecedores = fornecedoresUnicos.values.toList()
            ..sort((a, b) {
              final nomeA = (a.nome ?? a.contacto).toLowerCase();
              final nomeB = (b.nome ?? b.contacto).toLowerCase();
              return nomeA.compareTo(nomeB);
            });

          final fornecedorSelecionadoExiste =
              _idFornecedorSelecionado == null ||
              fornecedores.any((f) => f.id == _idFornecedorSelecionado);

          final idFornecedorSeguro = fornecedorSelecionadoExiste
              ? _idFornecedorSelecionado
              : null;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _TituloSecao(
                icon: Icons.local_shipping_rounded,
                label: 'Fornecedor',
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<int?>(
                value: idFornecedorSeguro,
                isExpanded: true,
                decoration: _inputDecoration(
                  label: 'Fornecedor',
                  icon: Icons.local_shipping_outlined,
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Sem fornecedor'),
                  ),
                  ...fornecedores.map(
                    (fornecedor) => DropdownMenuItem<int?>(
                      value: fornecedor.id,
                      child: Text(
                        _nomeFornecedor(fornecedor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: provider.salvando
                    ? null
                    : (valor) {
                        FornecedorModel? fornecedor;

                        for (final item in fornecedores) {
                          if (item.id == valor) {
                            fornecedor = item;
                            break;
                          }
                        }

                        setState(() {
                          _idFornecedorSelecionado = valor;
                          _fornecedorSelecionadoCache = fornecedor;
                        });
                      },
              ),

              const SizedBox(height: 12),

              OutlinedButton.icon(
                onPressed: _abrirCadastroRapidoFornecedor,
                icon: const Icon(Icons.add_business_rounded),
                label: const Text('Cadastrar fornecedor rapidamente'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kAzul,
                  side: const BorderSide(color: _kAzul),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

  Widget _buildCardDespesa() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const _TituloSecao(
              icon: Icons.receipt_long_rounded,
              label: 'Dados da Despesa',
            ),
            const SizedBox(height: 16),
Consumer<DespesaProvider>(
  builder: (context, provider, _) {
    return DropdownButtonFormField<int?>(
      value: _idTipoDespesaSelecionado,
      isExpanded: true,
      decoration: _inputDecoration(
        label: 'Tipo de despesa *',
        icon: Icons.account_tree_rounded,
      ),
      items: provider.tiposDespesa
          .map(
            (tipo) => DropdownMenuItem<int?>(
              value: tipo.idTipoDespesa,
              child: Text(tipo.nomeDespesa),
            ),
          )
          .toList(),
      onChanged: provider.salvando
          ? null
          : (value) {
              TipoDespesaModel? tipo;

              for (final item in provider.tiposDespesa) {
                if (item.idTipoDespesa == value) {
                  tipo = item;
                  break;
                }
              }

              setState(() {
                _idTipoDespesaSelecionado = value;
                _tipoDespesaSelecionadoCache = tipo;
              });
            },
      validator: (value) {
        if (value == null) {
          return 'Selecione o tipo de despesa.';
        }
        return null;
      },
    );
  },
),
const SizedBox(height: 14),
            _Campo(
              controller: _descricaoController,
              label: 'Descrição *',
              hint: 'Ex.: Compra de papel A4',
              icon: Icons.description_outlined,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Descrição é obrigatória';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _Campo(
              controller: _valorController,
              label: 'Valor gasto *',
              hint: 'Ex.: 1500.00',
              icon: Icons.payments_outlined,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              validator: (v) {
                final valor = double.tryParse(
                  (v ?? '').trim().replaceAll(',', '.'),
                );

                if (valor == null || valor <= 0) {
                  return 'Informe um valor maior que zero';
                }

                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  String _nomeFornecedor(FornecedorModel f) {
    final nome = f.nome?.trim();
    if (nome != null && nome.isNotEmpty) return nome;

    return f.contacto.trim().isNotEmpty ? f.contacto.trim() : 'Fornecedor';
  }
}

class _DialogNovoFornecedor extends StatefulWidget {
  const _DialogNovoFornecedor();

  @override
  State<_DialogNovoFornecedor> createState() => _DialogNovoFornecedorState();
}

class _DialogNovoFornecedorState extends State<_DialogNovoFornecedor> {
  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();
  final _nuitController = TextEditingController();
  final _contactoController = TextEditingController();
  final _moradaController = TextEditingController();

  @override
  void dispose() {
    _nomeController.dispose();
    _nuitController.dispose();
    _contactoController.dispose();
    _moradaController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    final fornecedor = FornecedorModel(
      nome: _emptyToNull(_nomeController.text),
      nuit: _emptyToNull(_nuitController.text),
      contacto: _contactoController.text.trim(),
      morada: _emptyToNull(_moradaController.text),
    );

    final provider = context.read<FornecedorProvider>();
    final sucesso = await provider.criarFornecedor(fornecedor);

    if (!mounted) return;

    if (sucesso) {
      final criado = provider.fornecedores.firstWhere(
        (f) => f.contacto == fornecedor.contacto,
        orElse: () => fornecedor,
      );

      Navigator.of(context).pop(criado);
    }
  }

  String? _emptyToNull(String value) {
    final texto = value.trim();
    return texto.isEmpty ? null : texto;
  }

  @override
  Widget build(BuildContext context) {
    final salvando = context.watch<FornecedorProvider>().salvando;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text(
        'Novo fornecedor',
        style: TextStyle(color: _kAzul, fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _Campo(
                  controller: _nomeController,
                  label: 'Nome / Razão Social',
                  icon: Icons.business_outlined,
                ),
                const SizedBox(height: 12),
                _Campo(
                  controller: _nuitController,
                  label: 'NUIT',
                  icon: Icons.badge_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(9),
                  ],
                ),
                const SizedBox(height: 12),
                _Campo(
                  controller: _contactoController,
                  label: 'Contacto *',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Contacto é obrigatório';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _Campo(
                  controller: _moradaController,
                  label: 'Morada',
                  icon: Icons.location_on_outlined,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: salvando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: salvando ? null : _salvar,
          icon: salvando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _kBranco,
                  ),
                )
              : const Icon(Icons.save_rounded),
          label: const Text('Salvar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kVermelho,
            foregroundColor: _kBranco,
          ),
        ),
      ],
    );
  }
}

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
    final salvando = context.watch<DespesaProvider>().salvando;

    return TextFormField(
      controller: controller,
      enabled: !salvando,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      validator: validator,
      decoration: _inputDecoration(label: label, hint: hint, icon: icon),
    );
  }
}

InputDecoration _inputDecoration({
  required String label,
  required IconData icon,
  String? hint,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    hintStyle: TextStyle(
      color: _kCinzaTexto.withOpacity(0.6),
      fontSize: 12,
    ),
    prefixIcon: Icon(icon, color: _kAzul, size: 20),
    filled: true,
    fillColor: _kBranco,
    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
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
  );
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
    final salvando = context.watch<DespesaProvider>().salvando;

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
        isEditMode ? 'SALVAR ALTERAÇÕES' : 'CADASTRAR DESPESA',
        style: const TextStyle(fontSize: 16, letterSpacing: 0.5),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _kVermelho,
        foregroundColor: _kBranco,
        disabledBackgroundColor: _kVermelho.withOpacity(0.5),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );
  }
}