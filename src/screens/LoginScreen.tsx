import { useMemo, useState } from 'react';
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
import { Design, useDesign } from '../design';

type Props = {
  onLoggedIn: (token: string, station: string | null, role: string | null) => void;
};

export default function LoginScreen({ onLoggedIn }: Props) {
  const design = useDesign();
  const styles = useMemo(() => makeStyles(design), [design]);
  const { colors } = design;
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
          android_ripple={{ color: 'rgba(255,255,255,0.24)' }}
        >
          {busy ? (
            <ActivityIndicator color={colors.onPrimary} />
          ) : (
            <Text style={styles.buttonText}>Anmelden</Text>
          )}
        </Pressable>

        <Text style={styles.meta}>Server: {API_BASE_URL}</Text>
      </View>
    </KeyboardAvoidingView>
  );
}

function makeStyles(design: Design) {
  const { colors, fontFamily } = design;
  return StyleSheet.create({
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
      borderRadius: design.cardRadius,
      padding: 24,
      borderWidth: design.glass ? StyleSheet.hairlineWidth : 0,
      borderColor: colors.border,
      ...design.cardShadow,
    },
    kicker: {
      fontSize: 12,
      letterSpacing: 2,
      textTransform: 'uppercase',
      color: colors.faint,
      fontWeight: '700',
      fontFamily,
    },
    title: { fontSize: 26, fontWeight: design.titleFontWeight, color: colors.text, fontFamily },
    subtitle: { fontSize: 15, color: colors.muted, marginBottom: 16, fontFamily },
    label: {
      fontSize: 12,
      color: colors.muted,
      fontWeight: '600',
      marginTop: 12,
      marginBottom: 4,
      fontFamily,
    },
    input: {
      borderWidth: 1,
      borderColor: colors.border,
      borderRadius: design.name === 'android' ? 8 : 10,
      paddingHorizontal: 12,
      paddingVertical: 11,
      fontSize: 15,
      color: colors.text,
      backgroundColor: colors.surface,
      fontFamily,
    },
    error: { color: colors.danger, fontSize: 13, marginTop: 12, fontFamily },
    button: {
      marginTop: 20,
      backgroundColor: colors.primary,
      paddingVertical: 14,
      borderRadius: design.buttonRadius,
      alignItems: 'center',
    },
    buttonPressed: { opacity: 0.85 },
    buttonText: { color: colors.onPrimary, fontSize: 16, fontWeight: '700', fontFamily },
    meta: { marginTop: 16, fontSize: 12, color: colors.faint, textAlign: 'center', fontFamily },
  });
}
