import { StatusBar } from 'expo-status-bar';
import { useCallback, useEffect, useState } from 'react';
import {
  ActivityIndicator,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';

import { API_BASE_URL, getServerStatus, ServerStatus } from './src/api';

type LoadState = 'idle' | 'loading' | 'ok' | 'error';

export default function App() {
  const [state, setState] = useState<LoadState>('idle');
  const [status, setStatus] = useState<ServerStatus | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [checkedAt, setCheckedAt] = useState<string | null>(null);

  const runCheck = useCallback(async () => {
    setState('loading');
    setError(null);
    try {
      const result = await getServerStatus();
      setStatus(result);
      setState('ok');
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
      setState('error');
    } finally {
      setCheckedAt(new Date().toLocaleTimeString('de-DE'));
    }
  }, []);

  useEffect(() => {
    runCheck();
  }, [runCheck]);

  const statusColor =
    state === 'ok' ? '#1a7f37' : state === 'error' ? '#c0392b' : '#8a8f98';
  const statusLabel =
    state === 'ok'
      ? 'Verbunden'
      : state === 'error'
        ? 'Nicht erreichbar'
        : 'Prüfe…';

  return (
    <View style={styles.screen}>
      <ScrollView contentContainerStyle={styles.container}>
        <Text style={styles.kicker}>Rettungswache</Text>
        <Text style={styles.title}>Wachbuch-Client</Text>
        <Text style={styles.subtitle}>
          Mobiler Client für iOS und Android
        </Text>

        <View style={styles.card}>
          <Text style={styles.cardLabel}>Server-Status</Text>
          <View style={styles.statusRow}>
            <View style={[styles.dot, { backgroundColor: statusColor }]} />
            {state === 'loading' ? (
              <ActivityIndicator color={statusColor} />
            ) : (
              <Text style={[styles.statusText, { color: statusColor }]}>
                {statusLabel}
              </Text>
            )}
          </View>

          {state === 'ok' && status ? (
            <View style={styles.detailBlock}>
              <Text style={styles.detail}>API-Version: {status.api_version}</Text>
              <Text style={styles.detail}>
                Angemeldet: {status.authenticated ? 'ja' : 'nein'}
              </Text>
              {status.station ? (
                <Text style={styles.detail}>Wache: {status.station}</Text>
              ) : null}
            </View>
          ) : null}
          {state === 'error' && error ? (
            <Text style={styles.errorDetail}>{error}</Text>
          ) : null}

          <Text style={styles.meta}>Backend: {API_BASE_URL}</Text>
          {checkedAt ? (
            <Text style={styles.meta}>Zuletzt geprüft: {checkedAt}</Text>
          ) : null}
        </View>

        <Pressable
          style={({ pressed }) => [
            styles.button,
            pressed && styles.buttonPressed,
          ]}
          onPress={runCheck}
          disabled={state === 'loading'}
        >
          <Text style={styles.buttonText}>Verbindung erneut prüfen</Text>
        </Pressable>

        <Text style={styles.platform}>Plattform: {Platform.OS}</Text>
      </ScrollView>
      <StatusBar style="dark" />
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: '#f5f7fa',
  },
  container: {
    flexGrow: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24,
    gap: 8,
  },
  kicker: {
    fontSize: 13,
    letterSpacing: 2,
    textTransform: 'uppercase',
    color: '#8a8f98',
    fontWeight: '600',
  },
  title: {
    fontSize: 30,
    fontWeight: '800',
    color: '#1b2733',
  },
  subtitle: {
    fontSize: 15,
    color: '#5b6672',
    marginBottom: 20,
  },
  card: {
    width: '100%',
    maxWidth: 420,
    backgroundColor: '#ffffff',
    borderRadius: 16,
    padding: 20,
    gap: 8,
    shadowColor: '#000',
    shadowOpacity: 0.08,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 4 },
    elevation: 3,
  },
  cardLabel: {
    fontSize: 12,
    letterSpacing: 1,
    textTransform: 'uppercase',
    color: '#8a8f98',
    fontWeight: '700',
  },
  statusRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    minHeight: 28,
  },
  dot: {
    width: 12,
    height: 12,
    borderRadius: 6,
  },
  statusText: {
    fontSize: 20,
    fontWeight: '700',
  },
  detailBlock: {
    gap: 2,
  },
  detail: {
    fontSize: 14,
    color: '#1b2733',
  },
  errorDetail: {
    fontSize: 13,
    color: '#c0392b',
  },
  meta: {
    fontSize: 12,
    color: '#8a8f98',
  },
  button: {
    marginTop: 20,
    backgroundColor: '#1b6ef3',
    paddingVertical: 14,
    paddingHorizontal: 24,
    borderRadius: 12,
    width: '100%',
    maxWidth: 420,
    alignItems: 'center',
  },
  buttonPressed: {
    opacity: 0.8,
  },
  buttonText: {
    color: '#ffffff',
    fontSize: 16,
    fontWeight: '700',
  },
  platform: {
    marginTop: 16,
    fontSize: 12,
    color: '#a2a9b3',
  },
});
