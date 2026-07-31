import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import {
  ActivityIndicator,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';

import {
  ApiError,
  createHandover,
  HANDOVER_CATEGORIES,
  HANDOVER_PRIORITIES,
} from '../api';
import { HandoverStackParamList } from '../navigation';
import { colors } from '../theme';

type Props = NativeStackScreenProps<HandoverStackParamList, 'HandoverCreate'>;

function ChipRow({
  options,
  value,
  onChange,
}: {
  options: { value: string; label: string }[];
  value: string;
  onChange: (value: string) => void;
}) {
  return (
    <View style={styles.chips}>
      {options.map((option) => (
        <Pressable
          key={option.value}
          onPress={() => onChange(option.value)}
          style={[styles.chip, value === option.value && styles.chipActive]}
        >
          <Text
            style={[
              styles.chipText,
              value === option.value && styles.chipTextActive,
            ]}
          >
            {option.label}
          </Text>
        </Pressable>
      ))}
    </View>
  );
}

export default function HandoverCreateScreen({ navigation }: Props) {
  const queryClient = useQueryClient();
  const [category, setCategory] = useState(HANDOVER_CATEGORIES[0].value);
  const [priority, setPriority] = useState(HANDOVER_PRIORITIES[0].value);
  const [title, setTitle] = useState('');
  const [details, setDetails] = useState('');

  const mutation = useMutation({
    mutationFn: () => createHandover({ category, priority, title, details }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['handovers'] });
      queryClient.invalidateQueries({ queryKey: ['overview'] });
      navigation.goBack();
    },
  });

  const error =
    mutation.error instanceof ApiError ? mutation.error.message : null;
  const canSubmit = title.trim().length > 0 && details.trim().length > 0;

  return (
    <ScrollView style={styles.screen} contentContainerStyle={styles.content}>
      <Text style={styles.label}>Kategorie</Text>
      <ChipRow options={HANDOVER_CATEGORIES} value={category} onChange={setCategory} />

      <Text style={styles.label}>Priorität</Text>
      <ChipRow options={HANDOVER_PRIORITIES} value={priority} onChange={setPriority} />

      <Text style={styles.label}>Titel</Text>
      <TextInput
        style={styles.input}
        value={title}
        onChangeText={setTitle}
        placeholder="Kurzer Titel"
        placeholderTextColor={colors.faint}
      />

      <Text style={styles.label}>Information für die nächste Schicht</Text>
      <TextInput
        style={[styles.input, styles.multiline]}
        value={details}
        onChangeText={setDetails}
        placeholder="Beschreibung"
        placeholderTextColor={colors.faint}
        multiline
        numberOfLines={5}
      />

      {error ? <Text style={styles.error}>{error}</Text> : null}

      <Pressable
        style={({ pressed }) => [
          styles.button,
          (!canSubmit || mutation.isPending) && styles.buttonDisabled,
          pressed && styles.buttonPressed,
        ]}
        onPress={() => mutation.mutate()}
        disabled={!canSubmit || mutation.isPending}
      >
        {mutation.isPending ? (
          <ActivityIndicator color="#fff" />
        ) : (
          <Text style={styles.buttonText}>Übergabe anlegen</Text>
        )}
      </Pressable>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.background },
  content: { padding: 16 },
  label: {
    fontSize: 13,
    fontWeight: '700',
    color: colors.muted,
    marginTop: 16,
    marginBottom: 6,
  },
  chips: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  chip: {
    paddingHorizontal: 12,
    paddingVertical: 7,
    borderRadius: 999,
    backgroundColor: colors.surface,
    borderWidth: 1,
    borderColor: colors.border,
  },
  chipActive: { backgroundColor: colors.primary, borderColor: colors.primary },
  chipText: { color: colors.muted, fontWeight: '600', fontSize: 13 },
  chipTextActive: { color: '#fff' },
  input: {
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 10,
    fontSize: 15,
    color: colors.text,
    backgroundColor: colors.surface,
  },
  multiline: { minHeight: 110, textAlignVertical: 'top' },
  error: { color: colors.danger, fontSize: 13, marginTop: 12 },
  button: {
    marginTop: 20,
    backgroundColor: colors.primary,
    paddingVertical: 14,
    borderRadius: 12,
    alignItems: 'center',
  },
  buttonDisabled: { opacity: 0.5 },
  buttonPressed: { opacity: 0.85 },
  buttonText: { color: '#fff', fontSize: 16, fontWeight: '700' },
});
