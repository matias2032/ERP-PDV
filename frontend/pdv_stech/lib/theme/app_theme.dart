// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ═════════════════════════════════════════════════════════════════════════════
// 1. CORES SEMÂNTICAS
// ═════════════════════════════════════════════════════════════════════════════

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.marca,
    required this.marcaBotao,
    required this.acento,
    required this.acentoTexto,
    required this.fundo,
    required this.superficie,
    required this.superficieAlt,
    required this.linhaAlternada,
    required this.borda,
    required this.textoPrincipal,
    required this.textoSecundario,
    required this.icone,
    required this.desactivado,
    required this.sucesso,
    required this.aviso,
    required this.perigo,
    required this.info,
    required this.sucessoFundo,
    required this.avisoFundo,
    required this.perigoFundo,
    required this.infoFundo,
  });

  // ── Constantes FIXAS (iguais nos dois temas → podem ir em widgets const) ──
  /// AppBar, cabeçalho da sidebar, cabeçalho de tabelas.
  static const Color azulMarca = Color(0xFF1B2A6B);
  static const Color azulMarcaEscuro = Color(0xFF11183E);

  /// FAB, botões primários de acção, ícones sobre fundo vermelho.
  static const Color vermelhoMarca = Color(0xFFC8102E);

  /// Texto/ícone sobre azulMarca / vermelhoMarca.
  static const Color branco = Colors.white;

  // ── Campos dinâmicos (mudam com o tema) ───────────────────────────────────
  final Color marca; // texto/ícone/borda "azul da marca"
  final Color marcaBotao; // fundo de botão primário azul
  final Color acento; // vermelho como FUNDO
  final Color acentoTexto; // vermelho como TEXTO/ÍCONE
  final Color fundo; // Scaffold
  final Color superficie; // cards, diálogos, linhas pares
  final Color superficieAlt; // rodapés, áreas elevadas (era grey[50])
  final Color linhaAlternada; // linhas ímpares de tabela
  final Color borda; // bordas de linha / divisores
  final Color textoPrincipal;
  final Color textoSecundario;
  final Color icone; // ícones neutros (era grey[700])
  final Color desactivado; // ícones/placeholder vazios (era grey[400])
  final Color sucesso;
  final Color aviso;
  final Color perigo;
  final Color info;
  final Color sucessoFundo;
  final Color avisoFundo;
  final Color perigoFundo;
  final Color infoFundo;

  // ── Paleta CLARA — valores actuais do projecto ────────────────────────────
  static const AppColors paletaClara = AppColors(
    marca: Color(0xFF1B2A6B),
    marcaBotao: Color(0xFF1B2A6B),
    acento: Color(0xFFC8102E),
    acentoTexto: Color(0xFFC8102E),
    fundo: Color(0xFFF4F5F7),
    superficie: Color(0xFFFFFFFF),
    superficieAlt: Color(0xFFFAFAFA), // grey[50]
    linhaAlternada: Color(0xFFF0F2FA),
    borda: Color(0xFFE8EAF0),
    textoPrincipal: Color(0xDD000000), // black87
    textoSecundario: Color(0xFF6B7280),
    icone: Color(0xFF616161), // grey[700]
    desactivado: Color(0xFFBDBDBD), // grey[400]
    sucesso: Color(0xFF388E3C), // green[700]
    aviso: Color(0xFFFF9800), // orange
    perigo: Color(0xFFD32F2F), // red[700]
    info: Color(0xFF1976D2), // blue[700]
    sucessoFundo: Color(0xFFE8F5E9), // green[50]
    avisoFundo: Color(0xFFFFF3E0), // orange[50]
    perigoFundo: Color(0xFFFFEBEE), // red[50]
    infoFundo: Color(0xFFE3F2FD), // blue[50]
  );

  // ── Paleta ESCURA ─────────────────────────────────────────────────────────
  // Contrastes calculados (WCAG), texto sobre superfície 181C30:
  //   textoPrincipal 13.8:1 | textoSecundario 6.6:1 | marca 6.9:1
  //   acentoTexto 5.6:1 | perigo 6.1:1 | sucesso/aviso/info > 8:1
  // Texto branco sobre marcaBotao 7.0:1; sobre vermelhoMarca 5.9:1.
  static const AppColors paletaEscura = AppColors(
    marca: Color(0xFF8EA0FF),
    marcaBotao: Color(0xFF3B4FB8),
    acento: Color(0xFFC8102E),
    acentoTexto: Color(0xFFFF5A6E),
    fundo: Color(0xFF0F1222),
    superficie: Color(0xFF181C30),
    superficieAlt: Color(0xFF20263F),
    linhaAlternada: Color(0xFF1C2138),
    borda: Color(0xFF2A3050),
    textoPrincipal: Color(0xFFE6E8F2),
    textoSecundario: Color(0xFF9AA3B8),
    icone: Color(0xFFB4BCD0),
    desactivado: Color(0xFF5A6280),
    sucesso: Color(0xFF6FD58A),
    aviso: Color(0xFFFFB74D),
    perigo: Color(0xFFFF6B7A),
    info: Color(0xFF7FB2FF),
    // fundos translúcidos (15%) — funcionam sobre qualquer superfície
    sucessoFundo: Color(0x266FD58A),
    avisoFundo: Color(0x26FFB74D),
    perigoFundo: Color(0x26FF6B7A),
    infoFundo: Color(0x267FB2FF),
  );

  @override
  AppColors copyWith() => this; // paletas são constantes e imutáveis

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return t < 0.5 ? this : other;
  }
}

