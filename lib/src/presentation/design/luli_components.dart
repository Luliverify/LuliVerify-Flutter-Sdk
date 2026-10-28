import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// SDK theme tokens/factories scoped to verification routes.
///
/// Geist and custom controls provide the default appearance. Host application
/// themes remain unchanged when using the managed launcher.
abstract final class LuliVerifyDesign {
  /// Default LuliVerify accent colour used when LuliVerify branding is absent/unsafe.
  static const primary = Color(0xff1f3fe2);

  /// Primary text/icon colour on light SDK surfaces.
  static const ink = Color(0xff202431);

  /// Secondary text colour with legible contrast on SDK light surfaces.
  static const muted = Color(0xff5d6375);

  /// Subtle background colour for notices and disabled controls.
  static const surface = Color(0xfff2f4fd);

  /// Default outline colour for SDK fields and secondary controls.
  static const border = Color(0xffd9dce7);

  /// Builds a scoped theme from optional LuliVerify branding.
  ///
  /// Supports a valid six-digit primaryColor with adequate white-label contrast
  /// and buttonRadius from 0 to 32. Unsupported/unsafe values use SDK defaults.
  static ThemeData fromBranding(Map<String, Object?>? branding) {
    final color = branding?['primaryColor'];
    var accent = primary;
    if (color is String && RegExp(r'^#[a-fA-F0-9]{6}$').hasMatch(color)) {
      final candidate = Color(int.parse('ff${color.substring(1)}', radix: 16));
      // Keep white button labels legible even for a misconfigured merchant theme.
      if (1.05 / (candidate.computeLuminance() + .05) >= 4.5) {
        accent = candidate;
      }
    }
    final radius = branding?['buttonRadius'];
    return theme(
      accent: accent,
      buttonRadius: radius is num && radius >= 0 && radius <= 32
          ? radius.toDouble()
          : 12,
    );
  }

  /// Builds the SDK’s light theme with [accent] and [buttonRadius].
  ///
  /// Advanced hosts may use this around low-level widgets. This factory does not
  /// validate arbitrary accents; use [fromBranding] for untrusted branding data.
  static ThemeData theme({Color accent = primary, double buttonRadius = 12}) {
    final base = ThemeData(
      useMaterial3: false,
      fontFamily: 'packages/luliverify_flutter/Geist',
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.light(
        primary: accent,
        secondary: accent,
        surface: Colors.white,
        onSurface: ink,
        error: const Color(0xffae263b),
      ),
    );
    return base.copyWith(
      extensions: [_LuliShape(buttonRadius)],
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: ink,
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: accent,
          textStyle: const TextStyle(
            fontFamily: 'packages/luliverify_flutter/Geist',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xfff8f9fc),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        labelStyle: const TextStyle(color: muted),
        floatingLabelStyle: TextStyle(
          color: accent,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        errorMaxLines: 3,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: accent.withValues(alpha: .16),
        selectionHandleColor: accent,
      ),
    );
  }
}

/// Theme extension carrying the SDK button radius through nested controls.
class _LuliShape extends ThemeExtension<_LuliShape> {
  const _LuliShape(this.radius);
  final double radius;
  @override
  _LuliShape copyWith({double? radius}) => _LuliShape(radius ?? this.radius);
  @override
  _LuliShape lerp(covariant _LuliShape? other, double t) =>
      other == null ? this : _LuliShape(radius + (other.radius - radius) * t);
}

