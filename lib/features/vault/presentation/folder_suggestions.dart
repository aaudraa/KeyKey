import 'package:flutter/material.dart';
import 'package:keykey/features/vault/application/login_search.dart';

/// Klasör kutusunun altında, yazılana uyan var olan klasörler.
class FolderSuggestions extends StatelessWidget {
  const new({
    required this.folders,
    required this.controller,
    required this.onPicked,
    super.key,
  });

  final List<String> folders;
  final TextEditingController controller;
  final ValueChanged<String> onPicked;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final typed = foldForSearch(controller.text.trim());
        final matches = [
          for (final folder in folders)
            if (foldForSearch(folder).contains(typed) &&
                foldForSearch(folder) != typed)
              folder,
        ];
        if (matches.isEmpty) return const SizedBox.shrink();
        return Padding(
          key: const Key('folder-suggestions'),
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final folder in matches)
                ActionChip(
                  avatar: const Icon(Icons.folder_outlined, size: 18),
                  label: Text(folder),
                  onPressed: () => onPicked(folder),
                ),
            ],
          ),
        );
      },
    );
  }
}
