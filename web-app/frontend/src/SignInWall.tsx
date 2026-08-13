import { Button, Center, Stack, Text, Title } from '@mantine/core';
import { useAuth } from './useAuth.tsx';

// Shown when no valid session exists; the button starts the Cognito authorization-code (PKCE) flow.
export function SignInWall() {
  const { signIn } = useAuth();

  return (
    <Center mih="100svh">
      <Stack align="center" gap="md">
        <Title order={1}>Sign in</Title>
        <Text c="dimmed">Sign in with your organization account to use the counter.</Text>
        <Button size="md" onClick={signIn}>
          Sign in
        </Button>
      </Stack>
    </Center>
  );
}
