import { createContext, ReactNode, useContext, useMemo, useState } from 'react';
import { Platform, Pressable, StyleSheet, Text, View, ViewStyle } from 'react-native';

export type DesignName = 'ios' | 'android';

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
  colors: Palette;
  // Shape / elevation language.
  cardRadius: number;
  buttonRadius: number;
  chipRadius: number;
  glass: boolean; // iOS: translucent frosted surfaces
  fab: boolean; // Android: floating action button for primary create
  headerTitleAlign: 'left' | 'center';
  fontFamily?: string;
  titleFontWeight: '700' | '800';
  cardShadow: ViewStyle;
};

const IOS_COLORS: Palette = {
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
  headerBackground: 'rgba(249,249,251,0.8)',
  headerTint: '#1C1C1E',
  tabBackground: 'rgba(249,249,251,0.8)',
};

const ANDROID_COLORS: Palette = {
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
};

const IOS_FONT =
  Platform.OS === 'ios'
    ? undefined
    : "-apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Helvetica Neue', system-ui, sans-serif";
const ANDROID_FONT =
  Platform.OS === 'android'
    ? 'sans-serif'
    : "Roboto, 'Helvetica Neue', system-ui, sans-serif";

export function buildDesign(name: DesignName): Design {
  if (name === 'android') {
    return {
      name,
      colors: ANDROID_COLORS,
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
        shadowOpacity: 0.12,
        shadowRadius: 3,
        shadowOffset: { width: 0, height: 1 },
        elevation: 2,
      },
    };
  }
  return {
    name,
    colors: IOS_COLORS,
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
      shadowOpacity: 0.04,
      shadowRadius: 6,
      shadowOffset: { width: 0, height: 1 },
      elevation: 0,
    },
  };
}

function initialDesign(): DesignName {
  if (Platform.OS === 'ios') return 'ios';
  if (Platform.OS === 'android') return 'android';
  // Web: allow ?design=android|ios for previewing either language.
  if (typeof window !== 'undefined' && window.location) {
    const param = new URLSearchParams(window.location.search).get('design');
    if (param === 'android' || param === 'ios') return param;
  }
  return 'ios';
}

type DesignContextValue = Design & {
  setDesignName: (name: DesignName) => void;
};

const DesignContext = createContext<DesignContextValue | null>(null);

export function DesignProvider({ children }: { children: ReactNode }) {
  const [name, setName] = useState<DesignName>(initialDesign);
  const value = useMemo<DesignContextValue>(
    () => ({ ...buildDesign(name), setDesignName: setName }),
    [name],
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
 * Small preview switch so the two design languages can be compared in the browser.
 * On real devices Platform.OS already dictates the look, so it is hidden there.
 */
export function DesignSwitcher() {
  const { name, setDesignName, colors } = useDesign();
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
              style={[
                styles.segment,
                active && { backgroundColor: colors.primary },
              ]}
            >
              <Text
                style={[
                  styles.segmentText,
                  { color: active ? '#fff' : '#1b2733' },
                ]}
              >
                {option === 'ios' ? 'iOS' : 'Android'}
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
    backgroundColor: 'rgba(255,255,255,0.92)',
    borderRadius: 999,
    padding: 4,
    shadowColor: '#000',
    shadowOpacity: 0.18,
    shadowRadius: 8,
    shadowOffset: { width: 0, height: 2 },
    elevation: 6,
  },
  segment: {
    paddingHorizontal: 18,
    paddingVertical: 8,
    borderRadius: 999,
  },
  segmentText: { fontWeight: '700', fontSize: 13 },
});
