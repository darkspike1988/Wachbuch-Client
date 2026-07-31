import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import {
  FlatList,
  Pressable,
  RefreshControl,
  StyleSheet,
  Text,
  View,
} from 'react-native';

import { getHandovers } from '../api';
import QueryState from '../components/QueryState';
import { HandoverStackParamList } from '../navigation';
import { colors, formatDateTime, priorityColor } from '../theme';

type Scope = 'aktiv' | 'dringend' | 'archiv';
const SCOPES: { key: Scope; label: string }[] = [
  { key: 'aktiv', label: 'Aktiv' },
  { key: 'dringend', label: 'Dringend' },
  { key: 'archiv', label: 'Archiv' },
];

type Props = NativeStackScreenProps<HandoverStackParamList, 'HandoverList'>;

export default function HandoversScreen({ navigation }: Props) {
  const [scope, setScope] = useState<Scope>('aktiv');
  const query = useQuery({
    queryKey: ['handovers', scope],
    queryFn: () => getHandovers(scope),
  });

  return (
    <View style={styles.screen}>
      <View style={styles.tabs}>
        {SCOPES.map((entry) => (
          <Pressable
            key={entry.key}
            onPress={() => setScope(entry.key)}
            style={[styles.tab, scope === entry.key && styles.tabActive]}
          >
            <Text
              style={[styles.tabText, scope === entry.key && styles.tabTextActive]}
            >
              {entry.label}
            </Text>
          </Pressable>
        ))}
      </View>

      <QueryState
        isLoading={query.isLoading}
        isError={query.isError}
        error={query.error}
        onRetry={query.refetch}
      >
        <FlatList
          data={query.data?.results ?? []}
          keyExtractor={(item) => String(item.id)}
          contentContainerStyle={styles.list}
          refreshControl={
            <RefreshControl
              refreshing={query.isRefetching}
              onRefresh={query.refetch}
            />
          }
          ListEmptyComponent={
            <Text style={styles.empty}>Keine Einträge in dieser Ansicht.</Text>
          }
          renderItem={({ item }) => (
            <Pressable
              style={({ pressed }) => [styles.card, pressed && styles.cardPressed]}
              onPress={() =>
                navigation.navigate('HandoverDetail', {
                  id: item.id,
                  title: item.title,
                })
              }
            >
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
            </Pressable>
          )}
        />
      </QueryState>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.background },
  tabs: {
    flexDirection: 'row',
    gap: 8,
    padding: 12,
    backgroundColor: colors.surface,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
  },
  tab: {
    paddingHorizontal: 14,
    paddingVertical: 7,
    borderRadius: 999,
    backgroundColor: colors.background,
  },
  tabActive: { backgroundColor: colors.primary },
  tabText: { color: colors.muted, fontWeight: '600', fontSize: 13 },
  tabTextActive: { color: '#fff' },
  list: { padding: 16, gap: 10 },
  empty: { color: colors.muted, textAlign: 'center', marginTop: 24 },
  card: {
    backgroundColor: colors.surface,
    borderRadius: 12,
    padding: 14,
    borderWidth: 1,
    borderColor: colors.border,
    gap: 4,
  },
  cardPressed: { opacity: 0.7 },
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
