import { ReactNode } from 'react';
import { ActivityIndicator, Pressable, StyleSheet, Text, View } from 'react-native';

import { useDesign } from '../design';

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
  const { colors, buttonRadius } = useDesign();
  if (isLoading) {
    return (
      <View style={[styles.center, { backgroundColor: colors.background }]}>
        <ActivityIndicator color={colors.primary} />
        <Text style={{ color: colors.muted, fontSize: 14 }}>Lädt…</Text>
      </View>
    );
  }
  if (isError) {
    const message =
      error instanceof Error ? error.message : 'Daten konnten nicht geladen werden';
    return (
      <View style={[styles.center, { backgroundColor: colors.background }]}>
        <Text style={{ color: colors.danger, fontSize: 14, textAlign: 'center' }}>
          {message}
        </Text>
        {onRetry ? (
          <Pressable
            style={{
              marginTop: 6,
              backgroundColor: colors.primary,
              paddingHorizontal: 18,
              paddingVertical: 10,
              borderRadius: buttonRadius,
            }}
            onPress={onRetry}
          >
            <Text style={{ color: colors.onPrimary, fontWeight: '700' }}>
              Erneut versuchen
            </Text>
          </Pressable>
        ) : null}
      </View>
    );
  }
  return <>{children}</>;
}

const styles = StyleSheet.create({
  center: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24, gap: 10 },
});
