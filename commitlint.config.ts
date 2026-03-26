import type { UserConfig } from '@commitlint/types';

const config: UserConfig = {
  extends: ['@commitlint/config-conventional'],

  // Accepte le format "✨ feat(scope): subject" ET "feat(scope): subject" (rétrocompat)
  parserPreset: {
    parserOpts: {
      headerPattern:
        /^(?:(?:✨|🐛|📝|💅|♻️|🚀|🧪|🔧|⏪|⚙️)\s+)?(\w*)(?:\((.+)\))?!?:\s+(.*)$/,
      headerCorrespondence: ['type', 'scope', 'subject'],
    },
  },

  rules: {
    'type-enum': [
      2,
      'always',
      ['feat', 'fix', 'docs', 'style', 'refactor', 'perf', 'test', 'chore', 'revert', 'ci'],
    ],
    'subject-case': [0],
  },

  prompt: {
    questions: {
      type: {
        description: 'Type de changement',
        enum: {
          feat: {
            description: 'Nouvelle fonctionnalité',
            title: 'Features',
            emoji: '✨',
          },
          fix: {
            description: 'Correction de bug',
            title: 'Bug Fixes',
            emoji: '🐛',
          },
          docs: {
            description: 'Documentation uniquement',
            title: 'Documentation',
            emoji: '📝',
          },
          style: {
            description: 'Style / formatage (pas de changement logique)',
            title: 'Styles',
            emoji: '💅',
          },
          refactor: {
            description: 'Refactoring sans ajout de feature ni correction de bug',
            title: 'Code Refactoring',
            emoji: '♻️',
          },
          perf: {
            description: 'Amélioration de performance',
            title: 'Performance',
            emoji: '🚀',
          },
          test: {
            description: 'Ajout ou correction de tests',
            title: 'Tests',
            emoji: '🧪',
          },
          chore: {
            description: 'Maintenance, dépendances, configuration',
            title: 'Chores',
            emoji: '🔧',
          },
          revert: {
            description: "Revert d'un commit précédent",
            title: 'Reverts',
            emoji: '⏪',
          },
          ci: {
            description: 'CI/CD, pipelines, workflows',
            title: 'CI',
            emoji: '⚙️',
          },
        },
      },
    },
  },
};

export default config;
