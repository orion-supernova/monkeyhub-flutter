import 'package:flutter/material.dart';
import '../theme/theme_scope.dart';

class AttachmentMenuChoice {
  const AttachmentMenuChoice._(this.id);
  final String id;
  static const gallery = AttachmentMenuChoice._('gallery');
  static const camera = AttachmentMenuChoice._('camera');
  static const voice = AttachmentMenuChoice._('voice');
  static const video = AttachmentMenuChoice._('video');
}

Future<AttachmentMenuChoice?> showAttachmentMenu(BuildContext context) {
  return showModalBottomSheet<AttachmentMenuChoice>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AttachmentSheet(),
  );
}

class _AttachmentSheet extends StatelessWidget {
  const _AttachmentSheet();
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final options = [
      (AttachmentMenuChoice.gallery, Icons.photo_library_outlined, 'PHOTO', 'pick an image'),
      (AttachmentMenuChoice.video, Icons.video_library_outlined, 'VIDEO', 'pick a clip'),
      (AttachmentMenuChoice.camera, Icons.photo_camera_outlined, 'CAMERA', 'capture now'),
      (AttachmentMenuChoice.voice, Icons.mic_none, 'VOICE', 'record a moment'),
    ];
    return Container(
      decoration: theme.sheetDecoration(),
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: theme.inkMuted.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2)),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('ATTACH', style: theme.label.copyWith(letterSpacing: 2.4)),
          ),
          const SizedBox(height: 12),
          for (final o in options)
            GestureDetector(
              onTap: () => Navigator.of(context).pop(o.$1),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.surface,
                  border: Border.all(color: theme.divider),
                  borderRadius: BorderRadius.circular(theme.radiusMd),
                ),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.accentSoft,
                      borderRadius: BorderRadius.circular(theme.radiusMd),
                    ),
                    child: Icon(o.$2, size: 18, color: theme.accent),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(o.$3, style: theme.label),
                        const SizedBox(height: 2),
                        Text(o.$4, style: theme.monoTiny),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_outward, size: 14, color: theme.inkMuted),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}
