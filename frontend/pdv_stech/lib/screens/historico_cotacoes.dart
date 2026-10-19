// lib/screens/historico_cotacoes_screen.dart

import 'package:flutter/material.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_sidebar.dart';
import 'cotacao_detalhes_screen.dart';

// ─── Cores ───────────────────────────────────────────────────────────────────
// As antigas constantes foram substituídas pelo tema:
//   _kAzul        → context.cores.marca (texto/ícone/borda)
//                   context.cores.marcaBotao (fundo de botão)
//                   AppColors.azulMarca / azulMarcaEscuro (AppBar, cabeçalho da tabela)
//   _kVermelho    → AppColors.vermelhoMarca (FUNDO: ícone da AppBar, snackbar de erro)
//                   context.cores.acentoTexto (vermelho como texto/ícone)
//                   context.cores.perigo (mensagem de erro de carregamento)
//   _kBranco      → context.cores.superficie (fundo) / AppColors.branco (sobre marca)
//   _kCinzaClaro  → context.cores.fundo
//   _kCinzaTexto  → context.cores.textoSecundario
//   _kVerde       → context.cores.sucesso
//   _kLaranja     → (não era usada neste ficheiro; removida)
//   0xFFF0F2FA    → context.cores.linhaAlternada
//   0xFFE8EAF0    → context.cores.borda

// ─────────────────────────────────────────────────────────────────────────────
//  Filtros disponíveis no histórico
// ─────────────────────────────────────────────────────────────────────────────

enum _FiltroHistorico { todas, convertidas, canceladas, expiradas }

extension _FiltroHistoricoExt on _FiltroHistorico {
  String get label => switch (this) {
        _FiltroHistorico.todas       => 'Todas',
        _FiltroHistorico.convertidas => 'Convertidas',
        _FiltroHistorico.canceladas  => 'Canceladas',
        _FiltroHistorico.expiradas   => 'Expiradas',
      };

  String? get statusCode => switch (this) {
        _FiltroHistorico.todas       => null,
        _FiltroHistorico.convertidas => 'CONVERTIDA',
        _FiltroHistorico.canceladas  => 'CANCELADA',
        _FiltroHistorico.expiradas   => 'EXPIRADA',
      };

