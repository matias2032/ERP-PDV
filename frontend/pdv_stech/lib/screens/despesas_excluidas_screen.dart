// lib/screens/despesas_excluidas_screen.dart

import 'package:flutter/material.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:provider/provider.dart';
import '/widgets/app_sidebar.dart';
import '../theme/app_theme.dart';

// ─── Cores ───────────────────────────────────────────────────────────────────
// As antigas constantes foram substituídas pelo tema:
//   _kAzul       → context.cores.marca (texto/ícone/borda)
//                  AppColors.azulMarca / azulMarcaEscuro (AppBar, cabeçalho de tabela)
//   _kVermelho   → AppColors.vermelhoMarca (fundo: ícone da AppBar; texto branco por cima)
//                  context.cores.acentoTexto (vermelho como texto/ícone)
//                  context.cores.perigo (mensagem de erro de carregamento)
//   _kBranco     → AppColors.branco (sobre fundos coloridos)
//                  context.cores.superficie (barra de informação)
//   _kCinzaClaro → context.cores.fundo
//   _kCinzaTexto → context.cores.textoSecundario

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
    final c = context.cores;
    final provider = context.watch<DespesaProvider>();

    return Scaffold(
      backgroundColor: c.fundo,
      appBar: AppBar(
        // Mesmo critério da AppBar do tema escuro (azulMarcaEscuro).
        backgroundColor:
            context.escuro ? AppColors.azulMarcaEscuro : AppColors.azulMarca,
        foregroundColor: AppColors.branco,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.vermelhoMarca,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.delete_sweep_rounded,
                color: AppColors.branco,
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
            color: c.superficie,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: c.marca, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Histórico de despesas removidas e os seus motivos.',
                    style: TextStyle(
                      color: c.textoSecundario,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  '${provider.despesas.length} excluída(s)',
                  style: TextStyle(fontSize: 13, color: c.textoSecundario),
                ),
                const SizedBox(width: 16),
                Text(
                  'Total: ${provider.totalDespesas.toStringAsFixed(2)} MZN',
                  style: TextStyle(
                    fontSize: 13,
                    color: c.marca,
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
    final c = context.cores;

    if (provider.carregando) {
      return Center(child: CircularProgressIndicator(color: c.marca));
    }

    if (provider.temErro) {
      return Center(
        child: Text(
          provider.erro!,
          textAlign: TextAlign.center,
          style: TextStyle(color: c.perigo),
        ),
      );
    }

    final lista = provider.despesas;

    if (lista.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_sweep_outlined,
                color: c.textoSecundario, size: 48),
            const SizedBox(height: 12),
            Text(
              'Nenhuma despesa excluída encontrada.',
              style: TextStyle(color: c.textoSecundario),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Cabeçalho de tabela: azulMarca FIXO + texto branco (igual nos dois temas).
        Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: AppColors.azulMarca,
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
    final c = context.cores;
    final data = despesa.dataDespesa;
    final dataTexto = data == null
        ? '—'
        : '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';

    return Container(
      decoration: BoxDecoration(
        color: isAlternate ? c.linhaAlternada : c.superficie,
        border: Border(bottom: BorderSide(color: c.borda)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor:
                  c.acentoTexto.withValues(alpha: context.escuro ? 0.18 : 0.12),
              child: Icon(
                Icons.delete_outline_rounded,
                color: c.acentoTexto,
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
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.marca,
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
                style: TextStyle(
                  fontSize: 12,
                  color: c.textoSecundario,
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
                style: TextStyle(fontSize: 12, color: c.textoSecundario),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '${despesa.valorGasto.toStringAsFixed(2)} MZN',
                style: TextStyle(
                  fontSize: 12,
                  color: c.marca,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                dataTexto,
                style: TextStyle(fontSize: 12, color: c.textoSecundario),
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
                style: TextStyle(
                  fontSize: 12,
                  color: c.textoSecundario,
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
        color: AppColors.branco,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}