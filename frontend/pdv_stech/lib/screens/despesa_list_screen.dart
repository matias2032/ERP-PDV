import 'package:flutter/material.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:provider/provider.dart';
import '/widgets/app_sidebar.dart';

const _kVermelho = Color(0xFFC8102E);
const _kAzul = Color(0xFF1B2A6B);
const _kBranco = Colors.white;
const _kCinzaClaro = Color(0xFFF4F5F7);
const _kCinzaTexto = Color(0xFF6B7280);

enum PeriodoDespesa {
  hoje,
  umDia,
  umaSemana,
  quinzeDias,
  umMes,
  tresMeses,
  seisMeses,
  umAno,
}

extension PeriodoDespesaExt on PeriodoDespesa {
  String get label => switch (this) {
        PeriodoDespesa.hoje => 'Hoje',
        PeriodoDespesa.umDia => '1 dia',
        PeriodoDespesa.umaSemana => '1 semana',
        PeriodoDespesa.quinzeDias => '15 dias',
        PeriodoDespesa.umMes => '1 mês',
        PeriodoDespesa.tresMeses => '3 meses',
        PeriodoDespesa.seisMeses => '6 meses',
        PeriodoDespesa.umAno => '1 ano',
      };

  DateTime get inicio {
    final agora = DateTime.now();

    return switch (this) {
      PeriodoDespesa.hoje => DateTime(agora.year, agora.month, agora.day),
      PeriodoDespesa.umDia => agora.subtract(const Duration(days: 1)),
      PeriodoDespesa.umaSemana => agora.subtract(const Duration(days: 7)),
      PeriodoDespesa.quinzeDias => agora.subtract(const Duration(days: 15)),
      PeriodoDespesa.umMes => DateTime(agora.year, agora.month - 1, agora.day),
      PeriodoDespesa.tresMeses => DateTime(agora.year, agora.month - 3, agora.day),
      PeriodoDespesa.seisMeses => DateTime(agora.year, agora.month - 6, agora.day),
      PeriodoDespesa.umAno => DateTime(agora.year - 1, agora.month, agora.day),
    };
  }
}

class DespesaListScreen extends StatefulWidget {
  const DespesaListScreen({super.key});

  @override
  State<DespesaListScreen> createState() => _DespesaListScreenState();
}

class _DespesaListScreenState extends State<DespesaListScreen> {
  PeriodoDespesa _periodo = PeriodoDespesa.hoje;
  int? _idTipoDespesaFiltro;

