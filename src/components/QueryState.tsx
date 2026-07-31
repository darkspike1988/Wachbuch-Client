import { ReactNode } from 'react';
import { ActivityIndicator, Pressable, StyleSheet, Text, View } from 'react-native';

import { colors } from '../theme';

type Props = {
  isLoading: boolean;
  isError: boolean;
  error?: unknown;
  onRetry?: () => void;
  children: ReactNode;
};

export default function QueryState({
  isLoading,
  isError,
  error,
  onRetry,
  children,
}: Props) {
  if (isLoading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator color={colors.primary} />
        <Text style={styles.muted}>Lädt…</Text>
      </View>
    );
  }
  if (isError) {
    const message =
      error instanceof Error ? error.message : 'Daten konnten nicht geladen werden';
    return (
      <View style={styles.center}>
        <Text style={styles.error}>{message}</Text>
        {onRetry ? (
          <Pressable style={styles.retry} onPress={onRetry}>
            <Text style={styles.retryText}>Erneut versuchen</Text>
          </Pressable>
        ) : null}
      </View>
    );
  }
  return <>{children}</>;
}

const styles = StyleSheet.create({
  center: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24, gap: 10 },
  muted: { color: colors.muted, fontSize: 14 },
  error: { color: colors.danger, fontSize: 14, textAlign: 'center' },
  retry: {
    marginTop: 6,
    backgroundColor: colors.primary,
    paddingHorizontal: 18,
    paddingVertical: 10,
    borderRadius: 10,
  },
  retryText: { color: '#fff', fontWeight: '700' },
});
