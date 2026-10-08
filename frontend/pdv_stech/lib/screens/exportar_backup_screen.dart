import 'dart:io';

import 'package:api_compartilhado/api_compartilhado.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../widgets/app_sidebar.dart';
import 'importar_backup_screen.dart';

const _rotulos = {
  'perfil': 'Perfis de utilizador',
  'perfil_cliente': 'Perfis de cliente',
  'tipo_documento_fiscal': 'Tipos de documento fiscal',
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
  'venda_credito': 'Vendas a crédito (servidor)',
  'venda_credito_parcela': 'Parcelas de venda a crédito (servidor)',
  'pagamento_credito': 'Pagamentos de crédito (servidor)',
  'historico_senhas': 'Histórico de senhas',
  'password_resets': 'Recuperações de senha',
  'logs': 'Registos de auditoria',
  'movimento_estoque': 'Movimentos de estoque',
};

/// Tabelas que o importador do app sabe mapear + as de apoio
/// (para preencher nome_perfil, tipo_codigo, etc.).
const _compativelComApp = {
  'perfil', 'perfil_cliente', 'tipo_documento_fiscal', 'tipo_pagamento',
  'usuario', 'cliente', 'fornecedor', 'tipo_despesa', 'categoria', 'marca',
  'produto', 'servico', 'pedido', 'item_pedido', 'item_pedido_servico',
  'pedido_credito_parcela', 'pedido_credito_pagamento', 'documento_fiscal',
  'cotacao', 'cotacao_item_produto', 'cotacao_item_servico', 'despesa',
};

String _tamanho(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
  return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
}

class ExportarBackupScreen extends StatefulWidget {
  const ExportarBackupScreen({super.key});

  @override
  State<ExportarBackupScreen> createState() => _ExportarBackupScreenState();
}

class _ExportarBackupScreenState extends State<ExportarBackupScreen> {
  final _servico = BackupExportService();
  final _bytes = ValueNotifier<int>(0);

  List<TabelaBackup> _tabelas = [];
  bool _carregando = true;
  String? _erroLista;

  bool _completo = true;
  bool _sensiveis = false;
  BackupFormato _formato = BackupFormato.json;
  final Set<String> _sel = {};

