// lib/screens/importar_backup_screen.dart

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:api_compartilhado/api_compartilhado.dart';

import '../theme/app_theme.dart';
import '../widgets/app_sidebar.dart';

// Nomes legíveis das tabelas do backup
const _rotulos = {
  'tipo_pagamento': 'Tipos de pagamento',
  'usuario': 'Utilizadores',
  'cliente': 'Clientes',
  'fornecedor': 'Fornecedores',
  'tipo_despesa': 'Tipos de despesa',
  'categoria': 'Categorias',
  'marca': 'Marcas',
  'produto': 'Produtos',
  'servico': 'Serviços',
  'pedido': 'Pedidos',
  'item_pedido': 'Itens de pedido (produtos)',
  'item_pedido_servico': 'Itens de pedido (serviços)',
  'pedido_credito_parcela': 'Parcelas de crédito',
  'pedido_credito_pagamento': 'Pagamentos de crédito',
  'documento_fiscal': 'Documentos fiscais',
  'cotacao': 'Cotações',
  'cotacao_item_produto': 'Itens de cotação (produtos)',
  'cotacao_item_servico': 'Itens de cotação (serviços)',
  'despesa': 'Despesas',
};

class _Prog {
  final String tabela;
  final int feito, total;
  const _Prog(this.tabela, this.feito, this.total);
}

class ImportarBackupScreen extends StatefulWidget {
  const ImportarBackupScreen({super.key});

  @override
  State<ImportarBackupScreen> createState() => _ImportarBackupScreenState();
}

class _ImportarBackupScreenState extends State<ImportarBackupScreen> {
  final _servico = BackupImportService();
  final _progresso = ValueNotifier<_Prog?>(null);

  String? _caminho;
  ImportResultado? _res;
  String? _erro;
  bool _ocupado = false;

  String? get _nomeFicheiro => _caminho?.split(RegExp(r'[\\/]')).last;

  @override
  void dispose() {
    _progresso.dispose();
    super.dispose();
  }

  // ── Acções ────────────────────────────────────────────────────────────────

  Future<void> _escolher() async {
    final r = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    final path = (r == null || r.isEmpty) ? null : r.first.path;
    if (path == null) return;
    setState(() {
      _caminho = path;
      _res = null;
      _erro = null;
    });
  }

