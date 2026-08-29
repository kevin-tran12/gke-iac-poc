import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = { vus: 2, duration: '30s' };

export default function () {
  const response = http.get(`${__ENV.BASE_URL}/healthz`);
  check(response, { healthy: (r) => r.status === 200 });
  sleep(1);
}
