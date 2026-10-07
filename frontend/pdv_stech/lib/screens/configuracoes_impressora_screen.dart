// lib/screens/configuracoes_impressora_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import '../widgets/app_sidebar.dart';

// ─── Paleta (idêntica à DetalhesProdutoScreen) ────────────────────────────────
const _kPrimary    = Color(0xFF1B2A6B);
const _kAccent     = Color(0xFFC8102E);
const _kBackground = Color(0xFFF4F5F7);
const _kSuccess    = Color(0xFF2E7D32);
const _kWarning    = Color(0xFFE65100);

class ConfiguracoesImpressoraScreen extends StatefulWidget {
  const ConfiguracoesImpressoraScreen({super.key});

  @override
  State<ConfiguracoesImpressoraScreen> createState() =>
      _ConfiguracoesImpressoraScreenState();
}

class _ConfiguracoesImpressoraScreenState
    extends State<ConfiguracoesImpressoraScreen>
    with SingleTickerProviderStateMixin {
  final _impressoraService = ImpressoraService.instance;

  List<Printer> _impressoras    = [];
  String?       _nomeSelecionado;
  bool          _carregando     = true;
  bool          _salvando       = false;

  late final AnimationController _entradaCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _entradaCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim  = CurvedAnimation(parent: _entradaCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entradaCtrl, curve: Curves.easeOutCubic));

    _carregar();
  }

  @override
  void dispose() {
    _entradaCtrl.dispose();
    super.dispose();
  }

  // ── Lógica ───────────────────────────────────────────────────────────────────

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final impressoras = await _impressoraService.listarImpressoras();
    final nomeSalvo   = await _impressoraService.lerImpressoraPadrao();
    setState(() {
      _impressoras     = impressoras;
      _nomeSelecionado = nomeSalvo;
      _carregando      = false;
    });
    _entradaCtrl.forward(from: 0);
  }

  Future<void> _salvar(String name) async {
    HapticFeedback.selectionClick();
    setState(() => _salvando = true);
    await _impressoraService.salvarImpressoraPadrao(name);
    setState(() {
      _nomeSelecionado = name;
      _salvando        = false;
    });
    _showSnack('Impressora "$name" definida como padrão', _kSuccess);
  }

  Future<void> _remover() async {
    HapticFeedback.mediumImpact();
    await _impressoraService.removerImpressoraPadrao();
    setState(() => _nomeSelecionado = null);
    _showSnack('Impressora padrão removida', _kWarning);
  }

  void _showSnack(String msg, Color cor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 14)),
        backgroundColor: cor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _kBackground,
        drawer: const AppSidebar(currentRoute: '/configuracoes_impressora'),
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Column(
                children: [
                  _buildHeader(context),
                  Expanded(
                    child: _carregando
                        ? _buildLoading()
                        : SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                _buildBannerEstado(),
                                const SizedBox(height: 24),
                                _buildSeccaoLista(),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: _kPrimary,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Row(
        children: [
          Builder(
            builder: (ctx) => GestureDetector(
              onTap: () => Scaffold.of(ctx).openDrawer(),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.menu_rounded, color: Colors.white, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Impressora Padrão',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.4,
                  ),
                ),
                Text(
                  'Seleccione uma impressora',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
          if (_nomeSelecionado != null)
            _HeaderIconButton(
              icon: Icons.link_off_rounded,
              tooltip: 'Remover padrão',
              cor: _kAccent,
              onTap: _remover,
            ),
          const SizedBox(width: 8),
          _HeaderIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Actualizar lista',
            cor: Colors.white,
            onTap: _carregar,
          ),
        ],
      ),
    );
  }

  // ── Loading ───────────────────────────────────────────────────────────────────

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28, height: 28,
            child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2.5),
          ),
          SizedBox(height: 14),
          Text(
            'A carregar impressoras…',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ── Banner de estado ──────────────────────────────────────────────────────────

  Widget _buildBannerEstado() {
    final temImpressora = _nomeSelecionado != null;
    final cor      = temImpressora ? _kSuccess    : _kWarning;
    final icone    = temImpressora ? Icons.check_circle_rounded : Icons.warning_amber_rounded;
    final mensagem = temImpressora ? _nomeSelecionado!  : 'Nenhuma impressora padrão definida';
    final subMsg   = temImpressora ? 'Impressora padrão activa' : 'Seleccione uma impressora abaixo';

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cor.withOpacity(0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: cor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icone, color: cor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subMsg,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: cor,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mensagem,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (temImpressora)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _kSuccess.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Text(
                  'ACTIVA',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: _kSuccess,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Secção lista ──────────────────────────────────────────────────────────────

  Widget _buildSeccaoLista() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Impressoras disponíveis',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _kPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                '${_impressoras.length}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: _kPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        const Text(
          'Toque numa impressora para defini-la como padrão',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 14),
        if (_impressoras.isEmpty)
          _buildListaVazia()
        else
          ...List.generate(_impressoras.length, (i) {
            final impressora    = _impressoras[i];
            final isSelecionada = impressora.name == _nomeSelecionado;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ImpressoraCard(
                impressora:    impressora,
                isSelecionada: isSelecionada,
                salvando:      _salvando,
                onTap:         () => _salvar(impressora.name),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildListaVazia() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.print_disabled_rounded, color: Colors.grey, size: 24),
            ),
            const SizedBox(height: 14),
            const Text(
              'Nenhuma impressora encontrada',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Verifique se a impressora está ligada\ne conectada ao computador.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Card de impressora ───────────────────────────────────────────────────────

class _ImpressoraCard extends StatelessWidget {
  final Printer      impressora;
  final bool         isSelecionada;
  final bool         salvando;
  final VoidCallback onTap;

  const _ImpressoraCard({
    required this.impressora,
    required this.isSelecionada,
    required this.salvando,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cor = isSelecionada ? _kPrimary : Colors.grey;

    return GestureDetector(
      onTap: salvando ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelecionada ? _kPrimary.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelecionada ? _kPrimary.withOpacity(0.5) : Colors.grey[200]!,
            width: isSelecionada ? 1.6 : 1,
          ),
          boxShadow: isSelecionada
              ? [BoxShadow(
                  color: _kPrimary.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: cor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.print_rounded, color: cor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    impressora.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelecionada ? FontWeight.w700 : FontWeight.w500,
                      color: isSelecionada ? Colors.black87 : Colors.grey[600],
                    ),
                  ),
                  if (isSelecionada) ...[
                    const SizedBox(height: 2),
                    const Text(
                      'Impressora padrão',
                      style: TextStyle(
                        fontSize: 11,
                        color: _kPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (salvando && isSelecionada)
              const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2),
              )
            else if (isSelecionada)
              const Icon(Icons.check_circle_rounded, color: _kPrimary, size: 20)
            else
              Icon(Icons.radio_button_unchecked_rounded, color: Colors.grey[300], size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Botão de ícone no header ─────────────────────────────────────────────────

class _HeaderIconButton extends StatelessWidget {
  final IconData     icon;
  final String       tooltip;
  final Color        cor;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.cor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: cor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cor.withOpacity(0.3)),
          ),
          child: Icon(icon, color: cor, size: 18),
        ),
      ),
    );
  }
}