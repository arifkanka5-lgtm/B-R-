import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:material_ui/material_ui.dart';

import '../widgets/boru_premium_ui.dart';
import '../widgets/boru_role_badge.dart';

class BoruRoomChatSheet extends StatefulWidget {
  const BoruRoomChatSheet({
    super.key,
    required this.messages,
    required this.currentUserPublicId,
    required this.onSend,
    required this.onOpenProfile,
  });

  final ValueListenable<List<Map<String, dynamic>>> messages;
  final String currentUserPublicId;
  final void Function(String text) onSend;
  final Future<void> Function(String userPublicId) onOpenProfile;

  @override
  State<BoruRoomChatSheet> createState() => _BoruRoomChatSheetState();
}

class _BoruRoomChatSheetState extends State<BoruRoomChatSheet> {
  final TextEditingController controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    try {
      widget.onSend(text);
      controller.clear();
    } catch (error) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = BoruPremium.accent;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF11141F),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(top: BorderSide(color: accent.withValues(alpha: 0.45))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(19, 17, 19, 13),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(Icons.forum_rounded, color: accent, size: 21),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ODA SOHBETİ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Kullanıcı adına dokunarak profili aç',
                          style: TextStyle(
                            color: BoruPremium.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sohbeti kapat',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                valueListenable: widget.messages,
                builder: (context, messages, _) {
                  if (messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: accent.withValues(alpha: 0.65),
                            size: 37,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'İlk mesajı sen gönder!',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(13, 15, 13, 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[messages.length - 1 - index];
                      final senderId =
                          message['senderPublicId']?.toString() ?? '';
                      final senderName =
                          message['senderName']?.toString() ?? 'Kullanıcı';
                      final avatarUrl =
                          message['senderAvatarUrl']?.toString() ?? '';
                      final mine = senderId == widget.currentUserPublicId;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 11),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(17),
                          gradient: LinearGradient(
                            colors: mine
                                ? [
                                    accent.withValues(alpha: 0.17),
                                    const Color(0xFF202538),
                                  ]
                                : [
                                    const Color(0xFF222638),
                                    const Color(0xFF191D2B),
                                  ],
                          ),
                          border: Border.all(
                            color: mine
                                ? accent.withValues(alpha: 0.28)
                                : Colors.white10,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: senderId.isEmpty
                                  ? null
                                  : () => widget.onOpenProfile(senderId),
                              borderRadius: BorderRadius.circular(24),
                              child: CircleAvatar(
                                radius: 19,
                                backgroundColor: const Color(0xFF444E6A),
                                backgroundImage: avatarUrl.isNotEmpty
                                    ? NetworkImage(avatarUrl)
                                    : null,
                                child: avatarUrl.isEmpty
                                    ? const Icon(
                                        Icons.person,
                                        size: 20,
                                        color: Colors.white70,
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  InkWell(
                                    onTap: senderId.isEmpty
                                        ? null
                                        : () => widget.onOpenProfile(senderId),
                                    child: Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        Text(
                                          mine ? 'Siz' : senderName,
                                          style: TextStyle(
                                            color: accent,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        BoruRoleBadge(
                                          platformRole: message['platformRole']
                                              ?.toString(),
                                          roomRole: message['roomRole']
                                              ?.toString(),
                                          compact: true,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    message['text']?.toString() ?? '',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                color: const Color(0xFF161A27),
                border: Border(
                  top: BorderSide(color: accent.withValues(alpha: 0.15)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      maxLength: 300,
                      maxLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Mesajını yaz...',
                        hintStyle: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                        counterText: '',
                        filled: true,
                        fillColor: const Color(0xFF24293A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Container(
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: IconButton(
                      tooltip: 'Gönder',
                      onPressed: _send,
                      icon: const Icon(
                        Icons.send_rounded,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
