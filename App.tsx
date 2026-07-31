import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { DefaultTheme, NavigationContainer, Theme } from '@react-navigation/native';
import {
  createNativeStackNavigator,
  NativeStackNavigationOptions,
} from '@react-navigation/native-stack';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { BlurView } from 'expo-blur';
import { StatusBar } from 'expo-status-bar';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { Platform, Pressable, StyleSheet, Text, View } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import { initApiBaseUrl, setAuthToken } from './src/api';
import { Design, DesignProvider, DesignSwitcher, useDesign } from './src/design';
import { CalendarStackParamList, HandoverStackParamList } from './src/navigation';
import CalendarCreateScreen from './src/screens/CalendarCreateScreen';
import CalendarScreen from './src/screens/CalendarScreen';
import CoffeeScreen from './src/screens/CoffeeScreen';
import HandoverCreateScreen from './src/screens/HandoverCreateScreen';
import HandoverDetailScreen from './src/screens/HandoverDetailScreen';
import HandoversScreen from './src/screens/HandoversScreen';
import LoginScreen from './src/screens/LoginScreen';
import OverviewScreen from './src/screens/OverviewScreen';

const queryClient = new QueryClient({
  defaultOptions: { queries: { retry: 1, refetchOnWindowFocus: false } },
});

const Tabs = createBottomTabNavigator();
const HandoverStack = createNativeStackNavigator<HandoverStackParamList>();
const CalendarStack = createNativeStackNavigator<CalendarStackParamList>();

function stackHeaderOptions(design: Design): NativeStackNavigationOptions {
  return {
    headerStyle: { backgroundColor: design.colors.headerBackground },
    headerTintColor: design.colors.headerTint,
    headerTitleAlign: design.headerTitleAlign,
    headerShadowVisible: design.name === 'android',
    contentStyle: { backgroundColor: design.colors.background },
  };
}

function HandoverStackScreen() {
  const design = useDesign();
  return (
    <HandoverStack.Navigator screenOptions={stackHeaderOptions(design)}>
      <HandoverStack.Screen
        name="HandoverList"
        component={HandoversScreen}
        options={{ title: 'Übergaben' }}
      />
      <HandoverStack.Screen
        name="HandoverDetail"
        component={HandoverDetailScreen}
        options={({ route }) => ({ title: route.params.title })}
      />
      <HandoverStack.Screen
        name="HandoverCreate"
        component={HandoverCreateScreen}
        options={{ title: 'Neue Übergabe' }}
      />
    </HandoverStack.Navigator>
  );
}

function CalendarStackScreen() {
  const design = useDesign();
  return (
    <CalendarStack.Navigator screenOptions={stackHeaderOptions(design)}>
      <CalendarStack.Screen
        name="CalendarList"
        component={CalendarScreen}
        options={{ title: 'Kalender' }}
      />
      <CalendarStack.Screen
        name="CalendarCreate"
        component={CalendarCreateScreen}
        options={{ title: 'Neuer Termin' }}
      />
    </CalendarStack.Navigator>
  );
}

function MainTabs({ onLogout }: { onLogout: () => void }) {
  const design = useDesign();
  const { colors } = design;

  const LogoutButton = () => (
    <Pressable onPress={onLogout} hitSlop={8}>
      <Text style={[styles.logout, { color: colors.headerTint }]}>Abmelden</Text>
    </Pressable>
  );

  return (
    <Tabs.Navigator
      screenOptions={{
        headerStyle: { backgroundColor: colors.headerBackground },
        headerTintColor: colors.headerTint,
        headerTitleAlign: design.headerTitleAlign,
        headerShadowVisible: design.name === 'android',
        tabBarActiveTintColor: design.name === 'android' ? colors.primary : colors.primary,
        tabBarInactiveTintColor: colors.muted,
        tabBarStyle: design.glass
          ? {
              position: 'absolute',
              backgroundColor: 'transparent',
              borderTopColor: colors.border,
              borderTopWidth: StyleSheet.hairlineWidth,
            }
          : {
              backgroundColor: colors.tabBackground,
              borderTopColor: colors.border,
            },
        tabBarBackground: design.glass
          ? () => (
              <BlurView
                tint="light"
                intensity={50}
                style={StyleSheet.absoluteFill}
              />
            )
          : undefined,
        headerRight: () => <LogoutButton />,
      }}
    >
      <Tabs.Screen name="Übersicht" component={OverviewScreen} />
      <Tabs.Screen
        name="Übergaben"
        component={HandoverStackScreen}
        options={{ headerShown: false }}
      />
      <Tabs.Screen
        name="Kalender"
        component={CalendarStackScreen}
        options={{ headerShown: false }}
      />
      <Tabs.Screen name="Kaffeekasse" component={CoffeeScreen} />
    </Tabs.Navigator>
  );
}

function Root() {
  const design = useDesign();
  const [token, setToken] = useState<string | null>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    initApiBaseUrl().finally(() => setReady(true));
  }, []);

  const handleLoggedIn = useCallback((newToken: string) => {
    setAuthToken(newToken);
    setToken(newToken);
  }, []);

  const handleLogout = useCallback(() => {
    setAuthToken(null);
    setToken(null);
    queryClient.clear();
  }, []);

  const navTheme = useMemo<Theme>(
    () => ({
      ...DefaultTheme,
      colors: {
        ...DefaultTheme.colors,
        background: design.colors.background,
        card: design.colors.headerBackground,
        primary: design.colors.primary,
        text: design.colors.text,
        border: design.colors.border,
      },
    }),
    [design],
  );

  return (
    <>
      {!ready ? (
        <View style={{ flex: 1, backgroundColor: design.colors.background }} />
      ) : token ? (
        <NavigationContainer theme={navTheme}>
          <MainTabs onLogout={handleLogout} />
        </NavigationContainer>
      ) : (
        <LoginScreen onLoggedIn={handleLoggedIn} />
      )}
      <DesignSwitcher />
      <StatusBar style={design.name === 'android' ? 'light' : 'dark'} />
    </>
  );
}

export default function App() {
  return (
    <SafeAreaProvider>
      <QueryClientProvider client={queryClient}>
        <DesignProvider>
          <Root />
        </DesignProvider>
      </QueryClientProvider>
    </SafeAreaProvider>
  );
}

const styles = StyleSheet.create({
  logout: { fontWeight: '700', fontSize: 14, marginRight: 12 },
});
