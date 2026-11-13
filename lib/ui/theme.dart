import 'package:material_ui/material_ui.dart';

/// Tally's look: a cool, calm slate base, one strong tide-teal accent, and a
/// coral that means "careful". Both themes are designed, not derived.
const ColorScheme _light = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF007A8A),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFC9EEF2),
  onPrimaryContainer: Color(0xFF00363E),
  secondary: Color(0xFF4A6572),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFDCE7EE),
  onSecondaryContainer: Color(0xFF14262F),
  error: Color(0xFFCB3F27),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFFDDD5),
  onErrorContainer: Color(0xFF410A00),
  surface: Color(0xFFF2F6F9),
  onSurface: Color(0xFF0F1B24),
  onSurfaceVariant: Color(0xFF4F6270),
  outline: Color(0xFF8497A4),
  outlineVariant: Color(0xFFC5D2DB),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
  inverseSurface: Color(0xFF16242E),
  onInverseSurface: Color(0xFFE8F0F5),
  inversePrimary: Color(0xFF59D4E4),
  surfaceTint: Color(0xFF007A8A),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceContainerLow: Color(0xFFFFFFFF),
  surfaceContainer: Color(0xFFE9EFF4),
  surfaceContainerHigh: Color(0xFFE1E9EF),
  surfaceContainerHighest: Color(0xFFD8E2EA),
);

const ColorScheme _dark = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF4FD8E8),
  onPrimary: Color(0xFF00363E),
  primaryContainer: Color(0xFF00505C),
  onPrimaryContainer: Color(0xFFC1F2F8),
  secondary: Color(0xFF9FB6C4),
  onSecondary: Color(0xFF16303D),
  secondaryContainer: Color(0xFF263E4D),
  onSecondaryContainer: Color(0xFFD3E6F0),
  error: Color(0xFFFF8F78),
  onError: Color(0xFF4A1000),
  errorContainer: Color(0xFF7A2615),
  onErrorContainer: Color(0xFFFFDAD2),
  surface: Color(0xFF0C151D),
  onSurface: Color(0xFFE6EEF3),
  onSurfaceVariant: Color(0xFF9DB0BD),
  outline: Color(0xFF62788A),
  outlineVariant: Color(0xFF2A3C4B),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
  inverseSurface: Color(0xFFE6EEF3),
  onInverseSurface: Color(0xFF16242E),
  inversePrimary: Color(0xFF007A8A),
  surfaceTint: Color(0xFF4FD8E8),
  surfaceContainerLowest: Color(0xFF09111A),
  surfaceContainerLow: Color(0xFF111C26),
  surfaceContainer: Color(0xFF16232F),
  surfaceContainerHigh: Color(0xFF1C2B38),
  surfaceContainerHighest: Color(0xFF243545),
);

/// Corner radii used across the app.
class Radii {
  static const double card = 28;
  static const double hero = 36;
  static const double sheet = 32;
  static const double field = 20;
}

ThemeData buildTheme(Brightness brightness) {
  final cs = brightness == Brightness.light ? _light : _dark;
  final base = ThemeData(useMaterial3: true, colorScheme: cs);
  final t = base.textTheme;

  final textTheme = t.copyWith(
    displaySmall: t.displaySmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
    headlineMedium: t.headlineMedium?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
    ),
    headlineSmall: t.headlineSmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
    ),
    titleLarge: t.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
    ),
    titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w600),
  );

  const stadium = StadiumBorder();

  return base.copyWith(
    scaffoldBackgroundColor: cs.surface,
    textTheme: textTheme,
    cardTheme: CardThemeData(
      color: cs.surfaceContainerLow,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: cs.surfaceContainerLow,
      modalBackgroundColor: cs.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: cs.outlineVariant,
      clipBehavior: Clip.antiAlias,
      constraints: const BoxConstraints(maxWidth: 640),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      elevation: 0,
      backgroundColor: cs.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      indicatorColor: cs.primaryContainer,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? cs.onSurface : cs.onSurfaceVariant,
        );
      }),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: cs.primary,
      foregroundColor: cs.onPrimary,
      elevation: 3,
      highlightElevation: 4,
      shape: stadium,
      extendedTextStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: cs.inverseSurface,
      contentTextStyle: TextStyle(color: cs.onInverseSurface, fontSize: 15),
      actionTextColor: cs.inversePrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 56),
        shape: stadium,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: stadium,
        side: BorderSide(color: cs.outlineVariant),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: stadium,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: const ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(48, 48)),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide(color: cs.outlineVariant),
      labelStyle: TextStyle(
        color: cs.onSurface,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: cs.outlineVariant,
      thickness: 1,
      space: 1,
    ),
  );
}

/// Input decoration used by every text field, so fields look the same
/// everywhere and do not depend on version-specific theme classes.
InputDecoration fieldDecoration(
  BuildContext context, {
  String? label,
  String? hint,
  String? prefixText,
  String? errorText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  String? helperText,
}) {
  final cs = Theme.of(context).colorScheme;
  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(Radii.field),
    borderSide: BorderSide(color: color, width: width),
  );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helperText,
    prefixText: prefixText,
    errorText: errorText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: cs.surfaceContainer,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    border: border(Colors.transparent, 0),
    enabledBorder: border(Colors.transparent, 0),
    focusedBorder: border(cs.primary, 2),
    errorBorder: border(cs.error, 1.5),
    focusedErrorBorder: border(cs.error, 2),
  );
}

/// Duration for tap-driven motion; zero when the system asks to reduce motion.
Duration motion(BuildContext context, int milliseconds) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: milliseconds);
