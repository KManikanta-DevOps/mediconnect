jsx
import { useState } from "react";
import {
  CognitoUser,
  CognitoUserPool,
  AuthenticationDetails,
} from "amazon-cognito-identity-js";

const pool = new CognitoUserPool({
  UserPoolId: import.meta.env.VITE_COGNITO_USER_POOL_ID,
  ClientId: import.meta.env.VITE_COGNITO_CLIENT_ID,
});

const api = (token) => async (path, opts = {}) => {
  const res = await fetch(path, {
    ...opts,
    headers: {
      "Content-Type": "application/json",
      ...(token && { Authorization: `Bearer ${token}` }),
      ...opts.headers,
    },
  });

  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(body.detail || body.message || res.statusText);
  }

  return res.json();
};

export default function App() {
  const [token, setToken] = useState(null);
  const [role, setRole] = useState("patient");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [appts, setAppts] = useState([]);
  const [doctor, setDoctor] = useState("dr-lee");
  const [when, setWhen] = useState("");
  const [msg, setMsg] = useState("");
  const [busy, setBusy] = useState(false);

  const call = api(token);

  const login = (e) => {
    e.preventDefault();
    setMsg("");
    setBusy(true);

    const user = new CognitoUser({
      Username: email.trim(),
      Pool: pool,
    });

    const authDetails = new AuthenticationDetails({
      Username: email.trim(),
      Password: password,
    });

    user.authenticateUser(authDetails, {
      onSuccess: (session) => {
        setToken(session.getIdToken().getJwtToken());
        setBusy(false);
        setMsg("Signed in successfully.");
      },
      onFailure: (err) => {
        setMsg(err.message || "Sign-in failed.");
        setBusy(false);
      },
      newPasswordRequired: () => {
        setMsg(
          "Your account requires a new password. Complete the password-change step before signing in."
        );
        setBusy(false);
      },
    });
  };

  const logout = () => {
    const user = pool.getCurrentUser();
    if (user) user.signOut();
    setToken(null);
    setPassword("");
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
        body: JSON.stringify({
          doctor_id: doctor,
          starts_at: when,
        }),
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

      const { url } = await call("/records/upload-url", {
        method: "POST",
        body: JSON.stringify({ title: file.name }),
      });

      const result = await fetch(url, {
        method: "PUT",
        body: file,
        headers: { "Content-Type": "application/pdf" },
      });

      if (!result.ok) throw new Error("Report upload failed.");

      setMsg(`Uploaded ${file.name}.`);
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
        <p>Sign in with your MediConnect account.</p>

        <form onSubmit={login} className="stack">
          <label>
            Email
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              autoComplete="username"
              required
            />
          </label>

          <label>
            Password
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              autoComplete="current-password"
              required
            />
          </label>

          <button disabled={busy}>
            {busy ? "Signing in..." : "Sign in"}
          </button>
        </form>

        <p role="status">{msg}</p>
      </main>
    );
  }

  return (
    <main className="shell">
      <h1>Your MediConnect</h1>
      <button className="ghost" onClick={logout}>
        Sign out
      </button>

      <button className="ghost" onClick={load}>
        Refresh appointments
      </button>

      <ul className="list">
        {appts.length === 0 && (
          <li className="empty">No appointments loaded yet.</li>
        )}
        {appts.map((a) => (
          <li key={a.id}>
            <b>{new Date(a.starts_at).toLocaleString()}</b>
            {" "}with {a.doctor_id} ({a.status})
          </li>
        ))}
      </ul>

      <h2>Book an appointment</h2>
      <form onSubmit={book} className="stack">
        <label>
          Doctor
          <input
            value={doctor}
            onChange={(e) => setDoctor(e.target.value)}
            required
          />
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

      <h2>Upload a report</h2>
      <input
        type="file"
        accept="application/pdf"
        onChange={upload}
      />

      <p role="status">{msg}</p>
    </main>
  );
}