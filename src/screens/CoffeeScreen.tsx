import { useQuery } from '@tanstack/react-query';
import { useMemo } from 'react';
import { FlatList, RefreshControl, StyleSheet, Text, View } from 'react-native';

import { getCoffee } from '../api';
import QueryState from '../components/QueryState';
import { Design, useDesign } from '../design';
import { formatDateTime, formatEuro } from '../theme';

export default function CoffeeScreen() {
  const design = useDesign();
  const styles = useMemo(() => makeStyles(design), [design]);
  const { colors } = design;
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
              tintColor={colors.primary}
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

function makeStyles(design: Design) {
  const { colors, fontFamily } = design;
  const surfaceCard = {
    backgroundColor: colors.card,
    borderRadius: design.cardRadius,
    borderWidth: design.glass ? StyleSheet.hairlineWidth : 0,
    borderColor: colors.border,
    ...design.cardShadow,
  } as const;
  return StyleSheet.create({
    screen: { flex: 1, backgroundColor: colors.background },
    list: { padding: 16, gap: 8, paddingBottom: design.glass ? 96 : 24 },
    summary: { flexDirection: 'row', gap: 10, marginBottom: 8 },
    summaryItem: { ...surfaceCard, flex: 1, padding: 16, alignItems: 'center' },
    summaryValue: { fontSize: 20, fontWeight: '800', color: colors.text, fontFamily },
    summaryLabel: { fontSize: 12, color: colors.muted, marginTop: 2, fontFamily },
    empty: { color: colors.muted, textAlign: 'center', marginTop: 24, fontFamily },
    row: { ...surfaceCard, flexDirection: 'row', alignItems: 'center', padding: 14 },
    rowMain: { flex: 1, gap: 2 },
    reason: { fontSize: 15, color: colors.text, fontWeight: '600', fontFamily },
    rowMeta: { fontSize: 12, color: colors.muted, fontFamily },
    amount: { fontSize: 16, fontWeight: '800', marginLeft: 12, fontFamily },
  });
}
