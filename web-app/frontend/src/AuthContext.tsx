import { createContext } from 'react';

export interface AuthUser {
  sub: string;
  email: string;
  name: string;
}

export type AuthState =
  | { status: 'loading' }
  | { status: 'unauthenticated' }
  | { status: 'authenticated'; token: string; user: AuthUser };

export interface AuthContextValue {
  state: AuthState;
  /** Call on 401 from API — clears token and re-shows sign-in wall. */
  handleUnauthorized: () => void;
  /** Imperatively trigger sign-in (used by SignInWall). */
  signIn: () => void;
  /** End the session, including Cognito's, and return to the sign-in wall. */
  signOut: () => void;
}

export const AuthContext = createContext<AuthContextValue | null>(null);
