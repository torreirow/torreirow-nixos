// Syncs ICS feeds into Google Calendars, one feed per calendar.
//
// Events are matched on their ICS UID: changed matches are updated in place,
// new ones are added, and future matches that disappeared from the feed are
// removed. Ownership is remembered with a private `feed` property, with the
// UID suffix as a fallback for feeds whose UIDs carry one. Duplicates with the
// same UID are reduced to one on every run, so a re-import cannot pile up.

const FEEDS = [
  {
    name: 'dindoa-j4',
    feedUrl: 'https://toorren.net/dindoa/dindoa-j4.ics',
    // 'primary', a calendar ID, or a calendar name (created when missing).
    calendar: 'primary',
    // Events from before the `feed` property existed are recognised by this.
    uidSuffix: '@dindoa.nl',
  },
  {
    name: 'pauwervoll-ma-2',
    feedUrl: 'https://api.nevobo.nl/export/team/CKL8X8J/meiden-a/2/programma.ics',
    // Vul hier het agenda-ID in (Instellingen -> [agenda] -> Agenda-ID).
    // Laat je een naam staan, dan maakt het script die agenda aan en logt het ID.
    calendar: 'Pauwervoll MA 2',
    uidSuffix: '',
  },
];

function sync() {
  for (const feed of FEEDS) {
    try {
      syncFeed_(feed);
    } catch (e) {
      console.error(feed.name + ': ' + e.message);
    }
  }
}

// Run once by hand to schedule sync() every hour.
function installTrigger() {
  for (const t of ScriptApp.getProjectTriggers()) {
    if (t.getHandlerFunction() === 'sync') ScriptApp.deleteTrigger(t);
  }
  ScriptApp.newTrigger('sync').timeBased().everyHours(1).create();
}

function syncFeed_(feed) {
  const calendarId = resolveCalendar_(feed.calendar);
  const events = fetchFeed_(feed);
  const existing = listOurs_(calendarId, feed);
  const seen = new Set();
  let added = 0, updated = 0, removed = 0;

  for (const ev of events) {
    seen.add(ev.iCalUID);
    const current = existing.get(ev.iCalUID);
    if (!current) {
      try {
        Calendar.Events.import(ev, calendarId);
        added++;
      } catch (e) {
        // Typically: you deleted this match by hand. Leave it deleted.
        console.warn(feed.name + ': import skipped for ' + ev.iCalUID + ': ' + e.message);
      }
    } else if (differs_(current, ev)) {
      Calendar.Events.patch({
        summary: ev.summary,
        location: ev.location,
        description: ev.description,
        start: ev.start,
        end: ev.end,
      }, calendarId, current.id);
      updated++;
    }
  }

  // Only remove future matches: past ones may drop out of the feed and
  // should stay in the calendar as history.
  const now = new Date();
  for (const [uid, current] of existing) {
    if (seen.has(uid)) continue;
    const start = new Date(current.start.dateTime || current.start.date);
    if (start < now) continue;
    Calendar.Events.remove(calendarId, current.id);
    removed++;
  }

  console.log(`${feed.name}: ${events.length} in feed, +${added} ~${updated} -${removed}`);
}

// A calendar ID, 'primary', or the name of a calendar to use or create.
function resolveCalendar_(nameOrId) {
  if (nameOrId === 'primary') return 'primary';
  let pageToken;
  do {
    const page = Calendar.CalendarList.list({ maxResults: 250, pageToken: pageToken });
    for (const c of page.items || []) {
      if (c.id === nameOrId || c.summary === nameOrId) return c.id;
    }
    pageToken = page.nextPageToken;
  } while (pageToken);
  const created = Calendar.Calendars.insert({ summary: nameOrId });
  console.log('Created calendar "' + nameOrId + '" (' + created.id + ')');
  return created.id;
}

function fetchFeed_(feed) {
  // A fresh parameter per request keeps a CDN from serving yesterday's copy;
  // the server ignores it (volleybal.nl's own `versie` is the same idea).
  const url = feed.feedUrl + (feed.feedUrl.includes('?') ? '&' : '?') + '_=' + Date.now();
  const res = UrlFetchApp.fetch(url, { muteHttpExceptions: true });
  if (res.getResponseCode() !== 200) {
    throw new Error('feed returned HTTP ' + res.getResponseCode());
  }
  const events = parseIcs_(res.getContentText('UTF-8'));
  // An empty feed is far more likely a broken upload than a cancelled
  // season; refuse instead of deleting every match.
  if (events.length === 0) throw new Error('feed contains no events; nothing changed');
  return events.map((ev) => {
    ev.extendedProperties = { private: { feed: feed.name } };
    return ev;
  });
}

