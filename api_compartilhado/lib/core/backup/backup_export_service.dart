import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:api_compartilhado/api_compartilhado.dart';

enum BackupFormato {
  sql('SQL', 'sql', 'Script INSERT para restauro no servidor (PostgreSQL)'),
  csv('CSV', 'zip', 'Um .csv por tabela, dentro de um ZIP'),
  json('JSON', 'json', 'Formato usado para importar no app'),
  xlsx('Excel', 'xlsx', 'Uma folha por tabela (máx. 1.048.575 linhas)');

  const BackupFormato(this.rotulo, this.extensao, this.descricao);
  final String rotulo, extensao, descricao;

  /// Valor esperado pelo enum do backend (SQL, CSV, JSON, XLSX).
  String get api => name.toUpperCase();
}

class TabelaBackup {
  const TabelaBackup(this.nome, this.linhas, this.sensivel);
  final String nome;
  final int linhas;
  final bool sensivel;

  factory TabelaBackup.fromJson(Map<String, dynamic> j) => TabelaBackup(
        j['nome'] as String,
        (j['linhasEstimadas'] as num?)?.toInt() ?? 0,
        j['sensivel'] == true,
      );
}

class ExportResultado {
  const ExportResultado(this.ficheiro, this.bytes, this.formato);
  final File ficheiro;
  final int bytes;
  final BackupFormato formato;
  String get nome => p.basename(ficheiro.path);
}

/// Erro JÁ tratado: [mensagem] é sempre segura para mostrar ao utilizador.
class BackupExportException implements Exception {
  BackupExportException(this.mensagem, {this.chaveInvalida = false});
  final String mensagem;

  /// true quando o servidor rejeitou a chave (401/403): a chave guardada
  /// em memória deve ser esquecida para voltar a ser pedida.
  final bool chaveInvalida;

  @override
  String toString() => mensagem;
}

class BackupExportService {
  static String? chaveSessao;

  Map<String, String> get _headers => {
        ...ApiConfig.defaultHeaders,
        if (chaveSessao != null) 'X-Backup-Key': chaveSessao!,
      };

  // ── Lista de tabelas ──────────────────────────────────────────────

  Future<List<TabelaBackup>> listarTabelas() async {
    try {
      final r = await http
          .get(Uri.parse(ApiConfig.backupTabelasUrl), headers: _headers)
          .timeout(ApiConfig.backupTimeout);
      if (r.statusCode != 200) {
        throw _erroHttp(r.statusCode, r.body);
      }
      final lista = jsonDecode(utf8.decode(r.bodyBytes)) as List;
      return lista
          .map((e) => TabelaBackup.fromJson(e as Map<String, dynamic>))
          .toList();
    } on BackupExportException {
      rethrow;
    } catch (e, st) {
      throw BackupExportException(_erroRede(e, st));
    }
  }

  // ── Exportação (streaming para ficheiro temporário) ───────────────

  /// [tabelas] null/vazio = dump completo.
  Future<ExportResultado> exportar({
    List<String>? tabelas,
    required BackupFormato formato,
    bool incluirSensiveis = false,
    void Function(int bytesRecebidos)? onProgresso,
  }) async {
    final client = http.Client();
    File? ficheiro;
    try {
      final req = http.Request('POST', Uri.parse(ApiConfig.backupExportarUrl))
        ..headers.addAll(_headers)
        ..body = jsonEncode({
          'tabelas': (tabelas == null || tabelas.isEmpty) ? null : tabelas,
          'formato': formato.api,
          'incluirSensiveis': incluirSensiveis,
        });

      final resp = await client.send(req).timeout(ApiConfig.backupTimeout);

      if (resp.statusCode != 200) {
        throw _erroHttp(
            resp.statusCode, await resp.stream.bytesToString());
      }

      final nome = _nomeDe(resp.headers['content-disposition']) ??
          'stech_backup_${DateTime.now().millisecondsSinceEpoch}.${formato.extensao}';
      final dir = await getTemporaryDirectory();
      ficheiro = File(p.join(dir.path, nome));

      final sink = ficheiro.openWrite();
      var total = 0;
      try {
        await for (final chunk
            in resp.stream.timeout(ApiConfig.backupTimeout)) {
          sink.add(chunk);
          total += chunk.length;
          onProgresso?.call(total);
        }
      } catch (_) {
        await sink.close();
        rethrow; // o catch externo apaga o ficheiro parcial
      }
      await sink.close();

      if (total == 0) {
        throw BackupExportException('O servidor devolveu um ficheiro vazio.');
      }
      return ExportResultado(ficheiro, total, formato);
    } on BackupExportException {
      await _apagar(ficheiro);
      rethrow;
    } catch (e, st) {
      await _apagar(ficheiro);
      throw BackupExportException(_erroRede(e, st));
    } finally {
      client.close();
    }
  }

