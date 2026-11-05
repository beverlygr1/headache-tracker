import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../data/local_workspace.dart';

class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({required this.workspace, this.onRetry, super.key});
  final LocalWorkspace workspace;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: workspace,
        builder: (context, _) {
          if (!workspace.offline && workspace.pendingCount == 0) {
            return const SizedBox.shrink();
          }
          final count = workspace.pendingCount;
          return Container(
            width: double.infinity,
            color: AppColors.bluePale,
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              const Icon(Icons.cloud_upload_outlined,
                  color: AppColors.blue, size: 22),
              const SizedBox(width: 10),
              Expanded(
                  child: Semantics(
                      liveRegion: true,
                      child: Text(
                        workspace.syncError ??
                            (count == 0
                                ? 'Нет связи с сервером. Показаны сохранённые данные.'
                                : workspace.syncing
                                    ? 'Отправляем записи: $count'
                                    : 'На устройстве сохранено записей: $count. Ожидают отправки.'),
                        style: const TextStyle(fontSize: 12, height: 1.35),
                      ))),
              IconButton(
                tooltip: 'Повторить отправку',
                onPressed: workspace.syncing ? null : onRetry ?? workspace.sync,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ]),
          );
        },
      );
}