  /// Cor do filtro como TEXTO/ÍCONE (e, com alpha, como fundo translúcido).
  /// Era um getter; agora é método porque a cor depende do tema.
  Color cor(BuildContext context) {
    final c = context.cores;
    return switch (this) {
      _FiltroHistorico.todas       => c.marca,
      _FiltroHistorico.convertidas => c.sucesso,
      _FiltroHistorico.canceladas  => c.acentoTexto,
      _FiltroHistorico.expiradas   => c.textoSecundario,
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────────────────────────────────────

String _labelStatus(String status) => switch (status) {
      'CONVERTIDA' => 'Convertida',
      'CANCELADA'  => 'Cancelada',
      'EXPIRADA'   => 'Expirada',
      _            => status,
    };

/// Cor do estado como TEXTO/ÍCONE. Depende do tema, por isso recebe o context.
Color _corStatus(BuildContext context, String status) {
  final c = context.cores;
  return switch (status) {
    'CONVERTIDA' => c.sucesso,
    'CANCELADA'  => c.acentoTexto,
    'EXPIRADA'   => c.textoSecundario,
    _            => c.textoSecundario,
  };
}

String _formatarData(DateTime? data) {
  if (data == null) return '—';
  return '${data.day.toString().padLeft(2, '0')}/'
      '${data.month.toString().padLeft(2, '0')}/${data.year}';
}

String _formatarTotal(double total) => 'MZN ${total.toStringAsFixed(2)}';

// ─────────────────────────────────────────────────────────────────────────────
//  Ecrã principal
// ─────────────────────────────────────────────────────────────────────────────

class HistoricoCotacoesScreen extends StatefulWidget {
  const HistoricoCotacoesScreen({super.key});

  @override
  State<HistoricoCotacoesScreen> createState() =>
      _HistoricoCotacoesScreenState();
}

class _HistoricoCotacoesScreenState extends State<HistoricoCotacoesScreen> {
  final TextEditingController _searchController = TextEditingController();

  _FiltroHistorico _filtro       = _FiltroHistorico.todas;
  String           _termoPesquisa = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recarregar());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Carregamento ────────────────────────────────────────────────────────

  Future<void> _recarregar() async {
    final provider = context.read<CotacaoProvider>();
    final codigo = _filtro.statusCode;
    if (codigo != null) {
      await provider.listarPorStatus(codigo);
    } else {
      // "Todas" = CONVERTIDA + CANCELADA + EXPIRADA em paralelo,
      // depois junta e ordena por data desc
      await _carregarTodosHistorico(provider);
    }
  }

  Future<void> _carregarTodosHistorico(CotacaoProvider provider) async {
    // Usa listarTodas e filtra localmente — evita 3 chamadas paralelas
    // que poderiam causar race condition no provider
    await provider.listarTodas();
  }

  // ── Filtro ──────────────────────────────────────────────────────────────

  void _onFiltro(_FiltroHistorico filtro) {
    if (_filtro == filtro) return;
    setState(() => _filtro = filtro);
    _recarregar();
  }

  void _onPesquisar(String termo) =>
      setState(() => _termoPesquisa = termo.trim().toLowerCase());

  void _limparPesquisa() {
    _searchController.clear();
    setState(() => _termoPesquisa = '');
  }

  List<CotacaoModel> _aplicarFiltros(List<CotacaoModel> lista) {
    const statusHistorico = {'CONVERTIDA', 'CANCELADA', 'EXPIRADA'};

    // Primeiro: garante que só aparecem estados de histórico
    var resultado = lista
        .where((c) => statusHistorico.contains(c.statusCotacao))
        .toList();

    // Segundo: aplica filtro de tab se não for "todas"
    if (_filtro.statusCode != null) {
      resultado = resultado
          .where((c) => c.statusCotacao == _filtro.statusCode)
          .toList();
    }

    // Terceiro: pesquisa textual
    if (_termoPesquisa.isNotEmpty) {
      resultado = resultado.where((c) {
        final ref    = c.referencia.toLowerCase();
        final nome   = (c.nomeCliente ?? '').toLowerCase();
        return ref.contains(_termoPesquisa) || nome.contains(_termoPesquisa);
      }).toList();
    }

    // Ordena do mais recente para o mais antigo
    resultado.sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));

    return resultado;
  }

  // ── Navegação ────────────────────────────────────────────────────────────



