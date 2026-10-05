// k6 run -e BASE=https://dev.mediconnect.example.com -e TOKEN=<jwt> load-test/booking.js
import http from "k6/http";
import { check, sleep } from "k6";

export const options = {
  stages: [
    { duration: "2m", target: 50 },
    { duration: "5m", target: 200 },   // watch HPA scale pods
    { duration: "2m", target: 0 },
  ],
  thresholds: { http_req_failed: ["rate<0.01"], http_req_duration: ["p(95)<500"] },
};

const headers = { Authorization: `Bearer ${__ENV.TOKEN}`, "Content-Type": "application/json" };

export default function () {
  const day = "2030-01-01";
  const r = http.get(`${__ENV.BASE}/appointments/slots?doctor_id=dr-lee&day=${day}`, { headers });
  check(r, { "slots 200": (x) => x.status === 200 });
  sleep(1);
}
