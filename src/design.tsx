import { createContext, ReactNode, useContext, useMemo, useState } from 'react';
import {
  Platform,
  Pressable,
  StyleSheet,
  Text,
  useColorScheme,
  View,
  ViewStyle,
} from 'react-native';

export type DesignName = 'ios' | 'android';
export type Scheme = 'light' | 'dark';

export type Palette = {
  background: string;
  surface: string;
  surfaceGlass: string;
  card: string;
  text: string;
  muted: string;
  faint: string;
  primary: string;
  onPrimary: string;
  border: string;
  danger: string;
  success: string;
  warning: string;
  headerBackground: string;
  headerTint: string;
  tabBackground: string;
};

export type Design = {
  name: DesignName;
  scheme: Scheme;
  colors: Palette;
  cardRadius: number;
  buttonRadius: number;
  chipRadius: number;
  glass: boolean;
  fab: boolean;
  headerTitleAlign: 'left' | 'center';
  fontFamily?: string;
  titleFontWeight: '700' | '800';
  cardShadow: ViewStyle;
  blurTint: 'light' | 'dark';
};

const PALETTES: Record<DesignName, Record<Scheme, Palette>> = {
  ios: {
    light: {
      background: '#F2F2F7',
      surface: '#FFFFFF',
      surfaceGlass: 'rgba(249,249,251,0.72)',
      card: '#FFFFFF',
      text: '#1C1C1E',
      muted: 'rgba(60,60,67,0.6)',
      faint: 'rgba(60,60,67,0.3)',
      primary: '#007AFF',
      onPrimary: '#FFFFFF',
      border: 'rgba(60,60,67,0.18)',
      danger: '#FF3B30',
      success: '#34C759',
      warning: '#FF9500',
      headerBackground: 'rgba(249,249,251,0.85)',
      headerTint: '#1C1C1E',
      tabBackground: 'rgba(249,249,251,0.85)',
    },
    dark: {
      background: '#000000',
      surface: '#1C1C1E',
      surfaceGlass: 'rgba(28,28,30,0.7)',
      card: '#1C1C1E',
      text: '#FFFFFF',
      muted: 'rgba(235,235,245,0.6)',
      faint: 'rgba(235,235,245,0.3)',
      primary: '#0A84FF',
      onPrimary: '#FFFFFF',
      border: 'rgba(84,84,88,0.6)',
      danger: '#FF453A',
      success: '#30D158',
      warning: '#FF9F0A',
      headerBackground: 'rgba(20,20,22,0.8)',
      headerTint: '#FFFFFF',
      tabBackground: 'rgba(20,20,22,0.8)',
    },
  },
  android: {
    light: {
      background: '#FEF7FF',
      surface: '#FFFFFF',
      surfaceGlass: '#F3EDF7',
      card: '#F7F2FA',
      text: '#1D1B20',
      muted: '#49454F',
      faint: '#79747E',
      primary: '#6750A4',
      onPrimary: '#FFFFFF',
      border: '#CAC4D0',
      danger: '#B3261E',
      success: '#386A20',
      warning: '#7D5700',
      headerBackground: '#6750A4',
      headerTint: '#FFFFFF',
      tabBackground: '#F3EDF7',
    },
    dark: {
      background: '#141218',
      surface: '#1D1B20',
      surfaceGlass: '#211F26',
      card: '#211F26',
      text: '#E6E0E9',
      muted: '#CAC4D0',
      faint: '#938F99',
      primary: '#D0BCFF',
      onPrimary: '#381E72',
      border: '#49454F',
      danger: '#F2B8B5',
      success: '#9CD67D',
      warning: '#E9C46A',
      headerBackground: '#211F26',
      headerTint: '#E6E0E9',
      tabBackground: '#211F26',
    },
  },
};

const IOS_FONT =
  Platform.OS === 'ios'
    ? undefined
    : "-apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Helvetica Neue', system-ui, sans-serif";
const ANDROID_FONT =
  Platform.OS === 'android'
    ? 'sans-serif'
    : "Roboto, 'Helvetica Neue', system-ui, sans-serif";

