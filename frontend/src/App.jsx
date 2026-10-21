import { useState } from "react";

const AUTH_API_URL = import.meta.env.VITE_AUTH_API_URL || "";
const APPOINTMENTS_API_URL = import.meta.env.VITE_APPOINTMENTS_API_URL || "";
const RECORDS_API_URL = import.meta.env.VITE_RECORDS_API_URL || "";

const api = (token) => async (path, opts = {}) => {
  const base = path.startsWith("/auth")
    ? AUTH_API_URL
    : path.startsWith("/appointments")
      ? APPOINTMENTS_API_URL
      : path.startsWith("/records")
        ? RECORDS_API_URL
        : "";
  const isForm = typeof FormData !== "undefined" && opts.body instanceof FormData;
  const headers = {
    ...(!isForm && opts.body ? { "Content-Type": "application/json" } : {}),
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
    ...opts.headers,
  };
  const res = await fetch(`${base}${path}`, { ...opts, headers });
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(body.detail || body.message || res.statusText);
  }
  return res.json();
};

export default function App() {
  const [token, setToken] = useState(null);
  const [email, setEmail] = useState("");
  const [appts, setAppts] = useState([]);
  const [doctor, setDoctor] = useState("dr-lee");
  const [when, setWhen] = useState("");
  const [msg, setMsg] = useState("");
  const [busy, setBusy] = useState(false);

  const call = api(token);

  const login = async (e) => {
    e.preventDefault();
    setMsg("");
    setBusy(true);
    try {
      const result = await api(null)("/auth/dev-login", {
        method: "POST",
        body: JSON.stringify({ email: email.trim(), role: "patient" }),
      });
      setToken(result.access_token);
      setMsg("Demo sign-in successful. Use a test email only.");
    } catch (err) {
      setMsg(err.message || "Sign-in failed.");
    } finally {
      setBusy(false);
    }
  };

  const logout = () => {
    setToken(null);
    setAppts([]);
    setMsg("Signed out.");
  };

  const load = async () => {
    try {
      setAppts(await call("/appointments"));
      setMsg("");
    } catch (err) {
      setMsg(err.message);
    }
  };

  const book = async (e) => {
    e.preventDefault();
    try {
      await call("/appointments", {
        method: "POST",
        body: JSON.stringify({ doctor_id: doctor, starts_at: when }),
      });
      setMsg("Appointment booked.");
      await load();
    } catch (err) {
      setMsg(err.message);
    }
  };

  const upload = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    try {
      if (file.type !== "application/pdf") {
        throw new Error("Please select a PDF file.");
      }
      const form = new FormData();
      form.append("file", file);
      const result = await call("/records/upload-url", {
        method: "POST",
        body: form,
      });
      setMsg(`Uploaded ${result.title} (report #${result.id}).`);
    } catch (err) {
      setMsg(err.message);
    } finally {
      e.target.value = "";
    }
  };

  if (!token) {
    return (
      <main className="shell">
        <h1>MediConnect</h1>
        <p>Public demo environment — do not enter real patient information.</p>
        <form onSubmit={login} className="stack">
          <label>
            Demo email
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              autoComplete="email"
              placeholder="demo@example.com"
              required
            />
          </label>
          <button disabled={busy}>
            {busy ? "Signing in..." : "Continue to demo"}
          </button>
        </form>
        <p role="status">{msg}</p>
      </main>
    );
  }

  return (
    <main className="shell">
      <h1>Your MediConnect Demo</h1>
      <p>Use fictional data only. Demo sessions expire after one hour.</p>
      <button className="ghost" onClick={logout}>Sign out</button>
      <button className="ghost" onClick={load}>Refresh appointments</button>

      <ul className="list">
        {appts.length === 0 && <li className="empty">No appointments loaded yet.</li>}
        {appts.map((a) => (
          <li key={a.id}>
            <b>{new Date(a.starts_at).toLocaleString()}</b>{" "}
            with {a.doctor_id} ({a.status})
          </li>
        ))}
      </ul>

      <h2>Book an appointment</h2>
      <form onSubmit={book} className="stack">
        <label>
          Doctor
          <input value={doctor} onChange={(e) => setDoctor(e.target.value)} required />
        </label>
        <label>
          Date and time
          <input
            type="datetime-local"
            value={when}
            onChange={(e) => setWhen(e.target.value)}
            required
          />
        </label>
        <button>Book appointment</button>
      </form>

      <h2>Upload a sample report</h2>
      <p>PDF only, maximum 5 MB. Files are stored in the Neon demo database.</p>
      <input type="file" accept="application/pdf" onChange={upload} />
      <p role="status">{msg}</p>
    </main>
  );
}