  Future<void> _executar({required bool simular}) async {
    if (_caminho == null || _ocupado) return;

    if (!simular && !await _confirmar()) return;

    HapticFeedback.selectionClick();
    setState(() {
      _ocupado = true;
      _erro = null;
      _res = null;
    });
    _progresso.value = null;

    try {
      final res = await _servico.importar(
        _caminho!,
        simular: simular,
        onProgresso: (tabela, feito, total) {
          // limita as reconstruções da UI
          if (feito == total || feito % 25 == 0) {
            _progresso.value = _Prog(tabela, feito, total);
          }
        },
      );
      if (!mounted) return;
      setState(() => _res = res);

      if (!simular) {
        _recarregarProviders();
        _snack('Importação concluída', context.cores.sucesso);
      }
    } on BackupImportException catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } catch (e) {
      if (mounted) setState(() => _erro = 'Erro inesperado: $e');
    } finally {
      _progresso.value = null;
      if (mounted) setState(() => _ocupado = false);
    }
  }

  /// Os dados mudaram por baixo dos providers → refrescar o essencial.
  void _recarregarProviders() {
    try {
      context.read<ProdutoProvider>().listarAtivos();
      context.read<PedidoProvider>().listarPorStatus('finalizado');
    } catch (_) {}
  }

  Future<bool> _confirmar() async {
    final c = context.cores;
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Importar backup',
                style: TextStyle(color: c.marca, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_nomeFicheiro ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _caixa(
                  Icons.shield_outlined,
                  'Será criada uma cópia de segurança da base de dados antes de gravar.',
                  c.info,
                ),
                const SizedBox(height: 8),
                _caixa(
                  Icons.sync_problem_outlined,
                  'Alterações locais ainda por sincronizar nunca são sobrescritas.',
                  c.aviso,
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.marcaBotao,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Importar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _snack(String msg, Color cor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: cor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            context.escuro ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: context.cores.fundo,
        drawer: const AppSidebar(currentRoute: '/importar_backup'),
        body: SafeArea(
          child: Column(children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _buildCardFicheiro(),
                  const SizedBox(height: 12),
                  _buildAcoes(),
                  if (_ocupado) ...[
                    const SizedBox(height: 12),
                    _buildProgresso(),
                  ],
                  if (_erro != null) ...[
                    const SizedBox(height: 12),
                    _buildErro(),
                  ],
                  if (_res != null) ...[
                    const SizedBox(height: 12),
                    _buildResultado(_res!),
                  ],
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.azulMarca,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Row(children: [
        Builder(
          builder: (ctx) => GestureDetector(
            onTap: () => Scaffold.of(ctx).openDrawer(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.menu_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Importar Backup',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.4,
                  )),
              Text('Restaurar dados do servidor para este dispositivo',
                  style: TextStyle(fontSize: 12, color: Colors.white70)),
            ],
          ),
        ),
      ]),
    );
  }

  // ── Ficheiro ──────────────────────────────────────────────────────────────

  Widget _buildCardFicheiro() {
    final c = context.cores;
    final temFicheiro = _caminho != null;
    return _card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _ocupado ? null : _escolher,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: c.marca.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                temFicheiro
                    ? Icons.description_rounded
                    : Icons.upload_file_rounded,
                color: c.marca,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    temFicheiro ? _nomeFicheiro! : 'Seleccionar ficheiro de backup',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: c.textoPrincipal),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    temFicheiro
                        ? 'Toca para escolher outro'
                        : 'Ficheiro .json exportado do STech PDV (servidor)',
                    style: TextStyle(fontSize: 11, color: c.textoSecundario),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.desactivado),
          ]),
        ),
      ),
    );
  }

  Widget _buildAcoes() {
    final c = context.cores;
    final pode = _caminho != null && !_ocupado;
    return Row(children: [
      Expanded(
        child: SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: pode ? () => _executar(simular: true) : null,
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: const Text('Simular',
                style: TextStyle(fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: pode ? () => _executar(simular: false) : null,
            icon: const Icon(Icons.download_done_rounded, size: 18),
            label: const Text('Importar',
                style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: c.marcaBotao,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ),
    ]);
  }

  // ── Progresso / erro ──────────────────────────────────────────────────────

  Widget _buildProgresso() {
    final c = context.cores;
    return _card(
      child: ValueListenableBuilder<_Prog?>(
        valueListenable: _progresso,
        builder: (_, p, __) {
          final valor = (p == null || p.total == 0) ? null : p.feito / p.total;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              p == null
                  ? 'A ler e validar o ficheiro…'
                  : '${_rotulos[p.tabela] ?? p.tabela} · ${p.feito}/${p.total}',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.textoPrincipal),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: valor,
                minHeight: 5,
                color: c.marca,
                backgroundColor: c.marca.withValues(alpha: 0.12),
              ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _buildErro() {
    final c = context.cores;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.perigoFundo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.perigo.withValues(alpha: 0.4)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.error_outline_rounded, color: c.perigo, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(_erro!,
              style: TextStyle(
                  color: c.perigo, fontSize: 13, fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }

  // ── Resultado ─────────────────────────────────────────────────────────────

  Widget _buildResultado(ImportResultado r) {
    final c = context.cores;
    final linhas = r.tabelas.entries
        .where((e) =>
            e.value.inseridos +
                e.value.atualizados +
                e.value.preservados +
                e.value.erros >
            0)
        .toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Banner de estado
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: r.simulacao ? c.infoFundo : c.sucessoFundo,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: (r.simulacao ? c.info : c.sucesso).withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          Icon(
            r.simulacao ? Icons.visibility_rounded : Icons.check_circle_rounded,
            color: r.simulacao ? c.info : c.sucesso,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              r.simulacao
                  ? 'Simulação — nada foi gravado'
                  : 'Importação concluída',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: r.simulacao ? c.info : c.sucesso),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 12),

      // Totais
      Row(children: [
        Expanded(child: _Stat('Novos', r.inseridos, c.sucesso)),
        const SizedBox(width: 8),
        Expanded(child: _Stat('Actualizados', r.atualizados, c.info)),
        const SizedBox(width: 8),
        Expanded(child: _Stat('Iguais', r.ignorados, c.textoSecundario)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _Stat('Preservados', r.preservados, c.aviso)),
        const SizedBox(width: 8),
        Expanded(child: _Stat('Erros', r.erros, c.perigo)),
        const SizedBox(width: 8),
        const Expanded(child: SizedBox()),
      ]),
      if (r.preservados > 0) ...[
        const SizedBox(height: 8),
        _caixa(
          Icons.sync_problem_outlined,
          '${r.preservados} registo(s) têm alterações locais por sincronizar e foram mantidos.',
          c.aviso,
        ),
      ],

      // Cópia de segurança
      if (r.copiaSeguranca != null) ...[
        const SizedBox(height: 8),
        _caixa(Icons.shield_outlined,
            'Cópia de segurança: ${r.copiaSeguranca!.split(RegExp(r'[\\/]')).last}',
            c.info),
      ],

      // Detalhe por tabela
      if (linhas.isNotEmpty) ...[
        const SizedBox(height: 12),
        _card(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text('Detalhe por tabela',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13, color: c.marca)),
            const SizedBox(height: 8),
            for (var i = 0; i < linhas.length; i++) ...[
              if (i > 0) const Divider(height: 14),
              _LinhaTabela(
                nome: _rotulos[linhas[i].key] ?? linhas[i].key,
                est: linhas[i].value,
              ),
            ],
          ]),
        ),
      ],

      // Avisos
      if (r.avisos.isNotEmpty) ...[
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: c.superficie,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: c.borda),
          ),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            leading: Icon(Icons.warning_amber_rounded, color: c.aviso),
            title: Text('Avisos (${r.avisos.length})',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13)),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: r.avisos
                      .map((a) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('• $a',
                                style: TextStyle(
                                    fontSize: 11, color: c.textoSecundario)),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    ]);
  }

  // ── Helpers visuais ───────────────────────────────────────────────────────

  Widget _card({required Widget child}) => Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: context.cores.superficie,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: context.cores.borda),
        ),
        child: Padding(padding: const EdgeInsets.all(12), child: child),
      );

  Widget _caixa(IconData icon, String texto, Color cor) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cor.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Icon(icon, size: 16, color: cor),
          const SizedBox(width: 8),
          Expanded(
              child: Text(texto, style: TextStyle(fontSize: 11, color: cor))),
        ]),
      );
}

class _Stat extends StatelessWidget {
  final String label;
  final int valor;
  final Color cor;
  const _Stat(this.label, this.valor, this.cor);

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.superficie,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$valor',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: cor)),
        Text(label,
            style: TextStyle(fontSize: 11, color: c.textoSecundario),
            overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

class _LinhaTabela extends StatelessWidget {
  final String nome;
  final EstatTabela est;
  const _LinhaTabela({required this.nome, required this.est});

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    Widget chip(String t, int n, Color cor) => n == 0
        ? const SizedBox.shrink()
        : Container(
            margin: const EdgeInsets.only(right: 6, top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('$n $t',
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700, color: cor)),
          );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(nome,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: c.textoPrincipal)),
      Wrap(children: [
        chip('novos', est.inseridos, c.sucesso),
        chip('actualizados', est.atualizados, c.info),
        chip('preservados', est.preservados, c.aviso),
        chip('erros', est.erros, c.perigo),
      ]),
    ]);
  }
}