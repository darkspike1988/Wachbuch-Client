import { useQuery } from '@tanstack/react-query';
import { FlatList, RefreshControl, StyleSheet, Text, View } from 'react-native';

import { getCoffee } from '../api';
import QueryState from '../components/QueryState';
import { colors, formatDateTime, formatEuro } from '../theme';

export default function CoffeeScreen() {
  const query = useQuery({ queryKey: ['coffee'], queryFn: getCoffee });
  const data = query.data;

  return (
    <QueryState
      isLoading={query.isLoading}
      isError={query.isError}
      error={query.error}
      onRetry={query.refetch}
    >
      {data ? (
        <FlatList
          style={styles.screen}
          data={data.results}
          keyExtractor={(item) => String(item.id)}
          contentContainerStyle={styles.list}
          refreshControl={
            <RefreshControl
              refreshing={query.isRefetching}
              onRefresh={query.refetch}
            />
          }
          ListHeaderComponent={
            <View style={styles.summary}>
              <View style={styles.summaryItem}>
                <Text style={styles.summaryValue}>
                  {formatEuro(data.balances.own_balance_euros)}
                </Text>
                <Text style={styles.summaryLabel}>Mein Stand</Text>
              </View>
              {data.balances.total_balance_euros !== undefined ? (
                <View style={styles.summaryItem}>
                  <Text style={styles.summaryValue}>
                    {formatEuro(data.balances.total_balance_euros)}
                  </Text>
                  <Text style={styles.summaryLabel}>Gesamtsaldo</Text>
                </View>
              ) : null}
            </View>
          }
          ListEmptyComponent={
            <Text style={styles.empty}>Noch keine Buchungen.</Text>
          }
          renderItem={({ item }) => (
            <View style={styles.row}>
              <View style={styles.rowMain}>
                <Text style={styles.reason}>{item.reason}</Text>
                <Text style={styles.rowMeta}>
                  {item.member} · {formatDateTime(item.created_at)}
                  {item.is_correction ? ' · Korrektur' : ''}
                </Text>
              </View>
              <Text
                style={[
                  styles.amount,
                  { color: item.amount_euros < 0 ? colors.danger : colors.success },
                ]}
              >
                {formatEuro(item.amount_euros)}
              </Text>
            </View>
          )}
        />
      ) : null}
    </QueryState>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.background },
  list: { padding: 16, gap: 8 },
  summary: {
    flexDirection: 'row',
    gap: 10,
    marginBottom: 8,
  },
  summaryItem: {
    flex: 1,
    backgroundColor: colors.surface,
    borderRadius: 12,
    padding: 16,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: colors.border,
  },
  summaryValue: { fontSize: 20, fontWeight: '800', color: colors.text },
  summaryLabel: { fontSize: 12, color: colors.muted, marginTop: 2 },
  empty: { color: colors.muted, textAlign: 'center', marginTop: 24 },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.surface,
    borderRadius: 12,
    padding: 14,
    borderWidth: 1,
    borderColor: colors.border,
  },
  rowMain: { flex: 1, gap: 2 },
  reason: { fontSize: 15, color: colors.text, fontWeight: '600' },
  rowMeta: { fontSize: 12, color: colors.muted },
  amount: { fontSize: 16, fontWeight: '800', marginLeft: 12 },
});
