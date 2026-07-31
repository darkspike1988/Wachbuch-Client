import { Palette } from './design';

export function priorityColor(colors: Palette, priority: string): string {
  if (priority === 'urgent') return colors.danger;
  if (priority === 'important') return colors.warning;
  return colors.faint;
}

export function formatDateTime(iso: string): string {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return iso;
  return date.toLocaleString('de-DE', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

export function formatEuro(value: number): string {
  return `${value.toFixed(2).replace('.', ',')} €`;
}
