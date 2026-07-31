import { useState } from 'react';
import {
  ActivityIndicator,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';

import { API_BASE_URL, login } from '../api';
import { colors } from '../theme';

type Props = {
  onLoggedIn: (token: string, station: string | null, role: string | null) => void;
};

export default function LoginScreen({ onLoggedIn }: Props) {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const submit = async () => {
    setBusy(true);
    setError(null);
    try {
      const result = await login(username.trim(), password);
      if (!result.has_membership) {
        setError('Kein Zugang zu einer Wache. Bitte Freigabe abwarten.');
        return;
      }
      onLoggedIn(result.token, result.station, result.role);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Anmeldung fehlgeschlagen');
    } finally {
      setBusy(false);
    }
  };

  return (
    <KeyboardAvoidingView
      style={styles.screen}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      <View style={styles.card}>
        <Text style={styles.kicker}>Rettungswache</Text>
        <Text style={styles.title}>Wachbuch-Client</Text>
        <Text style={styles.subtitle}>Anmeldung</Text>

        <Text style={styles.label}>Benutzername</Text>
        <TextInput
          style={styles.input}
          value={username}
          onChangeText={setUsername}
          autoCapitalize="none"
          autoCorrect={false}
          placeholder="z. B. admin"
          placeholderTextColor={colors.faint}
        />

        <Text style={styles.label}>Passwort</Text>
        <TextInput
          style={styles.input}
          value={password}
          onChangeText={setPassword}
          secureTextEntry
          placeholder="Passwort"
          placeholderTextColor={colors.faint}
          onSubmitEditing={submit}
        />

        {error ? <Text style={styles.error}>{error}</Text> : null}

        <Pressable
          style={({ pressed }) => [styles.button, pressed && styles.buttonPressed]}
          onPress={submit}
          disabled={busy}
        >
          {busy ? (
            <ActivityIndicator color="#fff" />
          ) : (
            <Text style={styles.buttonText}>Anmelden</Text>
          )}
        </Pressable>

        <Text style={styles.meta}>Server: {API_BASE_URL}</Text>
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: colors.background,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24,
  },
  card: {
    width: '100%',
    maxWidth: 420,
    backgroundColor: colors.surface,
    borderRadius: 16,
    padding: 24,
    shadowColor: '#000',
    shadowOpacity: 0.08,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 4 },
    elevation: 3,
  },
  kicker: {
    fontSize: 12,
    letterSpacing: 2,
    textTransform: 'uppercase',
    color: colors.faint,
    fontWeight: '700',
  },
  title: { fontSize: 26, fontWeight: '800', color: colors.text },
  subtitle: { fontSize: 15, color: colors.muted, marginBottom: 16 },
  label: {
    fontSize: 12,
    color: colors.muted,
    fontWeight: '600',
    marginTop: 12,
    marginBottom: 4,
  },
  input: {
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 10,
    fontSize: 15,
    color: colors.text,
    backgroundColor: '#fff',
  },
  error: { color: colors.danger, fontSize: 13, marginTop: 12 },
  button: {
    marginTop: 20,
    backgroundColor: colors.primary,
    paddingVertical: 14,
    borderRadius: 12,
    alignItems: 'center',
  },
  buttonPressed: { opacity: 0.85 },
  buttonText: { color: '#fff', fontSize: 16, fontWeight: '700' },
  meta: { marginTop: 16, fontSize: 12, color: colors.faint, textAlign: 'center' },
});
