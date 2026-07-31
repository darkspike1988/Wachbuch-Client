import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { useQuery } from '@tanstack/react-query';
import { useMemo } from 'react';
import {
  FlatList,
  Pressable,
  RefreshControl,
  StyleSheet,
  Text,
  View,
} from 'react-native';

import { getCalendar } from '../api';
import QueryState from '../components/QueryState';
import { Design, useDesign } from '../design';
import { CalendarStackParamList } from '../navigation';
import { formatDateTime } from '../theme';

type Props = NativeStackScreenProps<CalendarStackParamList, 'CalendarList'>;

export default function CalendarScreen({ navigation }: Props) {
  const design = useDesign();
  const styles = useMemo(() => makeStyles(design), [design]);
  const { colors } = design;
  const query = useQuery({ queryKey: ['calendar'], queryFn: getCalendar });

  const openCreate = () => navigation.navigate('CalendarCreate');

  return (
    <View style={styles.screen}>
      {!design.fab ? (
        <View style={styles.toolbar}>
          <Text style={styles.toolbarTitle}>Kommende Termine</Text>
          <Pressable
            style={({ pressed }) => [styles.newButton, pressed && styles.pressed]}
            onPress={openCreate}
          >
            <Text style={styles.newButtonText}>+ Neu</Text>
          </Pressable>
        </View>
      ) : null}

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
              tintColor={colors.primary}
            />
          }
          ListEmptyComponent={
            <Text style={styles.empty}>Keine kommenden Termine.</Text>
          }
          renderItem={({ item }) => (
            <View style={styles.card}>
              <Text style={styles.cardTitle}>{item.title}</Text>
              <Text style={styles.cardTime}>
                {formatDateTime(item.starts_at)} – {formatDateTime(item.ends_at)}
              </Text>
              {item.description ? (
                <Text style={styles.cardDesc}>{item.description}</Text>
              ) : null}
              <Text style={styles.cardMeta}>angelegt von {item.created_by}</Text>
            </View>
          )}
        />
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

function makeStyles(design: Design) {
  const { colors, fontFamily } = design;
  return StyleSheet.create({
    screen: { flex: 1, backgroundColor: colors.background },
    toolbar: {
      flexDirection: 'row',
      alignItems: 'center',
      justifyContent: 'space-between',
      padding: 12,
      backgroundColor: colors.surface,
      borderBottomWidth: StyleSheet.hairlineWidth,
      borderBottomColor: colors.border,
    },
    toolbarTitle: { fontSize: 14, fontWeight: '700', color: colors.text, fontFamily },
    newButton: {
      backgroundColor: colors.primary,
      paddingHorizontal: 14,
      paddingVertical: 7,
      borderRadius: design.buttonRadius,
    },
    newButtonText: { color: colors.onPrimary, fontWeight: '700', fontSize: 13, fontFamily },
    pressed: { opacity: 0.85 },
    list: { padding: 16, gap: 10, paddingBottom: design.fab ? 96 : design.glass ? 96 : 24 },
    empty: { color: colors.muted, textAlign: 'center', marginTop: 24, fontFamily },
    card: {
      backgroundColor: colors.card,
      borderRadius: design.cardRadius,
      padding: 14,
      gap: 3,
      borderWidth: design.glass ? StyleSheet.hairlineWidth : 0,
      borderColor: colors.border,
      ...design.cardShadow,
    },
    cardTitle: { fontSize: 16, fontWeight: '700', color: colors.text, fontFamily },
    cardTime: { fontSize: 13, color: colors.primary, fontWeight: '600', fontFamily },
    cardDesc: { fontSize: 13, color: colors.text, fontFamily },
    cardMeta: { fontSize: 12, color: colors.muted, marginTop: 2, fontFamily },
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
