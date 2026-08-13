import { Box, Button, Group, SimpleGrid, Stack, Text, Title } from '@mantine/core';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { api } from './api.ts';
import heroImg from './assets/hero.png';
import reactLogo from './assets/react.svg';
import viteLogo from './assets/vite.svg';
import { SignInWall } from './SignInWall.tsx';
import { useAuth } from './useAuth.tsx';
import classes from './App.module.css';

const socialLinks = [
  { label: 'GitHub', href: 'https://github.com/vitejs/vite', icon: 'github-icon' },
  { label: 'Discord', href: 'https://chat.vite.dev/', icon: 'discord-icon' },
  { label: 'X.com', href: 'https://x.com/vite_js', icon: 'x-icon' },
  { label: 'Bluesky', href: 'https://bsky.app/profile/vite.dev', icon: 'bluesky-icon' },
];

function AppContent({ token }: { token: string }) {
  const { handleUnauthorized } = useAuth();
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
    <>
      <Box className={classes.center}>
        <div className={classes.hero}>
          <img src={heroImg} className={classes.base} width="170" height="179" alt="" />
          <img src={reactLogo} className={classes.framework} alt="React logo" />
          <img src={viteLogo} className={classes.vite} alt="Vite logo" />
        </div>
        <Stack align="center" gap="md">
          <Title order={1} className={classes.count}>
            {count ?? '…'}
          </Title>
          <Group justify="center" gap="xs">
            <Button
              variant="light"
              size="md"
              aria-label="Decrement"
              onClick={() => void decrement()}
            >
              −
            </Button>
            <Button
              variant="light"
              size="md"
              aria-label="Increment"
              onClick={() => void increment()}
            >
              +
            </Button>
          </Group>
          {error !== null && (
            <Text c="red" size="sm">
              Failed to reach the API: {error}
            </Text>
          )}
        </Stack>
      </Box>

      <SimpleGrid cols={{ base: 1, sm: 2 }} spacing={0} className={classes.nextSteps}>
        <Box className={classes.section}>
          <svg className={classes.sectionIcon} role="presentation" aria-hidden="true">
            <use href="/icons.svg#documentation-icon" />
          </svg>
          <Title order={2} mb={4}>
            Documentation
          </Title>
          <Text c="dimmed">Your questions, answered</Text>
          <Group gap="xs" mt="md">
            <Button
              component="a"
              href="https://vite.dev/"
              target="_blank"
              rel="noreferrer"
              variant="default"
              leftSection={<img className={classes.linkIcon} src={viteLogo} alt="" />}
            >
              Explore Vite
            </Button>
            <Button
              component="a"
              href="https://react.dev/"
              target="_blank"
              rel="noreferrer"
              variant="default"
              leftSection={<img className={classes.linkIcon} src={reactLogo} alt="" />}
            >
              Learn more
            </Button>
          </Group>
        </Box>

        <Box className={classes.section}>
          <svg className={classes.sectionIcon} role="presentation" aria-hidden="true">
            <use href="/icons.svg#social-icon" />
          </svg>
          <Title order={2} mb={4}>
            Connect with us
          </Title>
          <Text c="dimmed">Join the Vite community</Text>
          <Group gap="xs" mt="md">
            {socialLinks.map(({ label, href, icon }) => (
              <Button
                key={label}
                component="a"
                href={href}
                target="_blank"
                rel="noreferrer"
                variant="default"
                leftSection={
                  <svg className={classes.linkIcon} role="presentation" aria-hidden="true">
                    <use href={`/icons.svg#${icon}`} />
                  </svg>
                }
              >
                {label}
              </Button>
            ))}
          </Group>
        </Box>
      </SimpleGrid>
    </>
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
  return <AppContent token={state.token} />;
}

export default App;
