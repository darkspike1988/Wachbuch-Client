import AsyncStorage from '@react-native-async-storage/async-storage';

// Client for the Rettungswache-Wachbuch read-only JSON API (see server docs/API.md).
//
// The backend address is configurable at runtime (persisted) so a single build
// works against any reachable server; it can be pre-seeded at build time with
// EXPO_PUBLIC_API_URL, e.g.:
//   - Web / iOS simulator on the same host: http://127.0.0.1:8090
//   - Android emulator: http://10.0.2.2:8090
//   - Physical device: http://<LAN-IP-of-server>:8090
const STORAGE_KEY = 'wachbuch.apiBaseUrl';

function normalize(url: string): string {
  return url.trim().replace(/\/$/, '');
}

export const DEFAULT_API_BASE_URL = normalize(
  process.env.EXPO_PUBLIC_API_URL ?? 'http://127.0.0.1:8090',
);

let apiBaseUrl = DEFAULT_API_BASE_URL;

export function getApiBaseUrl(): string {
  return apiBaseUrl;
}

export async function initApiBaseUrl(): Promise<void> {
  try {
    const stored = await AsyncStorage.getItem(STORAGE_KEY);
    if (stored) apiBaseUrl = normalize(stored);
  } catch {
    // Ignore storage errors; fall back to the default.
  }
}

export async function setApiBaseUrl(url: string): Promise<void> {
  apiBaseUrl = normalize(url) || DEFAULT_API_BASE_URL;
  try {
    await AsyncStorage.setItem(STORAGE_KEY, apiBaseUrl);
  } catch {
    // Ignore storage errors; the in-memory value still applies.
  }
}

const REQUEST_TIMEOUT_MS = 8000;

let authToken: string | null = null;

export function setAuthToken(token: string | null): void {
  authToken = token;
}

export function getAuthToken(): string | null {
  return authToken;
}

export class ApiError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

async function request<T>(
  path: string,
  options: { method?: string; body?: unknown; auth?: boolean } = {},
): Promise<T> {
  const { method = 'GET', body, auth = true } = options;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  const headers: Record<string, string> = { Accept: 'application/json' };
  if (body !== undefined) {
    headers['Content-Type'] = 'application/json';
  }
  if (auth && authToken) {
    headers.Authorization = `Bearer ${authToken}`;
  }
  try {
    const response = await fetch(`${apiBaseUrl}${path}`, {
      method,
      headers,
      body: body !== undefined ? JSON.stringify(body) : undefined,
      signal: controller.signal,
    });
    const text = await response.text();
    const data = text ? JSON.parse(text) : {};
    if (!response.ok) {
      const message =
        (data && typeof data.error === 'string' && data.error) ||
        `Serverfehler (HTTP ${response.status})`;
      throw new ApiError(response.status, message);
    }
    return data as T;
  } catch (err) {
    if (err instanceof ApiError) throw err;
    if (err instanceof Error && err.name === 'AbortError') {
      throw new ApiError(0, 'Zeitüberschreitung bei der Server-Anfrage');
    }
    throw new ApiError(0, 'Server nicht erreichbar');
  } finally {
    clearTimeout(timeout);
  }
}

// --- Types -----------------------------------------------------------------

export type ServerStatus = {
  api_version: string;
  authenticated: boolean;
  has_membership: boolean;
  station?: string;
  role?: string;
};

export type LoginResult = {
  token: string;
  expires_in: number;
  has_membership: boolean;
  station: string | null;
  role: string | null;
};

export type HandoverSummary = {
  id: number;
  title: string;
  category: string;
  category_label: string;
  priority: string;
  priority_label: string;
  status: string;
  status_label: string;
  updated_at: string;
};

export type HandoverDetail = HandoverSummary & {
  details: string;
  author: string;
  version: number;
  created_at: string;
  completed_at: string | null;
  revisions: { version: number; changed_by: string; created_at: string }[];
};

export type CoffeeBalances = {
  own_balance_euros: number;
  can_book: boolean;
  total_balance_euros?: number;
};

export type CoffeeEntry = {
  id: number;
  member: string;
  amount_euros: number;
  reason: string;
  created_at: string;
  is_correction: boolean;
};

