import 'package:flutter/material.dart';

/// Paleta tomada de la hoja original (Generador_Personajes_Avanzado).
class AppColors {
  static const bgDark = Color(0xFF2B2B2B);
  static const bgPanel = Color(0xFFE9E5DF);
  static const bgCard = Color(0xFFFAF8F5);
  static const bgPaper = Color(0xFFFDFBF7);
  static const bgStat = Color(0xFFF4F0E6);
  static const accent = Color(0xFF631212);
  static const accentDark = Color(0xFF3D0A0A);
  static const gold = Color(0xFFD4AF37);
  static const border = Color(0xFFE0D8C8);
  static const borderStat = Color(0xFFC9BCA7);
  static const text = Color(0xFF333333);
  static const muted = Color(0xFF555555);
  static const success = Color(0xFF2E7D32);
}

class AppTheme {
  static const _serif = 'Georgia';

  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.accent,
      onPrimary: Colors.white,
      secondary: AppColors.gold,
      onSecondary: Colors.black,
      error: Color(0xFFB3261E),
      onError: Colors.white,
      surface: AppColors.bgCard,
      onSurface: AppColors.text,
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: AppColors.borderStat),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: _serif,
      colorScheme: scheme,
      // Fondo claro tipo pergamino: todo el texto por defecto es legible.
      scaffoldBackgroundColor: AppColors.bgPanel,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgDark,
        foregroundColor: AppColors.gold,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.gold),
        actionsIconTheme: IconThemeData(color: AppColors.gold),
        titleTextStyle: TextStyle(
          fontFamily: _serif,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.gold,
          letterSpacing: 0.5,
        ),
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: AppColors.bgDark),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.accent,
        textColor: AppColors.text,
      ),
      cardTheme: CardThemeData(
        color: AppColors.bgCard,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, space: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.gold, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: _serif,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.accent,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade400,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: const BorderSide(color: AppColors.accentDark, width: 1.5),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.accent),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.gold, width: 2),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.gold,
        unselectedLabelColor: Color(0xFFAAAAAA),
        indicatorColor: AppColors.gold,
        dividerColor: Colors.transparent,
        labelStyle: TextStyle(fontFamily: _serif, fontWeight: FontWeight.bold),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.bgDark,
        contentTextStyle: const TextStyle(color: Colors.white, fontFamily: _serif),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }
}

/// Panel "papel" reutilizable con título estilo hoja de personaje.
class SheetCard extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  const SheetCard({
    super.key,
    this.title,
    required this.children,
    this.margin = const EdgeInsets.only(bottom: 16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Container(
              padding: const EdgeInsets.only(bottom: 6),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Text(
                title!.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ...children,
        ],
      ),
    );
  }
}

/// Mensaje centrado para listas vacías.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const EmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.gold),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 16, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Limita el ancho del contenido en pantallas grandes (web/escritorio).
class ContentWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const ContentWidth({super.key, required this.child, this.maxWidth = 1000});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
