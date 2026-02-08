module.exports = {
  rules: {
    // --- Type ---
    'type-enum': [
      2,
      'always',
      [
        'feat',
        'fix',
        'docs',
        'style',
        'refactor',
        'perf',
        'test',
        'chore',
        'revert',
        'ci',
        'build',
      ],
    ],
    'type-case': [2, 'always', 'lower-case'],
    'type-empty': [2, 'never'],

    // --- Scope (optional, but must be lowercase if present) ---
    'scope-case': [2, 'always', 'lower-case'],

    // --- Subject ---
    'subject-empty': [2, 'never'],
    'subject-case': [2, 'never', ['upper-case', 'pascal-case', 'start-case']],
    'subject-full-stop': [2, 'never', '.'],

    // --- Header (type + scope + subject combined) ---
    'header-max-length': [2, 'always', 100],
    'header-min-length': [2, 'always', 10],

    // --- Body ---
    'body-max-line-length': [1, 'always', 200],
    'body-leading-blank': [2, 'always'],

    // --- Footer ---
    'footer-max-line-length': [1, 'always', 200],
    'footer-leading-blank': [2, 'always'],
  },
};
