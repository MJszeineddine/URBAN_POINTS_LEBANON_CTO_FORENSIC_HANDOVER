export function requireTestEnv<T>(testEnv: T | undefined, name: string): T {
  if (!testEnv) throw new Error(`testEnv not initialized in ${name}`);
  return testEnv;
}