  @override
  void initState() {
    super.initState();
WidgetsBinding.instance.addPostFrameCallback((_) async {
  final provider = context.read<DespesaProvider>();
  await provider.carregarTiposDespesa();
  await _carregarPorPeriodo();
});
  }

Future<void> _carregarPorPeriodo() async {
  if (!mounted) return;

  final agora = DateTime.now();
  final provider = context.read<DespesaProvider>();

  provider.definirFiltroTipoDespesa(_idTipoDespesaFiltro);

  await provider.carregarPorPeriodoComFiltro(
    inicio: _periodo.inicio,
    fim: agora,
  );
}

Future<void> _abrirFormulario({DespesaModel? despesa}) async {
  final resultado = await Navigator.of(context).pushNamed(
    '/cadastrar_despesas',
    arguments: despesa,
  );

  if (!mounted) return;

  if (resultado is DespesaModel) {
    context.read<DespesaProvider>().inserirOuAtualizarNaLista(resultado);
    return;
  }

  if (resultado == true) {
    await _carregarPorPeriodo();
  }
}
  void _mostrarSnack(BuildContext ctx, String mensagem, {bool erro = false}) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: erro ? _kVermelho : _kAzul,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _confirmarExclusao(BuildContext ctx, DespesaModel despesa) async {
  final id = despesa.idDespesa;

  if (id == null) {
    _mostrarSnack(ctx, 'Despesa sem ID válido.', erro: true);
    return;
  }

  final motivo = await showDialog<String>(
    context: ctx,
    barrierDismissible: false,
    builder: (_) => _DialogoMotivoExclusao(despesa: despesa),
  );

  if (motivo == null) return;

  if (motivo.trim().isEmpty) {
    _mostrarSnack(ctx, 'Informe o motivo da exclusão.', erro: true);
    return;
  }

  if (!ctx.mounted) return;

  final provider = ctx.read<DespesaProvider>();

  final sucesso = await provider.excluirDespesa(
    id,
    motivoExclusao: motivo.trim(),
  );

  if (!ctx.mounted) return;

  if (sucesso) {
    _mostrarSnack(ctx, 'Despesa excluída com sucesso.');
  } else {
    _mostrarSnack(
      ctx,
      provider.erro ?? 'Erro ao excluir despesa.',
      erro: true,
    );
    provider.limparErro();
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kCinzaClaro,
      appBar: _buildAppBar(),
      drawer: const AppSidebar(currentRoute: '/gerenciar_despesas'),
      body: Column(
        children: [
        _FiltroPeriodo(
  periodo: _periodo,
  idTipoDespesaFiltro: _idTipoDespesaFiltro,
onPeriodoChanged: (novo) async {
  setState(() => _periodo = novo);
  await _carregarPorPeriodo();
},
onTipoChanged: (novoTipo) async {
  setState(() => _idTipoDespesaFiltro = novoTipo);
  await _carregarPorPeriodo();
},
),
          const Divider(height: 1),
    Expanded(
  child: _ListagemDespesas(
    onEditar: (d) => _abrirFormulario(despesa: d),
    onExcluir: (d) => _confirmarExclusao(context, d),
  ),
),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _kAzul,
      foregroundColor: _kBranco,
      elevation: 0,
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
          const Text(
            'Despesas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      actions: [
  IconButton(
    icon: const Icon(Icons.add_card_rounded),
    tooltip: 'Nova Despesa',
    onPressed: () => _abrirFormulario(),
  ),
  IconButton(
    icon: const Icon(Icons.refresh_rounded),
    tooltip: 'Recarregar',
    onPressed: () async {
      await _carregarPorPeriodo();
    },
  ),
  const SizedBox(width: 8),
],
    );
  }
}

class _FiltroPeriodo extends StatelessWidget {
  final PeriodoDespesa periodo;
  final int? idTipoDespesaFiltro;
  final ValueChanged<PeriodoDespesa> onPeriodoChanged;
  final ValueChanged<int?> onTipoChanged;

  const _FiltroPeriodo({
    required this.periodo,
    required this.idTipoDespesaFiltro,
    required this.onPeriodoChanged,
    required this.onTipoChanged,
  });
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DespesaProvider>();

    return Container(
      color: _kBranco,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.date_range_rounded, color: _kAzul, size: 20),
          const SizedBox(width: 10),
          const Text(
            'Período:',
            style: TextStyle(
              color: _kCinzaTexto,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 10),
          DropdownButton<PeriodoDespesa>(
            value: periodo,
            underline: const SizedBox.shrink(),
            items: PeriodoDespesa.values
                .map(
                  (p) => DropdownMenuItem(
                    value: p,
                    child: Text(p.label),
                  ),
                )
                .toList(),
         onChanged: (v) {
  if (v != null) onPeriodoChanged(v);
},
          ),

          const SizedBox(width: 18),
const Icon(Icons.account_tree_rounded, color: _kAzul, size: 20),
const SizedBox(width: 8),
const Text(
  'Tipo:',
  style: TextStyle(
    color: _kCinzaTexto,
    fontWeight: FontWeight.w600,
    fontSize: 13,
  ),
),
const SizedBox(width: 10),
DropdownButton<int?>(
  value: idTipoDespesaFiltro,
  underline: const SizedBox.shrink(),
  items: [
    const DropdownMenuItem<int?>(
      value: null,
      child: Text('Todos'),
    ),
    ...provider.tiposDespesa.map(
      (tipo) => DropdownMenuItem<int?>(
        value: tipo.idTipoDespesa,
        child: Text(tipo.nomeDespesa),
      ),
    ),
  ],
  onChanged: onTipoChanged,
),
          const Spacer(),
          Text(
            '${provider.despesas.length} despesa(s)',
            style: const TextStyle(fontSize: 13, color: _kCinzaTexto),
          ),
          const SizedBox(width: 16),
          Text(
            'Total: ${provider.totalDespesas.toStringAsFixed(2)} MZN',
            style: const TextStyle(
              fontSize: 13,
              color: _kAzul,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ListagemDespesas extends StatelessWidget {
  final void Function(DespesaModel) onEditar;
  final Future<void> Function(DespesaModel) onExcluir;

  const _ListagemDespesas({
    required this.onEditar,
    required this.onExcluir,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DespesaProvider>();

    if (provider.carregando) {
      return const Center(child: CircularProgressIndicator(color: _kAzul));
    }

    if (provider.temErro) {
      return Center(
        child: Text(
          provider.erro!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _kVermelho),
        ),
      );
    }

    final lista = provider.despesas;

    if (lista.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, color: _kCinzaTexto, size: 48),
            SizedBox(height: 12),
            Text(
              'Nenhuma despesa encontrada neste período.',
              style: TextStyle(color: _kCinzaTexto),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: _kAzul,
            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: const Row(
            children: [
              SizedBox(width: 44),
              SizedBox(width: 14),
              Expanded(flex: 3, child: _HeaderText('Descrição')),
              Expanded(flex: 2, child: _HeaderText('Tipo')),
              Expanded(flex: 2, child: _HeaderText('Fornecedor')),
              Expanded(flex: 2, child: _HeaderText('NUIT')),
              Expanded(flex: 2, child: _HeaderText('Valor')),
              Expanded(flex: 2, child: _HeaderText('Data')),
              SizedBox(width: 90),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
            itemCount: lista.length,
            itemBuilder: (_, i) => _LinhaDespesa(
              despesa: lista[i],
              isAlternate: i.isOdd,
              onEditar: onEditar,
              onExcluir: onExcluir,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderText extends StatelessWidget {
  final String text;

  const _HeaderText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _LinhaDespesa extends StatelessWidget {
  final DespesaModel despesa;
  final bool isAlternate;
  final void Function(DespesaModel) onEditar;
  final Future<void> Function(DespesaModel) onExcluir;

  const _LinhaDespesa({
    required this.despesa,
    required this.isAlternate,
    required this.onEditar,
    required this.onExcluir,
  });

  @override
  Widget build(BuildContext context) {
    final data = despesa.dataDespesa;
    final dataTexto = data == null
        ? '—'
        : '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';

    return Container(
      decoration: BoxDecoration(
        color: isAlternate ? const Color(0xFFF0F2FA) : Colors.white,
        border: const Border(bottom: BorderSide(color: Color(0xFFE8EAF0))),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _kAzul.withOpacity(0.12),
              child: const Icon(
                Icons.payments_outlined,
                color: _kAzul,
                size: 18,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 3,
              child: Text(
                despesa.descricao,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _kAzul,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                despesa.nomeTipoDespesa?.isNotEmpty == true
                    ? despesa.nomeTipoDespesa!
                    : 'Sem tipo',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: _kCinzaTexto,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                despesa.nomeFornecedor?.isNotEmpty == true
                    ? despesa.nomeFornecedor!
                    : 'Sem fornecedor',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: _kCinzaTexto),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                despesa.nuitFornecedor?.isNotEmpty == true
                    ? despesa.nuitFornecedor!
                    : '—',
                style: const TextStyle(fontSize: 12, color: _kCinzaTexto),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '${despesa.valorGasto.toStringAsFixed(2)} MZN',
                style: const TextStyle(
                  fontSize: 12,
                  color: _kAzul,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                dataTexto,
                style: const TextStyle(fontSize: 12, color: _kCinzaTexto),
              ),
            ),
            SizedBox(
              width: 90,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => onEditar(despesa),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.edit_rounded, color: _kAzul, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => onExcluir(despesa),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: _kVermelho,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogoMotivoExclusao extends StatefulWidget {
  final DespesaModel despesa;

  const _DialogoMotivoExclusao({
    required this.despesa,
  });

  @override
  State<_DialogoMotivoExclusao> createState() => _DialogoMotivoExclusaoState();
}

class _DialogoMotivoExclusaoState extends State<_DialogoMotivoExclusao> {
  final _controller = TextEditingController();
  String? _erro;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirmar() {
    final motivo = _controller.text.trim();

    if (motivo.isEmpty) {
      setState(() => _erro = 'Informe o motivo da exclusão.');
      return;
    }

    if (motivo.length > 500) {
      setState(() => _erro = 'O motivo deve ter no máximo 500 caracteres.');
      return;
    }

    Navigator.of(context).pop(motivo);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Row(
        children: [
          Icon(Icons.delete_outline_rounded, color: _kVermelho),
          SizedBox(width: 10),
          Text('Excluir despesa'),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.despesa.descricao,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _kAzul,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${widget.despesa.valorGasto.toStringAsFixed(2)} MZN',
                style: const TextStyle(
                  color: _kCinzaTexto,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: 'Motivo da exclusão',
                hintText: 'Ex.: Lançamento duplicado, valor incorrecto...',
                errorText: _erro,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (_) {
                if (_erro != null) setState(() => _erro = null);
              },
            ),
            const SizedBox(height: 6),
            const Text(
              'A despesa será removida da lista principal, mas continuará disponível em Despesas Excluídas.',
              style: TextStyle(
                color: _kCinzaTexto,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: _confirmar,
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Excluir'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kVermelho,
            foregroundColor: _kBranco,
          ),
        ),
      ],
    );
  }
}