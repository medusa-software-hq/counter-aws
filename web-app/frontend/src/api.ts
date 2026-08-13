import createClient from 'openapi-fetch';
import type { paths } from './gen/api';

const API_URL = import.meta.env.VITE_API_URL as string;

if (!API_URL) {
  throw new Error('VITE_API_URL is not set');
}

// VITE_API_URL is a same-origin path ("/api"); openapi-fetch needs an absolute base.
export const api = createClient<paths>({
  baseUrl: new URL(API_URL, window.location.origin).toString(),
});
