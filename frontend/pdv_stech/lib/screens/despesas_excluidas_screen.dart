import 'package:flutter/material.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:provider/provider.dart';
import '/widgets/app_sidebar.dart';

const _kVermelho = Color(0xFFC8102E);
const _kAzul = Color(0xFF1B2A6B);
const _kBranco = Colors.white;
const _kCinzaClaro = Color(0xFFF4F5F7);
const _kCinzaTexto = Color(0xFF6B7280);

class DespesasExcluidasScreen extends StatefulWidget {
  const DespesasExcluidasScreen({super.key});

  @override
  State<DespesasExcluidasScreen> createState() =>
      _DespesasExcluidasScreenState();
}

class _DespesasExcluidasScreenState extends State<DespesasExcluidasScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DespesaProvider>().carregarExcluidas();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DespesaProvider>();

    return Scaffold(
      backgroundColor: _kCinzaClaro,
      appBar: AppBar(
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
                Icons.delete_sweep_rounded,
                color: _kBranco,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Despesas Excluídas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Recarregar',
            onPressed: () =>
                context.read<DespesaProvider>().carregarExcluidas(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: const AppSidebar(currentRoute: '/despesas_excluidas'),
      body: Column(
        children: [
          Container(
            color: _kBranco,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: _kAzul, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Histórico de despesas removidas e os seus motivos.',
                    style: TextStyle(
                      color: _kCinzaTexto,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  '${provider.despesas.length} excluída(s)',
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
          ),
          const Divider(height: 1),
          Expanded(
            child: _ListagemDespesasExcluidas(provider: provider),
          ),
        ],
      ),
    );
  }
}

class _ListagemDespesasExcluidas extends StatelessWidget {
  final DespesaProvider provider;

  const _ListagemDespesasExcluidas({
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
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
            Icon(Icons.delete_sweep_outlined, color: _kCinzaTexto, size: 48),
            SizedBox(height: 12),
            Text(
              'Nenhuma despesa excluída encontrada.',
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
              Expanded(flex: 2, child: _HeaderText('Valor')),
              Expanded(flex: 2, child: _HeaderText('Data')),
              Expanded(flex: 4, child: _HeaderText('Motivo')),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
            itemCount: lista.length,
            itemBuilder: (_, i) => _LinhaDespesaExcluida(
              despesa: lista[i],
              isAlternate: i.isOdd,
            ),
          ),
        ),
      ],
    );
  }
}

class _LinhaDespesaExcluida extends StatelessWidget {
  final DespesaModel despesa;
  final bool isAlternate;

  const _LinhaDespesaExcluida({
    required this.despesa,
    required this.isAlternate,
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
              backgroundColor: _kVermelho.withOpacity(0.12),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: _kVermelho,
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
            Expanded(
              flex: 4,
              child: Text(
                despesa.motivoExclusao?.isNotEmpty == true
                    ? despesa.motivoExclusao!
                    : 'Sem motivo informado',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: _kCinzaTexto,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
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