  bool _ocupado = false;
  String? _erro;
  ExportResultado? _res;
  String? _guardadoEm;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _bytes.dispose();
    super.dispose();
  }

  // ── Acções ────────────────────────────────────────────────────────

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erroLista = null;
    });
    try {
      final t = await _servico.listarTabelas();
      if (mounted) setState(() => _tabelas = t);
    } on BackupExportException catch (e) {
      if (mounted) setState(() => _erroLista = e.mensagem);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _selecionarCompativeis() => setState(() {
        _sel
          ..clear()
          ..addAll(_tabelas
              .map((t) => t.nome)
              .where(_compativelComApp.contains));
      });

  void _alternarSensiveis(bool v) => setState(() {
        _sensiveis = v;
        if (!v) _sel.removeWhere((n) => _tabelas.any((t) => t.nome == n && t.sensivel));
      });

  Future<void> _exportar() async {
    if (_ocupado) return;
    if (!_completo && _sel.isEmpty) {
      _snack('Seleccione pelo menos uma tabela.', context.cores.aviso);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _ocupado = true;
      _erro = null;
      _res = null;
      _guardadoEm = null;
    });
    _bytes.value = 0;

    try {
      final res = await _servico.exportar(
        tabelas: _completo ? null : _sel.toList(),
        formato: _formato,
        incluirSensiveis: _sensiveis,
        onProgresso: (b) => _bytes.value = b,
      );
      if (!mounted) return;
      setState(() => _res = res);
      await _guardar();
    } on BackupExportException catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } catch (e) {
      if (mounted) setState(() => _erro = 'Erro inesperado: $e');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _guardar() async {
    final r = _res;
    if (r == null) return;
    try {
      final destino = await _servico.guardar(r.ficheiro);
      if (!mounted) return;
      if (destino != null) {
        setState(() => _guardadoEm = destino);
        _snack('Backup guardado', context.cores.sucesso);
      }
    } catch (e) {
      _snack('Não foi possível guardar: $e', context.cores.perigo);
    }
  }

  Future<void> _abrir() async {
    final caminho = _guardadoEm ?? _res?.ficheiro.path;
    if (caminho != null) await _servico.abrir(caminho);
  }

  void _importarEste() {
    final r = _res;
    if (r == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ImportarBackupScreen(caminhoInicial: r.ficheiro.path),
    ));
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

  // ── Build ─────────────────────────────────────────────────────────

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
        drawer: const AppSidebar(currentRoute: '/exportar_backup'),
        body: SafeArea(
          child: Column(children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _buildEscopo(),
                  const SizedBox(height: 12),
                  _buildFormato(),
                  const SizedBox(height: 12),
                  _buildSensiveis(),
                  const SizedBox(height: 16),
                  _buildBotao(),
                  if (_ocupado) ...[
                    const SizedBox(height: 12),
                    _buildProgresso(),
                  ],
                  if (_erro != null) ...[
                    const SizedBox(height: 12),
                    _buildErro(_erro!),
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
              child: const Icon(Icons.menu_rounded, color: Colors.white, size: 18),
            ),
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Exportar Backup',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.4)),
              Text('Descarregar a base de dados do servidor',
                  style: TextStyle(fontSize: 12, color: Colors.white70)),
            ],
          ),
        ),
      ]),
    );
  }

  // ── Escopo: completo / tabelas ────────────────────────────────────

  Widget _buildEscopo() {
    final c = context.cores;
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _titulo('O que exportar'),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                  value: true,
                  icon: Icon(Icons.storage_rounded, size: 18),
                  label: Text('Completo')),
              ButtonSegment(
                  value: false,
                  icon: Icon(Icons.checklist_rounded, size: 18),
                  label: Text('Escolher tabelas')),
            ],
            selected: {_completo},
            onSelectionChanged:
                _ocupado ? null : (s) => setState(() => _completo = s.first),
          ),
        ),
        if (_completo)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Todas as tabelas de dados. Senhas e tabelas sensíveis ficam de fora, salvo se activar a opção abaixo.',
              style: TextStyle(fontSize: 11, color: c.textoSecundario),
            ),
          )
        else ...[
          const SizedBox(height: 10),
          if (_carregando)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_erroLista != null) ...[
            _buildErro(_erroLista!),
            TextButton.icon(
              onPressed: _carregar,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar de novo'),
            ),
          ] else ...[
            Wrap(spacing: 8, runSpacing: 4, children: [
              ActionChip(
                avatar: const Icon(Icons.phone_android_rounded, size: 16),
                label: const Text('Compatível com o app'),
                onPressed: _ocupado ? null : _selecionarCompativeis,
              ),
              ActionChip(
                label: const Text('Todas'),
                onPressed: _ocupado
                    ? null
                    : () => setState(() => _sel
                      ..clear()
                      ..addAll(_tabelas
                          .where((t) => _sensiveis || !t.sensivel)
                          .map((t) => t.nome))),
              ),
              ActionChip(
                label: const Text('Nenhuma'),
                onPressed: _ocupado ? null : () => setState(_sel.clear),
              ),
            ]),
            const SizedBox(height: 4),
            Text('${_sel.length} de ${_tabelas.length} seleccionadas',
                style: TextStyle(fontSize: 11, color: c.textoSecundario)),
            for (final t in _tabelas) _tileTabela(t),
          ],
        ],
      ]),
    );
  }

  Widget _tileTabela(TabelaBackup t) {
    final c = context.cores;
    final bloqueada = t.sensivel && !_sensiveis;
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: _sel.contains(t.nome),
      onChanged: (_ocupado || bloqueada)
          ? null
          : (v) => setState(() => v == true ? _sel.add(t.nome) : _sel.remove(t.nome)),
      title: Text(_rotulos[t.nome] ?? t.nome,
          style: TextStyle(fontSize: 13, color: c.textoPrincipal)),
      subtitle: Text(
        '${t.nome} · ~${t.linhas} linhas${t.sensivel ? ' · sensível' : ''}',
        style: TextStyle(
            fontSize: 10, color: t.sensivel ? c.aviso : c.textoSecundario),
      ),
    );
  }

  // ── Formato ───────────────────────────────────────────────────────

  Widget _buildFormato() {
    final c = context.cores;
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _titulo('Formato'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          for (final f in BackupFormato.values)
            ChoiceChip(
              label: Text(f.rotulo),
              selected: _formato == f,
              onSelected: _ocupado ? null : (_) => setState(() => _formato = f),
            ),
        ]),
        const SizedBox(height: 8),
        Text(_formato.descricao,
            style: TextStyle(fontSize: 11, color: c.textoSecundario)),
        if (_formato != BackupFormato.json)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Para restaurar neste app use JSON. Os outros formatos não são importáveis no ecrã de importação.',
              style: TextStyle(fontSize: 11, color: c.aviso),
            ),
          ),
      ]),
    );
  }

  Widget _buildSensiveis() {
    final c = context.cores;
    return _card(
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _sensiveis,
        onChanged: _ocupado ? null : _alternarSensiveis,
        title: const Text('Incluir dados sensíveis',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Text(
          'Hashes de senha, histórico de senhas e recuperações. Guarde o ficheiro em local seguro.',
          style: TextStyle(fontSize: 11, color: _sensiveis ? c.perigo : c.textoSecundario),
        ),
      ),
    );
  }

  // ── Acção / progresso / erro / resultado ──────────────────────────

  Widget _buildBotao() {
    final c = context.cores;
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _ocupado ? null : _exportar,
        icon: const Icon(Icons.download_rounded, size: 18),
        label: Text(_completo ? 'Exportar tudo' : 'Exportar selecção',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: c.marcaBotao,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildProgresso() {
    final c = context.cores;
    return _card(
      child: ValueListenableBuilder<int>(
        valueListenable: _bytes,
        builder: (_, b, __) => Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            b == 0 ? 'A aguardar o servidor…' : 'A descarregar… ${_tamanho(b)}',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: c.textoPrincipal),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              minHeight: 5,
              color: c.marca,
              backgroundColor: c.marca.withValues(alpha: 0.12),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildErro(String msg) {
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
          child: Text(msg,
              style: TextStyle(
                  color: c.perigo, fontSize: 13, fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }

  Widget _buildResultado(ExportResultado r) {
    final c = context.cores;
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.check_circle_rounded, color: c.sucesso, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Backup gerado · ${_tamanho(r.bytes)}',
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13, color: c.sucesso)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(r.nome, style: TextStyle(fontSize: 12, color: c.textoPrincipal)),
        if (_guardadoEm != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Guardado em: $_guardadoEm',
                style: TextStyle(fontSize: 10, color: c.textoSecundario)),
          ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(
            onPressed: _guardar,
            icon: const Icon(Icons.save_alt_rounded, size: 18),
            label: Text(_guardadoEm == null ? 'Guardar como…' : 'Guardar outra cópia'),
          ),
          OutlinedButton.icon(
            onPressed: _abrir,
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Abrir'),
          ),
          if (r.formato == BackupFormato.json)
            ElevatedButton.icon(
              onPressed: _importarEste,
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: const Text('Importar este ficheiro'),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.marcaBotao,
                foregroundColor: Colors.white,
              ),
            ),
        ]),
      ]),
    );
  }

  // ── Helpers visuais ───────────────────────────────────────────────

  Widget _titulo(String t) => Text(t,
      style: TextStyle(
          fontWeight: FontWeight.bold, fontSize: 13, color: context.cores.marca));

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
}