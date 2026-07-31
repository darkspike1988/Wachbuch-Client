export const colors = {
  background: '#f5f7fa',
  surface: '#ffffff',
  primary: '#1b6ef3',
  text: '#1b2733',
  muted: '#5b6672',
  faint: '#8a8f98',
  success: '#1a7f37',
  danger: '#c0392b',
  warning: '#b26a00',
  border: '#e3e7ec',
};

export function priorityColor(priority: string): string {
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
