import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:api_compartilhado/api_compartilhado.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/filtros_listagem.dart';
import 'servico_form_screen.dart';

const _kVermelho   = Color(0xFFC8102E);
const _kAzul       = Color(0xFF1B2A6B);
const _kBranco     = Colors.white;
const _kCinzaClaro = Color(0xFFF4F5F7);
const _kCinzaTexto = Color(0xFF6B7280);

class ServicoListScreen extends StatefulWidget {
  const ServicoListScreen({Key? key}) : super(key: key);

  @override
  State<ServicoListScreen> createState() => _ServicoListScreenState();
}

class _ServicoListScreenState extends State<ServicoListScreen> {
  // ── Filtros ──────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  String _busca = '';
  double _precoMin = 0;
  double _precoMax = double.infinity;
  EstadoFiltro _estado = EstadoFiltro.todos;

  bool get _temFiltros =>
      _busca.isNotEmpty ||
      _precoMin > 0 ||
      _precoMax != double.infinity ||
      _estado != EstadoFiltro.todos;

  void _limparFiltros() {
    _searchCtrl.clear();
    setState(() {
      _busca = '';
      _precoMin = 0;
      _precoMax = double.infinity;
      _estado = EstadoFiltro.todos;
    });
  }

  List<ServicoModel> _filtrar(List<ServicoModel> todos) {
    return todos.where((s) {
      final matchNome = s.nomeServico.toLowerCase().contains(_busca);
      final matchPreco =
          s.precoUnitario >= _precoMin && s.precoUnitario <= _precoMax;
      final matchEstado = _estado == EstadoFiltro.todos ||
          (_estado == EstadoFiltro.ativos ? s.ativo : !s.ativo);
      return matchNome && matchPreco && matchEstado;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ServicoProvider>().carregarTodosOsServicos();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleStatus(ServicoModel servico) async {
    await context.read<ServicoProvider>().toggleEstadoServico(servico.idServico);

    if (!mounted) return;

    final provider = context.read<ServicoProvider>();
    if (provider.errorMessage == null) {
      final atualizado = provider.servicos
          .firstWhere((s) => s.idServico == servico.idServico);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Serviço "${servico.nomeServico}" agora está '
            '${atualizado.ativo ? 'Ativo' : 'Inativo'}',
          ),
          backgroundColor: atualizado.ativo ? Colors.green : Colors.orange,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao alterar status: ${provider.errorMessage}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _navegarParaFormulario({ServicoModel? servico}) async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ServicoFormScreen(servico: servico),
      ),
    );

    if (resultado == true && mounted) {
      context.read<ServicoProvider>().carregarTodosOsServicos();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ServicoProvider>();

    return Scaffold(
      backgroundColor: _kCinzaClaro,
      appBar: AppBar(
        title: const Text('Catálogo de Serviços'),
        backgroundColor: _kAzul,
        foregroundColor: _kBranco,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                context.read<ServicoProvider>().carregarTodosOsServicos(),
            tooltip: 'Atualizar',
          ),
        ],
      ),
      drawer: const AppSidebar(currentRoute: '/gerenciar_servicos'),
      body: _buildBody(provider),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navegarParaFormulario(),
        backgroundColor: _kVermelho,
        foregroundColor: _kBranco,
        icon: const Icon(Icons.add),
        label: const Text('Novo Serviço'),
      ),
    );
  }

  Widget _buildBody(ServicoProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator(color: _kAzul));
    }

    if (provider.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: _kVermelho),
              const SizedBox(height: 16),
              Text(
                provider.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _kCinzaTexto),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () =>
                    context.read<ServicoProvider>().carregarTodosOsServicos(),
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar Novamente'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _kAzul, foregroundColor: _kBranco),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.servicos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.miscellaneous_services_outlined,
                size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Nenhum serviço cadastrado',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    final filtrados = _filtrar(provider.servicos);

    return Column(
      children: [
        _buildFiltros(provider.servicos, filtrados.length),
        Expanded(
          child: filtrados.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('Nenhum serviço corresponde ao filtro',
                          style: TextStyle(
                              fontSize: 16, color: Colors.grey[500])),
                      TextButton(
                        onPressed: _limparFiltros,
                        child: const Text('Limpar filtros'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: _kAzul,
                  onRefresh: () => context
                      .read<ServicoProvider>()
                      .carregarTodosOsServicos(),
                  child: Column(
                    children: [
                      Container( /* cabeçalho da tabela: inalterado */ ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                          itemCount: filtrados.length,
                          itemBuilder: (_, i) => _ServicoLinhaTabela(
                            servico: filtrados[i],
                            isAlternate: i.isOdd,
                            onEditar: () => _navegarParaFormulario(
                                servico: filtrados[i]),
                            onToggle: () => _toggleStatus(filtrados[i]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
    Widget _buildFiltros(List<ServicoModel> todos, int totalFiltrado) {
    final precoMaxAbs = todos.isEmpty
        ? 0.0
        : todos.map((s) => s.precoUnitario).reduce((a, b) => a > b ? a : b);

    return Container(
      color: _kAzul.withOpacity(0.04),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        children: [
          FiltroPesquisa(
            controller: _searchCtrl,
            hint: 'Pesquisar serviço…',
            onChanged: (v) => setState(() => _busca = v.toLowerCase()),
            onClear: () {
              _searchCtrl.clear();
              setState(() => _busca = '');
            },
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FiltroPrecoRow(
                  precoMin: _precoMin,
                  precoMax: _precoMax,
                  precoMaxAbsoluto: precoMaxAbs,
                  onChanged: (min, max) =>
                      setState(() { _precoMin = min; _precoMax = max; }),
                ),
                const SizedBox(width: 12),
                FiltroEstadoChips(
                  selecionado: _estado,
                  onChanged: (e) => setState(() => _estado = e),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_temFiltros)
                TextButton.icon(
                  onPressed: _limparFiltros,
                  icon: const Icon(Icons.filter_alt_off, size: 14),
                  label: const Text('Limpar filtros',
                      style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    foregroundColor: _kVermelho,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 24),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
              else
                const SizedBox.shrink(),
              Text('$totalFiltrado serviço(s) encontrado(s)',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Widget de linha — sem alterações de lógica ─────────────────────────────

class _ServicoLinhaTabela extends StatelessWidget {
  const _ServicoLinhaTabela({
    required this.servico,
    required this.isAlternate,
    required this.onEditar,
    required this.onToggle,
  });

  final ServicoModel servico;
  final bool         isAlternate;
  final VoidCallback onEditar;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final ativo = servico.ativo;

    return Container(
      decoration: BoxDecoration(
        color: isAlternate ? const Color(0xFFF0F2FA) : Colors.white,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE8EAF0)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Ícone + Nome
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: ativo
                          ? _kAzul.withOpacity(0.08)
                          : Colors.grey.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.settings_suggest_rounded,
                      size: 16,
                      color: ativo ? _kAzul : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      servico.nomeServico,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ativo ? _kAzul : _kCinzaTexto,
                        decoration:
                            ativo ? null : TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Descrição
            Expanded(
              flex: 3,
              child: Text(
                servico.descricao?.isNotEmpty == true
                    ? servico.descricao!
                    : '—',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),

            // Preço
            Expanded(
              flex: 2,
              child: Text(
                'MZN ${servico.precoUnitario.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _kAzul,
                ),
              ),
            ),

            // Unidade
            Expanded(
              flex: 1,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  servico.unidade,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            // Estado
            Expanded(
              flex: 1,
              child: GestureDetector(
                onTap: onToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: ativo ? Colors.green[50] : Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: ativo ? Colors.green : Colors.orange,
                    ),
                  ),
                  child: Text(
                    ativo ? 'Ativo' : 'Inativo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color:
                          ativo ? Colors.green[700] : Colors.orange[700],
                    ),
                  ),
                ),
              ),
            ),

            // Ações
            SizedBox(
              width: 100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Tooltip(
                    message: ativo ? 'Desativar' : 'Ativar',
                    child: Transform.scale(
                      scale: 0.75,
                      child: Switch(
                        value: ativo,
                        onChanged: (_) => onToggle(),
                        activeColor: Colors.green,
                        inactiveThumbColor: Colors.orange,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Editar',
                    child: InkWell(
                      onTap: onEditar,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _kAzul.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.edit_rounded,
                            size: 16, color: _kAzul),
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