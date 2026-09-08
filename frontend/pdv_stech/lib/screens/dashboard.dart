import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import '../widgets/app_sidebar.dart';
import 'package:provider/provider.dart';

// ─── Paleta ───────────────────────────────────────────────────────────────────
const _kPrimary    = Color.fromARGB(255, 58, 62, 79);
const _kAccent     = Color(0xFFC8102E);
const _kBackground = Color(0xFFF4F5F7);
const _kCardBg     = Colors.white;
const _kSuccess    = Color(0xFF2E7D32);
const _kWarning    = Color(0xFFF59E0B);
const _kTextSub    = Color(0xFF6B7280);

const _kAvatarCores = [
  _kPrimary,
  _kAccent,
  _kSuccess,
  _kWarning,
  Color(0xFF7C3AED),
  Color(0xFF0891B2),
];

// ─── Períodos ─────────────────────────────────────────────────────────────────

enum _Periodo {
  dia('Hoje', 1),
  semana('7D', 7),
  mes('30D', 30),
  tresMeses('3M', 90),
  seisMeses('6M', 180),
  ano('1A', 365);

  final String label;
  final int dias;
  const _Periodo(this.label, this.dias);
}

// ─── Modelos locais ───────────────────────────────────────────────────────────

class _Metricas {
  final int    totalPedidos;
  final double totalReceita;
  final double totalProdutos;
  final double totalServicos;
  final int    nItensProduto;
  final int    nItensServico;
  final double ticketMedio;

  const _Metricas({
    required this.totalPedidos,
    required this.totalReceita,
    required this.totalProdutos,
    required this.totalServicos,
    required this.nItensProduto,
    required this.nItensServico,
    required this.ticketMedio,
  });

  factory _Metricas.zero() => const _Metricas(
        totalPedidos:  0,
        totalReceita:  0,
        totalProdutos: 0,
        totalServicos: 0,
        nItensProduto: 0,
        nItensServico: 0,
        ticketMedio:   0,
      );
}

class _DesempenhoOperador {
  final int    idUsuario;
  final String nome;
  final int    totalPedidos;
  final double totalReceita;
  final double ticketMedio;

  const _DesempenhoOperador({
    required this.idUsuario,
    required this.nome,
    required this.totalPedidos,
    required this.totalReceita,
    required this.ticketMedio,
  });
}

// ─── Tela principal ───────────────────────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {

  final _currencyFmt   = NumberFormat.currency(locale: 'pt_PT', symbol: 'MZN');

  _Periodo _periodo = _Periodo.semana;


  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;

@override
void initState() {
  super.initState();
  _fadeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));
  _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // Dispara animação imediatamente — dados do cache já estão disponíveis
    _fadeCtrl.forward();
    context.read<PedidoProvider>().listarPorStatus('finalizado');
  });
}
@override
void dispose() {
  _fadeCtrl.dispose();
  super.dispose();
}

  // ── Dados ─────────────────────────────────────────────────────────────────

Future<void> _carregar() async {
  await context.read<PedidoProvider>().listarPorStatus('finalizado');
  if (mounted) _fadeCtrl.forward(from: 0);
}

  // ── Filtragem ─────────────────────────────────────────────────────────────

