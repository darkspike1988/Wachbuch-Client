import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import {
  ActivityIndicator,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';

import { ApiError, createCalendarEvent } from '../api';
import { Design, useDesign } from '../design';
import { CalendarStackParamList } from '../navigation';

type Props = NativeStackScreenProps<CalendarStackParamList, 'CalendarCreate'>;

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const TIME_RE = /^\d{2}:\d{2}$/;

export default function CalendarCreateScreen({ navigation }: Props) {
  const design = useDesign();
  const styles = useMemo(() => makeStyles(design), [design]);
  const { colors } = design;
  const queryClient = useQueryClient();
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [date, setDate] = useState('');
  const [startTime, setStartTime] = useState('');
  const [endTime, setEndTime] = useState('');
  const [localError, setLocalError] = useState<string | null>(null);

  const mutation = useMutation({
    mutationFn: () =>
      createCalendarEvent({
        title,
        description,
        starts_at: `${date} ${startTime}:00`,
        ends_at: `${date} ${endTime}:00`,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['calendar'] });
      queryClient.invalidateQueries({ queryKey: ['overview'] });
      navigation.goBack();
    },
  });

  const submit = () => {
    if (!DATE_RE.test(date)) {
      setLocalError('Datum im Format JJJJ-MM-TT angeben.');
      return;
    }
    if (!TIME_RE.test(startTime) || !TIME_RE.test(endTime)) {
      setLocalError('Zeiten im Format HH:MM angeben.');
      return;
    }
    setLocalError(null);
    mutation.mutate();
  };

  const apiError = mutation.error instanceof ApiError ? mutation.error.message : null;
  const error = localError ?? apiError;
  const canSubmit = title.trim().length > 0 && date && startTime && endTime;

  return (
    <ScrollView style={styles.screen} contentContainerStyle={styles.content}>
      <Text style={styles.label}>Titel</Text>
      <TextInput
        style={styles.input}
        value={title}
        onChangeText={setTitle}
        placeholder="z. B. Fahrzeugcheck"
        placeholderTextColor={colors.faint}
      />

      <Text style={styles.label}>Beschreibung (optional)</Text>
      <TextInput
        style={[styles.input, styles.multiline]}
        value={description}
        onChangeText={setDescription}
        placeholder="Details"
        placeholderTextColor={colors.faint}
        multiline
      />

      <Text style={styles.label}>Datum (JJJJ-MM-TT)</Text>
      <TextInput
        style={styles.input}
        value={date}
        onChangeText={setDate}
        placeholder="2026-08-05"
        placeholderTextColor={colors.faint}
        autoCapitalize="none"
      />

      <View style={styles.timeRow}>
        <View style={styles.timeCol}>
          <Text style={styles.label}>Beginn (HH:MM)</Text>
          <TextInput
            style={styles.input}
            value={startTime}
            onChangeText={setStartTime}
            placeholder="08:00"
            placeholderTextColor={colors.faint}
          />
        </View>
        <View style={styles.timeCol}>
          <Text style={styles.label}>Ende (HH:MM)</Text>
          <TextInput
            style={styles.input}
            value={endTime}
            onChangeText={setEndTime}
            placeholder="09:00"
            placeholderTextColor={colors.faint}
          />
        </View>
      </View>

      {error ? <Text style={styles.error}>{error}</Text> : null}

      <Pressable
        style={({ pressed }) => [
          styles.button,
          (!canSubmit || mutation.isPending) && styles.buttonDisabled,
          pressed && styles.pressed,
        ]}
        onPress={submit}
        disabled={!canSubmit || mutation.isPending}
        android_ripple={{ color: 'rgba(255,255,255,0.24)' }}
      >
        {mutation.isPending ? (
          <ActivityIndicator color={colors.onPrimary} />
        ) : (
          <Text style={styles.buttonText}>Termin anlegen</Text>
        )}
      </Pressable>
    </ScrollView>
  );
}

function makeStyles(design: Design) {
  const { colors, fontFamily } = design;
  return StyleSheet.create({
    screen: { flex: 1, backgroundColor: colors.background },
    content: { padding: 16, paddingBottom: design.glass ? 96 : 24 },
    label: {
      fontSize: 13,
      fontWeight: '700',
      color: colors.muted,
      marginTop: 16,
      marginBottom: 6,
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
    multiline: { minHeight: 80, textAlignVertical: 'top' },
    timeRow: { flexDirection: 'row', gap: 12 },
    timeCol: { flex: 1 },
    error: { color: colors.danger, fontSize: 13, marginTop: 12, fontFamily },
    button: {
      marginTop: 20,
      backgroundColor: colors.primary,
      paddingVertical: 14,
      borderRadius: design.buttonRadius,
      alignItems: 'center',
    },
    buttonDisabled: { opacity: 0.5 },
    pressed: { opacity: 0.85 },
    buttonText: { color: colors.onPrimary, fontSize: 16, fontWeight: '700', fontFamily },
  });
}
