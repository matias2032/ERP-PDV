// lib/widgets/dialogo_chave_backup.dart

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pede a chave de backup ao utilizador.
/// Devolve a chave (sem espaços nas pontas) ou null se foi cancelado.
Future<String?> pedirChaveBackup(BuildContext context) => showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DialogoChave(),
    );

class _DialogoChave extends StatefulWidget {
  const _DialogoChave();

  @override
  State<_DialogoChave> createState() => _DialogoChaveState();
}

class _DialogoChaveState extends State<_DialogoChave> {
  // O controller pertence ao State: só é libertado quando o diálogo já
  // saiu da árvore (depois da animação de fecho). Fazer dispose logo a
  // seguir ao `await showDialog` deixa o TextField a usar um controller
  // já destruído durante essa animação.
  final _ctrl = TextEditingController();
  bool _ver = false;
  bool _fechado = false; // impede pop duplo (Enter + botão)

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _fechar(String? valor) {
    if (_fechado) return;
    _fechado = true;
    Navigator.of(context).pop(valor);
  }

  void _confirmar() {
    final v = _ctrl.text.trim();
    if (v.isEmpty) return;
    _fechar(v);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Chave de backup',
          style: TextStyle(color: c.marca, fontWeight: FontWeight.bold)),
      content: TextField(
        controller: _ctrl,
        obscureText: !_ver,
        autofocus: true,
        autocorrect: false,
        enableSuggestions: false,
        onSubmitted: (_) => _confirmar(),
        decoration: InputDecoration(
          labelText: 'Chave do administrador',
          helperText: 'Fica apenas em memória durante esta sessão.',
          suffixIcon: IconButton(
            tooltip: _ver ? 'Ocultar' : 'Mostrar',
            icon: Icon(_ver
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded),
            onPressed: () => setState(() => _ver = !_ver),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _fechar(null),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _confirmar,
          style: ElevatedButton.styleFrom(
            backgroundColor: c.marcaBotao,
            foregroundColor: AppColors.branco,
          ),
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}