List<PedidoModel> get _filtrados {
  final corte = DateTime.now().subtract(Duration(days: _periodo.dias));
  return context.read<PedidoProvider>().pedidos
      .where((p) => p.dataPedido.isAfter(corte))
      .toList();
}

  // ── Métricas ──────────────────────────────────────────────────────────────

  _Metricas get _metricas {
    final lista = _filtrados;
    if (lista.isEmpty) return _Metricas.zero();

    double receita    = 0;
    double produtos   = 0;
    double servicos   = 0;
    int    nProdutos  = 0;
    int    nServicos  = 0;

    for (final p in lista) {
      receita += p.total;
      for (final item in p.itensProduto) {
        produtos += item.subtotal;
        nProdutos++;
      }
      for (final item in p.itensServico) {
        servicos += item.subtotal;
        nServicos++;
      }
    }

    final ticket = lista.isNotEmpty ? receita / lista.length : 0.0;

    return _Metricas(
      totalPedidos:  lista.length,
      totalReceita:  receita,
      totalProdutos: produtos,
      totalServicos: servicos,
      nItensProduto: nProdutos,
      nItensServico: nServicos,
      ticketMedio:   ticket,
    );
  }

  // ── Desempenho por operador ───────────────────────────────────────────────

  List<_DesempenhoOperador> get _desempenhoOperadores {
    final lista = _filtrados;
    if (lista.isEmpty) return [];

    final Map<int, List<PedidoModel>> porUsuario = {};
    for (final p in lista) {
      porUsuario.putIfAbsent(p.idUsuario, () => []).add(p);
    }

    final ops = porUsuario.entries.map((e) {
      final pedidos = e.value;
      final receita = pedidos.fold(0.0, (acc, p) => acc + p.total);
      final ticket  = pedidos.isNotEmpty ? receita / pedidos.length : 0.0;
      final primeiro = pedidos.first;
      return _DesempenhoOperador(
        idUsuario:    e.key,
        nome:         _nomeDoUsuario(primeiro),
        totalPedidos: pedidos.length,
        totalReceita: receita,
        ticketMedio:  ticket,
      );
    }).toList();

    ops.sort((a, b) => b.totalReceita.compareTo(a.totalReceita));
    return ops;
  }

  // Tenta ler nomeUsuario/apelidoUsuario do PedidoModel; fallback para ID
  String _nomeDoUsuario(PedidoModel p) {
    // PedidoModel actual não tem nome — usamos ID como fallback seguro
    // Se o teu PedidoModel tiver nomeUsuario, substitui abaixo:
    return 'Operador #${p.idUsuario}';
  }

bool get _ehAdmin {
  final perfil = SessaoService.instance.usuarioAtual?.nomePerfil
      .toLowerCase()
      .trim() ?? '';
  return perfil == 'administrador' || perfil == 'admin';
}

  // ── Build ─────────────────────────────────────────────────────────────────

@override
Widget build(BuildContext context) {
  // lê o provider — redesenha sempre que carregar/erro/lista mudar
  final provider = context.watch<PedidoProvider>();

  return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _kBackground,
        drawer: const AppSidebar(currentRoute: '/dashboard'),
        body: SafeArea(
          child: Column(
            children: [
       _buildHeader(provider),
              _buildSeletorPeriodo(),
       Expanded(child: _buildBody(provider)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

Widget _buildHeader(PedidoProvider provider) {
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
                child: const Icon(Icons.menu_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dashboard',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.4,
                    )),
                Text(
                  'Olá, ${SessaoService.instance.usuarioAtual?.nome ?? 'utilizador'}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _carregar,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: provider.isLoading  
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.refresh_rounded,
                      color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ── Seletor de período ────────────────────────────────────────────────────

  Widget _buildSeletorPeriodo() {
    return Container(
      color: _kPrimary,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: _Periodo.values.map((p) {
            final sel = p == _periodo;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _periodo = p);
                  _fadeCtrl.forward(from: 0);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: sel ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Center(
                    child: Text(p.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: sel ? _kPrimary : Colors.white70,
                        )),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────

Widget _buildBody(PedidoProvider provider) {
    if (provider.isLoading && provider.pedidos.isEmpty) {
    return const Center(
        child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2.5));
  }
  if (provider.errorMessage != null && provider.pedidos.isEmpty) {
    return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wifi_off_rounded,
                    color: _kAccent, size: 28),
              ),
              const SizedBox(height: 14),
                Text(provider.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: _kTextSub)),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _carregar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    final m          = _metricas;
    final operadores = _desempenhoOperadores;
    final receitaMax = operadores.isNotEmpty
        ? operadores.first.totalReceita
        : 0.0;

    return FadeTransition(
      opacity: _fadeAnim,
      child: RefreshIndicator(
        color: _kPrimary,
        onRefresh: _carregar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [

            // ── Card KPI principal ────────────────────────────────────────
            _KpiPrincipal(metricas: m, currencyFmt: _currencyFmt),
            const SizedBox(height: 12),

            // ── Grid KPIs secundários ─────────────────────────────────────
            Row(children: [
              Expanded(child: _KpiCard(
                label: 'Pedidos',
                valor: '${m.totalPedidos}',
                icone: Icons.receipt_long_outlined,
                cor: _kPrimary,
              )),
              const SizedBox(width: 10),
              Expanded(child: _KpiCard(
                label: 'Ticket médio',
                valor: _currencyFmt.format(m.ticketMedio),
                icone: Icons.analytics_outlined,
                cor: _kWarning,
              )),
            ]),
            const SizedBox(height: 12),

            // ── Breakdown produtos vs serviços ────────────────────────────
            _BreakdownCard(metricas: m, currencyFmt: _currencyFmt),
            const SizedBox(height: 12),

            // ── Desempenho dos operadores (só admin) ──────────────────────
            if (_ehAdmin && operadores.isNotEmpty) ...[
              _DesempenhoCard(
                operadores: operadores,
                receitaMax: receitaMax,
                currencyFmt: _currencyFmt,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── KPI Principal ────────────────────────────────────────────────────────────

class _KpiPrincipal extends StatelessWidget {
  final _Metricas    metricas;
  final NumberFormat currencyFmt;
  const _KpiPrincipal({required this.metricas, required this.currencyFmt});

  @override
  Widget build(BuildContext context) {
    final pctProd = metricas.totalReceita > 0
        ? metricas.totalProdutos / metricas.totalReceita
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kPrimary,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Text('RECEITA TOTAL',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Colors.white70,
                  letterSpacing: 1.2,
                )),
          ),
          const SizedBox(height: 12),
          Text(
            currencyFmt.format(metricas.totalReceita),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${metricas.totalPedidos} pedido${metricas.totalPedidos != 1 ? 's' : ''} finalizados',
            style: const TextStyle(fontSize: 13, color: Colors.white60),
          ),
          const SizedBox(height: 16),

          // Barra produtos vs serviços
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(
                  height: 5,
                  color: Colors.white.withOpacity(0.15),
                ),
                FractionallySizedBox(
                  widthFactor: pctProd.clamp(0.0, 1.0),
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            _Legenda(cor: Colors.white, texto: 'Produtos'),
            const SizedBox(width: 14),
            _Legenda(cor: Colors.white38, texto: 'Serviços'),
          ]),
        ],
      ),
    );
  }
}

class _Legenda extends StatelessWidget {
  final Color cor;
  final String texto;
  const _Legenda({required this.cor, required this.texto});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: cor, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(texto,
            style: const TextStyle(fontSize: 11, color: Colors.white60)),
      ]);
}

// ─── KPI Card ─────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String   label;
  final String   valor;
  final IconData icone;
  final Color    cor;

  const _KpiCard({
    required this.label,
    required this.valor,
    required this.icone,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: _kCardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cor.withOpacity(0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: cor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icone, color: cor, size: 18),
            ),
            const SizedBox(height: 10),
            Text(valor,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: cor,
                  letterSpacing: -0.3,
                ),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: _kTextSub)),
          ],
        ),
      ),
    );
  }
}

