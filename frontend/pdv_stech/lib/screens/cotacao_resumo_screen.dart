// lib/screens/cotacao_resumo_screen.dart

import 'package:flutter/material.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';

// ─── Cores ───────────────────────────────────────────────────────────────────
// As antigas constantes foram substituídas pelo tema:
//   _kPrimary    → context.cores.marca (texto/ícone/borda)
//                  context.cores.marcaBotao (fundo de botão/toggle seleccionado)
//                  AppColors.azulMarca / azulMarcaEscuro (AppBar)
//   _kAccent     → AppColors.vermelhoMarca (fundo de snackbar de erro)
//   _kBackground → context.cores.fundo
//   _kCotacao    → _kCotacaoBotao (fundo, igual nos dois temas, texto branco)
//                  context.cotacaoTexto (azul-cotação como TEXTO/ÍCONE:
//                  mais claro no tema escuro para manter contraste)

/// Azul da cotação usado como FUNDO de botão (texto branco por cima: 5.1:1).
const _kCotacaoBotao = Color(0xFF0077B6);

/// Azul da cotação para TEXTO/ÍCONE em cada tema.
/// Escuro: 0xFF4FC3F7 → ~9:1 sobre a superfície 181C30.
extension _CotacaoCores on BuildContext {
  Color get cotacaoTexto =>
      escuro ? const Color(0xFF4FC3F7) : _kCotacaoBotao;
}

class CotacaoResumoScreen extends StatefulWidget {
  final CotacaoModel cotacao;
  const CotacaoResumoScreen({Key? key, required this.cotacao})
      : super(key: key);

  @override
  State<CotacaoResumoScreen> createState() => _CotacaoResumoScreenState();
}

class _CotacaoResumoScreenState extends State<CotacaoResumoScreen> {
  final _currencyFmt = NumberFormat.currency(locale: 'pt_PT', symbol: 'MZN');

  // ── Cliente ───────────────────────────────────────────────────────────────
  String _tipoCliente = 'singular';
  List<ClienteModel> _empresas = [];
  ClienteModel? _empresaSelecionada;
  final _nomeCtrl = TextEditingController();
  final _apelidoCtrl = TextEditingController();

  // ── Estado ────────────────────────────────────────────────────────────────
  bool _carregando = true;
  bool _gerando = false;
  bool _clienteBloqueado = false; // true quando cotação já tem cliente

  @override
  void initState() {
    super.initState();

    final temEmpresa = widget.cotacao.idCliente != null;

    final temSingular = (widget.cotacao.nomeClienteSingular != null &&
            widget.cotacao.nomeClienteSingular!.trim().isNotEmpty) ||
        (widget.cotacao.apelidoClienteSingular != null &&
            widget.cotacao.apelidoClienteSingular!.trim().isNotEmpty);

    _clienteBloqueado = temEmpresa || temSingular;

    if (temEmpresa) {
      _tipoCliente = 'empresa';
    } else if (temSingular) {
      _tipoCliente = 'singular';
      _nomeCtrl.text = widget.cotacao.nomeClienteSingular?.trim() ?? '';
      _apelidoCtrl.text = widget.cotacao.apelidoClienteSingular?.trim() ?? '';
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _carregar());
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _apelidoCtrl.dispose();
    super.dispose();
  }

  // ── Carregamento ──────────────────────────────────────────────────────────

  Future<void> _carregar() async {
    try {
      await context.read<ClienteListaProvider>().filtrarPorPerfil(1);
    } catch (_) {}

    if (!mounted) return;

    final empresas = context.read<ClienteListaProvider>().clientes;

    ClienteModel? empresaSelecionada;
    if (widget.cotacao.idCliente != null) {
      try {
        empresaSelecionada = empresas.firstWhere(
          (e) => e.id == widget.cotacao.idCliente,
        );
      } catch (_) {
        empresaSelecionada = null;
      }
    }

    setState(() {
      _empresas = empresas;
      _empresaSelecionada = empresaSelecionada;
      _carregando = false;
    });
  }

