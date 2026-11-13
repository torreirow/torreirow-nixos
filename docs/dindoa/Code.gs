// Syncs the dindoa ICS feed into an existing Google Calendar.
//
// Events are matched on their ICS UID: changed matches are updated in place,
// new ones are added, and future matches that disappeared from the feed are
// removed. Ownership is decided by the UID suffix, not by a private property,
// so a renamed calendar or a re-import cannot create a second copy: duplicates
// with the same UID are cleaned up on the next run.

const FEED_URL = 'https://toorren.net/dindoa/dindoa-j4.ics';
const CALENDAR_ID = 'primary'; // or the calendar ID from its settings page
const UID_SUFFIX = '@dindoa.nl';
const TAG_KEY = 'dindoa';
const TAG_VALUE = 'j4';

function sync() {
  const feed = fetchFeed_();
  const existing = listOurs_();
  const seen = new Set();
  let added = 0, updated = 0, removed = 0;

  for (const ev of feed) {
    seen.add(ev.iCalUID);
    const current = existing.get(ev.iCalUID);
    if (!current) {
      try {
        Calendar.Events.import(ev, CALENDAR_ID);
        added++;
      } catch (e) {
        // Typically: you deleted this match by hand. Leave it deleted.
        console.warn('Import skipped for ' + ev.iCalUID + ': ' + e.message);
      }
    } else if (differs_(current, ev)) {
      Calendar.Events.patch({
        summary: ev.summary,
        location: ev.location,
        description: ev.description,
        start: ev.start,
        end: ev.end,
      }, CALENDAR_ID, current.id);
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
    Calendar.Events.remove(CALENDAR_ID, current.id);
    removed++;
  }

  console.log(`dindoa sync: ${feed.length} in feed, +${added} ~${updated} -${removed}`);
}

// Run once by hand to schedule sync() every hour.
function installTrigger() {
  for (const t of ScriptApp.getProjectTriggers()) {
    if (t.getHandlerFunction() === 'sync') ScriptApp.deleteTrigger(t);
  }
  ScriptApp.newTrigger('sync').timeBased().everyHours(1).create();
}

function fetchFeed_() {
  const res = UrlFetchApp.fetch(FEED_URL, { muteHttpExceptions: true });
  if (res.getResponseCode() !== 200) {
    throw new Error('Feed returned HTTP ' + res.getResponseCode());
  }
  const events = parseIcs_(res.getContentText('UTF-8'));
  // An empty feed is far more likely a broken upload than a cancelled
  // season; refuse instead of deleting every match.
  if (events.length === 0) throw new Error('Feed contains no events; nothing changed');
  return events;
}

// All events this script owns, keyed by ICS UID. Events with the same UID
// (a re-import, or an import next to an existing event) are reduced to one:
// the most recently updated copy wins.
function listOurs_() {
  const map = new Map();
  const now = Date.now();
  let pageToken;
  do {
    const page = Calendar.Events.list(CALENDAR_ID, {
      timeMin: new Date(now - 120 * 864e5).toISOString(),
      timeMax: new Date(now + 500 * 864e5).toISOString(),
      maxResults: 2500,
      showDeleted: false,
      pageToken: pageToken,
    });
    for (const item of page.items || []) {
      const uid = item.iCalUID || '';
      if (!uid.endsWith(UID_SUFFIX)) continue;
      const prev = map.get(uid);
      if (!prev) {
        map.set(uid, item);
        continue;
      }
      const keep = new Date(item.updated) >= new Date(prev.updated) ? item : prev;
      const drop = keep === item ? prev : item;
      Calendar.Events.remove(CALENDAR_ID, drop.id);
      console.log('Removed duplicate ' + uid);
      map.set(uid, keep);
    }
    pageToken = page.nextPageToken;
  } while (pageToken);
  return map;
}

function differs_(cur, ev) {
  const t = (x) => x ? new Date(x.dateTime || x.date).getTime() : null;
  return (cur.summary || '') !== (ev.summary || '') ||
         (cur.location || '') !== (ev.location || '') ||
         (cur.description || '') !== (ev.description || '') ||
         t(cur.start) !== t(ev.start) ||
         t(cur.end) !== t(ev.end);
}

// Minimal RFC 5545 parser: enough for what dindoa writes, plus TZID and
// all-day dates for robustness.
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
    extendedProperties: { private: { [TAG_KEY]: TAG_VALUE } },
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
