import 'package:material_ui/material_ui.dart';

/// Yetki bilgisi yalnızca backend'den gelir; kullanıcı düzenleyemez.
class BoruRoleBadge extends StatelessWidget {
  const BoruRoleBadge({
    super.key,
    this.platformRole,
    this.roomRole,
    this.compact = false,
  });

  final String? platformRole;
  final String? roomRole;
  final bool compact;

  static bool hasBadge(String? platformRole, String? roomRole) {
    return platformRole == 'SUPER_ADMIN' ||
        platformRole == 'ADMIN' ||
        platformRole == 'MODERATOR' ||
        roomRole == 'OWNER' ||
        roomRole == 'ADMIN' ||
        roomRole == 'MODERATOR';
  }

  @override
  Widget build(BuildContext context) {
    String label;
    IconData icon;
    Color color;
    switch (platformRole) {
      case 'SUPER_ADMIN':
        label = 'SUPER ADMIN';
        icon = Icons.workspace_premium;
        color = const Color(0xFFFFD36A);
        break;
      case 'ADMIN':
        label = 'ADMIN';
        icon = Icons.verified_user;
        color = const Color(0xFF67B7FF);
        break;
      case 'MODERATOR':
        label = 'MODERATOR';
        icon = Icons.shield;
        color = const Color(0xFFC4A4FF);
        break;
      default:
        switch (roomRole) {
          case 'OWNER':
            label = 'ODA SAHİBİ';
            icon = Icons.stars;
            color = const Color(0xFFFFD36A);
            break;
          case 'ADMIN':
            label = 'ODA ADMİNİ';
            icon = Icons.shield;
            color = const Color(0xFF67B7FF);
            break;
          case 'MODERATOR':
            label = 'ODA MOD.';
            icon = Icons.security;
            color = const Color(0xFFC4A4FF);
            break;
          default:
            return const SizedBox.shrink();
        }
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 9,
        vertical: compact ? 2 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.75)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 9 : 14, color: color),
          SizedBox(width: compact ? 2 : 5),
          Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: compact ? 8 : 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
