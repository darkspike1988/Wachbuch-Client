(() => {
  const PROFILES = window.WACHBUCH_DEMO;
  const STORAGE_KEY = "wachbuch-demo-service";

  const PRIORITY_LABEL = {
    urgent: "Dringend",
    important: "Wichtig",
    normal: "Normal",
    done: "Erledigt",
  };

  const STATUS_LABEL = {
    open: "Offen",
    in_progress: "In Bearbeitung",
    done: "Erledigt",
  };

  const state = {
    service: null,
    view: "overview",
    query: "",
    statusFilter: null,
    priorityFilter: null,
    detailId: null,
  };

  const els = {
    setup: document.getElementById("setup"),
    shell: document.getElementById("shell"),
    serviceList: document.getElementById("service-list"),
    main: document.getElementById("main"),
    rail: document.getElementById("rail-nav"),
    bottom: document.getElementById("bottom-nav"),
    topStation: document.getElementById("top-station"),
    demoLabel: document.getElementById("demo-label"),
    dialog: document.getElementById("dialog-root"),
    switchBtn: document.getElementById("btn-switch"),
  };

  function profile() {
    return PROFILES[state.service];
  }

  function metrics(handovers) {
    return {
      open: handovers.filter((h) => h.status === "open").length,
      progress: handovers.filter((h) => h.status === "in_progress").length,
      urgent: handovers.filter((h) => h.priority === "urgent").length,
    };
  }

  function filteredHandovers() {
    const p = profile();
    const q = state.query.trim().toLowerCase();
    return p.handovers.filter((item) => {
      if (state.statusFilter && item.status !== state.statusFilter) return false;
      if (state.priorityFilter && item.priority !== state.priorityFilter) {
        return false;
      }
      if (!q) return true;
      return (
        item.title.toLowerCase().includes(q) ||
        item.description.toLowerCase().includes(q) ||
        item.category.toLowerCase().includes(q)
      );
    });
  }

  function icon(name) {
    const labels = {
      home: "⌂",
      list: "☰",
      user: "◎",
      cal: "▦",
      coffee: "♨",
      check: "☑",
    };
    return `<span class="icon" aria-hidden="true">${labels[name] || "•"}</span>`;
  }

  function chipsFor(item) {
    return `
      <span class="chip chip-${item.priority}">${PRIORITY_LABEL[item.priority]}</span>
      <span class="chip chip-${item.status === "done" ? "done-status" : item.status}">${STATUS_LABEL[item.status]}</span>
    `;
  }

  function renderNav() {
    const items = [
      { id: "overview", label: "Übersicht", glyph: "home" },
      { id: "handovers", label: "Übergaben", glyph: "list" },
      { id: "account", label: "Konto", glyph: "user" },
    ];
    const html = items
      .map(
        (item) => `
      <button type="button" class="nav-btn" data-view="${item.id}" aria-current="${
          state.view === item.id ||
          (["calendar", "coffee", "checklists"].includes(state.view) &&
            item.id === "overview")
            ? "page"
            : "false"
        }">
        ${icon(item.glyph)}
        <span>${item.label}</span>
      </button>`,
      )
      .join("");
    els.rail.innerHTML = html;
    els.bottom.innerHTML = html;
  }

  function renderOverview() {
    const p = profile();
    const m = metrics(p.handovers);
    els.main.innerHTML = `
      <section class="station-hero" aria-labelledby="station-name">
        <h1 id="station-name">${p.station}</h1>
        <p>${p.role} · ${p.tagline}</p>
      </section>
      <h2 class="section-label">Aktive Übergaben</h2>
      <div class="metrics" aria-label="Kennzahlen">
        <div class="metric"><strong>${m.open}</strong><span>offen</span></div>
        <div class="metric"><strong>${m.progress}</strong><span>in Bearbeitung</span></div>
        <div class="metric ${m.urgent ? "is-urgent" : ""}"><strong>${m.urgent}</strong><span>dringend</span></div>
      </div>
      <h2 class="section-label">Schnellzugriff</h2>
      <div class="module-row">
        <button type="button" class="module-tile" data-view="calendar">
          ${icon("cal")}
          <strong>Kalender</strong>
          <span>Wachentermine und Dienste</span>
        </button>
        <button type="button" class="module-tile" data-view="coffee">
          ${icon("coffee")}
          <strong>Kaffeekasse</strong>
          <span>Kassenstand und Buchungen</span>
        </button>
        <button type="button" class="module-tile" data-view="checklists">
          ${icon("check")}
          <strong>Checklisten</strong>
          <span>Punkte abhaken und abschließen</span>
        </button>
      </div>
      <h2 class="section-label">Aktuelle Hinweise</h2>
      <div class="list">
        ${p.handovers
          .filter((h) => h.status !== "done")
          .slice(0, 3)
          .map(
            (item, index) => `
          <button type="button" class="handover" data-detail="${item.id}" style="animation-delay:${index * 50}ms">
            <div class="meta">${chipsFor(item)}</div>
            <h3>${item.title}</h3>
            <p class="sub">${item.category} · ${item.updated}</p>
          </button>`,
          )
          .join("")}
      </div>
    `;
  }

  function handoverListHtml(items) {
    if (!items.length) {
      return `<p class="empty">Keine Übergaben für diese Filter.</p>`;
    }
    return items
      .map(
        (item, index) => `
      <button type="button" class="handover" data-detail="${item.id}" style="animation-delay:${index * 40}ms">
        <div class="meta">${chipsFor(item)}</div>
        <h3>${item.title}</h3>
        <p class="sub">${item.category} · ${item.author} · ${item.updated}</p>
      </button>`,
      )
      .join("");
  }

  function refreshHandoverResults() {
    const items = filteredHandovers();
    const count = document.getElementById("handover-count");
    const list = document.getElementById("handover-list");
    if (count) {
      count.textContent = `${items.length} von ${profile().handovers.length} Übergaben`;
    }
    if (list) list.innerHTML = handoverListHtml(items);
    document.querySelectorAll("[data-status]").forEach((btn) => {
      btn.setAttribute(
        "aria-pressed",
        String(state.statusFilter === btn.dataset.status),
      );
    });
    document.querySelectorAll("[data-priority]").forEach((btn) => {
      btn.setAttribute(
        "aria-pressed",
        String(state.priorityFilter === btn.dataset.priority),
      );
    });
  }

  function renderHandovers() {
    const items = filteredHandovers();
    els.main.innerHTML = `
      <h1 class="section-label">Übergaben</h1>
      <div class="toolbar">
        <label class="sr-only" for="search">Übergaben durchsuchen</label>
        <input id="search" class="search" type="search" placeholder="Übergaben durchsuchen" value="${state.query.replace(/"/g, "&quot;")}" />
      </div>
      <div class="filters" aria-label="Status filtern">
        ${["open", "in_progress", "done"]
          .map(
            (s) => `
          <button type="button" class="chip-btn" data-status="${s}" aria-pressed="${
            state.statusFilter === s
          }">${STATUS_LABEL[s]}</button>`,
          )
          .join("")}
      </div>
      <div class="filters" style="margin:0.55rem 0 1rem" aria-label="Priorität filtern">
        ${["urgent", "important", "normal"]
          .map(
            (p) => `
          <button type="button" class="chip-btn" data-priority="${p}" aria-pressed="${
            state.priorityFilter === p
          }">${PRIORITY_LABEL[p]}</button>`,
          )
          .join("")}
      </div>
      <p class="sub" id="handover-count" style="margin:0 0 0.85rem;color:var(--text-muted)">${items.length} von ${profile().handovers.length} Übergaben</p>
      <div class="list" id="handover-list">
        ${handoverListHtml(items)}
      </div>
    `;
  }

  function renderCalendar() {
    const p = profile();
    els.main.innerHTML = `
      <h1 class="section-label">Kalender</h1>
      ${p.calendar
        .map(
          (entry) => `
        <article class="panel-block">
          <h3>${entry.title}</h3>
          <p>${entry.when}</p>
          <p>${entry.location}</p>
        </article>`,
        )
        .join("")}
      <button type="button" class="btn btn-ghost" data-view="overview">← Zur Übersicht</button>
    `;
  }

  function renderCoffee() {
    const coffee = profile().coffee;
    els.main.innerHTML = `
      <h1 class="section-label">Kaffeekasse</h1>
      <article class="panel-block">
        <p>Aktueller Kassenstand</p>
        <p class="balance">${coffee.balance}</p>
        <p>${coffee.hint}</p>
      </article>
      <h2 class="section-label">Letzte Buchungen</h2>
      ${coffee.ledger
        .map(
          (row) => `
        <article class="panel-block">
          <h3>${row.amount}</h3>
          <p>${row.note}</p>
          <p>${row.who}</p>
        </article>`,
        )
        .join("")}
      <button type="button" class="btn btn-ghost" data-view="overview">← Zur Übersicht</button>
    `;
  }

  function renderChecklists() {
    const lists = profile().checklists;
    els.main.innerHTML = `
      <h1 class="section-label">Checklisten</h1>
      ${lists
        .map(
          (list, listIndex) => `
        <article class="panel-block">
          <h3>${list.title}</h3>
          ${list.items
            .map(
              (item, itemIndex) => `
            <label class="check-item">
              <input type="checkbox" data-list="${listIndex}" data-item="${itemIndex}" ${
                item.checked ? "checked" : ""
              } />
              <span>${item.text}</span>
            </label>`,
            )
            .join("")}
        </article>`,
        )
        .join("")}
      <button type="button" class="btn btn-ghost" data-view="overview">← Zur Übersicht</button>
    `;
  }

  function renderAccount() {
    const p = profile();
    els.main.innerHTML = `
      <h1 class="section-label">Konto</h1>
      <dl class="panel-block">
        <div class="account-row"><dt>Angemeldet als</dt><dd>${p.username}</dd></div>
        <div class="account-row"><dt>Rolle</dt><dd>${p.role}</dd></div>
        <div class="account-row"><dt>Organisation</dt><dd>${p.label}</dd></div>
        <div class="account-row"><dt>Server</dt><dd>Demo (offline)</dd></div>
        <div class="account-row"><dt>Lizenz</dt><dd>AGPL-3.0</dd></div>
      </dl>
      <div class="toolbar">
        <button type="button" class="btn btn-cta" id="btn-exit-demo">Demo beenden</button>
        <button type="button" class="btn btn-ghost" data-view="overview">Zur Übersicht</button>
      </div>
    `;
    document.getElementById("btn-exit-demo")?.addEventListener("click", showSetup);
  }

  function renderDetail() {
    const item = profile().handovers.find((h) => h.id === state.detailId);
    if (!item) {
      els.dialog.classList.add("app-hidden");
      els.dialog.innerHTML = "";
      return;
    }
    els.dialog.classList.remove("app-hidden");
    els.dialog.innerHTML = `
      <div class="dialog" role="dialog" aria-modal="true" aria-labelledby="detail-title">
        <div class="meta">${chipsFor(item)}</div>
        <h2 id="detail-title">${item.title}</h2>
        <p>${item.description}</p>
        <p><strong>Kategorie:</strong> ${item.category}</p>
        <p><strong>Autor:</strong> ${item.author}</p>
        <p><strong>Aktualisiert:</strong> ${item.updated}</p>
        <div class="dialog-actions">
          <button type="button" class="btn btn-cta" id="close-detail">Schließen</button>
        </div>
      </div>
    `;
    document.getElementById("close-detail")?.addEventListener("click", () => {
      state.detailId = null;
      renderDetail();
    });
    els.dialog.onclick = (event) => {
      if (event.target === els.dialog) {
        state.detailId = null;
        renderDetail();
      }
    };
  }

  function renderView() {
    document.documentElement.style.setProperty(
      "--service-accent",
      profile().accent,
    );
    els.topStation.textContent = profile().station;
    els.demoLabel.textContent = `Demo-Modus · ${profile().label}`;
    renderNav();
    switch (state.view) {
      case "handovers":
        renderHandovers();
        break;
      case "calendar":
        renderCalendar();
        break;
      case "coffee":
        renderCoffee();
        break;
      case "checklists":
        renderChecklists();
        break;
      case "account":
        renderAccount();
        break;
      default:
        renderOverview();
    }
    renderDetail();
  }

  function enterService(serviceId) {
    if (!PROFILES[serviceId]) return;
    state.service = serviceId;
    state.view = "overview";
    state.query = "";
    state.statusFilter = null;
    state.priorityFilter = null;
    state.detailId = null;
    localStorage.setItem(STORAGE_KEY, serviceId);
    const url = new URL(window.location.href);
    url.searchParams.set("service", serviceId);
    history.replaceState({}, "", url);
    els.setup.classList.add("app-hidden");
    els.shell.classList.remove("app-hidden");
    renderView();
    els.main.focus({ preventScroll: true });
  }

  function showSetup() {
    state.service = null;
    localStorage.removeItem(STORAGE_KEY);
    const url = new URL(window.location.href);
    url.searchParams.delete("service");
    history.replaceState({}, "", url);
    els.shell.classList.add("app-hidden");
    els.setup.classList.remove("app-hidden");
    els.dialog.classList.add("app-hidden");
  }

  function renderSetup() {
    const order = ["rettungsdienst", "feuerwehr", "polizei"];
    els.serviceList.innerHTML = order
      .map((id) => {
        const p = PROFILES[id];
        return `
        <button type="button" class="service-option" data-service="${id}" style="--opt-accent:${p.accent}">
          <span class="mark" aria-hidden="true"></span>
          <span>
            <h2>${p.label}</h2>
            <p>${p.tagline}</p>
          </span>
          <span aria-hidden="true">›</span>
        </button>`;
      })
      .join("");
  }

  function onClick(event) {
    const serviceBtn = event.target.closest("[data-service]");
    if (serviceBtn) {
      enterService(serviceBtn.dataset.service);
      return;
    }

    const viewBtn = event.target.closest("[data-view]");
    if (viewBtn && state.service) {
      state.view = viewBtn.dataset.view;
      state.detailId = null;
      renderView();
      return;
    }

    const detailBtn = event.target.closest("[data-detail]");
    if (detailBtn) {
      state.detailId = Number(detailBtn.dataset.detail);
      renderDetail();
      return;
    }

    const statusBtn = event.target.closest("[data-status]");
    if (statusBtn) {
      const value = statusBtn.dataset.status;
      state.statusFilter = state.statusFilter === value ? null : value;
      refreshHandoverResults();
      return;
    }

    const priorityBtn = event.target.closest("[data-priority]");
    if (priorityBtn) {
      const value = priorityBtn.dataset.priority;
      state.priorityFilter = state.priorityFilter === value ? null : value;
      refreshHandoverResults();
    }
  }

  function onInput(event) {
    if (event.target.id !== "search") return;
    state.query = event.target.value;
    refreshHandoverResults();
  }

  function onChange(event) {
    const box = event.target.closest('input[type="checkbox"][data-list]');
    if (!box || !state.service) return;
    const listIndex = Number(box.dataset.list);
    const itemIndex = Number(box.dataset.item);
    const item = profile().checklists[listIndex]?.items[itemIndex];
    if (item) item.checked = box.checked;
  }

  els.switchBtn.addEventListener("click", showSetup);
  document.addEventListener("click", onClick);
  document.addEventListener("change", onChange);
  document.addEventListener("input", onInput);
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && state.detailId != null) {
      state.detailId = null;
      renderDetail();
    }
  });

  renderSetup();

  const params = new URLSearchParams(window.location.search);
  const fromQuery = params.get("service") || params.get("demo");
  const fromStorage = localStorage.getItem(STORAGE_KEY);
  const initial = fromQuery || fromStorage;
  if (initial && PROFILES[initial]) {
    enterService(initial);
  }
})();
