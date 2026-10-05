import { useState } from "react";

const api = (token) => async (path, opts = {}) => {
  const res = await fetch(path, {
    ...opts,
    headers: { "Content-Type": "application/json", ...(token && { Authorization: `Bearer ${token}` }) },
  });
  if (!res.ok) throw new Error((await res.json().catch(() => ({}))).detail || res.statusText);
  return res.json();
};

export default function App() {
  const [token, setToken] = useState(null);
  const [role, setRole] = useState("patient");
  const [email, setEmail] = useState("");
  const [appts, setAppts] = useState([]);
  const [doctor, setDoctor] = useState("dr-lee");
  const [when, setWhen] = useState("");
  const [msg, setMsg] = useState("");
  const call = api(token);

  const login = async (e) => {
    e.preventDefault();
    const r = await api()("/auth/dev-login", { method: "POST", body: JSON.stringify({ email, role }) });
    setToken(r.access_token);
  };
  const load = async () => setAppts(await call("/appointments"));
  const book = async (e) => {
    e.preventDefault();
    try {
      await call("/appointments", { method: "POST", body: JSON.stringify({ doctor_id: doctor, starts_at: when }) });
      setMsg("Appointment booked."); load();
    } catch (err) { setMsg(err.message); }
  };
  const upload = async (e) => {
    const file = e.target.files[0];
    if (!file) return;
    const { url } = await call("/records/upload-url", { method: "POST", body: JSON.stringify({ title: file.name }) });
    await fetch(url, { method: "PUT", body: file, headers: { "Content-Type": "application/pdf" } });
    setMsg(`Uploaded ${file.name}.`);
  };

  if (!token)
    return (
      <main className="shell">
        <h1>MediConnect</h1>
        <form onSubmit={login} className="stack">
          <label>Email<input value={email} onChange={(e) => setEmail(e.target.value)} required /></label>
          <label>I am a
            <select value={role} onChange={(e) => setRole(e.target.value)}>
              <option value="patient">patient</option><option value="doctor">doctor</option>
            </select>
          </label>
          <button>Sign in</button>
        </form>
      </main>
    );

  return (
    <main className="shell">
      <h1>{role === "doctor" ? "Your schedule" : "Your appointments"}</h1>
      <button className="ghost" onClick={load}>Refresh</button>
      <ul className="list">
        {appts.length === 0 && <li className="empty">No appointments yet.</li>}
        {appts.map((a) => <li key={a.id}><b>{new Date(a.starts_at).toLocaleString()}</b> with {a.doctor_id} ({a.status})</li>)}
      </ul>
      {role === "patient" && (
        <>
          <h2>Book an appointment</h2>
          <form onSubmit={book} className="stack">
            <label>Doctor<input value={doctor} onChange={(e) => setDoctor(e.target.value)} /></label>
            <label>Date and time<input type="datetime-local" value={when} onChange={(e) => setWhen(e.target.value)} required /></label>
            <button>Book appointment</button>
          </form>
          <h2>Upload a report</h2>
          <input type="file" accept="application/pdf" onChange={upload} />
        </>
      )}
      <p role="status">{msg}</p>
    </main>
  );
}
