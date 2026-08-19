import { Box, Button, Group, Stack, Text, Title } from '@mantine/core';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { api } from './api.ts';
import heroImg from './assets/hero.png';
import type { AuthUser } from './AuthContext.tsx';
import { SignInWall } from './SignInWall.tsx';
import { useAuth } from './useAuth.tsx';
import classes from './App.module.css';

function AppContent({ token, user }: { token: string; user: AuthUser }) {
  const { handleUnauthorized, signOut } = useAuth();
  const [count, setCount] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);

  const headers = useMemo(() => ({ Authorization: `Bearer ${token}` }), [token]);

  // openapi-fetch returns HTTP errors (rather than throwing); only transport failures throw.
  const apply = useCallback(
    (value: number | undefined, isError: boolean, status: number) => {
      if (status === 401) {
        handleUnauthorized();
      } else if (isError || value === undefined) {
        setError(`Failed to reach the API (${status})`);
      } else {
        setCount(value);
        setError(null);
      }
    },
    [handleUnauthorized]
  );

  const handleThrown = useCallback((err: unknown) => {
    setError(err instanceof Error ? err.message : String(err));
  }, []);

  useEffect(() => {
    let cancelled = false;

    async function load() {
      try {
        const { data, error, response } = await api.GET('/counter/get', { headers });
        if (!cancelled) {
          apply(data?.count, error !== undefined, response.status);
        }
      } catch (err: unknown) {
        if (!cancelled) {
          handleThrown(err);
        }
      }
    }

    void load();
    return () => {
      cancelled = true;
    };
  }, [headers, apply, handleThrown]);

  async function increment() {
    try {
      const { data, error, response } = await api.POST('/counter/increment', { headers });
      apply(data?.count, error !== undefined, response.status);
    } catch (err: unknown) {
      handleThrown(err);
    }
  }

  async function decrement() {
    try {
      const { data, error, response } = await api.POST('/counter/decrement', { headers });
      apply(data?.count, error !== undefined, response.status);
    } catch (err: unknown) {
      handleThrown(err);
    }
  }

  return (
    <Box className={classes.center}>
      <div className={classes.hero}>
        <img src={heroImg} className={classes.base} width="170" height="179" alt="" />
      </div>
      <Stack align="center" gap="md">
        <Title order={1} className={classes.count}>
          {count ?? '…'}
        </Title>
        <Group justify="center" gap="xs">
          <Button variant="light" size="md" aria-label="Decrement" onClick={() => void decrement()}>
            −
          </Button>
          <Button variant="light" size="md" aria-label="Increment" onClick={() => void increment()}>
            +
          </Button>
        </Group>
        {error !== null && (
          <Text c="red" size="sm">
            Failed to reach the API: {error}
          </Text>
        )}
        <Group gap="xs" mt="xl">
          <Text c="dimmed" size="sm">
            {user.email}
          </Text>
          <Button variant="subtle" size="compact-sm" onClick={signOut}>
            Sign out
          </Button>
        </Group>
      </Stack>
    </Box>
  );
}

function App() {
  const { state } = useAuth();

  if (state.status === 'loading') {
    return null;
  }
  if (state.status === 'unauthenticated') {
    return <SignInWall />;
  }
  return <AppContent token={state.token} user={state.user} />;
}

export default App;