export type CalendarEvent = {
  id: number;
  title: string;
  description: string;
  starts_at: string;
  ends_at: string;
  created_by: string;
};

export type NewCalendarEvent = {
  title: string;
  description: string;
  starts_at: string;
  ends_at: string;
};

export type Overview = {
  station: { name: string; slug: string };
  role: string;
  role_label: string;
  modules: {
    calendar: boolean;
    birthdays: boolean;
    coffee: boolean;
    feeds: boolean;
    checklists: boolean;
  };
  handovers: { open_count: number; urgent_count: number; items: HandoverSummary[] };
  events?: { id: number; title: string; starts_at: string; ends_at: string }[];
  coffee?: CoffeeBalances;
};

export type Paginated<T> = {
  count: number;
  page: number;
  num_pages: number;
  results: T[];
};

// --- Endpoints -------------------------------------------------------------

export function getServerStatus(): Promise<ServerStatus> {
  return request<ServerStatus>('/api/v1/status/', { auth: true });
}

export function login(username: string, password: string): Promise<LoginResult> {
  return request<LoginResult>('/api/v1/anmeldung/', {
    method: 'POST',
    body: { username, password },
    auth: false,
  });
}

export function getOverview(): Promise<Overview> {
  return request<Overview>('/api/v1/uebersicht/');
}

export function getHandovers(
  scope: 'aktiv' | 'dringend' | 'archiv' = 'aktiv',
): Promise<Paginated<HandoverSummary>> {
  return request<Paginated<HandoverSummary>>(
    `/api/v1/uebergaben/?ansicht=${scope}`,
  );
}

export function getHandover(id: number): Promise<HandoverDetail> {
  return request<HandoverDetail>(`/api/v1/uebergaben/${id}/`);
}

export function getCoffee(): Promise<
  Paginated<CoffeeEntry> & { balances: CoffeeBalances }
> {
  return request<Paginated<CoffeeEntry> & { balances: CoffeeBalances }>(
    '/api/v1/kaffeekasse/',
  );
}

// --- Write endpoints (bearer token only) -----------------------------------

export type NewHandover = {
  category: string;
  priority: string;
  title: string;
  details: string;
};

export const HANDOVER_CATEGORIES: { value: string; label: string }[] = [
  { value: 'station', label: 'Wache' },
  { value: 'vehicle', label: 'Fahrzeugstatus' },
  { value: 'material', label: 'Material' },
  { value: 'task', label: 'Offene Aufgabe' },
  { value: 'safety', label: 'Sicherheit/Mangel' },
];

export const HANDOVER_PRIORITIES: { value: string; label: string }[] = [
  { value: 'normal', label: 'Normal' },
  { value: 'important', label: 'Wichtig' },
  { value: 'urgent', label: 'Dringend' },
];

export const HANDOVER_STATUSES: { value: string; label: string }[] = [
  { value: 'open', label: 'Offen' },
  { value: 'in_progress', label: 'In Bearbeitung' },
  { value: 'done', label: 'Erledigt' },
];

export function createHandover(body: NewHandover): Promise<HandoverDetail> {
  return request<HandoverDetail>('/api/v1/uebergaben/', {
    method: 'POST',
    body,
  });
}

export function setHandoverStatus(
  id: number,
  status: string,
): Promise<HandoverSummary> {
  return request<HandoverSummary>(`/api/v1/uebergaben/${id}/status/`, {
    method: 'POST',
    body: { status },
  });
}

export function getCalendar(): Promise<Paginated<CalendarEvent>> {
  return request<Paginated<CalendarEvent>>('/api/v1/kalender/');
}

export type Checklist = {
  id: number;
  title: string;
  description: string;
  items: string[];
  last_completed_at: string | null;
  last_completed_by: string | null;
};

export function getChecklists(): Promise<{ results: Checklist[] }> {
  return request<{ results: Checklist[] }>('/api/v1/checklisten/');
}

export function completeChecklist(id: number, note = ''): Promise<unknown> {
  return request(`/api/v1/checklisten/${id}/erledigt/`, {
    method: 'POST',
    body: { note },
  });
}

export function createCalendarEvent(
  body: NewCalendarEvent,
): Promise<CalendarEvent> {
  return request<CalendarEvent>('/api/v1/kalender/', {
    method: 'POST',
    body,
  });
}
