import http from 'k6/http';
import { sleep } from 'k6';

export const options = {
  vus: 5,
  duration: '3m',
  thresholds: { http_req_failed: ['rate<0.05'] },
};

export default function () {
  http.get(__ENV.HPA_URL);
  sleep(0.1);
}
