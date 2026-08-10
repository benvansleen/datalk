import { vi } from 'vitest';

export const stubConfigEnv = () => {
  vi.stubEnv('DB_USER', 'user');
  vi.stubEnv('DB_PASSWORD', 'password');
  vi.stubEnv('DB_HOST', 'localhost');
  vi.stubEnv('DB_PORT', '5432');
  vi.stubEnv('DB_NAME', 'datalk');
  vi.stubEnv('PYTHON_SERVER_HOST', 'localhost');
  vi.stubEnv('PYTHON_SERVER_PORT', '8000');
  vi.stubEnv('ENVIRONMENT', 'test');
  vi.stubEnv('OPENAI_API_KEY', 'test-key');
  vi.stubEnv('INTERNAL_PROJECTION_SECRET', 'test-internal-projection-secret');
};

export const resetConfigEnv = () => {
  vi.unstubAllEnvs();
};
