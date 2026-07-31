import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { useQuery } from '@tanstack/react-query';
import { ScrollView, StyleSheet, Text, View } from 'react-native';

import { getHandover } from '../api';
import QueryState from '../components/QueryState';
import { HandoverStackParamList } from '../navigation';
import { colors, formatDateTime, priorityColor } from '../theme';

type Props = NativeStackScreenProps<HandoverStackParamList, 'HandoverDetail'>;

export default function HandoverDetailScreen({ route }: Props) {
  const { id } = route.params;
  const query = useQuery({
    queryKey: ['handover', id],
    queryFn: () => getHandover(id),
  });
  const data = query.data;

  return (
    <QueryState
      isLoading={query.isLoading}
      isError={query.isError}
      error={query.error}
      onRetry={query.refetch}
    >
      {data ? (
        <ScrollView style={styles.screen} contentContainerStyle={styles.content}>
          <View
            style={[styles.badge, { backgroundColor: priorityColor(data.priority) }]}
          >
            <Text style={styles.badgeText}>{data.priority_label}</Text>
          </View>
          <Text style={styles.title}>{data.title}</Text>
          <Text style={styles.meta}>
            {data.category_label} · {data.status_label}
          </Text>

          <View style={styles.card}>
            <Text style={styles.details}>{data.details}</Text>
          </View>

          <View style={styles.metaBlock}>
            <Text style={styles.metaLine}>Verfasst von: {data.author}</Text>
            <Text style={styles.metaLine}>
              Angelegt: {formatDateTime(data.created_at)}
            </Text>
            <Text style={styles.metaLine}>
              Aktualisiert: {formatDateTime(data.updated_at)}
            </Text>
            <Text style={styles.metaLine}>Version: {data.version}</Text>
          </View>

          {data.revisions.length > 0 ? (
            <>
              <Text style={styles.sectionTitle}>Verlauf</Text>
              {data.revisions.map((rev) => (
                <View key={rev.version} style={styles.revision}>
                  <Text style={styles.revisionText}>
                    v{rev.version} · {rev.changed_by}
                  </Text>
                  <Text style={styles.revisionMeta}>
                    {formatDateTime(rev.created_at)}
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
  badge: {
    alignSelf: 'flex-start',
    borderRadius: 6,
    paddingHorizontal: 8,
    paddingVertical: 2,
  },
  badgeText: { color: '#fff', fontSize: 11, fontWeight: '700' },
  title: { fontSize: 22, fontWeight: '800', color: colors.text, marginTop: 4 },
  meta: { fontSize: 13, color: colors.muted, marginBottom: 8 },
  card: {
    backgroundColor: colors.surface,
    borderRadius: 12,
    padding: 16,
    borderWidth: 1,
    borderColor: colors.border,
  },
  details: { fontSize: 15, color: colors.text, lineHeight: 22 },
  metaBlock: { marginTop: 12, gap: 2 },
  metaLine: { fontSize: 13, color: colors.muted },
  sectionTitle: {
    fontSize: 13,
    fontWeight: '700',
    textTransform: 'uppercase',
    letterSpacing: 1,
    color: colors.faint,
    marginTop: 16,
    marginBottom: 4,
  },
  revision: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    backgroundColor: colors.surface,
    borderRadius: 10,
    padding: 12,
    borderWidth: 1,
    borderColor: colors.border,
    marginBottom: 6,
  },
  revisionText: { fontSize: 13, color: colors.text, fontWeight: '600' },
  revisionMeta: { fontSize: 12, color: colors.muted },
});
