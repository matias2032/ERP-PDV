import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CampoPesquisa extends StatelessWidget {
  const CampoPesquisa({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    // No claro mantém-se sem contorno (como estava); no escuro usa a borda do tema.
    final corBorda = context.escuro ? c.borda : Colors.transparent;
    OutlineInputBorder borda(Color cor) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cor),
        );

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (_, valor, __) => TextField(
        controller: controller,
        onChanged: onChanged,
        cursorColor: c.marca,
        style: TextStyle(fontSize: 14, color: c.textoPrincipal),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: c.textoSecundario),
          prefixIcon: Icon(Icons.search, color: c.marca),
          suffixIcon: valor.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close, size: 18, color: c.textoSecundario),
                  onPressed: onClear,
                ),
          filled: true,
          fillColor: c.superficie,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: borda(corBorda),
          enabledBorder: borda(corBorda),
          focusedBorder: borda(c.marca),
        ),
      ),
    );
  }
}