/// Internal branded action control with disabled and busy states.
class LuliButton extends StatelessWidget {
  /// Creates an action control; null [onPressed] or [busy] disables interaction.
  const LuliButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.secondary = false,
    this.busy = false,
  });

  /// Customer-facing action copy.
  final String label;

  /// Action callback, or null when interaction is disabled.
  final VoidCallback? onPressed;

  /// Optional leading outline icon, hidden while busy.
  final IconData? icon;

  /// Whether to use the outlined secondary style and show in-progress state.
  final bool secondary, busy;
  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final radius = Theme.of(context).extension<_LuliShape>()?.radius ?? 12;
    final enabled = onPressed != null && !busy;
    return Semantics(
      button: true,
      enabled: enabled,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 54),
        child: Material(
          color: secondary
              ? Colors.white
              : enabled
              ? accent
              : LuliVerifyDesign.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: secondary
                ? const BorderSide(color: LuliVerifyDesign.border)
                : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: enabled ? onPressed : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (busy) ...[
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (icon != null && !busy) ...[
                    Icon(
                      icon,
                      size: 20,
                      color: secondary
                          ? LuliVerifyDesign.ink
                          : enabled
                          ? Colors.white
                          : LuliVerifyDesign.muted,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: secondary
                            ? LuliVerifyDesign.ink
                            : enabled
                            ? Colors.white
                            : LuliVerifyDesign.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Internal accessible notice with information/error styling.
class LuliNotice extends StatelessWidget {
  /// Creates a live-region notice for safe customer-facing [message] copy.
  const LuliNotice(this.message, {super.key, this.error = false});

  /// Notice text; must not contain credentials or sensitive provider payloads.
  final String message;

  /// Whether to use the theme’s error treatment instead of information styling.
  final bool error;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: error ? const Color(0xfffff1f2) : LuliVerifyDesign.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            error ? LucideIcons.circleAlert : LucideIcons.info,
            size: 20,
            color: error
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Accessible branded selection field using LuliVerify values and labels.
///
/// Keys are submitted values; labels are display-only. The selection sheet
/// returns the original key and preserves the parent form’s save/validation hooks.
class LuliSelect extends FormField<String> {
  /// Creates a select field from a customer-facing label and value-to-label options.
  ///
  /// The initial value and allowed options must come from the current LuliVerify
  /// contract. onChanged receives the selected wire value, not its label.
  LuliSelect({
    super.key,
    required String label,
    required Map<String, String> options,
    super.initialValue,
    super.enabled,
    ValueChanged<String?>? onChanged,
    super.onSaved,
    super.validator,
  }) : super(
         builder: (state) => Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Text(
               label,
               style: const TextStyle(
                 fontSize: 14,
                 height: 1.4,
                 fontWeight: FontWeight.w500,
               ),
             ),
             const SizedBox(height: 8),
             Semantics(
               button: true,
               enabled: enabled,
               label: label,
               value: options[state.value] ?? 'Not selected',
               child: Material(
                 color: Colors.transparent,
                 child: InkWell(
                   onTap: !enabled
                       ? null
                       : () async {
                           final selected = await showModalBottomSheet<String>(
                             context: state.context,
                             backgroundColor: Colors.white,
                             shape: const RoundedRectangleBorder(
                               borderRadius: BorderRadius.vertical(
                                 top: Radius.circular(24),
                               ),
                             ),
                             builder: (context) => SafeArea(
                               child: Padding(
                                 padding: const EdgeInsets.fromLTRB(
                                   24,
                                   24,
                                   24,
                                   16,
                                 ),
                                 child: Column(
                                   mainAxisSize: MainAxisSize.min,
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     Text(
                                       label,
                                       style: const TextStyle(
                                         fontSize: 22,
                                         fontWeight: FontWeight.w600,
                                       ),
                                     ),
                                     const SizedBox(height: 16),
                                     Flexible(
                                       child: ListView(
                                         shrinkWrap: true,
                                         children: [
                                           for (final item in options.entries)
                                             ListTile(
                                               contentPadding: EdgeInsets.zero,
                                               title: Text(item.value),
                                               trailing: item.key == state.value
                                                   ? Icon(
                                                       LucideIcons.check,
                                                       color: Theme.of(context)
                                                           .colorScheme
                                                           .primary,
                                                     )
                                                   : null,
                                               onTap: () =>
                                                   Navigator.of(context)
                                                       .pop(item.key),
                                             ),
                                         ],
                                       ),
                                     ),
                                   ],
                                 ),
                               ),
                             ),
                           );
                           if (selected != null && state.mounted) {
                             state.didChange(selected);
                             onChanged?.call(selected);
                           }
                         },
                   borderRadius: BorderRadius.circular(12),
                   child: InputDecorator(
                     decoration: InputDecoration(
                       enabled: enabled,
                       errorText: state.errorText,
                     ),
                     child: Row(
                       children: [
                         Expanded(
                           child: Text(
                             options[state.value] ?? 'Select an option',
                             style: TextStyle(
                               fontSize: 16,
                               color: state.value == null
                                   ? LuliVerifyDesign.muted
                                   : LuliVerifyDesign.ink,
                             ),
                           ),
                         ),
                         const SizedBox(width: 12),
                         const Icon(LucideIcons.chevronDown, size: 18),
                       ],
                     ),
                   ),
                 ),
               ),
             ),
           ],
         ),
       );
}