// All events of this feed, keyed by ICS UID. Events with the same UID (a
// re-import next to an existing event) are reduced to one: the most recently
// updated copy wins.
function listOurs_(calendarId, feed) {
  const map = new Map();
  const now = Date.now();
  let pageToken;
  do {
    const page = Calendar.Events.list(calendarId, {
      timeMin: new Date(now - 120 * 864e5).toISOString(),
      timeMax: new Date(now + 500 * 864e5).toISOString(),
      maxResults: 2500,
      showDeleted: false,
      pageToken: pageToken,
    });
    for (const item of page.items || []) {
      if (!owns_(item, feed)) continue;
      const uid = item.iCalUID || item.id;
      const prev = map.get(uid);
      if (!prev) {
        map.set(uid, item);
        continue;
      }
      const keep = new Date(item.updated) >= new Date(prev.updated) ? item : prev;
      const drop = keep === item ? prev : item;
      Calendar.Events.remove(calendarId, drop.id);
      console.log(feed.name + ': removed duplicate ' + uid);
      map.set(uid, keep);
    }
    pageToken = page.nextPageToken;
  } while (pageToken);
  return map;
}

function owns_(item, feed) {
  const tag = item.extendedProperties && item.extendedProperties.private;
  if (tag && tag.feed === feed.name) return true;
  return !!feed.uidSuffix && (item.iCalUID || '').endsWith(feed.uidSuffix);
}

function differs_(cur, ev) {
  const t = (x) => x ? new Date(x.dateTime || x.date).getTime() : null;
  return (cur.summary || '') !== (ev.summary || '') ||
         (cur.location || '') !== (ev.location || '') ||
         (cur.description || '') !== (ev.description || '') ||
         t(cur.start) !== t(ev.start) ||
         t(cur.end) !== t(ev.end);
}

// Minimal RFC 5545 parser: enough for what dindoa and Nevobo write, plus TZID
// and all-day dates for robustness.
function parseIcs_(text) {
  const lines = text.replace(/\r\n[ \t]/g, '').replace(/\n[ \t]/g, '').split(/\r?\n/);
  const events = [];
  let cur = null;

  for (const line of lines) {
    if (line === 'BEGIN:VEVENT') { cur = {}; continue; }
    if (line === 'END:VEVENT') {
      if (cur.UID && cur.DTSTART) events.push(toEvent_(cur));
      cur = null;
      continue;
    }
    if (!cur) continue;
    const colon = line.indexOf(':');
    if (colon < 0) continue;
    const [name, ...params] = line.slice(0, colon).split(';');
    cur[name] = { value: line.slice(colon + 1), params: params };
  }
  return events;
}

function toEvent_(raw) {
  const text = (p) => p ? p.value
      .replace(/\\n/gi, '\n').replace(/\\,/g, ',')
      .replace(/\\;/g, ';').replace(/\\\\/g, '\\') : '';
  const start = toTime_(raw.DTSTART);
  const end = raw.DTEND ? toTime_(raw.DTEND)
                        : { dateTime: new Date(new Date(start.dateTime).getTime() + 3600e3).toISOString() };
  return {
    iCalUID: raw.UID.value,
    summary: text(raw.SUMMARY),
    location: text(raw.LOCATION),
    description: text(raw.DESCRIPTION),
    start: start,
    end: end,
  };
}

function toTime_(prop) {
  const v = prop.value;
  const tzid = (prop.params.find((p) => p.startsWith('TZID=')) || '').slice(5);
  if (/^\d{8}$/.test(v)) {
    return { date: `${v.slice(0, 4)}-${v.slice(4, 6)}-${v.slice(6, 8)}` };
  }
  const m = v.match(/^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(Z?)$/);
  if (!m) throw new Error('Unsupported date: ' + v);
  const local = `${m[1]}-${m[2]}-${m[3]}T${m[4]}:${m[5]}:${m[6]}`;
  if (m[7] === 'Z') return { dateTime: local + 'Z' };
  return { dateTime: local, timeZone: tzid || 'Europe/Amsterdam' };
}