  /// Fundo colorido FIXO + texto branco explícito: sem isso, no tema escuro
  /// o texto herdaria `textoPrincipal` (claro) e perderia contraste.
  void _mostrarSnack(String mensagem, {bool erro = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem, style: const TextStyle(color: Colors.white)),
        backgroundColor:
            erro ? AppColors.vermelhoMarca : context.cores.marcaBotao,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.cores;

    return Scaffold(
      backgroundColor: c.fundo,
      appBar: _buildAppBar(),
      drawer: const AppSidebar(currentRoute: '/historico_cotacoes'),
      body: Column(
        children: [
          _BarraPesquisa(
            controller: _searchController,
            onChanged: _onPesquisar,
            onLimpar: _limparPesquisa,
          ),
          _BarraFiltros(
            filtroActivo: _filtro,
            onSelecionar: _onFiltro,
          ),
          const Divider(height: 1),
          Expanded(
            child: _Listagem(
              aplicarFiltros: _aplicarFiltros,
              onRecarregar: _recarregar,
              onSnack: _mostrarSnack,
            ),
          ),
        ],
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
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.vermelhoMarca,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.history_rounded,
                color: AppColors.branco, size: 20),
          ),
          const SizedBox(width: 10),
          const Text(
            'Histórico de Cotações',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Recarregar',
          onPressed: _recarregar,
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Barra de Pesquisa
// ─────────────────────────────────────────────────────────────────────────────

class _BarraPesquisa extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onLimpar;

  const _BarraPesquisa({
    required this.controller,
    required this.onChanged,
    required this.onLimpar,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cores;

    return Container(
      color: c.superficie,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: 'Pesquisar por referência ou cliente...',
                hintStyle: TextStyle(fontSize: 13, color: c.textoSecundario),
                prefixIcon: Icon(Icons.search_rounded, color: c.marca),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: c.textoSecundario, size: 18),
                        onPressed: onLimpar,
                      )
                    : null,
                filled: true,
                fillColor: c.fundo,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Consumer<CotacaoProvider>(
            builder: (_, p, __) => Text(
              '${p.cotacoes.length} registo(s)',
              style: TextStyle(fontSize: 13, color: c.textoSecundario),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Barra de Filtros por estado
// ─────────────────────────────────────────────────────────────────────────────

class _BarraFiltros extends StatelessWidget {
  final _FiltroHistorico filtroActivo;
  final ValueChanged<_FiltroHistorico> onSelecionar;

  const _BarraFiltros({
    required this.filtroActivo,
    required this.onSelecionar,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cores;

    return Container(
      color: c.superficie,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _FiltroHistorico.values.map((filtro) {
            final ativo = filtro == filtroActivo;
            final cor   = filtro.cor(context);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(filtro.label),
                selected: ativo,
                onSelected: (_) => onSelecionar(filtro),
                selectedColor:
                    cor.withValues(alpha: context.escuro ? 0.22 : 0.15),
                backgroundColor: c.fundo,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      ativo ? FontWeight.w700 : FontWeight.normal,
                  color: ativo ? cor : c.textoSecundario,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: ativo
                        ? cor.withValues(alpha: 0.4)
                        : Colors.transparent,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Listagem
// ─────────────────────────────────────────────────────────────────────────────

class _Listagem extends StatelessWidget {
  final List<CotacaoModel> Function(List<CotacaoModel>) aplicarFiltros;
  final Future<void> Function() onRecarregar;

  final void Function(String mensagem, {bool erro}) onSnack;

  const _Listagem({
    required this.aplicarFiltros,
    required this.onRecarregar,
    required this.onSnack,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final provider = context.watch<CotacaoProvider>();

    if (provider.isLoading) {
      return Center(child: CircularProgressIndicator(color: c.marca));
    }

    if (provider.status == CotacaoStatus.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: c.perigo, size: 48),
            const SizedBox(height: 12),
            Text(
              provider.errorMessage ?? 'Erro ao carregar histórico.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.perigo),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRecarregar,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.marcaBotao,
                foregroundColor: AppColors.branco,
              ),
            ),
          ],
        ),
      );
    }

    final lista = aplicarFiltros(provider.cotacoes);

    if (lista.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_toggle_off_rounded,
                color: c.textoSecundario, size: 48),
            const SizedBox(height: 12),
            Text('Nenhum registo encontrado.',
                style: TextStyle(color: c.textoSecundario)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: c.marca,
      backgroundColor: c.superficie,
      onRefresh: onRecarregar,
      child: Column(
        children: [
          // Cabeçalho da tabela
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: context.escuro
                  ? AppColors.azulMarcaEscuro
                  : AppColors.azulMarca,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: const Row(
              children: [
                SizedBox(width: 44),
                SizedBox(width: 14),
                Expanded(
                  flex: 3,
                  child: Text('Referência / Cliente',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Estado',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Total',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Data',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
                SizedBox(width: 44),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
              itemCount: lista.length,
              itemBuilder: (_, i) => _LinhaHistorico(
                cotacao: lista[i],
                isAlternate: i.isOdd,
                onSnack: onSnack,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Badge de Estado
// ─────────────────────────────────────────────────────────────────────────────

class _BadgeEstado extends StatelessWidget {
  final String status;
  const _BadgeEstado({required this.status});

  @override
  Widget build(BuildContext context) {
    final cor = _corStatus(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: context.escuro ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _labelStatus(status),
        style: TextStyle(
          fontSize: 11,
          color: cor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Linha do histórico
// ─────────────────────────────────────────────────────────────────────────────

class _LinhaHistorico extends StatelessWidget {
  const _LinhaHistorico({
    required this.cotacao,
    required this.isAlternate,
    required this.onSnack,
  });

  final CotacaoModel cotacao;
  final bool isAlternate;
  final void Function(String mensagem, {bool erro}) onSnack;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final escuro = context.escuro;
    final corEstado = _corStatus(context, cotacao.statusCotacao);

    final nomeCliente = cotacao.nomeCliente?.isNotEmpty == true
        ? cotacao.nomeCliente!
        : 'Sem cliente associado';

    final isConvertida = cotacao.statusCotacao == 'CONVERTIDA';

    return Container(
      decoration: BoxDecoration(
        color: isAlternate ? c.linhaAlternada : c.superficie,
        border: Border(
          bottom: BorderSide(color: c.borda),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Avatar — ícone reflecte o estado
            CircleAvatar(
              radius: 18,
              backgroundColor:
                  corEstado.withValues(alpha: escuro ? 0.18 : 0.12),
              child: Icon(
                isConvertida
                    ? Icons.task_alt_rounded
                    : cotacao.statusCotacao == 'CANCELADA'
                        ? Icons.cancel_outlined
                        : Icons.timer_off_outlined,
                size: 18,
                color: corEstado,
              ),
            ),
            const SizedBox(width: 14),

            // Referência + cliente
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cotacao.referencia,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.marca,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    nomeCliente,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: c.textoSecundario),
                  ),
                  if (isConvertida && cotacao.referenciaPedidoConvertido != null)
                    Text(
                      '→ ${cotacao.referenciaPedidoConvertido}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: c.sucesso),
                    ),
                ],
              ),
            ),

            // Estado
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _BadgeEstado(status: cotacao.statusCotacao),
              ),
            ),

            // Total
            Expanded(
              flex: 2,
              child: Text(
                _formatarTotal(cotacao.total),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.marca,
                ),
              ),
            ),

            // Data de criação
            Expanded(
              flex: 2,
              child: Row(children: [
                Icon(Icons.calendar_today_outlined,
                    size: 13, color: c.textoSecundario),
                const SizedBox(width: 4),
                Text(
                  _formatarData(cotacao.createdAt),
                  style: TextStyle(fontSize: 12, color: c.textoSecundario),
                ),
              ]),
            ),

            // Ações
            SizedBox(
              width: 44,
              child: Align(
                alignment: Alignment.centerRight,
                child: Tooltip(
                  message: isConvertida
                      ? 'Gerar PDF'
                      : 'PDF indisponível para este estado',
                  child: isConvertida
                      ? _BotaoPdfHistorico(
                          cotacao: cotacao,
                          onSnack: onSnack,
                        )
                      : Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: c.fundo,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.picture_as_pdf_outlined,
                            size: 16,
                            color: c.textoSecundario,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Botão PDF (apenas CONVERTIDAS)
// ─────────────────────────────────────────────────────────────────────────────

class _BotaoPdfHistorico extends StatefulWidget {
  final CotacaoModel cotacao;
  final void Function(String mensagem, {bool erro}) onSnack;

  const _BotaoPdfHistorico({
    required this.cotacao,
    required this.onSnack,
  });

  @override
  State<_BotaoPdfHistorico> createState() => _BotaoPdfHistoricoState();
}

class _BotaoPdfHistoricoState extends State<_BotaoPdfHistorico> {
  bool _gerando = false;

  Future<void> _gerarPdf() async {
    if (_gerando) return;
    setState(() => _gerando = true);
    try {
      final file =
          await CotacaoPdfService.instance.gerarCotacao(widget.cotacao);
      if (!mounted) return;
      await CotacaoPdfService.instance.abrirPdf(file);
    } catch (e) {
      if (!mounted) return;
      widget.onSnack('Erro ao gerar PDF: $e', erro: true);
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;

    return InkWell(
      onTap: _gerarPdf,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: c.sucesso.withValues(alpha: context.escuro ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: _gerando
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: c.sucesso,
                ),
              )
            : Icon(Icons.picture_as_pdf_outlined, size: 16, color: c.sucesso),
      ),
    );
  }
}