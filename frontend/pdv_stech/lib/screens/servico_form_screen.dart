// lib/screens/servico_form_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import '../theme/app_theme.dart';

class ServicoFormScreen extends StatefulWidget {
  final ServicoModel? servico;

  const ServicoFormScreen({Key? key, this.servico}) : super(key: key);

  @override
  State<ServicoFormScreen> createState() => _ServicoFormScreenState();
}

class _ServicoFormScreenState extends State<ServicoFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _currencyFmt = NumberFormat.currency(locale: 'pt_PT', symbol: 'MZN');

  late TextEditingController _nomeController;
  late TextEditingController _descricaoController;
  late TextEditingController _precoController; // preço BASE (sem IVA)
  late TextEditingController _unidadeController;

  bool _houveAlteracoes = false;
  bool get _isEditMode => widget.servico != null;

  /// IVA vigente (configuração do sistema).
  double get _ivaPct => ConfiguracaoService.instance.ivaPercentual;

  // ═══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(
      text: widget.servico?.nomeServico ?? '',
    );
    _descricaoController = TextEditingController(
      text: widget.servico?.descricao ?? '',
    );
    // O formulário edita o preço BASE (sem IVA); o preço final é calculado.
    _precoController = TextEditingController(
      text: widget.servico?.precoSemIva.toStringAsFixed(2) ?? '',
    );
    _unidadeController = TextEditingController(
      text: widget.servico?.unidade ?? 'unidade',
    );

    // Recalcula o resumo do IVA enquanto o utilizador digita.
    _precoController.addListener(_aoMudar);
    _unidadeController.addListener(_aoMudar);
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    _precoController.dispose();
    _unidadeController.dispose();
    super.dispose();
  }

  void _aoMudar() {
    if (mounted) setState(() {});
  }

  double? _lerValor(TextEditingController c) {
    final t = c.text.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  String _fmtPct(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  // ═══════════════════════════════════════════════════════════════════════════
  // SALVAR
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    // Preço BASE (sem IVA). O preço final é calculado pelo backend / repositório.
    final precoString = _precoController.text.trim().replaceAll(',', '.');
    final precoSemIva = double.parse(precoString);

    final dto = ServicoRequestModel(
      nomeServico: _nomeController.text.trim(),
      descricao: _descricaoController.text.trim().isEmpty
          ? null
          : _descricaoController.text.trim(),
      precoSemIva: precoSemIva,
      unidade: _unidadeController.text.trim(),
    );

    if (_isEditMode) {
      await context
          .read<ServicoProvider>()
          .actualizarServico(widget.servico!.idServico, dto);
    } else {
      await context.read<ServicoProvider>().criarServico(dto);
    }

    if (!mounted) return;

    final provider = context.read<ServicoProvider>();
    if (provider.errorMessage == null) {
      _houveAlteracoes = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode
                ? 'Serviço atualizado com sucesso'
                : 'Serviço criado com sucesso',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar: ${provider.errorMessage}'),
          backgroundColor: AppColors.vermelhoMarca,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<ServicoProvider>().isLoading;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) Navigator.pop(context, _houveAlteracoes);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditMode ? 'Editar Serviço' : 'Novo Serviço'),
          backgroundColor:
              context.escuro ? AppColors.azulMarcaEscuro : AppColors.azulMarca,
          foregroundColor: AppColors.branco,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context, _houveAlteracoes),
          ),
        ),
        backgroundColor: context.cores.fundo,
        body: _buildFormulario(isLoading),
      ),
    );
  }

  // ─── Helpers de UI ────────────────────────────────────────────────────────

  Widget _card({required Widget child}) {
    final c = context.cores;
    return Card(
      elevation: 0,
      color: c.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.borda),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  Widget _cabecalho(IconData icone, String titulo, {Widget? trailing}) {
    final c = context.cores;
    return Row(children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: c.marca.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icone, color: c.marca, size: 16),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(titulo,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: c.marca)),
      ),
      if (trailing != null) trailing,
    ]);
  }

  Widget _caixaInfo({
    required IconData icone,
    required String texto,
    required Color cor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cor.withValues(alpha: 0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icone, size: 15, color: cor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(texto, style: TextStyle(fontSize: 12, color: cor)),
        ),
      ]),
    );
  }

  Widget _linhaValor(String label, String valor, {bool destaque = false}) {
    final c = context.cores;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: destaque ? 14 : 13,
                  fontWeight: destaque ? FontWeight.bold : FontWeight.normal,
                  color: destaque ? c.textoPrincipal : c.textoSecundario)),
          Text(valor,
              style: TextStyle(
                  fontSize: destaque ? 17 : 13,
                  fontWeight: destaque ? FontWeight.bold : FontWeight.w600,
                  color: destaque ? c.marca : c.textoPrincipal)),
        ],
      ),
    );
  }

  // ─── Formulário ───────────────────────────────────────────────────────────

  Widget _buildFormulario(bool isLoading) {
    final c = context.cores;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cabecalho(
                    Icons.miscellaneous_services, 'Informações do Serviço'),
                const Divider(height: 24),

                // NOME DO SERVIÇO
                TextFormField(
                  controller: _nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome do Serviço *',
                    hintText: 'Ex: Impressão A4, Formatação...',
                    prefixIcon: Icon(Icons.title),
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, informe o nome do serviço';
                    }
                    if (value.trim().length < 2) {
                      return 'O nome deve ter pelo menos 2 caracteres';
                    }
                    return null;
                  },
                  enabled: !isLoading,
                ),
                const SizedBox(height: 16),

                // PREÇO (SEM IVA) E UNIDADE LADO A LADO
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _precoController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Preço sem IVA (MZN) *',
                          hintText: '0.00',
                          prefixIcon: Icon(Icons.money),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Informe o preço';
                          }
                          final validDouble =
                              double.tryParse(value.replaceAll(',', '.'));
                          if (validDouble == null || validDouble < 0) {
                            return 'Preço inválido';
                          }
                          return null;
                        },
                        enabled: !isLoading,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _unidadeController,
                        decoration: const InputDecoration(
                          labelText: 'Unidade *',
                          hintText: 'página, hora...',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Obrigatório';
                          }
                          return null;
                        },
                        enabled: !isLoading,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // DESCRIÇÃO
                TextFormField(
                  controller: _descricaoController,
                  decoration: const InputDecoration(
                    labelText: 'Descrição (Opcional)',
                    hintText: 'Detalhes adicionais sobre o serviço...',
                    prefixIcon: Icon(Icons.description),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  enabled: !isLoading,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // SECÇÃO IVA
          _buildCardIva(),
          const SizedBox(height: 24),

          // BOTÕES DE AÇÃO
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () => Navigator.pop(context, _houveAlteracoes),
                  icon: const Icon(Icons.cancel),
                  label: const Text('Cancelar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.marca,
                    side: BorderSide(color: c.marca.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : _salvar,
                  icon: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isEditMode ? 'Atualizar' : 'Salvar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.vermelhoMarca,
                    foregroundColor: AppColors.branco,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ─── IVA e preço final ────────────────────────────────────────────────────

  Widget _buildCardIva() {
    final c = context.cores;
    final iva = _ivaPct;

    final double? base = _lerValor(_precoController);
    final bool baseValida = base != null && base >= 0;
    final double? precoFinal = baseValida ? IvaUtil.comIva(base, iva) : null;
    final double? valorIva = precoFinal != null ? precoFinal - base! : null;

    final unidade = _unidadeController.text.trim();
    final sufixo = unidade.isEmpty ? '' : ' / $unidade';

    // Em edição: o serviço foi gravado com outro IVA que não o vigente.
    final bool ivaDifere =
        _isEditMode && (widget.servico!.ivaAplicado - iva).abs() > 0.001;

    String fmt(double? v) => v == null ? '—' : '${_currencyFmt.format(v)}$sufixo';

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cabecalho(
            Icons.receipt_long_outlined,
            'IVA e Preço Final',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: c.marca.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: c.marca.withValues(alpha: 0.18)),
              ),
              child: Text('IVA ${_fmtPct(iva)}%',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: c.marca)),
            ),
          ),
          const Divider(height: 24),
          _caixaInfo(
            icone: Icons.info_outline,
            texto:
                'O preço introduzido é o valor BASE (sem IVA). O preço cobrado '
                'ao cliente é calculado automaticamente com o IVA em vigor '
                '(${_fmtPct(iva)}%).',
            cor: c.info,
          ),
          const SizedBox(height: 12),
          _linhaValor('Preço base (sem IVA)', fmt(baseValida ? base : null)),
          _linhaValor('IVA (${_fmtPct(iva)}%)', fmt(valorIva)),
          Divider(height: 16, color: c.borda),
          _linhaValor('Preço final (com IVA)', fmt(precoFinal), destaque: true),
          if (ivaDifere) ...[
            const SizedBox(height: 10),
            _caixaInfo(
              icone: Icons.update_rounded,
              texto: 'Este serviço foi gravado com IVA de '
                  '${_fmtPct(widget.servico!.ivaAplicado)}%. Ao guardar, será '
                  'recalculado com o IVA actual (${_fmtPct(iva)}%).',
              cor: c.aviso,
            ),
          ],
        ],
      ),
    );
  }
}