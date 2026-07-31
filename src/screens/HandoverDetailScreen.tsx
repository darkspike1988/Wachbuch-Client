import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useMemo } from 'react';
import { ActivityIndicator, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';

import { ApiError, getHandover, HANDOVER_STATUSES, setHandoverStatus } from '../api';
import QueryState from '../components/QueryState';
import { Design, useDesign } from '../design';
import { HandoverStackParamList } from '../navigation';
import { formatDateTime, priorityColor } from '../theme';

type Props = NativeStackScreenProps<HandoverStackParamList, 'HandoverDetail'>;

export default function HandoverDetailScreen({ route }: Props) {
  const design = useDesign();
  const styles = useMemo(() => makeStyles(design), [design]);
  const { colors } = design;
  const { id } = route.params;
  const queryClient = useQueryClient();
  const query = useQuery({
    queryKey: ['handover', id],
    queryFn: () => getHandover(id),
  });
  const data = query.data;

  const mutation = useMutation({
    mutationFn: (status: string) => setHandoverStatus(id, status),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['handover', id] });
      queryClient.invalidateQueries({ queryKey: ['handovers'] });
      queryClient.invalidateQueries({ queryKey: ['overview'] });
    },
  });
  const statusError =
    mutation.error instanceof ApiError ? mutation.error.message : null;

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
            style={[styles.badge, { backgroundColor: priorityColor(colors, data.priority) }]}
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

          <Text style={styles.sectionTitle}>Status ändern</Text>
          <View style={styles.statusRow}>
            {HANDOVER_STATUSES.map((option) => {
              const active = option.value === data.status;
              return (
                <Pressable
                  key={option.value}
                  disabled={active || mutation.isPending}
                  onPress={() => mutation.mutate(option.value)}
                  style={[styles.statusBtn, active && styles.statusBtnActive]}
                  android_ripple={{ color: 'rgba(0,0,0,0.06)' }}
                >
                  <Text
                    style={[
                      styles.statusText,
                      active && styles.statusTextActive,
                    ]}
                  >
                    {option.label}
                  </Text>
                </Pressable>
              );
            })}
          </View>
          {mutation.isPending ? (
            <ActivityIndicator color={colors.primary} style={styles.spinner} />
          ) : null}
          {statusError ? <Text style={styles.error}>{statusError}</Text> : null}

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
    content: { padding: 16, gap: 6, paddingBottom: design.glass ? 96 : 24 },
    badge: {
      alignSelf: 'flex-start',
      borderRadius: 6,
      paddingHorizontal: 8,
      paddingVertical: 2,
    },
    badgeText: { color: '#fff', fontSize: 11, fontWeight: '700', fontFamily },
    title: { fontSize: 22, fontWeight: design.titleFontWeight, color: colors.text, marginTop: 4, fontFamily },
    meta: { fontSize: 13, color: colors.muted, marginBottom: 8, fontFamily },
    card: { ...surfaceCard, padding: 16 },
    details: { fontSize: 15, color: colors.text, lineHeight: 22, fontFamily },
    metaBlock: { marginTop: 12, gap: 2 },
    metaLine: { fontSize: 13, color: colors.muted, fontFamily },
    sectionTitle: {
      fontSize: 13,
      fontWeight: '700',
      textTransform: 'uppercase',
      letterSpacing: 1,
      color: colors.faint,
      marginTop: 16,
      marginBottom: 6,
      fontFamily,
    },
    statusRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
    statusBtn: {
      paddingHorizontal: 14,
      paddingVertical: 9,
      borderRadius: design.chipRadius,
      backgroundColor: colors.surface,
      borderWidth: 1,
      borderColor: colors.border,
    },
    statusBtnActive: { backgroundColor: colors.primary, borderColor: colors.primary },
    statusText: { color: colors.muted, fontWeight: '600', fontSize: 13, fontFamily },
    statusTextActive: { color: colors.onPrimary, fontFamily },
    spinner: { marginTop: 10, alignSelf: 'flex-start' },
    error: { color: colors.danger, fontSize: 13, marginTop: 10, fontFamily },
    revision: {
      ...surfaceCard,
      flexDirection: 'row',
      justifyContent: 'space-between',
      padding: 12,
      marginBottom: 6,
    },
    revisionText: { fontSize: 13, color: colors.text, fontWeight: '600', fontFamily },
    revisionMeta: { fontSize: 12, color: colors.muted, fontFamily },
  });
}
