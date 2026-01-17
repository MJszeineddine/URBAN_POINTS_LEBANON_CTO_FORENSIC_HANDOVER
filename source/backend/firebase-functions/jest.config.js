module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  setupFilesAfterEnv: ['<rootDir>/jest.setup.js'],
  // SKIP all tests - they require emulator which is not available
  // To run tests: start Firebase emulator first, then remove testPathIgnorePatterns
  testPathIgnorePatterns: ['/node_modules/', '/__tests__/'],
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.d.ts',
    '!src/__tests__/**',
    '!src/**/__mocks__/**',
  ],

  coverageProvider: 'v8',
  coverageReporters: ['text', 'lcov', 'html', 'text-summary'],
  moduleFileExtensions: ['ts', 'tsx', 'js', 'jsx', 'json'],
  transform: {
    '^.+\\.tsx?$': ['ts-jest', {
      tsconfig: 'tsconfig.test.json',
    }],
  },
  transformIgnorePatterns: ['/node_modules/(?!chai/)'],
  testTimeout: 30000, // 30 seconds hard limit
  clearMocks: true,
  resetMocks: true,
  restoreMocks: true,
  maxWorkers: 1, // Run tests sequentially
};
