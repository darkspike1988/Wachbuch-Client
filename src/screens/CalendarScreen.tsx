import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { useQuery } from '@tanstack/react-query';
import { useEffect, useMemo, useState } from 'react';
import {
  Pressable,
  RefreshControl,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { Calendar, LocaleConfig } from 'react-native-calendars';

import { CalendarEvent, getCalendar } from '../api';
import QueryState from '../components/QueryState';
import { Design, useDesign } from '../design';
import { holidayName, holidaysForYear } from '../holidays';
import { addDays, binsOn, isoDate, todayIso, upcomingPickups } from '../muell';
import { CalendarStackParamList } from '../navigation';
import { scheduleGarbageReminders } from '../reminders';

LocaleConfig.locales.de = {
  monthNames: [
    'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
    'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
  ],
  monthNamesShort: [
    'Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun',
    'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez',
  ],
  dayNames: [
    'Sonntag', 'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag',
  ],
  dayNamesShort: ['So', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa'],
  today: 'Heute',
};
LocaleConfig.defaultLocale = 'de';

type Props = NativeStackScreenProps<CalendarStackParamList, 'CalendarList'>;

function eventDay(event: CalendarEvent): string {
  return isoDate(new Date(event.starts_at));
}

function eventTime(iso: string): string {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return '';
  return date.toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' });
}

export default function CalendarScreen({ navigation }: Props) {
  const design = useDesign();
  const styles = useMemo(() => makeStyles(design), [design]);
  const { colors } = design;
  const query = useQuery({ queryKey: ['calendar'], queryFn: getCalendar });
  const today = todayIso();
  const [selected, setSelected] = useState(today);

  useEffect(() => {
    scheduleGarbageReminders();
  }, []);

  const eventsByDay = useMemo(() => {
    const map: Record<string, CalendarEvent[]> = {};
    for (const event of query.data?.results ?? []) {
      const day = eventDay(event);
      (map[day] ||= []).push(event);
    }
    return map;
  }, [query.data]);

  const marked = useMemo(() => {
    const result: Record<string, { dots: { key: string; color: string }[]; selected?: boolean; selectedColor?: string }> = {};
    const addDot = (day: string, dot: { key: string; color: string }) => {
      (result[day] ||= { dots: [] }).dots.push(dot);
    };
    const year = new Date().getFullYear();
    for (const y of [year, year + 1]) {
      for (const day of Object.keys(holidaysForYear(y))) {
        addDot(day, { key: 'holiday', color: colors.danger });
      }
    }
    for (const pickup of upcomingPickups(addDays(today, -31), 220)) {
      for (const bin of pickup.bins) addDot(pickup.date, { key: bin.key, color: bin.color });
    }
    for (const day of Object.keys(eventsByDay)) {
      addDot(day, { key: 'event', color: colors.primary });
    }
    result[selected] = {
      ...(result[selected] ?? { dots: [] }),
      selected: true,
      selectedColor: colors.primary,
    };
    return result;
  }, [eventsByDay, selected, colors, today]);

  const tomorrow = addDays(today, 1);
  const tomorrowBins = binsOn(tomorrow);

  const selectedHoliday = holidayName(selected);
  const selectedEvents = eventsByDay[selected] ?? [];
  const selectedBins = binsOn(selected);

  const calendarTheme = {
    calendarBackground: colors.surface,
    monthTextColor: colors.text,
    textSectionTitleColor: colors.muted,
    dayTextColor: colors.text,
    todayTextColor: colors.primary,
    selectedDayBackgroundColor: colors.primary,
    selectedDayTextColor: colors.onPrimary,
    arrowColor: colors.primary,
    textDisabledColor: colors.faint,
    textMonthFontWeight: '700' as const,
  };

  const openCreate = () => navigation.navigate('CalendarCreate');

  return (
    <View style={styles.screen}>
      <QueryState
        isLoading={query.isLoading}
        isError={query.isError}
        error={query.error}
        onRetry={query.refetch}
      >
        <ScrollView
          contentContainerStyle={styles.content}
          refreshControl={
            <RefreshControl
              refreshing={query.isRefetching}
              onRefresh={query.refetch}
              tintColor={colors.primary}
            />
          }
        >
          {tomorrowBins.length > 0 ? (
            <View style={styles.reminder}>
              <Text style={styles.reminderTitle}>Morgen rausstellen</Text>
              <View style={styles.binRow}>
                {tomorrowBins.map((bin) => (
                  <View key={bin.key} style={styles.binChip}>
                    <View style={[styles.binDot, { backgroundColor: bin.color }]} />
                    <Text style={styles.binChipText}>{bin.name}</Text>
                  </View>
                ))}
              </View>
            </View>
          ) : null}

          <View style={styles.calendarCard}>
            <Calendar
              current={selected}
              onDayPress={(day) => setSelected(day.dateString)}
              markedDates={marked}
              markingType="multi-dot"
              firstDay={1}
              enableSwipeMonths
              theme={calendarTheme}
            />
          </View>

          <View style={styles.legend}>
            <LegendItem color={colors.primary} label="Termin" styles={styles} />
            <LegendItem color={colors.danger} label="Feiertag" styles={styles} />
            <LegendItem color="#eab308" label="Gelbe Tonne" styles={styles} />
            <LegendItem color="#7c4a02" label="Bio" styles={styles} />
            <LegendItem color="#4b5563" label="Rest" styles={styles} />
            <LegendItem color="#2563eb" label="Papier" styles={styles} />
          </View>

          <Text style={styles.sectionTitle}>{formatSelected(selected)}</Text>

          {selectedHoliday ? (
            <View style={[styles.card, styles.holidayCard]}>
              <Text style={styles.holidayText}>Feiertag: {selectedHoliday}</Text>
            </View>
          ) : null}

          {selectedBins.length > 0 ? (
            <View style={styles.card}>
              <Text style={styles.cardLabel}>Abfuhr</Text>
              <View style={styles.binRow}>
                {selectedBins.map((bin) => (
                  <View key={bin.key} style={styles.binChip}>
                    <View style={[styles.binDot, { backgroundColor: bin.color }]} />
                    <Text style={styles.binChipText}>{bin.name}</Text>
                  </View>
                ))}
              </View>
            </View>
          ) : null}

          {selectedEvents.map((event) => (
            <View key={event.id} style={styles.card}>
              <Text style={styles.cardTitle}>{event.title}</Text>
              <Text style={styles.cardTime}>
                {eventTime(event.starts_at)} – {eventTime(event.ends_at)} Uhr
              </Text>
              {event.description ? (
                <Text style={styles.cardDesc}>{event.description}</Text>
              ) : null}
            </View>
          ))}

          {!selectedHoliday && selectedBins.length === 0 && selectedEvents.length === 0 ? (
            <Text style={styles.empty}>Keine Einträge an diesem Tag.</Text>
          ) : null}

          {!design.fab ? (
            <Pressable
              style={({ pressed }) => [styles.newButton, pressed && styles.pressed]}
              onPress={openCreate}
            >
              <Text style={styles.newButtonText}>+ Termin anlegen</Text>
            </Pressable>
          ) : null}
        </ScrollView>
      </QueryState>

      {design.fab ? (
        <Pressable
          style={({ pressed }) => [styles.fab, pressed && styles.pressed]}
          onPress={openCreate}
          android_ripple={{ color: 'rgba(255,255,255,0.24)' }}
        >
          <Text style={styles.fabText}>＋</Text>
        </Pressable>
      ) : null}
    </View>
  );
}

function LegendItem({
  color,
  label,
  styles,
}: {
  color: string;
  label: string;
  styles: ReturnType<typeof makeStyles>;
}) {
  return (
    <View style={styles.legendItem}>
      <View style={[styles.legendDot, { backgroundColor: color }]} />
      <Text style={styles.legendText}>{label}</Text>
    </View>
  );
}

function formatSelected(dateStr: string): string {
  const date = new Date(dateStr + 'T00:00:00');
  return date.toLocaleDateString('de-DE', {
    weekday: 'long',
    day: '2-digit',
    month: 'long',
    year: 'numeric',
  });
}

function makeStyles(design: Design) {
  const { colors, fontFamily } = design;
  const card = {
    backgroundColor: colors.card,
    borderRadius: design.cardRadius,
    padding: 14,
    borderWidth: design.glass ? StyleSheet.hairlineWidth : 0,
    borderColor: colors.border,
    ...design.cardShadow,
  } as const;
  return StyleSheet.create({
    screen: { flex: 1, backgroundColor: colors.background },
    content: { padding: 16, gap: 10, paddingBottom: design.fab || design.glass ? 96 : 24 },
    reminder: {
      backgroundColor: colors.primary,
      borderRadius: design.cardRadius,
      padding: 14,
      gap: 8,
    },
    reminderTitle: { color: colors.onPrimary, fontWeight: '800', fontSize: 15, fontFamily },
    calendarCard: {
      ...card,
      padding: design.glass ? 6 : 4,
      overflow: 'hidden',
    },
    legend: { flexDirection: 'row', flexWrap: 'wrap', gap: 12, paddingHorizontal: 4 },
    legendItem: { flexDirection: 'row', alignItems: 'center', gap: 5 },
    legendDot: { width: 9, height: 9, borderRadius: 5 },
    legendText: { fontSize: 12, color: colors.muted, fontFamily },
    sectionTitle: {
      fontSize: 13,
      fontWeight: '700',
      textTransform: 'uppercase',
      letterSpacing: 1,
      color: colors.faint,
      marginTop: 6,
      fontFamily,
    },
    card,
    holidayCard: { borderLeftWidth: 4, borderLeftColor: colors.danger },
    holidayText: { fontSize: 15, fontWeight: '700', color: colors.text, fontFamily },
    cardLabel: {
      fontSize: 11,
      textTransform: 'uppercase',
      letterSpacing: 1,
      color: colors.faint,
      fontWeight: '700',
      marginBottom: 6,
      fontFamily,
    },
    cardTitle: { fontSize: 16, fontWeight: '700', color: colors.text, fontFamily },
    cardTime: { fontSize: 13, color: colors.primary, fontWeight: '600', fontFamily },
    cardDesc: { fontSize: 13, color: colors.text, marginTop: 2, fontFamily },
    binRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
    binChip: {
      flexDirection: 'row',
      alignItems: 'center',
      gap: 6,
      backgroundColor: colors.surface,
      borderRadius: 999,
      paddingHorizontal: 10,
      paddingVertical: 5,
    },
    binDot: { width: 10, height: 10, borderRadius: 5 },
    binChipText: { fontSize: 13, color: colors.text, fontWeight: '600', fontFamily },
    empty: { color: colors.muted, fontFamily },
    newButton: {
      marginTop: 6,
      backgroundColor: colors.primary,
      paddingVertical: 12,
      borderRadius: design.buttonRadius,
      alignItems: 'center',
    },
    newButtonText: { color: colors.onPrimary, fontWeight: '700', fontSize: 14, fontFamily },
    pressed: { opacity: 0.85 },
    fab: {
      position: 'absolute',
      right: 20,
      bottom: 24,
      width: 56,
      height: 56,
      borderRadius: 18,
      backgroundColor: colors.primary,
      alignItems: 'center',
      justifyContent: 'center',
      shadowColor: '#000',
      shadowOpacity: 0.25,
      shadowRadius: 6,
      shadowOffset: { width: 0, height: 3 },
      elevation: 6,
    },
    fabText: { color: colors.onPrimary, fontSize: 28, lineHeight: 30, fontWeight: '600' },
  });
}
