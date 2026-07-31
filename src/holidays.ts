import Holidays from 'date-holidays';

// German public holidays. The Bundesland decides which holidays apply; the
// Wachbuch content sources are from NRW, so NRW is the sensible default. Adjust
// REGION for another Bundesland (e.g. 'BY', 'BE', ...).
export const REGION = { country: 'DE', state: 'NW' };

let instance: Holidays | null = null;
function holidays(): Holidays {
  if (!instance) instance = new Holidays(REGION.country, REGION.state);
  return instance;
}

const yearCache = new Map<number, Record<string, string>>();

export function holidaysForYear(year: number): Record<string, string> {
  const cached = yearCache.get(year);
  if (cached) return cached;
  const map: Record<string, string> = {};
  for (const entry of holidays().getHolidays(year)) {
    if (entry.type !== 'public') continue;
    const day = String(entry.date).slice(0, 10);
    map[day] = entry.name;
  }
  yearCache.set(year, map);
  return map;
}

export function holidayName(dateStr: string): string | null {
  const year = Number(dateStr.slice(0, 4));
  if (Number.isNaN(year)) return null;
  return holidaysForYear(year)[dateStr] ?? null;
}