/// Atalhos: `context.cores.marca`, `context.escuro`.
extension AppColorsContext on BuildContext {
  AppColors get cores {
    final tema = Theme.of(this);
    return tema.extension<AppColors>() ??
        (tema.brightness == Brightness.dark
            ? AppColors.paletaEscura
            : AppColors.paletaClara);
  }

  bool get escuro => Theme.of(this).brightness == Brightness.dark;
}

// ═════════════════════════════════════════════════════════════════════════════
// 2. TEMAS
// ═════════════════════════════════════════════════════════════════════════════

class AppTheme {
  AppTheme._();

  /// Claro = tema actual do projecto (sem alterações visuais) + extensão.
  static final ThemeData light = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.azulMarca,
      primary: AppColors.azulMarca,
    ),
    useMaterial3: true,
    extensions: const [AppColors.paletaClara],
  );

  static final ThemeData dark = _construirEscuro();

  static ThemeData _construirEscuro() {
    final c = AppColors.paletaEscura;
    const bordaCampo = Color(0xFF6B7499); // 3.7:1 sobre a superfície

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.azulMarca,
      brightness: Brightness.dark,
    ).copyWith(
      primary: c.marca,
      onPrimary: c.fundo,
      primaryContainer: c.marcaBotao,
      onPrimaryContainer: Colors.white,
      secondary: c.acentoTexto,
      onSecondary: c.fundo,
      error: c.perigo,
      surface: c.superficie,
      onSurface: c.textoPrincipal,
      onSurfaceVariant: c.textoSecundario,
      surfaceContainerLowest: c.fundo,
      surfaceContainerLow: c.superficie,
      surfaceContainer: c.superficie,
      surfaceContainerHigh: c.superficieAlt,
      surfaceContainerHighest: c.superficieAlt,
      outline: bordaCampo,
      outlineVariant: c.borda,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.fundo,
      canvasColor: c.superficie,
      extensions:  [c],
      iconTheme: IconThemeData(color: c.icone),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.azulMarcaEscuro,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
  cardTheme: CardThemeData(
        color: c.superficie,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      dialogTheme:  DialogThemeData(
        backgroundColor: c.superficie,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme:  BottomSheetThemeData(
        backgroundColor: c.superficie,
        modalBackgroundColor: c.superficie,
        surfaceTintColor: Colors.transparent,
      ),
      drawerTheme:  DrawerThemeData(
        backgroundColor: c.superficie,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme:  InputDecorationTheme(
        filled: true,
        fillColor: c.superficie,
        labelStyle: TextStyle(color: c.textoSecundario),
        hintStyle: TextStyle(color: c.textoSecundario),
        prefixIconColor: c.textoSecundario,
        suffixIconColor: c.textoSecundario,
      ),
      dividerTheme:  DividerThemeData(color: c.borda),
      chipTheme: ChipThemeData(
        backgroundColor: c.superficie,
        selectedColor: c.marca.withValues(alpha: 0.22),
        disabledColor: c.superficieAlt,
        checkmarkColor: c.marca,
        labelStyle: TextStyle(color: c.textoPrincipal),
        secondaryLabelStyle: TextStyle(color: c.textoPrincipal),
        side: BorderSide(color: c.borda),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF262C4A),
contentTextStyle: TextStyle(color: c.textoPrincipal),
        actionTextColor: c.marca,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Colors.white
              : c.textoSecundario,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.marcaBotao : c.borda,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Colors.transparent
              : bordaCampo,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? c.marcaBotao
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side:  BorderSide(color: c.textoSecundario, width: 2),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.marca,
        inactiveTrackColor: c.borda,
        thumbColor: c.marca,
        overlayColor: c.marca.withValues(alpha: 0.16),
        valueIndicatorColor: c.marcaBotao,
        rangeThumbShape: null,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.icone,
        textColor: c.textoPrincipal,
        selectedColor: c.marca,
        selectedTileColor: c.marca.withValues(alpha: 0.12),
      ),
      tabBarTheme:  TabBarThemeData(
        labelColor: c.marca,
        unselectedLabelColor: c.textoSecundario,
        indicatorColor: c.marca,
        dividerColor: c.borda,
      ),
      popupMenuTheme:  PopupMenuThemeData(
        color: c.superficieAlt,
        surfaceTintColor: Colors.transparent,
      ),
      progressIndicatorTheme:  ProgressIndicatorThemeData(color: c.marca),
      floatingActionButtonTheme:  FloatingActionButtonThemeData(
        backgroundColor: c.acento,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.marcaBotao,
          foregroundColor: Colors.white,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.marcaBotao,
          foregroundColor: Colors.white,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.marca),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.marca,
          side: const BorderSide(color: bordaCampo),
        ),
      ),
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: c.textoPrincipal,
        displayColor: c.textoPrincipal,
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 3. CONTROLADOR (estado + persistência)
// ═════════════════════════════════════════════════════════════════════════════

class ThemeController extends ChangeNotifier {
  static const _chave = 'tema_escuro';

  // 1.º arranque: segue o sistema. Após o toggle, guarda escolha explícita.
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  /// Estado EFECTIVO (também correcto quando o modo é `system`).
  bool get escuro => _themeMode == ThemeMode.system
      ? WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark
      : _themeMode == ThemeMode.dark;

  /// Chamar ANTES do runApp para evitar "flash" de tema errado.
  Future<void> carregar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final guardado = prefs.getBool(_chave);
      if (guardado != null) {
        _themeMode = guardado ? ThemeMode.dark : ThemeMode.light;
      }
    } catch (_) {
      // Sem persistência disponível: mantém ThemeMode.system.
    }
  }

  Future<void> alternar() async {
    _themeMode = escuro ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_chave, _themeMode == ThemeMode.dark);
    } catch (_) {}
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 4. TOGGLE PARA A SIDEBAR
// ═════════════════════════════════════════════════════════════════════════════

/// Linha "Modo escuro" com Divider. Não fecha o drawer.
/// Só esta linha reconstrói quando o tema muda (Consumer local).
class ModoEscuroTile extends StatelessWidget {
  const ModoEscuroTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeController>(
      builder: (context, ctrl, _) {
        final escuro = ctrl.escuro;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(height: 16),
            Semantics(
              label: 'Alternar modo escuro',
              toggled: escuro,
              child: Tooltip(
                message: 'Alternar modo escuro',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    leading: Icon(
                      escuro
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                    ),
                    title: const Text('Modo escuro'),
                    trailing: Switch(
                      value: escuro,
                      onChanged: (_) => ctrl.alternar(),
                    ),
                    onTap: ctrl.alternar,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}