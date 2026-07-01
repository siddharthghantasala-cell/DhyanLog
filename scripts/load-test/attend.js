// k6 load test for the mass-event attend path. Exercises the hot, contended
// route — abhyasis giving GPS attendance to one session — to validate the
// geo-bucket fan-out and (separately) the single meditation-stop flush before a
// real 40k–70k event.
//
// Run against STAGING, never prod:
//   k6 run -e BASE_URL=https://<ref>.supabase.co/functions/v1/api \
//          -e ANON_KEY=<anon> -e TOKEN=<a-test-member-jwt> \
//          -e LAT=13.0827 -e LNG=80.2707 attend.js
//
// NOTE: identity comes from the JWT, not the body. A realistic test needs many
// distinct member tokens (pre-provision N test members and pass a token pool);
// this skeleton uses one TOKEN to validate latency/throughput of the route.
import http from "k6/http";
import { check, sleep } from "k6";

export const options = {
  scenarios: {
    rush: {
      // Ramp to a crowd arriving over a few minutes, like a real session.
      executor: "ramping-vus",
      startVUs: 0,
      stages: [
        { duration: "1m", target: 200 },
        { duration: "3m", target: 1000 },
        { duration: "1m", target: 0 },
      ],
    },
  },
  thresholds: {
    http_req_failed: ["rate<0.01"],
    http_req_duration: ["p(95)<800"],
  },
};

const BASE_URL = __ENV.BASE_URL;
const ANON_KEY = __ENV.ANON_KEY;
const TOKEN = __ENV.TOKEN || ANON_KEY;
const LAT = parseFloat(__ENV.LAT || "13.0827");
const LNG = parseFloat(__ENV.LNG || "80.2707");

export default function () {
  const res = http.post(
    `${BASE_URL}/attend`,
    JSON.stringify({ latitude: LAT, longitude: LNG }),
    {
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${TOKEN}`,
        "apikey": ANON_KEY,
      },
    },
  );
  check(res, {
    "status 200": (r) => r.status === 200,
    "matched a session": (r) => (r.json("outcome") || "") !== "",
  });
  sleep(1);
}
