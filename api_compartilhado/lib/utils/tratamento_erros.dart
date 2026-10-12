// lib/utils/tratamento_erros.dart
//
// Chamar UMA vez no main(), logo a seguir a WidgetsFlutterBinding.ensureInitialized():
//   instalarTratamentoDeErros();

import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void instalarTratamentoDeErros() {
  // Erros do framework (build, layout, gestos…)
  FlutterError.onError = (detalhes) {
    FlutterError.presentError(detalhes); // consola
    // TODO: enviar para Sentry/Crashlytics, se vier a usar.
  };

  // Erros assíncronos que ninguém apanhou
  PlatformDispatcher.instance.onError = (erro, stack) {
    if (kDebugMode) debugPrint('Erro não tratado: $erro\n$stack');
    return true; // marcado como tratado: não rebenta a app
  };

  // Em debug mantém o ecrã vermelho (útil para programar).
  // Em release mostra uma mensagem simples em vez do texto técnico.
  ErrorWidget.builder = (detalhes) {
    if (kDebugMode) return ErrorWidget(detalhes.exception);
    return const _ErroAmigavel();
  };
}

class _ErroAmigavel extends StatelessWidget {
  const _ErroAmigavel();

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: Color(0xFFF4F5F7),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Ocorreu um erro inesperado.\nVolte atrás e tente novamente.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}