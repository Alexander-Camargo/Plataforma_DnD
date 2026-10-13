import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/data/tutorial_topics.dart';
import '../core/theme/app_theme.dart';

class QuickHelp extends StatelessWidget {
  final TutorialTopic topic;
  const QuickHelp({super.key, required this.topic});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Ayuda: ${topic.title}',
      icon: const Icon(Icons.help_outline, size: 20, color: AppColors.accent),
      onPressed: () async {
        final learnMore = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(topic.title),
            content: Text(topic.summary),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cerrar')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Saber más')),
            ],
          ),
        );
        if (learnMore == true && context.mounted) {
          context.push('/campaign-tutorial?section=${topic.id}');
        }
      },
    );
  }
}

/// Conserva espacio para el campo y una zona de ayuda accesible al tacto.
class HelpField extends StatelessWidget {
  final Widget child;
  final TutorialTopic? topic;
  const HelpField({super.key, required this.child, this.topic});
  @override
  Widget build(BuildContext context) => topic == null
      ? child
      : Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [Expanded(child: child), QuickHelp(topic: topic!)],
        );
}