// ─── Breakdown Produtos vs Serviços ──────────────────────────────────────────

class _BreakdownCard extends StatelessWidget {
  final _Metricas    metricas;
  final NumberFormat currencyFmt;
  const _BreakdownCard(
      {required this.metricas, required this.currencyFmt});

  @override
  Widget build(BuildContext context) {
    final total    = metricas.totalReceita;
    final pctProd  = total > 0 ? metricas.totalProdutos / total : 0.0;
    final pctServ  = total > 0 ? metricas.totalServicos / total : 0.0;

    return Card(
      elevation: 0,
      color: _kCardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.pie_chart_outline_rounded,
                    color: _kPrimary, size: 16),
              ),
              const SizedBox(width: 10),
              const Text('Vendas por tipo',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _kPrimary)),
            ]),
            const SizedBox(height: 16),
            _BreakdownLinha(
              label:     'Produtos',
              descricao: '${metricas.nItensProduto} item(ns)',
              receita:   metricas.totalProdutos,
              pct:       pctProd,
              cor:       _kPrimary,
              icone:     Icons.inventory_2_outlined,
              currencyFmt: currencyFmt,
            ),
            const SizedBox(height: 14),
            _BreakdownLinha(
              label:     'Serviços',
              descricao: '${metricas.nItensServico} item(ns)',
              receita:   metricas.totalServicos,
              pct:       pctServ,
              cor:       _kAccent,
              icone:     Icons.miscellaneous_services_outlined,
              currencyFmt: currencyFmt,
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakdownLinha extends StatelessWidget {
  final String       label;
  final String       descricao;
  final double       receita;
  final double       pct;
  final Color        cor;
  final IconData     icone;
  final NumberFormat currencyFmt;

  const _BreakdownLinha({
    required this.label,
    required this.descricao,
    required this.receita,
    required this.pct,
    required this.cor,
    required this.icone,
    required this.currencyFmt,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: cor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icone, color: cor, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87)),
              Text(descricao,
                  style: const TextStyle(
                      fontSize: 11, color: _kTextSub)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(currencyFmt.format(receita),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: cor)),
            Text('${(pct * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                    fontSize: 11, color: _kTextSub)),
          ],
        ),
      ]),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: pct.clamp(0.0, 1.0),
          backgroundColor: cor.withOpacity(0.1),
          valueColor: AlwaysStoppedAnimation<Color>(cor),
          minHeight: 4,
        ),
      ),
    ]);
  }
}

