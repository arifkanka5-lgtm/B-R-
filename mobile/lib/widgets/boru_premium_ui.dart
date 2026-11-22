import 'package:material_ui/material_ui.dart';

import '../theme/boru_theme.dart';

/// Shared, theme-aware visual language for BÖRÜ's premium screens.
class BoruPremium {
  static const Color ink = Color(0xFF090B11);
  static const Color textMuted = Color(0xFFAAAEC0);
  static const Color gold = Color(0xFFF1C777);

  static Color get accent => BoruThemeController.instance.appPalette.accent;
  static Color get surface => BoruThemeController.instance.appPalette.surface;

  static BoxDecoration panel({double radius = 22, bool highlighted = false}) {
    final color = accent;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          surface.withValues(alpha: 0.96),
          const Color(0xFF10131E).withValues(alpha: 0.98),
        ],
      ),
      border: Border.all(
        color: highlighted
            ? color.withValues(alpha: 0.58)
            : Colors.white.withValues(alpha: 0.10),
        width: highlighted ? 1.2 : 0.9,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.28),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
        if (highlighted)
          BoxShadow(
            color: color.withValues(alpha: 0.10),
            blurRadius: 24,
            spreadRadius: -6,
          ),
      ],
    );
  }
}

class BoruAmbientBackground extends StatelessWidget {
  const BoruAmbientBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = BoruThemeController.instance.appPalette;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(palette.background, palette.surface, 0.23)!,
            palette.background,
            palette.background,
          ],
          stops: const [0, 0.42, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -125,
            right: -145,
            child: IgnorePointer(
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      palette.accent.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -185,
            left: -150,
            child: IgnorePointer(
              child: Container(
                width: 330,
                height: 330,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      palette.secondary.withValues(alpha: 0.13),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class BoruSectionHeading extends StatelessWidget {
  const BoruSectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 3,
          height: 27,
          decoration: BoxDecoration(
            color: BoruPremium.accent,
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: Colors.white,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: BoruPremium.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class BoruPremiumButton extends StatelessWidget {
  const BoruPremiumButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.compact = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = BoruPremium.accent;
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [accent, Color.lerp(accent, Colors.white, 0.24)!],
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 14 : 20,
              vertical: compact ? 11 : 15,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: compact ? 17 : 19, color: Colors.black87),
                const SizedBox(width: 8),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: compact ? 12 : 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BoruRoomCard extends StatelessWidget {
  const BoruRoomCard({
    super.key,
    required this.room,
    required this.onTap,
    this.compact = false,
  });

  final Map<String, dynamic> room;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final private = room['isPrivate'] == true;
    final name = (room['name'] ?? 'İsimsiz oda').toString();
    final description = (room['description'] ?? '').toString().trim();
    final capacity = int.tryParse(room['capacity']?.toString() ?? '');
    final accent = BoruPremium.accent;

    return Container(
      decoration: BoruPremium.panel(highlighted: !private),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(compact ? 15 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: compact ? 44 : 50,
                      height: compact ? 44 : 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        gradient: LinearGradient(
                          colors: [
                            accent.withValues(alpha: 0.28),
                            accent.withValues(alpha: 0.06),
                          ],
                        ),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.32),
                        ),
                      ),
                      child: Icon(
                        private
                            ? Icons.lock_outline_rounded
                            : Icons.graphic_eq_rounded,
                        color: accent,
                        size: 24,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: private
                            ? Colors.white.withValues(alpha: 0.07)
                            : const Color(0xFF37CF9C).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        private ? 'ÖZEL ODA' : 'HERKESE AÇIK',
                        style: TextStyle(
                          color: private
                              ? Colors.white70
                              : const Color(0xFF6FE6B9),
                          fontWeight: FontWeight.w800,
                          fontSize: 9,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description.isEmpty ? 'Sesli sohbet • BÖRÜ' : description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: BoruPremium.textMuted,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.groups_2_outlined, size: 15, color: accent),
                    const SizedBox(width: 5),
                    Text(
                      capacity == null ? 'Sesli oda' : 'Kapasite: $capacity',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      private ? 'KİLİTLİ' : 'KATIL',
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(Icons.arrow_forward_rounded, size: 17, color: accent),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
