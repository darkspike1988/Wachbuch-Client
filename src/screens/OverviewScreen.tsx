import { useQuery } from '@tanstack/react-query';
import { RefreshControl, ScrollView, StyleSheet, Text, View } from 'react-native';

import { getOverview } from '../api';
import QueryState from '../components/QueryState';
import { colors, formatDateTime, formatEuro, priorityColor } from '../theme';

export default function OverviewScreen() {
  const query = useQuery({ queryKey: ['overview'], queryFn: getOverview });
  const data = query.data;

  return (
    <QueryState
      isLoading={query.isLoading}
      isError={query.isError}
      error={query.error}
      onRetry={query.refetch}
    >
      {data ? (
        <ScrollView
          style={styles.screen}
          contentContainerStyle={styles.content}
          refreshControl={
            <RefreshControl
              refreshing={query.isRefetching}
              onRefresh={query.refetch}
            />
          }
        >
          <Text style={styles.station}>{data.station.name}</Text>
          <Text style={styles.role}>Rolle: {data.role_label}</Text>

          <View style={styles.row}>
            <View style={styles.stat}>
              <Text style={styles.statValue}>{data.handovers.open_count}</Text>
              <Text style={styles.statLabel}>offene Übergaben</Text>
            </View>
            <View style={styles.stat}>
              <Text style={[styles.statValue, { color: colors.danger }]}>
                {data.handovers.urgent_count}
              </Text>
              <Text style={styles.statLabel}>dringend</Text>
            </View>
            {data.coffee ? (
              <View style={styles.stat}>
                <Text style={styles.statValue}>
                  {formatEuro(data.coffee.own_balance_euros)}
                </Text>
                <Text style={styles.statLabel}>mein Kaffeestand</Text>
              </View>
            ) : null}
          </View>

          <Text style={styles.sectionTitle}>Für die nächste Schicht</Text>
          {data.handovers.items.length === 0 ? (
            <Text style={styles.empty}>Keine offenen Übergaben.</Text>
          ) : (
            data.handovers.items.map((item) => (
              <View key={item.id} style={styles.card}>
                <View
                  style={[
                    styles.badge,
                    { backgroundColor: priorityColor(item.priority) },
                  ]}
                >
                  <Text style={styles.badgeText}>{item.priority_label}</Text>
                </View>
                <Text style={styles.cardTitle}>{item.title}</Text>
                <Text style={styles.cardMeta}>
                  {item.category_label} · {item.status_label} ·{' '}
                  {formatDateTime(item.updated_at)}
                </Text>
              </View>
            ))
          )}

          {data.events && data.events.length > 0 ? (
            <>
              <Text style={styles.sectionTitle}>Nächste Termine</Text>
              {data.events.map((event) => (
                <View key={event.id} style={styles.card}>
                  <Text style={styles.cardTitle}>{event.title}</Text>
                  <Text style={styles.cardMeta}>
                    {formatDateTime(event.starts_at)}
                  </Text>
                </View>
              ))}
            </>
          ) : null}
        </ScrollView>
      ) : null}
    </QueryState>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.background },
  content: { padding: 16, gap: 6 },
  station: { fontSize: 22, fontWeight: '800', color: colors.text },
  role: { fontSize: 14, color: colors.muted, marginBottom: 8 },
  row: { flexDirection: 'row', gap: 10, marginBottom: 8 },
  stat: {
    flex: 1,
    backgroundColor: colors.surface,
    borderRadius: 12,
    padding: 14,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: colors.border,
  },
  statValue: { fontSize: 20, fontWeight: '800', color: colors.text },
  statLabel: { fontSize: 11, color: colors.muted, textAlign: 'center', marginTop: 2 },
  sectionTitle: {
    fontSize: 13,
    fontWeight: '700',
    textTransform: 'uppercase',
    letterSpacing: 1,
    color: colors.faint,
    marginTop: 14,
    marginBottom: 4,
  },
  empty: { color: colors.muted, fontSize: 14 },
  card: {
    backgroundColor: colors.surface,
    borderRadius: 12,
    padding: 14,
    borderWidth: 1,
    borderColor: colors.border,
    gap: 4,
  },
  badge: {
    alignSelf: 'flex-start',
    borderRadius: 6,
    paddingHorizontal: 8,
    paddingVertical: 2,
  },
  badgeText: { color: '#fff', fontSize: 11, fontWeight: '700' },
  cardTitle: { fontSize: 16, fontWeight: '700', color: colors.text },
  cardMeta: { fontSize: 12, color: colors.muted },
});