// ─── Desempenho dos Operadores ────────────────────────────────────────────────

class _DesempenhoCard extends StatelessWidget {
  final List<_DesempenhoOperador> operadores;
  final double       receitaMax;
  final NumberFormat currencyFmt;

  const _DesempenhoCard({
    required this.operadores,
    required this.receitaMax,
    required this.currencyFmt,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: _kCardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho
            Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.leaderboard_rounded,
                    color: _kPrimary, size: 16),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Desempenho por operador',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _kPrimary)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: _kPrimary.withOpacity(0.18)),
                ),
                child: Text(
                  '${operadores.length} op.',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _kPrimary),
                ),
              ),
            ]),
            const SizedBox(height: 16),

            // Lista
            ...operadores.asMap().entries.map((e) {
              final idx     = e.key;
              final op      = e.value;
              final cor     = _kAvatarCores[idx % _kAvatarCores.length];
              final pct     = receitaMax > 0
                  ? (op.totalReceita / receitaMax).clamp(0.0, 1.0)
                  : 0.0;
              final isLider = idx == 0;

              return Padding(
                padding: EdgeInsets.only(
                    bottom: idx < operadores.length - 1 ? 14 : 0),
                child: _OperadorLinha(
                  posicao:    idx + 1,
                  operador:   op,
                  cor:        cor,
                  pct:        pct,
                  isLider:    isLider,
                  currencyFmt: currencyFmt,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _OperadorLinha extends StatelessWidget {
  final int                  posicao;
  final _DesempenhoOperador  operador;
  final Color                cor;
  final double               pct;
  final bool                 isLider;
  final NumberFormat         currencyFmt;

  const _OperadorLinha({
    required this.posicao,
    required this.operador,
    required this.cor,
    required this.pct,
    required this.isLider,
    required this.currencyFmt,
  });

  @override
  Widget build(BuildContext context) {
    final partes   = operador.nome.trim().split(' ');
    final iniciais = partes.length >= 2
        ? '${partes.first[0]}${partes.last[0]}'.toUpperCase()
        : operador.nome
            .substring(0, operador.nome.length.clamp(1, 2))
            .toUpperCase();

    return Column(children: [
      Row(children: [
        // Posição
        SizedBox(
          width: 22,
          child: Text(
            '#$posicao',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isLider ? _kWarning : _kTextSub,
            ),
          ),
        ),
        const SizedBox(width: 6),

        // Avatar
        Stack(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: cor.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: cor.withOpacity(isLider ? 0.6 : 0.25),
                width: isLider ? 1.5 : 1,
              ),
            ),
            child: Center(
              child: Text(iniciais,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: cor)),
            ),
          ),
          if (isLider)
            Positioned(
              right: 0, top: 0,
              child: Container(
                width: 13, height: 13,
                decoration: BoxDecoration(
                  color: _kWarning,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Icon(Icons.star_rounded,
                    color: Colors.white, size: 7),
              ),
            ),
        ]),
        const SizedBox(width: 10),

        // Nome + sub
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(operador.nome,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87),
                  overflow: TextOverflow.ellipsis),
              Text(
                '${operador.totalPedidos} pedido${operador.totalPedidos != 1 ? 's' : ''}'
                ' · ticket ${currencyFmt.format(operador.ticketMedio)}',
                style: const TextStyle(
                    fontSize: 10, color: _kTextSub),
              ),
            ],
          ),
        ),

        // Receita
        Text(
          currencyFmt.format(operador.totalReceita),
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: cor),
        ),
      ]),
      const SizedBox(height: 7),
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: pct,
          backgroundColor: cor.withOpacity(0.08),
          valueColor: AlwaysStoppedAnimation<Color>(
              cor.withOpacity(isLider ? 1.0 : 0.55)),
          minHeight: 3,
        ),
      ),
    ]);
  }
}