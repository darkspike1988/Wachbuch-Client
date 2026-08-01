const statusEl = document.getElementById("status");
const identityEl = document.getElementById("identity");
const stationLine = document.getElementById("station-line");
const countsEl = document.getElementById("counts");
const handoversEl = document.getElementById("handovers");
const eventsEl = document.getElementById("events");
const apiBaseInput = document.getElementById("api-base");
const reloadButton = document.getElementById("reload");

const STORAGE_KEY = "wachbuch.apiBase";

function apiBase() {
  const value = (apiBaseInput.value || window.location.origin).trim().replace(/\/$/, "");
  return value;
}

async function fetchJson(path) {
  const response = await fetch(`${apiBase()}${path}`, {
    credentials: "include",
    headers: { Accept: "application/json" },
  });
  if (response.status === 401 || response.status === 302) {
    throw new Error("Nicht angemeldet. Bitte zuerst im Server-UI anmelden.");
  }
  if (!response.ok) {
    throw new Error(`API-Fehler ${response.status} für ${path}`);
  }
  return response.json();
}

function renderList(target, items, mapper, emptyText) {
  target.innerHTML = "";
  if (!items.length) {
    const empty = document.createElement("p");
    empty.className = "empty-state";
    empty.textContent = emptyText;
    target.appendChild(empty);
    return;
  }
  for (const item of items) {
    target.appendChild(mapper(item));
  }
}

function handoverRow(item) {
  const row = document.createElement("article");
  row.className = "list-row";
  row.innerHTML = `
    <strong>${escapeHtml(item.title)}</strong>
    <small>${escapeHtml(item.priority_label)} · ${escapeHtml(item.status_label)} · ${escapeHtml(item.category_label)}</small>
  `;
  return row;
}

function eventRow(item) {
  const row = document.createElement("article");
  row.className = "list-row";
  const when = new Date(item.starts_at);
  row.innerHTML = `
    <strong>${escapeHtml(item.title)}</strong>
    <small>${when.toLocaleString("de-DE", { dateStyle: "short", timeStyle: "short" })}</small>
  `;
  return row;
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

async function refresh() {
  statusEl.textContent = "Lade Daten …";
  statusEl.classList.remove("status-error");
  localStorage.setItem(STORAGE_KEY, apiBase());
  try {
    const [me, dashboard] = await Promise.all([
      fetchJson("/api/v1/me/"),
      fetchJson("/api/v1/dashboard/"),
    ]);
    identityEl.textContent = `${me.user.display_name} · ${me.role_label}`;
    stationLine.textContent = me.station.name;
    countsEl.textContent = `${dashboard.urgent_count} dringend · ${dashboard.open_count} aktiv`;
    renderList(handoversEl, dashboard.handovers, handoverRow, "Keine aktiven Übergaben.");
    renderList(eventsEl, dashboard.events, eventRow, "Keine anstehenden Termine.");
    statusEl.textContent = "Verbindung aktiv.";
  } catch (error) {
    identityEl.textContent = "Nicht angemeldet";
    stationLine.textContent = "Serververbindung";
    countsEl.textContent = "";
    handoversEl.innerHTML = "";
    eventsEl.innerHTML = "";
    statusEl.textContent = error.message;
    statusEl.classList.add("status-error");
  }
}

apiBaseInput.value = localStorage.getItem(STORAGE_KEY) || window.location.origin;
reloadButton.addEventListener("click", refresh);

if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("./sw.js").catch(() => {
    /* Offline-Hülle ist optional. */
  });
}

refresh();