  // ── Gerar cotação ─────────────────────────────────────────────────────────

  Future<void> _gerarCotacao() async {
    if (_gerando) return;
    if (_tipoCliente == 'empresa' && _empresaSelecionada == null) {
      return _snack('Seleccione a empresa', Colors.orange.shade800);
    }

    setState(() => _gerando = true);
    try {
      debugPrint('════════════════════════════════════════════════════');
      debugPrint('🧾 CotacaoResumoScreen._gerarCotacao — cliente escolhido');
      debugPrint('👤 tipoCliente: $_tipoCliente');
      debugPrint('🔒 clienteBloqueado: $_clienteBloqueado');
      debugPrint('🏢 empresaSelecionada.id: ${_empresaSelecionada?.id}');
      debugPrint(
          '🏢 empresaSelecionada.nome: ${_empresaSelecionada?.nomeCompleto}');
      debugPrint('👤 nome digitado: "${_nomeCtrl.text}"');
      debugPrint('👤 apelido digitado: "${_apelidoCtrl.text}"');
      debugPrint('════════════════════════════════════════════════════');

      final provider = context.read<CotacaoProvider>();

      if (!_clienteBloqueado) {
        final dtoCliente = _tipoCliente == 'empresa'
            ? AtualizarCotacaoRequestModel(idCliente: _empresaSelecionada!.id)
            : AtualizarCotacaoRequestModel(
                nomeClienteSingular: _nomeCtrl.text.trim().nullIfEmpty,
                apelidoClienteSingular: _apelidoCtrl.text.trim().nullIfEmpty,
              );
        debugPrint('📦 CotacaoResumoScreen._gerarCotacao — dtoCliente');
        debugPrint('👤 dto.idCliente: ${dtoCliente.idCliente}');
        debugPrint(
            '👤 dto.nomeClienteSingular: "${dtoCliente.nomeClienteSingular}"');
        debugPrint(
            '👤 dto.apelidoClienteSingular: "${dtoCliente.apelidoClienteSingular}"');

        await provider.atualizarCotacao(widget.cotacao.idCotacao, dtoCliente);
        if (!mounted) return;
        if (provider.status != CotacaoStatus.success) {
          _snack('Erro ao associar cliente: ${provider.errorMessage}',
              AppColors.vermelhoMarca);
          return;
        }
      }

      final actualizada = await provider.atualizarCotacao(
        widget.cotacao.idCotacao,
        const AtualizarCotacaoRequestModel(statusCotacao: 'PRONTA'),
      );
      if (!mounted) return;

      if (provider.status == CotacaoStatus.success && actualizada != null) {
        CotacaoAtivaController.instance.limpar();
        _snack('Cotação fechada e pronta para converter!',
            const Color(0xFF388E3C));
        Navigator.pop(context, true);
      } else {
        _snack('Erro: ${provider.errorMessage}', AppColors.vermelhoMarca);
      }
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  /// Fundo colorido FIXO + texto branco explícito: sem isso, no tema escuro
  /// o texto herdaria `textoPrincipal` (claro) e perderia contraste.
  void _snack(String msg, Color cor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: cor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final c = context.cores;

    return Scaffold(
      backgroundColor: c.fundo,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: _carregando
                ? SizedBox(
                    height: 300,
                    child: Center(
                        child: CircularProgressIndicator(color: c.marca)))
                : Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildResumoCard(),
                        const SizedBox(height: 10),
                        _buildClienteCard(),
                        const SizedBox(height: 16),
                        _buildBotao(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    // Mesmo critério da AppBar do tema escuro (azulMarcaEscuro).
    final corBarra =
        context.escuro ? AppColors.azulMarcaEscuro : AppColors.azulMarca;

    return SliverAppBar(
      pinned: true,
      expandedHeight: 110,
      backgroundColor: corBarra,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle),
        child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [corBarra, corBarra.withBlue(140)],
            ),
          ),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.request_quote_outlined,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Finalizar Cotação',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    Text(widget.cotacao.referencia,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12)),
                  ],
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ── Resumo dos itens ──────────────────────────────────────────────────────

  Widget _buildResumoCard() {
    final c = context.cores;
    final cotacao = widget.cotacao;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _secLabel(Icons.receipt_outlined, 'Resumo da Cotação'),
          const SizedBox(height: 8),

          // Itens produto
          ...cotacao.itensProduto.map((i) => _linhaItem(
                '${i.quantidade}× ${i.nomeProduto ?? 'Produto #${i.idProduto}'}',
                i.subtotal,
              )),

          // Itens serviço
          ...cotacao.itensServico.map((i) => _linhaItem(
                '${i.quantidade}× ${i.nomeServico ?? 'Serviço #${i.idServico}'}',
                i.subtotal,
              )),

          const Divider(height: 14),

          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Total',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: c.marca)),
            Text(
              _currencyFmt.format(cotacao.total),
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: context.cotacaoTexto),
            ),
          ]),
        ],
      ),
    );
  }

  String get _nomeClienteSingularAtual {
    return [
      widget.cotacao.nomeClienteSingular,
      widget.cotacao.apelidoClienteSingular,
    ].where((v) => v != null && v.trim().isNotEmpty).join(' ').trim();
  }

  bool get _temClienteSingularAtual => _nomeClienteSingularAtual.isNotEmpty;

  // ── Selector de cliente ───────────────────────────────────────────────────

  Widget _buildClienteCard() {
    final c = context.cores;

    // Se já tem cliente e está bloqueado, mostrar modo leitura
    if (_clienteBloqueado &&
        (widget.cotacao.idCliente != null || _temClienteSingularAtual)) {
      return _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _secLabel(Icons.person_outline, 'Cliente'),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: c.marca
                        .withValues(alpha: context.escuro ? 0.10 : 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: c.marca
                            .withValues(alpha: context.escuro ? 0.30 : 0.15)),
                  ),
                  child: Text(
                    widget.cotacao.idCliente != null
                        ? (_empresaSelecionada?.nomeCompleto ??
                            widget.cotacao.nomeCliente ??
                            'Cliente #${widget.cotacao.idCliente}')
                        : _nomeClienteSingularAtual,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.marca,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => setState(() {
                  _clienteBloqueado = false;

                  if (widget.cotacao.idCliente != null) {
                    _tipoCliente = 'empresa';
                  } else {
                    _tipoCliente = 'singular';
                    _nomeCtrl.text =
                        widget.cotacao.nomeClienteSingular?.trim() ?? '';
                    _apelidoCtrl.text =
                        widget.cotacao.apelidoClienteSingular?.trim() ?? '';
                  }
                }),
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: const Text('Alterar', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                    foregroundColor: context.cotacaoTexto),
              ),
            ]),
          ],
        ),
      );
    }

    // Modo edição (sem cliente ou após "Alterar")
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _secLabel(Icons.person_outline, 'Cliente'),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: _toggleBtn('singular', Icons.person_outline, 'Singular')),
            const SizedBox(width: 8),
            Expanded(child: _toggleBtn('empresa', Icons.business, 'Empresa')),
          ]),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _tipoCliente == 'empresa'
                ? _buildEmpresaSelector()
                : _buildSingularFields(),
          ),
        ],
      ),
    );
  }

  Widget _toggleBtn(String tipo, IconData icon, String label) {
    final c = context.cores;
    final sel = _tipoCliente == tipo;
    return GestureDetector(
      onTap: () => setState(() {
        _tipoCliente = tipo;
        _empresaSelecionada = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: sel ? c.marcaBotao : c.superficieAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? c.marcaBotao : c.borda),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon,
              size: 15, color: sel ? Colors.white : c.textoSecundario),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: sel ? Colors.white : c.textoSecundario)),
        ]),
      ),
    );
  }

  Widget _buildEmpresaSelector() {
    final c = context.cores;

    if (_empresas.isEmpty) {
      return _infoBox(
        key: const ValueKey('sem-empresas'),
        icon: Icons.info_outline,
        texto: 'Nenhuma empresa cadastrada.',
        cor: c.aviso,
      );
    }
    return DropdownButtonFormField<ClienteModel>(
      key: const ValueKey('dropdown-empresa'),
      value: _empresaSelecionada,
      iconEnabledColor: c.textoSecundario,
      decoration: _inputDecoration('Seleccionar empresa…'),
      items: _empresas
          .map((e) => DropdownMenuItem(
                value: e,
                child: Text(e.nomeCompleto,
                    style: TextStyle(fontSize: 13, color: c.textoPrincipal)),
              ))
          .toList(),
      onChanged: (v) => setState(() => _empresaSelecionada = v),
    );
  }

  Widget _buildSingularFields() {
    final c = context.cores;

    return Column(
      key: const ValueKey('singular-fields'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: _textField(_nomeCtrl, 'Nome (opcional)')),
          const SizedBox(width: 8),
          Expanded(child: _textField(_apelidoCtrl, 'Apelido (opcional)')),
        ]),
        const SizedBox(height: 5),
        Row(children: [
          Icon(Icons.info_outline, size: 11, color: c.textoSecundario),
          const SizedBox(width: 4),
          Text('Cliente singular não será cadastrado na base de dados.',
              style: TextStyle(fontSize: 10, color: c.textoSecundario)),
        ]),
      ],
    );
  }

  // ── Botão ─────────────────────────────────────────────────────────────────

  Widget _buildBotao() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _gerando ? null : _gerarCotacao,
        icon: _gerando
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.send_outlined),
        label: Text(
          _gerando ? 'A fechar…' : 'Fechar Cotação',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _kCotacaoBotao,
          foregroundColor: Colors.white,
          // Estado desactivado explícito: no tema escuro o tema global
          // não deve apagar o fundo e o spinner branco tem de continuar visível.
          disabledBackgroundColor: _kCotacaoBotao.withValues(alpha: 0.6),
          disabledForegroundColor: Colors.white70,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 3,
        ),
      ),
    );
  }

  // ── Utilitários de UI ─────────────────────────────────────────────────────

  Widget _card({required Widget child}) => Card(
        elevation: 0,
        color: context.cores.superficie,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(padding: const EdgeInsets.all(12), child: child),
      );

  Widget _secLabel(IconData icon, String texto) {
    final c = context.cores;
    return Row(children: [
      Icon(icon, size: 14, color: c.marca),
      const SizedBox(width: 6),
      Text(texto,
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 13, color: c.marca)),
    ]);
  }

  Widget _linhaItem(String nome, double subtotal) {
    final c = context.cores;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
              child: Text(nome,
                  style: TextStyle(fontSize: 12, color: c.icone),
                  overflow: TextOverflow.ellipsis)),
          Text(_currencyFmt.format(subtotal),
              style: TextStyle(fontSize: 12, color: c.marca)),
        ],
      ),
    );
  }

  Widget _textField(TextEditingController ctrl, String hint) => TextField(
        controller: ctrl,
        style: TextStyle(fontSize: 13, color: context.cores.textoPrincipal),
        decoration: _inputDecoration(hint),
      );

  InputDecoration _inputDecoration(String hint) {
    final c = context.cores;
    final corBorda =
        c.marca.withValues(alpha: context.escuro ? 0.35 : 0.15);

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: c.textoSecundario, fontSize: 12),
      filled: true,
      fillColor: c.fundo,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: corBorda),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: corBorda),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.marca),
      ),
    );
  }

  Widget _infoBox({
    Key? key,
    required IconData icon,
    required String texto,
    required Color cor,
  }) =>
      Container(
        key: key,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: context.escuro ? 0.12 : 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cor.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Icon(icon, size: 14, color: cor),
          const SizedBox(width: 7),
          Expanded(
              child: Text(texto, style: TextStyle(fontSize: 11, color: cor))),
        ]),
      );
}

extension _Str on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}