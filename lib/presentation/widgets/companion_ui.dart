import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'greca.dart';

/// Piezas comunes de las pantallas del acompañante (diseño «Barniz de
/// Pasto»): cabecera con greca, cifras, tarjetas y navegación inferior.

/// Cabecera de color con la greca en la esquina.
class CompanionHeader extends StatelessWidget {
  const CompanionHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.color = AppColors.esmeralda,
    this.stepColor = AppColors.esmeraldaDeep,
    this.trailing,
    this.bottom,
    this.onBack,
    this.backLabel = 'Volver',
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Color color;
  final Color stepColor;
  final Widget? trailing;
  final Widget? bottom;

  /// Muestra el botón «Volver» arriba a la izquierda.
  final VoidCallback? onBack;

  /// Texto del botón de regreso.
  final String backLabel;

  @override
  Widget build(BuildContext context) {
    final back = onBack;
    final text = Theme.of(context).textTheme;
    final eyebrowText = eyebrow;
    final subtitleText = subtitle;
    final trailingWidget = trailing;
    final bottomWidget = bottom;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      child: ColoredBox(
        color: color,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              right: 0,
              child: GrecaCorner(
                color: stepColor,
                accent: AppColors.oro,
                width: 112,
                height: 82,
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (back != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.paper,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                          ),
                          icon: const Icon(Icons.arrow_back),
                          label: Text(backLabel),
                          onPressed: back,
                        ),
                      ),
                    if (eyebrowText != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          eyebrowText,
                          style: text.titleMedium?.copyWith(
                            color: AppColors.paper,
                          ),
                        ),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(
                              title,
                              style:
                                  AppText.display(32, color: AppColors.paper),
                            ),
                          ),
                        ),
                        if (trailingWidget != null) trailingWidget,
                      ],
                    ),
                    if (subtitleText != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          subtitleText,
                          style: text.bodyMedium?.copyWith(
                            color: AppColors.paper,
                          ),
                        ),
                      ),
                    if (bottomWidget != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: bottomWidget,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cifra grande con su etiqueta.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.background,
    this.foreground,
  });

  final String value;
  final String label;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final fg = foreground ?? scheme.onSurface;
    return Semantics(
      container: true,
      label: '$value $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: background ?? scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: AppText.display(28, color: fg)),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de sección con título.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.children,
    this.title,
  });

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = title;
    // Material (no Container) para que los interruptores y las listas dibujen
    // su fondo y su efecto al tocar sobre la tarjeta.
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (t != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Semantics(
                    header: true,
                    child:
                        Text(t, style: Theme.of(context).textTheme.titleLarge),
                  ),
                ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// Pestañas del acompañante.
enum CompanionTab {
  map('Mapa', Icons.map_outlined, Icons.map),
  history('Historial', Icons.history, Icons.history),
  settings('Ajustes', Icons.tune, Icons.tune),
  privacy('Privacidad', Icons.lock_outline, Icons.lock);

  const CompanionTab(this.label, this.icon, this.activeIcon);

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Navegación inferior en forma de píldora oscura con la pestaña activa en
/// oro.
class PillNav extends StatelessWidget {
  const PillNav({super.key, required this.current, required this.onSelect});

  final CompanionTab current;
  final ValueChanged<CompanionTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Row(
            children: [
              for (final tab in CompanionTab.values)
                Expanded(
                    child: _PillItem(
                        tab: tab,
                        active: tab == current,
                        onTap: () => onSelect(tab))),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillItem extends StatelessWidget {
  const _PillItem(
      {required this.tab, required this.active, required this.onTap});

  final CompanionTab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = active ? AppColors.ink : AppColors.paper;
    return Semantics(
      button: true,
      selected: active,
      label: tab.label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          decoration: BoxDecoration(
            color: active ? AppColors.oro : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            // Sin esto la columna ocupa toda la altura disponible y la
            // píldora tapa la pantalla.
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(active ? tab.activeIcon : tab.icon, color: fg, size: 22),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  tab.label,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pide confirmación antes de una acción que no se puede deshacer.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool danger = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: danger
              ? FilledButton.styleFrom(
                  backgroundColor: AppColors.carmin,
                  foregroundColor: AppColors.paper,
                )
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Muestra un aviso breve en la parte inferior.
void showNotice(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
