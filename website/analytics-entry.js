import { inject } from '@vercel/analytics';

if (location.hostname !== 'localhost' && location.hostname !== '127.0.0.1' && location.protocol === 'https:') {
  inject({ mode: 'production' });
}
