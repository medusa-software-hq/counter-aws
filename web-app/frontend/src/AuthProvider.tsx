import {
  UserManager,
  WebStorageStateStore,
  type User,
  type UserManagerSettings,
} from 'oidc-client-ts';
import { useCallback, useEffect, useState, type ReactNode } from 'react';
import { AuthContext, type AuthState, type AuthUser } from './AuthContext.tsx';

const AUTHORITY = import.meta.env.VITE_COGNITO_AUTHORITY as string | undefined;
const CLIENT_ID = import.meta.env.VITE_COGNITO_CLIENT_ID as string | undefined;

if (!AUTHORITY || !CLIENT_ID) {
  throw new Error('VITE_COGNITO_AUTHORITY and VITE_COGNITO_CLIENT_ID must be set');
}

// The redirect target must be one of the app client's registered callback URLs (the origin with a
// trailing slash). The API verifies the ID token (its audience is this app client), so the SPA
// presents `id_token` — not the access token — as the bearer.
const settings: UserManagerSettings = {
  authority: AUTHORITY,
  client_id: CLIENT_ID,
  redirect_uri: `${window.location.origin}/`,
  post_logout_redirect_uri: `${window.location.origin}/`,
  response_type: 'code',
  scope: 'openid email profile',
  userStore: new WebStorageStateStore({ store: window.localStorage }),
  automaticSilentRenew: false,
};

const userManager = new UserManager(settings);

function authenticatedState(user: User): AuthState {
  const claims = user.profile;
  const authUser: AuthUser = {
    sub: claims.sub,
    email: claims.email ?? '',
    name: claims.name ?? claims.email ?? '',
    picture: claims.picture ?? '',
  };
  return { status: 'authenticated', token: user.id_token ?? '', user: authUser };
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<AuthState>({ status: 'loading' });

  useEffect(() => {
    let cancelled = false;

    async function resolve() {
      const params = new URLSearchParams(window.location.search);
      try {
        let user: User | null;
        if (params.has('code') && params.has('state')) {
          user = await userManager.signinRedirectCallback();
          // Strip the OAuth params so a reload doesn't re-run the (single-use) code exchange.
          window.history.replaceState({}, document.title, `${window.location.origin}/`);
        } else {
          user = await userManager.getUser();
        }
        if (cancelled) {
          return;
        }
        setState(user && !user.expired ? authenticatedState(user) : { status: 'unauthenticated' });
      } catch {
        if (!cancelled) {
          setState({ status: 'unauthenticated' });
        }
      }
    }

    void resolve();
    return () => {
      cancelled = true;
    };
  }, []);

  const signIn = useCallback(() => {
    void userManager.signinRedirect();
  }, []);

  const handleUnauthorized = useCallback(() => {
    void userManager.removeUser();
    setState({ status: 'unauthenticated' });
  }, []);

  return <AuthContext value={{ state, handleUnauthorized, signIn }}>{children}</AuthContext>;
}
