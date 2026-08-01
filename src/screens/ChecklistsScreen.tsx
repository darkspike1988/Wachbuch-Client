import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useMemo } from 'react';
import {
  ActivityIndicator,
  Pressable,
  RefreshControl,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';

import { completeChecklist, getChecklists } from '../api';
import QueryState from '../components/QueryState';
import { Design, useDesign } from '../design';
import { formatDateTime } from '../theme';

export default function ChecklistsScreen() {
  const design = useDesign();
  const styles = useMemo(() => makeStyles(design), [design]);
  const { colors } = design;
  const queryClient = useQueryClient();
  const query = useQuery({ queryKey: ['checklists'], queryFn: getChecklists });

  const mutation = useMutation({
    mutationFn: (id: number) => completeChecklist(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['checklists'] });
    },
  });

  return (
    <QueryState
      isLoading={query.isLoading}
      isError={query.isError}
      error={query.error}
      onRetry={query.refetch}
    >
      <ScrollView
        style={styles.screen}
        contentContainerStyle={styles.content}
        refreshControl={
          <RefreshControl
            refreshing={query.isRefetching}
            onRefresh={query.refetch}
            tintColor={colors.primary}
          />
        }
      >
        {(query.data?.results ?? []).length === 0 ? (
          <Text style={styles.empty}>Keine aktiven Checklisten.</Text>
        ) : null}
        {(query.data?.results ?? []).map((checklist) => (
          <View key={checklist.id} style={styles.card}>
            <Text style={styles.cardTitle}>{checklist.title}</Text>
            {checklist.description ? (
              <Text style={styles.cardDesc}>{checklist.description}</Text>
            ) : null}
            {checklist.items.map((item, index) => (
              <View key={index} style={styles.itemRow}>
                <Text style={styles.itemBullet}>•</Text>
                <Text style={styles.itemText}>{item}</Text>
              </View>
            ))}
            {checklist.last_completed_at ? (
              <Text style={styles.meta}>
                Zuletzt erledigt: {formatDateTime(checklist.last_completed_at)}
                {checklist.last_completed_by ? ` · ${checklist.last_completed_by}` : ''}
              </Text>
            ) : (
              <Text style={styles.meta}>Noch nicht erledigt.</Text>
            )}
            <Pressable
              style={({ pressed }) => [styles.button, pressed && styles.pressed]}
              onPress={() => mutation.mutate(checklist.id)}
              disabled={mutation.isPending}
              android_ripple={{ color: 'rgba(255,255,255,0.24)' }}
            >
              {mutation.isPending && mutation.variables === checklist.id ? (
                <ActivityIndicator color={colors.onPrimary} />
              ) : (
                <Text style={styles.buttonText}>Als erledigt vermerken</Text>
              )}
            </Pressable>
          </View>
        ))}
      </ScrollView>
    </QueryState>
  );
}

function makeStyles(design: Design) {
  const { colors, fontFamily } = design;
  return StyleSheet.create({
    screen: { flex: 1, backgroundColor: colors.background },
    content: { padding: 16, gap: 12, paddingBottom: design.glass ? 96 : 24 },
    empty: { color: colors.muted, textAlign: 'center', marginTop: 24, fontFamily },
    card: {
      backgroundColor: colors.card,
      borderRadius: design.cardRadius,
      padding: 16,
      gap: 6,
      borderWidth: design.glass ? StyleSheet.hairlineWidth : 0,
      borderColor: colors.border,
      ...design.cardShadow,
    },
    cardTitle: { fontSize: 17, fontWeight: '700', color: colors.text, fontFamily },
    cardDesc: { fontSize: 13, color: colors.muted, fontFamily },
    itemRow: { flexDirection: 'row', gap: 8, alignItems: 'flex-start' },
    itemBullet: { color: colors.primary, fontSize: 16, lineHeight: 20 },
    itemText: { flex: 1, fontSize: 15, color: colors.text, lineHeight: 20, fontFamily },
    meta: { fontSize: 12, color: colors.muted, marginTop: 4, fontFamily },
    button: {
      marginTop: 8,
      backgroundColor: colors.primary,
      paddingVertical: 12,
      borderRadius: design.buttonRadius,
      alignItems: 'center',
    },
    pressed: { opacity: 0.85 },
    buttonText: { color: colors.onPrimary, fontWeight: '700', fontSize: 15, fontFamily },
  });
}
