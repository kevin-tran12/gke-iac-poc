import http from 'k6/http';
import { check } from 'k6';

export const options = { vus: 5, iterations: 100 };

export default function () {
  const response = http.get(`${__ENV.BASE_URL}/healthz`);
  check(response, { allowed_or_limited: (r) => r.status === 200 || r.status === 429 });
}
