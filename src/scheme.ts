import * as SunCalc from 'suncalc';

export type Scheme = 'light' | 'dark';
export type Coords = { latitude: number; longitude: number };

// Fallback when no location is available: dark between 19:00 and 07:00 local time.
export function schemeByTime(date: Date = new Date()): Scheme {
  const hour = date.getHours();
  return hour >= 7 && hour < 19 ? 'light' : 'dark';
}

// Light while the sun is up at the given location, dark otherwise. Handles polar
// day/night (no sunrise/sunset) by falling back to the local-time heuristic.
export function schemeByLocation(coords: Coords, date: Date = new Date()): Scheme {
  const times = SunCalc.getTimes(date, coords.latitude, coords.longitude);
  const sunrise = times.sunrise?.getTime();
  const sunset = times.sunset?.getTime();
  if (!sunrise || !sunset || Number.isNaN(sunrise) || Number.isNaN(sunset)) {
    return schemeByTime(date);
  }
  const now = date.getTime();
  return now >= sunrise && now < sunset ? 'light' : 'dark';
}

// Resolve the automatic scheme: prefer sun times at the device location, then the
// OS setting, then a plain time-of-day heuristic.
export function resolveAutoScheme(
  coords: Coords | null,
  systemScheme: Scheme | null,
  date: Date = new Date(),
): Scheme {
  if (coords) return schemeByLocation(coords, date);
  if (systemScheme) return systemScheme;
  return schemeByTime(date);
}
