module.exports = {
  branchPrefix: 'test-renovate/',
  dryRun: false,
  username: 'filipemiguelrocha',
  gitAuthor: 'Renovate Bot <bot@renovateapp.com>',
  onboarding: true,
  platform: 'github',
  includeForks: true,
  repositories: [
    'filipemiguelrocha/renovate-test',
  ],
  packageRules: [
    {
      description: 'lockFileMaintenance',
      matchUpdateTypes: [
        'pin',
        'digest',
        'patch',
        'minor',
        'major',
        'lockFileMaintenance',
      ],
      dependencyDashboardApproval: false,
      stabilityDays: 0,
    },
  ],
};
