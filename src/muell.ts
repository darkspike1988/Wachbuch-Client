// Local, configurable "Müllkalender" (waste collection schedule).
//
// Real schedules are municipal and often published as ICS feeds; this module
// keeps a deterministic, easily editable schedule so the feature works offline
// and can later be replaced by an imported feed without touching the UI.

export type Bin = { key: string; name: string; color: string };

export const BINS: Record<string, Bin> = {
  rest: { key: 'rest', name: 'Restmüll', color: '#4b5563' },
  bio: { key: 'bio', name: 'Biotonne', color: '#7c4a02' },
  papier: { key: 'papier', name: 'Papiertonne', color: '#2563eb' },
  gelb: { key: 'gelb', name: 'Gelbe Tonne', color: '#eab308' },
};

// weekday: 0=Sonntag … 6=Samstag. Interval in weeks with a known reference date.
type Rule = { bin: keyof typeof BINS; weekday: number; intervalWeeks: number; anchor: string };

export const SCHEDULE: Rule[] = [
  { bin: 'bio', weekday: 3, intervalWeeks: 1, anchor: '2026-01-07' }, // wöchentlich Mittwoch
  { bin: 'rest', weekday: 3, intervalWeeks: 2, anchor: '2026-01-07' }, // 14-tägig Mittwoch
  { bin: 'gelb', weekday: 6, intervalWeeks: 2, anchor: '2026-08-01' }, // 14-tägig Samstag
  { bin: 'papier', weekday: 1, intervalWeeks: 4, anchor: '2026-01-05' }, // 4-wöchentlich Montag
];

const DAY_MS = 24 * 60 * 60 * 1000;

export function parseDate(str: string): Date {
  const [y, m, d] = str.split('-').map(Number);
  return new Date(y, m - 1, d);
}

export function isoDate(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

export function addDays(str: string, days: number): string {
  const date = parseDate(str);
  date.setDate(date.getDate() + days);
  return isoDate(date);
}

export function todayIso(): string {
  return isoDate(new Date());
}

function weeksBetween(anchor: Date, target: Date): number {
  return Math.round((target.getTime() - anchor.getTime()) / (7 * DAY_MS));
}

export function binsOn(dateStr: string): Bin[] {
  const date = parseDate(dateStr);
  const weekday = date.getDay();
  const result: Bin[] = [];
  for (const rule of SCHEDULE) {
    if (rule.weekday !== weekday) continue;
    const weeks = weeksBetween(parseDate(rule.anchor), date);
    const mod = ((weeks % rule.intervalWeeks) + rule.intervalWeeks) % rule.intervalWeeks;
    if (mod === 0) result.push(BINS[rule.bin]);
  }
  return result;
}

export type Pickup = { date: string; bins: Bin[] };

export function upcomingPickups(fromStr: string, days: number): Pickup[] {
  const result: Pickup[] = [];
  for (let i = 0; i < days; i += 1) {
    const day = addDays(fromStr, i);
    const bins = binsOn(day);
    if (bins.length > 0) result.push({ date: day, bins });
  }
  return result;
}