export function buildDesign(name: DesignName, scheme: Scheme): Design {
  const colors = PALETTES[name][scheme];
  if (name === 'android') {
    return {
      name,
      scheme,
      colors,
      cardRadius: 16,
      buttonRadius: 20,
      chipRadius: 8,
      glass: false,
      fab: true,
      headerTitleAlign: 'left',
      fontFamily: ANDROID_FONT,
      titleFontWeight: '700',
      cardShadow: {
        shadowColor: '#000',
        shadowOpacity: scheme === 'dark' ? 0.4 : 0.12,
        shadowRadius: 3,
        shadowOffset: { width: 0, height: 1 },
        elevation: 2,
      },
      blurTint: scheme === 'dark' ? 'dark' : 'light',
    };
  }
  return {
    name,
    scheme,
    colors,
    cardRadius: 12,
    buttonRadius: 12,
    chipRadius: 999,
    glass: true,
    fab: false,
    headerTitleAlign: 'center',
    fontFamily: IOS_FONT,
    titleFontWeight: '800',
    cardShadow: {
      shadowColor: '#000',
      shadowOpacity: scheme === 'dark' ? 0.5 : 0.04,
      shadowRadius: 6,
      shadowOffset: { width: 0, height: 1 },
      elevation: 0,
    },
    blurTint: scheme === 'dark' ? 'dark' : 'light',
  };
}

function initialDesign(): DesignName {
  if (Platform.OS === 'ios') return 'ios';
  if (Platform.OS === 'android') return 'android';
  if (typeof window !== 'undefined' && window.location) {
    const param = new URLSearchParams(window.location.search).get('design');
    if (param === 'android' || param === 'ios') return param;
  }
  return 'ios';
}

type DesignContextValue = Design & {
  setDesignName: (name: DesignName) => void;
  setScheme: (scheme: Scheme | null) => void;
};

const DesignContext = createContext<DesignContextValue | null>(null);

export function DesignProvider({ children }: { children: ReactNode }) {
  const systemScheme = useColorScheme();
  const [name, setName] = useState<DesignName>(initialDesign);
  const [schemeOverride, setSchemeOverride] = useState<Scheme | null>(null);
  const scheme: Scheme = schemeOverride ?? (systemScheme === 'dark' ? 'dark' : 'light');
  const value = useMemo<DesignContextValue>(
    () => ({
      ...buildDesign(name, scheme),
      setDesignName: setName,
      setScheme: setSchemeOverride,
    }),
    [name, scheme],
  );
  return <DesignContext.Provider value={value}>{children}</DesignContext.Provider>;
}

export function useDesign(): DesignContextValue {
  const ctx = useContext(DesignContext);
  if (!ctx) {
    throw new Error('useDesign must be used within a DesignProvider');
  }
  return ctx;
}

/**
 * Preview switch (web only): compare the two design languages and light/dark.
 * On real devices Platform.OS and the system color scheme already drive the look.
 */
export function DesignSwitcher() {
  const { name, scheme, setDesignName, setScheme, colors } = useDesign();
  if (Platform.OS !== 'web') return null;
  return (
    <View style={styles.switcher} pointerEvents="box-none">
      <View style={styles.pill}>
        {(['ios', 'android'] as DesignName[]).map((option) => {
          const active = option === name;
          return (
            <Pressable
              key={option}
              onPress={() => setDesignName(option)}
              style={[styles.segment, active && { backgroundColor: colors.primary }]}
            >
              <Text
                style={[styles.segmentText, { color: active ? colors.onPrimary : '#1b2733' }]}
              >
                {option === 'ios' ? 'iOS' : 'Android'}
              </Text>
            </Pressable>
          );
        })}
        <View style={styles.divider} />
        {(['light', 'dark'] as Scheme[]).map((option) => {
          const active = option === scheme;
          return (
            <Pressable
              key={option}
              onPress={() => setScheme(option)}
              style={[styles.segment, active && { backgroundColor: colors.primary }]}
            >
              <Text
                style={[styles.segmentText, { color: active ? colors.onPrimary : '#1b2733' }]}
              >
                {option === 'light' ? 'Hell' : 'Dunkel'}
              </Text>
            </Pressable>
          );
        })}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  switcher: {
    position: 'absolute',
    bottom: 90,
    alignSelf: 'center',
    zIndex: 1000,
  },
  pill: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(255,255,255,0.94)',
    borderRadius: 999,
    padding: 4,
    shadowColor: '#000',
    shadowOpacity: 0.18,
    shadowRadius: 8,
    shadowOffset: { width: 0, height: 2 },
    elevation: 6,
  },
  divider: { width: 1, height: 20, backgroundColor: 'rgba(0,0,0,0.12)', marginHorizontal: 4 },
  segment: { paddingHorizontal: 14, paddingVertical: 8, borderRadius: 999 },
  segmentText: { fontWeight: '700', fontSize: 13 },
});
