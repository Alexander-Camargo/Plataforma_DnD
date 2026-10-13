import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../core/data/tutorial_topics.dart';

class CampaignTutorialScreen extends StatelessWidget {
  final String? section;
  const CampaignTutorialScreen({super.key, this.section});

  void _openTopic(BuildContext context, String id) {
    context.replace('/campaign-tutorial?section=$id');
  }

  Widget _topicCard(TutorialTopic topic) {
    final paragraphs = topic.detail.split('\n\n');
    return SheetCard(
      title: topic.title,
      children: [
        Text(topic.summary,
            style: const TextStyle(
                color: AppColors.accent, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Text.rich(
          TextSpan(children: [
            for (var i = 0; i < paragraphs.length; i++) ...[
              TextSpan(
                text: paragraphs[i].split('\n').first,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.accent),
              ),
              TextSpan(
                  text: paragraphs[i].contains('\n')
                      ? paragraphs[i].substring(paragraphs[i].indexOf('\n'))
                      : ''),
              if (i < paragraphs.length - 1) const TextSpan(text: '\n\n'),
            ],
          ]),
          style: const TextStyle(fontSize: 16, height: 1.65),
        ),
      ],
    );
  }

  Widget _indexGroup(BuildContext context, String title, List<String> ids) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.accent)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final topic
                in tutorialTopics.where((topic) => ids.contains(topic.id)))
              ActionChip(
                label: Text(topic.title),
                onPressed: () => _openTopic(context, topic.id),
              ),
          ]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/')),
        title: const Text('Guía de juego y de la aplicación'),
      ),
      body: ContentWidth(
        maxWidth: 900,
        child: ListView(
          key: ValueKey(section),
          padding: const EdgeInsets.all(16),
          children: [
            for (final topic
                in tutorialTopics.where((topic) => topic.id == section))
              _topicCard(topic),
            SheetCard(title: 'Tu primera aventura · Empieza aquí', children: [
              const Text(
                  'No necesitas haber jugado ni memorizar reglas. Aprende primero cómo se conversa en una partida, después cómo leer tu hoja y por último cómo resolver una tirada. Puedes volver a esta guía cuando aparezca una duda.',
                  style: TextStyle(height: 1.6)),
              const SizedBox(height: 16),
              for (final entry in const [
                ('intro', '1. Entiende qué es D&D y quién participa'),
                (
                  'player',
                  '2. Sigue el ejemplo de una conversación en la mesa'
                ),
                ('abilities', '3. Aprende a leer los números de tu personaje'),
                ('rolls', '4. Resuelve tu primera tirada paso a paso'),
              ])
                Material(
                  color: AppColors.bgCard,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.$2),
                    trailing: const Icon(Icons.chevron_right,
                        color: AppColors.accent),
                    onTap: () => _openTopic(context, entry.$1),
                  ),
                ),
              TextButton.icon(
                onPressed: () => _openTopic(context, 'dm'),
                icon: const Icon(Icons.shield_outlined),
                label: const Text(
                    'Voy a dirigir: cómo preparar mi primera sesión'),
              ),
            ]),
            SheetCard(title: 'Todos los temas · D&D 5e (2014)', children: [
              const Text(
                  'Selecciona un tema para abrir su explicación completa al principio de la guía. Las ayudas de los formularios también te llevan directamente aquí.'),
              _indexGroup(context, 'Empezar y jugar', [
                'intro',
                'player',
                'dm',
                'rolls',
                'combat',
                'rests',
              ]),
              _indexGroup(context, 'Crear y entender tu personaje', [
                'race',
                'subrace',
                'class',
                'alignment',
                'abilities',
                'strength',
                'dexterity',
                'constitution',
                'intelligence',
                'wisdom',
                'charisma',
                'background',
                'avatar',
                'hp',
                'ac',
                'initiative',
                'skills',
                'equipment',
                'spells',
              ]),
              _indexGroup(context, 'Competencias y pericia: cada habilidad', [
                'skills',
                'expertise',
                'tool-thieves-tools',
                ...tutorialTopics
                    .where((topic) => topic.id.startsWith('skill-'))
                    .map((topic) => topic.id)
              ]),
              _indexGroup(context, 'Organizar la campaña en la aplicación', [
                'invitation',
                'campaign-name',
                'campaign-description',
                'join-character',
                'status',
                'notes',
              ]),
            ]),
            for (final topic
                in tutorialTopics.where((topic) => topic.id != section))
              _topicCard(topic),
            const SheetCard(title: 'Fuentes y licencia', children: [
              SelectableText(
                  'Guía de D&D 5e (2014), basada en SRD 5.1 y en las reglas del proyecto. Referencias: Races, Classes, Using Ability Scores, Adventuring, Combat y Spellcasting. Los ejemplos numéricos son ilustrativos; los consejos de mesa y las instrucciones de la plataforma son explicaciones propias.',
                  style: TextStyle(height: 1.5)),
              SizedBox(height: 12),
              SelectableText(
                  'SRD 5.1: https://www.dndbeyond.com/attachments/39j2li89/SRD5.1-CCBY4.0License.pdf'),
              SizedBox(height: 12),
              SelectableText(
                  'This work includes material taken from the System Reference Document 5.1 (“SRD 5.1”) by Wizards of the Coast LLC and available at https://dnd.wizards.com/resources/systems-reference-document. The SRD 5.1 is licensed under the Creative Commons Attribution 4.0 International License available at https://creativecommons.org/licenses/by/4.0/legalcode.'),
            ]),
          ],
        ),
      ),
    );
  }
}
