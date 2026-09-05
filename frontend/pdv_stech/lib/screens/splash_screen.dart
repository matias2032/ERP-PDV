// lib/screens/splash_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:api_compartilhado/api_compartilhado.dart';
import 'dart:convert';
import 'package:api_compartilhado/core/database/daos/usuario_dao.dart';
import 'package:api_compartilhado/core/database/daos/produto_dao.dart';
import 'package:api_compartilhado/core/database/daos/servico_dao.dart';
import 'package:sqflite/sqflite.dart';
import 'package:api_compartilhado/core/database/daos/cliente_dao.dart';
import 'package:flutter/foundation.dart'; // para kDebugMode

// ── Paleta STech ─────────────────────────────────────────────────────
const _navy   = Color.fromARGB(255, 58, 62, 79);
const _red    = Color.fromARGB(255, 200, 16, 46);
const _bg     = Color.fromARGB(255, 244, 245, 247);

// ── Configuração ─────────────────────────────────────────────────────
const _kHealthTimeout  = Duration(seconds: 8);
const _kHealthPath     = '/actuator/health';
const _kMinSplashMs    = 1800; // tempo mínimo de splash em ms

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  // ── Animações ─────────────────────────────────────────────────────
  late final AnimationController _logoCtrl;
  late final AnimationController _textCtrl;
  late final AnimationController _pulseCtrl;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _pulse;

  // ── Estado ────────────────────────────────────────────────────────
  _SplashState _state       = _SplashState.iniciando;
  _ConnMode    _connMode    = _ConnMode.desconhecido;
  String       _statusMsg   = 'A iniciar…';
  String?      _errorDetail;
  double       _barProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startSequence();

    
  }

  // ── Animações ─────────────────────────────────────────────────────

  void _setupAnimations() {
    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);

    _logoScale = Tween<double>(begin: .6, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoFade =
        CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut);
    _textFade =
        CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut);
    _textSlide = Tween<Offset>(
            begin: const Offset(0, .3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));
    _pulse = Tween<double>(begin: .92, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  // ── Sequência principal ───────────────────────────────────────────

  Future<void> _startSequence() async {
  final stopwatch = Stopwatch()..start();

  // ── TEMPORÁRIO — limpar queue e pedidos órfãos ─────────────────
  // if (kDebugMode) {
  //   final db = LocalDatabase.instance.db;
  //   final deletedQueue = await db.delete('sync_queue');
  //   final deletedPedidos = await db.delete('pedido', where: 'id < 0');
  //   await db.delete('item_pedido', where: 'id_pedido < 0');
  //   await db.delete('item_pedido_servico', where: 'id_pedido < 0');
  //   debugPrint('🧹 Limpeza debug: queue=$deletedQueue, pedidos=$deletedPedidos');
  // }
  // ── FIM TEMPORÁRIO ─────────────────────────────────────────────

  // 1. Animações de entrada
  await _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    await _textCtrl.forward();

    // 2. Resolver URL base
    _setStep('A resolver servidor…', 0.15);
    final url = await ApiConfig.baseUrlAsync;

    // 3. Verificar conectividade de rede
    _setStep('A verificar conectividade…', 0.30);
    final isNetworkUp = ConnectivityService.instance.isOnline;

    // 4. Verificar se o backend responde
    _setStep('A contactar servidor…', 0.50);
    final isBackendUp = isNetworkUp ? await _healthCheck(url) : false;

// 5. Determinar modo de operação
    _setStep('A preparar modo de operação…', 0.70);
    await Future.delayed(const Duration(milliseconds: 300));

    if (isBackendUp) {
      _setConnMode(_ConnMode.online);
    } else if (isNetworkUp) {
      _setConnMode(_ConnMode.offlineFirst);
      // ── NOVO: mostra popup se backend não responde ────────────
      final continuar = await _mostrarDialogoOffline(
        titulo: 'Servidor indisponível',
        mensagem: 'A rede está activa mas o servidor não responde.\n'
            'Pode tentar novamente ou continuar em modo offline.',
      );
      if (!continuar && mounted) {
        // Reinicia a sequência completa (equivalente a hot restart)
        _logoCtrl.reset();
        _textCtrl.reset();
        setState(() {
          _state       = _SplashState.iniciando;
          _statusMsg   = 'A iniciar…';
          _barProgress = 0.0;
          _connMode    = _ConnMode.desconhecido;
        });
        _startSequence();
        return;
      }
    } else {
      _setConnMode(_ConnMode.fullOffline);
      // ── NOVO: mostra popup se sem rede ────────────────────────
      final continuar = await _mostrarDialogoOffline(
        titulo: 'Sem ligação à rede',
        mensagem: 'Não foi detectada nenhuma ligação à internet.\n'
            'Pode tentar novamente ou continuar com os dados locais.',
      );
      if (!continuar && mounted) {
        _logoCtrl.reset();
        _textCtrl.reset();
        setState(() {
          _state       = _SplashState.iniciando;
          _statusMsg   = 'A iniciar…';
          _barProgress = 0.0;
          _connMode    = _ConnMode.desconhecido;
        });
        _startSequence();
        return;
      }
    }

    // 6. Verificar se há dados locais em modo offline
_setStep('A sincronizar dados…', 0.80);
if (isBackendUp) {
  await _sincronizarCompleto();
} else {
  await _verificarDadosLocais();
}

    // 7. Garantir tempo mínimo de splash
    _setStep('Pronto!', 1.0);
    final elapsed = stopwatch.elapsedMilliseconds;
    if (elapsed < _kMinSplashMs) {
      await Future.delayed(
          Duration(milliseconds: _kMinSplashMs - elapsed));
    }

    // 8. Navegar
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  // ── Health-check ao backend ───────────────────────────────────────

  Future<bool> _healthCheck(String baseUrl) async {
    try {
      final uri = Uri.parse('$baseUrl$_kHealthPath');
      final response = await http
          .get(uri, headers: ApiConfig.defaultHeaders)
          .timeout(_kHealthTimeout);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  // ── Verifica se há dados no SQLite local ──────────────────────────

Future<bool> _verificarDadosLocais() async {
  try {
    final db = LocalDatabase.instance.db;

    final rUsuarios  = await db.rawQuery('SELECT COUNT(*) as t FROM usuario');
    final rProdutos  = await db.rawQuery('SELECT COUNT(*) as t FROM produto');
    final rServicos  = await db.rawQuery('SELECT COUNT(*) as t FROM servico');
    final rClientes  = await db.rawQuery('SELECT COUNT(*) as t FROM cliente');
    final rPedidos   = await db.rawQuery('SELECT COUNT(*) as t FROM pedido');
    final rPendentes = await db.rawQuery(
        "SELECT COUNT(*) as t FROM sync_queue WHERE tentativas < 5");

    final nU = (rUsuarios.first['t']  as int?) ?? 0;
    final nPr = (rProdutos.first['t'] as int?) ?? 0;
    final nS = (rServicos.first['t']  as int?) ?? 0;
    final nC = (rClientes.first['t']  as int?) ?? 0;
    final nPe = (rPedidos.first['t']  as int?) ?? 0;
    final nPend = (rPendentes.first['t'] as int?) ?? 0;

    debugPrint('📦 Cache local:');
    debugPrint('   👤 Utilizadores : $nU');
    debugPrint('   📦 Produtos     : $nPr');
    debugPrint('   🔧 Serviços     : $nS');
    debugPrint('   🏢 Clientes     : $nC');
    debugPrint('   🧾 Pedidos      : $nPe');
    debugPrint('   ⏳ Sync pendente: $nPend operação(ões)');

    return nU > 0 || nPr > 0;
  } catch (e) {
    debugPrint('⚠️ Splash — erro ao ler cache: $e');
    return false;
  }
}

Future<void> _sincronizarCompleto() async {
  try {
    final url = await ApiConfig.baseUrlAsync;
    final client = http.Client();

    // ── Utilizadores ──────────────────────────────────────────────
    _setStep('A sincronizar utilizadores…', 0.82);
    try {
      final resp = await client
          .get(Uri.parse('$url/api/usuarios'),
               headers: ApiConfig.defaultHeaders)
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final lista = (jsonDecode(resp.body) as List<dynamic>)
            .map((e) => UsuarioModel.fromJson(e as Map<String, dynamic>))
            .toList();
        final dao = UsuarioDao();
        await dao.upsertAll(lista.map((u) => u.toLocalDb()).toList());
        debugPrint('✅ Splash sync — ${lista.length} utilizadores');
      }
    } catch (e) {
      debugPrint('⚠️ Splash sync utilizadores: $e');
    }

    // ── Produtos ──────────────────────────────────────────────────
    _setStep('A sincronizar produtos…', 0.87);
    try {
      final resp = await client
          .get(Uri.parse('$url/api/produtos'),
               headers: ApiConfig.defaultHeaders)
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final lista = (jsonDecode(resp.body) as List<dynamic>)
            .map((e) => ProdutoModel.fromJson(e as Map<String, dynamic>))
            .toList();
        final dao = ProdutoDao();
        await dao.upsertAll(lista.map((p) => p.toLocalDb()).toList());
        debugPrint('✅ Splash sync — ${lista.length} produtos');
      }
    } catch (e) {
      debugPrint('⚠️ Splash sync produtos: $e');
    }

    // ── Serviços ──────────────────────────────────────────────────
    _setStep('A sincronizar serviços…', 0.91);
    try {
      final resp = await client
          .get(Uri.parse('$url/api/servicos'),
               headers: ApiConfig.defaultHeaders)
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final lista = (jsonDecode(resp.body) as List<dynamic>)
            .map((e) => ServicoModel.fromJson(e as Map<String, dynamic>))
            .toList();
        final dao = ServicoDao();
        await dao.upsertAll(lista.map((s) => s.toLocalDb()).toList());
        debugPrint('✅ Splash sync — ${lista.length} serviços');
      }
    } catch (e) {
      debugPrint('⚠️ Splash sync serviços: $e');
    }

    // ── Clientes ──────────────────────────────────────────────────
    _setStep('A sincronizar clientes…', 0.95);
    try {
      final resp = await client
          .get(Uri.parse('$url/api/clientes'),
               headers: ApiConfig.defaultHeaders)
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final lista = (jsonDecode(resp.body) as List<dynamic>)
            .map((e) => ClienteModel.fromJson(e as Map<String, dynamic>))
            .toList();
        final dao = ClienteDao();
        await dao.upsertAll(lista.map((c) => c.toLocalDb()).toList());
        debugPrint('✅ Splash sync — ${lista.length} clientes');
      }
    } catch (e) {
      debugPrint('⚠️ Splash sync clientes: $e');
    }

// ── Fornecedores ──────────────────────────────────────────────────
_setStep('A sincronizar fornecedores…', 0.95);

try {
  final resp = await client
      .get(
        Uri.parse('$url/api/fornecedores'),
        headers: ApiConfig.defaultHeaders,
      )
      .timeout(const Duration(seconds: 10));

  if (resp.statusCode == 200) {
    final lista = (jsonDecode(utf8.decode(resp.bodyBytes)) as List<dynamic>)
        .map((e) => FornecedorModel.fromJson(e as Map<String, dynamic>))
        .toList();

    final dao = FornecedorDao();

    await dao.limpar();
    await dao.inserirTodos(lista);

    debugPrint('✅ Splash sync — ${lista.length} fornecedores');
  } else {
    debugPrint(
      '⚠️ Splash sync fornecedores HTTP ${resp.statusCode}: ${resp.body}',
    );
  }
} catch (e, s) {
  debugPrint('⚠️ Splash sync fornecedores: $e');
  debugPrint('$s');
}

            // ── despesas ──────────────────────────────────────────────────
    _setStep('A sincronizar despesas…', 0.95);
    try {
      final resp = await client
          .get(Uri.parse('$url/api/despesas'),
               headers: ApiConfig.defaultHeaders)
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final lista = (jsonDecode(resp.body) as List<dynamic>)
            .map((e) => DespesaModel.fromJson(e as Map<String, dynamic>))
            .toList();
        final dao = DespesaDao();
        await dao.upsertAll(lista.map((d) => d.toLocalDb()).toList());
        debugPrint('✅ Splash sync — ${lista.length} despesas');
      }
    } catch (e) {
      debugPrint('⚠️ Splash sync despesas: $e');
    }

    _setStep('A sincronizar Pedidos', 0.97);

 try {
      final resp = await client
          .get(Uri.parse('$url/api/pedidos'),
               headers: ApiConfig.defaultHeaders)
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final lista = (jsonDecode(resp.body) as List<dynamic>)
            .map((e) => PedidoModel.fromJson(e as Map<String, dynamic>))
            .toList();
        final dao = PedidoDao();
        await dao.upsertAll(lista.map((p) => p.toLocalDb()).toList());
        debugPrint('✅ Splash sync — ${lista.length} pedidos');
      }
    } catch (e) {
      debugPrint('⚠️ Splash sync pedidos: $e');
    }

     try {
      final resp = await client
          .get(Uri.parse('$url/api/cotacoes'),
               headers: ApiConfig.defaultHeaders)
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final lista = (jsonDecode(resp.body) as List<dynamic>)
            .map((e) => CotacaoModel.fromJson(e as Map<String, dynamic>))
            .toList();
        final dao = CotacaoDao();
        await dao.upsertAll(lista.map((p) => p.toLocalDb()).toList());
        debugPrint('✅ Splash sync — ${lista.length} cotações');
      }
    } catch (e) {
      debugPrint('⚠️ Splash sync cotações: $e');
    }

    // ── Tipos de Pagamento ────────────────────────────────────────────
