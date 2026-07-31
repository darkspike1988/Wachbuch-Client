import { Platform } from 'react-native';

import { parseDate, todayIso, upcomingPickups } from './muell';

// Schedules a local notification the evening before each upcoming waste pickup so
// the app "announces one day before" even when it is closed. This is a best-effort
// enhancement on native devices; on web (and in environments without notification
// support such as Expo Go) it simply does nothing.
export async function scheduleGarbageReminders(): Promise<void> {
  if (Platform.OS === 'web') return;
  try {
    const Notifications = await import('expo-notifications');
    const current = await Notifications.getPermissionsAsync();
    let granted = current.granted;
    if (!granted) {
      const requested = await Notifications.requestPermissionsAsync();
      granted = requested.granted;
    }
    if (!granted) return;

    await Notifications.cancelAllScheduledNotificationsAsync();
    const pickups = upcomingPickups(todayIso(), 21);
    for (const pickup of pickups) {
      const eve = parseDate(pickup.date);
      eve.setDate(eve.getDate() - 1);
      eve.setHours(18, 0, 0, 0);
      if (eve.getTime() <= Date.now()) continue;
      const names = pickup.bins.map((bin) => bin.name).join(', ');
      await Notifications.scheduleNotificationAsync({
        content: {
          title: 'Müllabfuhr morgen',
          body: `Bitte heute Abend rausstellen: ${names}`,
        },
        trigger: { type: 'date', date: eve } as never,
      });
    }
  } catch {
    // Ignore: reminders are optional and must never break the app.
  }
}
