/** Shared demo profiles for the Wachbuch web app. */
window.WACHBUCH_DEMO = {
  rettungsdienst: {
    id: "rettungsdienst",
    label: "Rettungsdienst",
    station: "Rettungswache Musterstadt",
    role: "Schichtleitung",
    username: "demo-schicht",
    tagline: "Schichtübergabe, Material und Wachalltag für den Rettungsdienst.",
    accent: "#2563eb",
    handovers: [
      {
        id: 1,
        title: "RTW 1 – Defibrillator-Akku tauschen",
        description:
          "Akku zeigt unter 40 %. Ersatzakku aus dem Materiallager entnehmen und Gerät neu kalibrieren.",
        status: "open",
        priority: "urgent",
        category: "Material",
        author: "demo-schicht",
        updated: "vor 25 Min.",
      },
      {
        id: 2,
        title: "Funkgerät Wachzimmer knackt",
        description:
          "Kanal 4 mit Störgeräusch. IT informiert; bis dahin Ersatzgerät aus Spind B nutzen.",
        status: "in_progress",
        priority: "important",
        category: "Wache",
        author: "demo-mitglied",
        updated: "vor 2 Std.",
      },
      {
        id: 3,
        title: "Kühlschrank Medikamente – Temperaturlog fehlt",
        description: "Bitte heutige Temperaturwerte nachtragen und Kühlkette dokumentieren.",
        status: "open",
        priority: "normal",
        category: "Aufgabe",
        author: "demo-admin",
        updated: "vor 5 Std.",
      },
      {
        id: 4,
        title: "Kaffeekasse – Nachzahlung Schicht A",
        description: "Schicht A hat Nachzahlung erledigt. Beleg liegt in der Kasse.",
        status: "done",
        priority: "normal",
        category: "Wache",
        author: "demo-kasse",
        updated: "gestern",
      },
    ],
    calendar: [
      {
        title: "Geräteprüfung RTW",
        when: "Heute · 12:00–13:00",
        location: "Fahrzeughalle",
      },
      {
        title: "Teambesprechung Hygiene",
        when: "Morgen · 09:00–10:00",
        location: "Wachzimmer",
      },
    ],
    coffee: {
      balance: "42,50 €",
      hint: "Bitte bar in die Kasse oder per Überweisung an die Wache.",
      ledger: [
        { amount: "-12,00 €", note: "Milch & Filterkaffee", who: "demo-kasse" },
        { amount: "+20,00 €", note: "Nachzahlung Schicht A", who: "demo-mitglied" },
      ],
    },
    checklists: [
      {
        title: "Fahrzeugcheck RTW 1",
        items: [
          { text: "Sauerstoffflasche voll", checked: true },
          { text: "Trage gereinigt", checked: true },
          { text: "Medikamentenschrank inventiert", checked: false },
        ],
      },
      {
        title: "Wachabschluss",
        items: [
          { text: "Müll entsorgt", checked: false },
          { text: "Schlüsselübergabe", checked: false },
        ],
      },
    ],
  },
  feuerwehr: {
    id: "feuerwehr",
    label: "Feuerwehr",
    station: "Feuerwehrwache Nord",
    role: "Wachabteilungsführer",
    username: "demo-waf",
    tagline: "Gerätehaus, Fahrzeuge und Dienstübergabe für die Feuerwehr.",
    accent: "#dc2626",
    handovers: [
      {
        id: 11,
        title: "HLF 20 – Atemschutzgerät 3 außer Betrieb",
        description:
          "Druckminderer undicht. Gerät gekennzeichnet und Werkstatt informiert. Ersatz aus Reservehalle.",
        status: "open",
        priority: "urgent",
        category: "Fahrzeug",
        author: "demo-waf",
        updated: "vor 40 Min.",
      },
      {
        id: 12,
        title: "Hydrantentest Straße 12 verschoben",
        description: "Wegen Baustelle auf Donnerstag verlegt. Neue Liste liegt am Melder.",
        status: "in_progress",
        priority: "important",
        category: "Aufgabe",
        author: "demo-mitglied",
        updated: "vor 3 Std.",
      },
      {
        id: 13,
        title: "Schlauchturm – Beleuchtung defekt",
        description: "Obere Leuchte flackert. Elektrofirma angefragt.",
        status: "open",
        priority: "normal",
        category: "Sicherheit",
        author: "demo-admin",
        updated: "vor 8 Std.",
      },
      {
        id: 14,
        title: "Übung Löschangriff abgeschlossen",
        description: "Protokoll unterschrieben, Material wieder einsatzklar.",
        status: "done",
        priority: "normal",
        category: "Wache",
        author: "demo-waf",
        updated: "gestern",
      },
    ],
    calendar: [
      {
        title: "Atemschutz-Übung",
        when: "Heute · 14:00–16:00",
        location: "Übungsanlage",
      },
      {
        title: "Fahrzeugpflege DLK",
        when: "Übermorgen · Vormittag",
        location: "Fahrzeughalle",
      },
    ],
    coffee: {
      balance: "18,75 €",
      hint: "Kaffeekasse Gerätehaus – Einwurf neben dem Melder.",
      ledger: [{ amount: "-8,50 €", note: "Kaffee & Zucker", who: "demo-kasse" }],
    },
    checklists: [
      {
        title: "Fahrzeugcheck HLF 20",
        items: [
          { text: "Pumpe Funktionstest", checked: true },
          { text: "Atemschutz vollzählig", checked: false },
          { text: "Funkprobe", checked: true },
        ],
      },
      {
        title: "Wochencheck Gerätehaus",
        items: [
          { text: "Notstromaggregat geprüft", checked: false },
          { text: "Schlauchlager Ordnung", checked: false },
        ],
      },
    ],
  },
  polizei: {
    id: "polizei",
    label: "Polizei",
    station: "Polizeiwache Innenstadt",
    role: "Dienstgruppenleitung",
    username: "demo-dgl",
    tagline: "Dienstübergabe, Material und Organisation für die Polizei.",
    accent: "#7dd3fc",
    handovers: [
      {
        id: 21,
        title: "Streifenwagen 3 – Reifenprofil vorne links",
        description:
          "Profil unter Grenzmaß. Werkstatttermin heute 14:00. Bis dahin Fahrzeug nur Notbetrieb.",
        status: "open",
        priority: "urgent",
        category: "Fahrzeug",
        author: "demo-dgl",
        updated: "vor 15 Min.",
      },
      {
        id: 22,
        title: "Bodycam-Akkus nachladen",
        description: "Dock 2 und 4 leer. Bitte alle Cams nach Schichtende einstellen.",
        status: "in_progress",
        priority: "important",
        category: "Material",
        author: "demo-mitglied",
        updated: "vor 1 Std.",
      },
      {
        id: 23,
        title: "Schlüsselbrett Zellentür – Ersatzschlüssel fehlt",
        description: "Haken 7 leer. Schlüsselverwaltung informiert.",
        status: "open",
        priority: "normal",
        category: "Sicherheit",
        author: "demo-admin",
        updated: "vor 6 Std.",
      },
      {
        id: 24,
        title: "Dienstübergabe Nachtschicht erledigt",
        description: "Offene Hinweise an Tagesdienst weitergegeben.",
        status: "done",
        priority: "normal",
        category: "Wache",
        author: "demo-dgl",
        updated: "vor 10 Std.",
      },
    ],
    calendar: [
      {
        title: "Lagebesprechung",
        when: "Heute · in 2 Std.",
        location: "Besprechungsraum",
      },
      {
        title: "Fahrzeugübergabe Fuhrpark",
        when: "Morgen · 08:00–09:00",
        location: "Hof",
      },
    ],
    coffee: {
      balance: "31,00 €",
      hint: "Kaffeekasse Wache – Liste am Kühlschrank.",
      ledger: [
        { amount: "+15,00 €", note: "Einsammlung Dienstgruppe", who: "demo-kasse" },
        { amount: "-9,20 €", note: "Kapseln & Milch", who: "demo-mitglied" },
      ],
    },
    checklists: [
      {
        title: "Fahrzeugcheck FuStW 3",
        items: [
          { text: "Blaulicht / Folgetonhorn", checked: true },
          { text: "Bodycams geladen", checked: false },
          { text: "Erste-Hilfe-Set vollständig", checked: true },
        ],
      },
      {
        title: "Wachrundgang",
        items: [
          { text: "Eingänge gesichert", checked: false },
          { text: "Funkraum aufgeräumt", checked: false },
        ],
      },
    ],
  },
};