_setStep('A sincronizar tipos de pagamento…', 0.97);
try {
  final resp = await client
      .get(Uri.parse('$url/api/pedidos/tipos-pagamento'),
           headers: ApiConfig.defaultHeaders)
      .timeout(const Duration(seconds: 10));
  if (resp.statusCode == 200) {
    final lista = jsonDecode(resp.body) as List<dynamic>;
    final db = LocalDatabase.instance.db;
    final batch = db.batch();
    for (final t in lista) {
      batch.insert(
        'tipo_pagamento',
        {
          'id':             (t['idTipoPagamento'] as num).toInt(),
          'tipo_pagamento': t['tipoPagamento'] as String,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    debugPrint('✅ Splash sync — ${lista.length} tipos de pagamento');
  }
} catch (e) {
  debugPrint('⚠️ Splash sync tipos de pagamento: $e');
}





    client.close();
  } catch (e) {
    debugPrint('⚠️ _sincronizarCompleto falhou globalmente: $e');
    // Nunca bloqueia a navegação — falha silenciosa
  }
}
  // ── Helpers de estado ─────────────────────────────────────────────

  void _setStep(String msg, double progress) {
    if (!mounted) return;
    setState(() {
      _state       = _SplashState.carregando;
      _statusMsg   = msg;
      _barProgress = progress;
    });
  }

  void _setConnMode(_ConnMode mode) {
    if (!mounted) return;
    setState(() => _connMode = mode);
  }

  void _setError(String msg, String detail) {
    if (!mounted) return;
    setState(() {
      _state       = _SplashState.erro;
      _statusMsg   = msg;
      _errorDetail = detail;
    });
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                _buildLogo(),
                const SizedBox(height: 28),
                _buildTitle(),
                const Spacer(flex: 2),
                _buildConnBadge(),
                const SizedBox(height: 20),
                _buildStatusArea(),
                const Spacer(flex: 1),
                _buildFooter(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Logo ──────────────────────────────────────────────────────────

  Widget _buildLogo() {
    return FadeTransition(
      opacity: _logoFade,
      child: ScaleTransition(
        scale: _logoScale,
        child: ScaleTransition(
          scale: _state == _SplashState.carregando
              ? _pulse
              : const AlwaysStoppedAnimation(1.0),
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: _navy,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: _navy.withOpacity(.35),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
              border: Border.all(
                  color: Colors.white.withOpacity(.12), width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/icon/app_icon.png',
                width: 110,
                height: 110,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Título ────────────────────────────────────────────────────────

  Widget _buildTitle() {
    return FadeTransition(
      opacity: _textFade,
      child: SlideTransition(
        position: _textSlide,
        child: Column(
          children: [
            const Text(
              'ERP & PDV',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: Color.fromARGB(255, 58, 62, 79),
                letterSpacing: .4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Sistema de Gestão de Pedidos',
              style: TextStyle(
                fontSize: 13,
                color: const Color.fromARGB(255, 58, 62, 79).withOpacity(.5),
                letterSpacing: .5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Badge de modo de conectividade ───────────────────────────────

  Widget _buildConnBadge() {
    if (_connMode == _ConnMode.desconhecido) return const SizedBox.shrink();

    final cfg = switch (_connMode) {
      _ConnMode.online => (
          icon: Icons.cloud_done_rounded,
          label: 'Online',
          sub: 'Servidor disponível',
          bg: const Color(0xFFECFDF5),
          border: const Color(0xFF6EE7B7),
          fg: const Color(0xFF065F46),
        ),
      _ConnMode.offlineFirst => (
          icon: Icons.cloud_sync_rounded,
          label: 'Offline-First',
          sub: 'A usar dados locais — sincroniza quando o servidor voltar',
          bg: const Color(0xFFFFFBEB),
          border: const Color(0xFFFCD34D),
          fg: const Color(0xFF92400E),
        ),
      _ConnMode.fullOffline => (
          icon: Icons.wifi_off_rounded,
          label: 'Sem ligação',
          sub: 'A usar cache local — sem acesso à rede',
          bg: const Color(0xFFFEF2F2),
          border: const Color(0xFFFCA5A5),
          fg: const Color(0xFF991B1B),
        ),
      _ConnMode.desconhecido => (
          icon: Icons.help_outline,
          label: '',
          sub: '',
          bg: Colors.transparent,
          border: Colors.transparent,
          fg: Colors.transparent,
        ),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: Container(
        key: ValueKey(_connMode),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: cfg.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cfg.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(cfg.icon, color: cfg.fg, size: 20),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cfg.label,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: cfg.fg)),
                  Text(cfg.sub,
                      style: TextStyle(
                          fontSize: 11,
                          color: cfg.fg.withOpacity(.8),
                          height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Área de status / erro ────────────────────────────────────────

  Widget _buildStatusArea() {
    if (_state == _SplashState.erro) return _buildErrorArea();
    return _buildProgressArea();
  }



  Widget _buildProgressArea() {
    return Column(
      children: [
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 58, 62, 79).withOpacity(.10),
            borderRadius: BorderRadius.circular(4),
          ),
          child: LayoutBuilder(
            builder: (_, constraints) => Stack(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  width: constraints.maxWidth * _barProgress,
                  decoration: BoxDecoration(
                    color: _barProgress == 1.0
                        ? Colors.green[600]
                        : _red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Row(
            key: ValueKey(_statusMsg),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_state == _SplashState.carregando &&
                  _barProgress < 1.0)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.8, color: _red),
                ),
              if (_barProgress == 1.0)
                const Icon(Icons.check_circle_outline,
                    size: 14, color: Colors.green),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _statusMsg,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: _navy.withOpacity(.6),
                    letterSpacing: .3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorArea() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Column(
            children: [
              const Icon(Icons.cloud_off_rounded, color: _red, size: 28),
              const SizedBox(height: 10),
              Text(
                _statusMsg,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF991B1B),
                ),
              ),
              if (_errorDetail != null) ...[
                const SizedBox(height: 6),
                Text(
                  _errorDetail!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.red[400],
                      height: 1.5),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _state       = _SplashState.iniciando;
                _statusMsg   = 'A iniciar…';
                _errorDetail = null;
                _barProgress = 0;
                _connMode    = _ConnMode.desconhecido;
              });
              _logoCtrl.reset();
              _textCtrl.reset();
              _startSequence();
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Tentar novamente',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _navy,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  /// Retorna true  → continuar offline
  /// Retorna false → tentar novamente (reinicia sequência)
  Future<bool> _mostrarDialogoOffline({
    required String titulo,
    required String mensagem,
  }) async {
    if (!mounted) return true;

    final resultado = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // obriga a escolher
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.wifi_off_rounded, color: _red, size: 22),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              titulo,
              style: const TextStyle(
                color: _navy,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ]),
        content: Text(
          mensagem,
          style: TextStyle(fontSize: 13, color: _navy.withOpacity(.7), height: 1.5),
        ),
        actions: [
          // Continuar offline
          TextButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.offline_bolt_outlined, size: 16),
            label: const Text('Continuar offline'),
            style: TextButton.styleFrom(foregroundColor: _navy),
          ),
          // Tentar novamente
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, false),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Tentar novamente'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _navy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );

    return resultado ?? true; // se fechar sem escolher, continua offline
  }

  // ── Rodapé ────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return Text(
      'ERP & PDV © ${DateTime.now().year}',
      style: TextStyle(
          fontSize: 11,
          color: _navy.withOpacity(.3),
          letterSpacing: .4),
    );
  }
}

// ── Enumerações internas ──────────────────────────────────────────────
enum _SplashState { iniciando, carregando, erro }
enum _ConnMode    { desconhecido, online, offlineFirst, fullOffline }