  // ── Guardar / abrir ───────────────────────────────────────────────

  /// Devolve o caminho/URI escolhido, ou null se o utilizador cancelou.
  /// No file_picker 13 o próprio saveFile grava os bytes no destino.
  Future<String?> guardar(File f) async {
    final uri = await FilePicker.saveFile(
      dialogTitle: 'Guardar backup',
      fileName: p.basename(f.path),
      bytes: await f.readAsBytes(),
    );
    if (uri == null) return null;
    // desktop devolve file://..., Android pode devolver content://...
    return uri.scheme == 'file' ? uri.toFilePath() : uri.toString();
  }

  Future<void> abrir(String caminho) => OpenFilex.open(caminho);

  // ── Helpers ───────────────────────────────────────────────────────

  static String? _nomeDe(String? disposition) {
    if (disposition == null) return null;
    final m = RegExp(r'filename="?([^";]+)"?').firstMatch(disposition);
    final n = m?.group(1);
    return (n == null || n.isEmpty) ? null : p.basename(n); // evita path traversal
  }

  /// Texto vindo do servidor que parece técnico (stack, classe Java, HTML…).
  static final _pareceTecnico = RegExp(
    r'Exception|Caused by|\bat [\w$.]+\(|JSON parse|Cannot deserialize|'
    r'\b(?:java|javax|jakarta|org|com)\.\w+\.\w|<html|\n',
    caseSensitive: false,
  );

  /// Só aceitamos texto do servidor nos códigos em que ele é nosso
  /// (filtro da chave, validações) e só se for curto e legível.
  static String? _mensagemServidor(int codigo, String corpo) {
    if (!const {400, 403, 409, 422, 503}.contains(codigo)) return null;
    try {
      final j = jsonDecode(corpo);
      if (j is! Map) return null;
      final m = (j['message'] ?? j['mensagem'])?.toString().trim();
      if (m == null || m.isEmpty || m.length > 200) return null;
      if (_pareceTecnico.hasMatch(m)) return null;
      return m;
    } catch (_) {
      return null;
    }
  }

  static BackupExportException _erroHttp(int codigo, String corpo) {
    if (kDebugMode) debugPrint('[Backup] HTTP $codigo: $corpo');
    final texto = _mensagemServidor(codigo, corpo) ??
        switch (codigo) {
          400 => 'Pedido inválido (tabelas ou formato não aceites pelo servidor).',
          401 || 403 => 'Chave de backup inválida ou em falta.',
          404 => 'Endpoint de backup não encontrado no servidor.',
          503 => 'Backup desactivado no servidor.',
          >= 500 => 'O servidor encontrou um problema. Tente de novo dentro de instantes.',
          _ => 'Não foi possível concluir o pedido (código $codigo).',
        };
    return BackupExportException(
      texto,
      chaveInvalida: codigo == 401 || codigo == 403,
    );
  }

  /// Converte QUALQUER excepção numa frase segura. O detalhe técnico
  /// vai apenas para a consola em modo debug.
  static String _erroRede(Object e, [StackTrace? st]) {
    if (kDebugMode) debugPrint('[Backup] $e\n${st ?? ''}');
    if (e is TimeoutException) {
      return 'O servidor demorou demasiado a responder. Tente de novo (o servidor pode estar a acordar).';
    }
    if (e is SocketException ||
        e is HandshakeException ||
        e is http.ClientException) {
      return 'Sem ligação ao servidor, ou a ligação caiu durante o download.';
    }
    if (e is FileSystemException) {
      return 'Não foi possível escrever o ficheiro temporário. Verifique o espaço livre no dispositivo.';
    }
    return 'Não foi possível concluir a operação. Tente novamente.';
  }

  static Future<void> _apagar(File? f) async {
    try {
      if (f != null && await f.exists()) await f.delete();
    } catch (_) {}
  }
}