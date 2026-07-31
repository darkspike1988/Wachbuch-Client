import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { StatusBar } from 'expo-status-bar';
import { useCallback, useState } from 'react';
import { Pressable, StyleSheet, Text } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import { setAuthToken } from './src/api';
import { HandoverStackParamList } from './src/navigation';
import CoffeeScreen from './src/screens/CoffeeScreen';
import HandoverCreateScreen from './src/screens/HandoverCreateScreen';
import HandoverDetailScreen from './src/screens/HandoverDetailScreen';
import HandoversScreen from './src/screens/HandoversScreen';
import LoginScreen from './src/screens/LoginScreen';
import OverviewScreen from './src/screens/OverviewScreen';
import { colors } from './src/theme';

const queryClient = new QueryClient({
  defaultOptions: { queries: { retry: 1, refetchOnWindowFocus: false } },
});

const Tabs = createBottomTabNavigator();
const HandoverStack = createNativeStackNavigator<HandoverStackParamList>();

function HandoverStackScreen() {
  return (
    <HandoverStack.Navigator screenOptions={headerStyle}>
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

const headerStyle = {
  headerStyle: { backgroundColor: colors.primary },
  headerTintColor: '#fff',
  headerTitleStyle: { fontWeight: '700' as const },
};

export default function App() {
  const [token, setToken] = useState<string | null>(null);

  const handleLoggedIn = useCallback((newToken: string) => {
    setAuthToken(newToken);
    setToken(newToken);
  }, []);

  const handleLogout = useCallback(() => {
    setAuthToken(null);
    setToken(null);
    queryClient.clear();
  }, []);

  const LogoutButton = () => (
    <Pressable onPress={handleLogout} hitSlop={8}>
      <Text style={styles.logout}>Abmelden</Text>
    </Pressable>
  );

  return (
    <SafeAreaProvider>
      <QueryClientProvider client={queryClient}>
        {token ? (
          <NavigationContainer>
            <Tabs.Navigator
              screenOptions={{
                ...headerStyle,
                tabBarActiveTintColor: colors.primary,
                headerRight: () => <LogoutButton />,
              }}
            >
              <Tabs.Screen
                name="Übersicht"
                component={OverviewScreen}
                options={{ tabBarLabel: 'Übersicht' }}
              />
              <Tabs.Screen
                name="Übergaben"
                component={HandoverStackScreen}
                options={{ headerShown: false }}
              />
              <Tabs.Screen name="Kaffeekasse" component={CoffeeScreen} />
            </Tabs.Navigator>
          </NavigationContainer>
        ) : (
          <LoginScreen onLoggedIn={handleLoggedIn} />
        )}
        <StatusBar style="light" />
      </QueryClientProvider>
    </SafeAreaProvider>
  );
}

const styles = StyleSheet.create({
  logout: {
    color: '#fff',
    fontWeight: '700',
    fontSize: 14,
    marginRight: 12,
  },
});
