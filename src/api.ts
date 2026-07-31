export type ServerHealth = {
  status: string;
};

// Base URL of the Rettungswache-Wachbuch backend (the Docker server).
// Override per environment with EXPO_PUBLIC_API_URL, e.g.:
//   - Web / iOS simulator on the same host: http://127.0.0.1:8090
//   - Android emulator: http://10.0.2.2:8090
//   - Physical device: http://<LAN-IP-of-server>:8090
export const API_BASE_URL = (
  process.env.EXPO_PUBLIC_API_URL ?? 'http://127.0.0.1:8090'
).replace(/\/$/, '');

const REQUEST_TIMEOUT_MS = 8000;

export async function checkServerHealth(): Promise<ServerHealth> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  try {
    const response = await fetch(`${API_BASE_URL}/healthz/`, {
      headers: { Accept: 'application/json' },
      signal: controller.signal,
    });
    if (!response.ok) {
      throw new Error(`Server antwortete mit HTTP ${response.status}`);
    }
    const data = (await response.json()) as ServerHealth;
    return data;
  } catch (err) {
    if (err instanceof Error && err.name === 'AbortError') {
      throw new Error('Zeitüberschreitung bei der Server-Anfrage');
    }
    throw err;
  } finally {
    clearTimeout(timeout);
  }
}
