pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// The events of the calendars Settings.clock.calendars names, for the month under
// the clock. A calendar is an iCalendar file, read again as it changes, or an
// address that gives one, as a CalDAV server's or Google's "secret address in iCal
// format" does: that's asked for as it's added and every half hour after, by the
// clock, as the weather is, and what came last stays while asking again goes
// wrong. A calendar is read once as it comes; what happens on the days the month
// asks about is worked out as it asks, and a rule that repeats an event is
// followed into those days and no further.
Singleton {
	id: events

	// As text first, so that only a change of the list itself is one: the rest of
	// the clock's settings change without it.
	readonly property string listed: JSON.stringify(Array.isArray(Settings.clock.calendars) ? Settings.clock.calendars.filter(source => typeof source === "string" && source !== "") : [])
	readonly property var sources: JSON.parse(listed)
	readonly property bool on: sources.length > 0
	// What was read of each, by the source as it's set: { name, events }, `name` the
	// one the calendar gives itself, or "".
	property var known: ({})
	// What went wrong with each the last time, by the same.
	property var trouble: ({})
	readonly property bool troubled: Object.keys(trouble).length > 0
	// The events of all of them, as parse() has them.
	readonly property var items: sources.reduce((found, source) => found.concat(known[source]?.events ?? []), [])
	// What's wrong with a calendar nothing has come from yet, for the month to say.
	readonly property string problem: {
		const source = sources.find(one => trouble[one] && !known[one]);
		return source ? trouble[source] : "";
	}
	// When the addresses were last asked, and when each was, in milliseconds.
	property double tried: 0
	property var asked: ({})

	readonly property double oneDay: 24 * 60 * 60 * 1000

	// Whether `source` is one this takes: a file by its whole path, or an address.
	function takes(source) {
		return /^(\/|~\/|file:\/\/|https?:\/\/|webcals?:\/\/)/i.test(source);
	}

	function remote(source) {
		return /^(https?|webcals?):\/\//i.test(source);
	}

	function pathOf(source) {
		if (source.startsWith("~/"))
			return Quickshell.env("HOME") + source.slice(1);
		return source.startsWith("file://") ? decodeURIComponent(source.slice(7)) : source;
	}

	// Where a calendar is, as the settings show it: an address by its server alone,
	// as the rest of one can be a secret, and a file with the home folder as ~.
	function where(source) {
		if (remote(source))
			return source.replace(/^[a-z]+:\/\//i, "").split(/[\/?#]/)[0].replace(/^.*@/, "");
		const home = Quickshell.env("HOME");
		const path = pathOf(source);
		return home && path.startsWith(home + "/") ? `~${path.slice(home.length)}` : path;
	}

	// A calendar's name, as it gives one, or where it is.
	function title(source) {
		return known[source]?.name || where(source);
	}

	// What the settings say under that: where it is, if the name was shown, and how
	// it went.
	function about(source) {
		const count = known[source]?.events.length;
		const state = trouble[source] || (count === undefined ? "Reading it" : count === 0 ? "Nothing in it" : count === 1 ? "One event" : `${count} events`);
		return known[source]?.name ? `${where(source)} · ${state}` : state;
	}

	function got(source, text) {
		const plain = text.replace(/^\uFEFF/, "");
		if (!/^BEGIN:VCALENDAR/im.test(plain)) {
			failed(source, "It isn't a calendar", false);
			return;
		}
		known = Object.assign({}, known, { [source]: parse(plain) });
		failed(source, "", false);
	}

	// With `forget`, what was read of it goes too: a file that's gone has no events.
	function failed(source, why, forget) {
		if (forget && known[source]) {
			const left = Object.assign({}, known);
			delete left[source];
			known = left;
		}
		if ((trouble[source] ?? "") === why)
			return;
		const next = Object.assign({}, trouble);
		if (why)
			next[source] = why;
		else
			delete next[source];
		trouble = next;
	}

	function ask(source) {
		asked[source] = Date.now();
		const request = new XMLHttpRequest();
		request.onreadystatechange = () => {
			if (request.readyState !== XMLHttpRequest.DONE || !sources.includes(source))
				return;
			if (request.status === 200)
				got(source, request.responseText);
			else
				failed(source, request.status ? `It answered ${request.status}` : "It can't be reached", false);
		};
		// webcal:// is how some give an address for a calendar app to take.
		request.open("GET", source.replace(/^webcals?:/i, "https:"));
		request.send();
	}

	// Every address again, and every file: one put in another's place by a rename
	// isn't seen as it changes.
	function fetch() {
		tried = Date.now();
		for (let index = 0; index < files.instances.length; index++)
			files.instances[index].reload();
		sources.filter(source => remote(source)).forEach(source => ask(source));
	}

	// A line of the text as { name, params, value }, or null for one with none.
	function field(line) {
		let quoted = false;
		let colon = -1;
		for (let at = 0; at < line.length && colon < 0; at++) {
			if (line[at] === "\"")
				quoted = !quoted;
			else if (line[at] === ":" && !quoted)
				colon = at;
		}
		if (colon < 0)
			return null;
		const head = line.slice(0, colon).split(";");
		const params = {};
		head.slice(1).forEach(param => {
			const at = param.indexOf("=");
			if (at > 0)
				params[param.slice(0, at).trim().toUpperCase()] = param.slice(at + 1).replace(/^"|"$/g, "");
		});
		return { name: head[0].trim().toUpperCase(), params, value: line.slice(colon + 1) };
	}

	// Text as iCalendar writes it, with \, \; \\ and \n for what they stand for.
	function unescaped(value) {
		return value.replace(/\\([\\;,nN])/g, (whole, letter) => letter === "n" || letter === "N" ? "\n" : letter);
	}

	// When a property says, as { kind, zone, wall }. `wall` is the time on the clock
	// there, in milliseconds as if it were at Greenwich, so that days and months
	// go by it as they do there. `kind` is "date" for a whole day, "utc", "zone"
	// for a time in a zone the calendar describes, with what it says of that zone
	// in `zone`, or "local". A time in a zone it doesn't describe is taken as one
	// here: without the zone's rules there's nothing to tell its offset by, and a
	// calendar of one's own is mostly in one's own zone. `value` is one of a list
	// the property has, as EXDATE can.
	function moment(one, zones, value) {
		if (!one)
			return null;
		const match = /^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?(Z)?)?$/i.exec((value ?? one.value).trim());
		if (!match)
			return null;
		const date = Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3]));
		if (!match[4] || (one.params.VALUE ?? "").toUpperCase() === "DATE")
			return { kind: "date", zone: null, wall: date };
		const wall = date + ((Number(match[4]) * 60 + Number(match[5])) * 60 + Number(match[6] ?? 0)) * 1000;
		if (match[7])
			return { kind: "utc", zone: null, wall };
		const id = one.params.TZID ?? "";
		if (zones[id]?.length > 0)
			return { kind: "zone", zone: zones[id], wall };
		if (/^(utc|gmt|z|etc\/utc|etc\/gmt)$/i.test(id))
			return { kind: "utc", zone: null, wall };
		return { kind: "local", zone: null, wall };
	}

	// The moment a wall time of `at`'s kind and zone is, in milliseconds.
	function instant(at, wall) {
		if (at.kind === "utc")
			return wall;
		if (at.kind === "zone")
			return wall - offsetAt(at.zone, wall) * 60 * 1000;
		const time = new Date(wall);
		return new Date(time.getUTCFullYear(), time.getUTCMonth(), time.getUTCDate(), time.getUTCHours(), time.getUTCMinutes(), time.getUTCSeconds()).getTime();
	}

	// "+0130" in minutes.
	function minutes(value) {
		const match = /^([+-])(\d{2})(\d{2})/.exec((value ?? "").trim());
		return match ? (match[1] === "-" ? -1 : 1) * (Number(match[2]) * 60 + Number(match[3])) : 0;
	}

	// How long DURATION says, in milliseconds: P1D, PT1H30M, P2W. Null for what
	// isn't one.
	function duration(value) {
		const match = /^([+-])?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/i.exec(value.trim());
		if (!match)
			return null;
		const length = ((((Number(match[2] ?? 0) * 7 + Number(match[3] ?? 0)) * 24 + Number(match[4] ?? 0)) * 60 + Number(match[5] ?? 0)) * 60 + Number(match[6] ?? 0)) * 1000;
		return match[1] === "-" ? -length : length;
	}

	// A day's key, for the days of the month to be looked up by.
	function key(day) {
		return `${day.getFullYear()}-${day.getMonth()}-${day.getDate()}`;
	}

	// The rule an event repeats by, or null for one this doesn't follow, which
	// leaves only its first time: FREQ of DAILY, WEEKLY, MONTHLY or YEARLY, every
	// INTERVAL of those, COUNT times or UNTIL a time, on the days BYDAY,
	// BYMONTHDAY and BYMONTH name, and BYSETPOS of those in a month. The days of a
	// year by their place in all of it, and hours and minutes of their own, aren't.
	function ruleOf(value) {
		const parts = {};
		value.split(";").forEach(part => {
			const at = part.indexOf("=");
			if (at > 0)
				parts[part.slice(0, at).trim().toUpperCase()] = part.slice(at + 1).trim();
		});
		const freq = (parts.FREQ ?? "").toUpperCase();
		const followed = ["FREQ", "INTERVAL", "COUNT", "UNTIL", "BYDAY", "BYMONTHDAY", "BYMONTH", "BYSETPOS", "WKST"];
		if (!["DAILY", "WEEKLY", "MONTHLY", "YEARLY"].includes(freq) || Object.keys(parts).some(name => !followed.includes(name)))
			return null;
		const weekdays = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"];
		// A day of the week, with the how-manieth of the month it is first, as 2TU or
		// -1FR, or 0 for every one.
		const days = (parts.BYDAY ?? "").split(",").filter(one => one.trim() !== "").map(one => {
			const match = /^([+-]?\d{1,2})?(SU|MO|TU|WE|TH|FR|SA)$/i.exec(one.trim());
			return match ? { n: Number(match[1] ?? 0), weekday: weekdays.indexOf(match[2].toUpperCase()) } : null;
		});
		const numbers = text => (text ?? "").split(",").filter(one => one.trim() !== "").map(Number);
		const until = parts.UNTIL ? moment({ value: parts.UNTIL, params: {} }, {}) : null;
		const made = {
			freq,
			interval: Math.max(1, Math.floor(Number(parts.INTERVAL)) || 1),
			count: Math.max(0, Math.floor(Number(parts.COUNT)) || 0),
			// A last day goes on to its end.
			until: !until ? null : until.kind === "date" ? instant(until, until.wall + oneDay) - 1 : instant(until, until.wall),
			days,
			monthDays: numbers(parts.BYMONTHDAY),
			months: numbers(parts.BYMONTH),
			positions: numbers(parts.BYSETPOS),
			weekStart: parts.WKST ? weekdays.indexOf(parts.WKST.toUpperCase()) : 1
		};
		if (days.includes(null) || (parts.UNTIL && !until) || made.weekStart < 0 || [made.monthDays, made.months, made.positions].some(list => list.some(n => !Number.isInteger(n) || n === 0)))
			return null;
		if (freq === "YEARLY" && made.months.length === 0 && (days.length > 0 || made.monthDays.length > 0))
			return null;
		return made;
	}

	// The days of `month` in `year` a rule that repeats monthly or yearly has, in
	// order: those BYDAY and BYMONTHDAY both leave in, BYSETPOS of those, or with
	// none of them `date`, the day it began on, where the month has one.
	function daysIn(rule, year, month, date) {
		const length = new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
		if (rule.days.length === 0 && rule.monthDays.length === 0)
			return date <= length ? [date] : [];
		const found = [];
		for (let that = 1; that <= length; that++) {
			const weekday = new Date(Date.UTC(year, month, that)).getUTCDay();
			const ahead = Math.floor((that - 1) / 7) + 1;
			const behind = -(Math.floor((length - that) / 7) + 1);
			if ((rule.monthDays.length === 0 || rule.monthDays.some(n => n === that || n === that - length - 1)) && (rule.days.length === 0 || rule.days.some(one => one.weekday === weekday && (one.n === 0 || one.n === ahead || one.n === behind))))
				found.push(that);
		}
		if (rule.positions.length === 0)
			return found;
		return rule.positions.map(n => found[n > 0 ? n - 1 : found.length + n]).filter((that, index, all) => that !== undefined && all.indexOf(that) === index).sort((a, b) => a - b);
	}

	// The offset in minutes a zone the calendar describes has at a wall time there:
	// that of whichever of its parts, standard time or summer time, began last
	// before then. A part begins by a rule, each year, or once.
	function offsetAt(zone, wall) {
		const year = new Date(wall).getUTCFullYear();
		let latest = -Infinity;
		let offset = zone[0].from;
		zone.forEach(part => {
			const until = part.rule?.until ?? null;
			const onsets = [];
			if (part.rule?.freq === "YEARLY") {
				const months = part.rule.months.length > 0 ? part.rule.months.map(month => month - 1) : [part.month];
				[year - 1, year].filter(one => one >= part.year).forEach(one => months.forEach(month => daysIn(part.rule, one, month, part.date).forEach(date => onsets.push(Date.UTC(one, month, date) + part.clock))));
			} else {
				onsets.push(part.wall);
			}
			onsets.forEach(onset => {
				if (onset <= wall && onset >= part.wall && onset > latest && (until === null || onset - part.from * 60 * 1000 <= until)) {
					latest = onset;
					offset = part.to;
				}
			});
		});
		return offset;
	}

	// The events of an iCalendar text, each as times() needs it, and the name the
	// calendar gives itself: { name, events }. One of a series moved or called off
	// on its own keeps the series from being there at the time it was.
	function parse(text) {
		// A line that goes on starts with a space or a tab.
		const lines = text.replace(/\r\n?/g, "\n").replace(/\n[ \t]/g, "").split("\n");
		const open = [];
		const raw = [];
		const described = {};
		let props = null;
		let zone = null;
		let name = "";
		lines.forEach(line => {
			const one = field(line);
			if (!one)
				return;
			const top = open[open.length - 1];
			if (one.name === "BEGIN") {
				const kind = one.value.trim().toUpperCase();
				open.push(kind);
				if (kind === "VEVENT")
					props = {};
				else if (kind === "VTIMEZONE")
					zone = { id: "", parts: [] };
				else if (zone && top === "VTIMEZONE" && (kind === "STANDARD" || kind === "DAYLIGHT"))
					props = {};
				return;
			}
			if (one.name === "END") {
				const kind = open.pop();
				if (kind === "VEVENT" && props) {
					raw.push(props);
					props = null;
				} else if ((kind === "STANDARD" || kind === "DAYLIGHT") && zone && props) {
					zone.parts.push(props);
					props = null;
				} else if (kind === "VTIMEZONE" && zone) {
					if (zone.id && zone.parts.length > 0)
						described[zone.id] = zone.parts;
					zone = null;
				}
				return;
			}
			if (top === "VCALENDAR" && one.name === "X-WR-CALNAME") {
				name = unescaped(one.value).trim();
			} else if (top === "VTIMEZONE" && zone && one.name === "TZID") {
				zone.id = one.value;
			} else if (props && (top === "VEVENT" || top === "STANDARD" || top === "DAYLIGHT")) {
				// Only the event's own: what's in an alarm of it isn't.
				if (one.name === "EXDATE")
					props.EXDATE = (props.EXDATE ?? []).concat([one]);
				else if (!props[one.name])
					props[one.name] = one;
			}
		});
		const zones = {};
		Object.keys(described).forEach(id => {
			zones[id] = described[id].map(part => {
				const start = moment(part.DTSTART, {}) ?? { wall: 0 };
				const time = new Date(start.wall);
				return {
					wall: start.wall,
					year: time.getUTCFullYear(),
					month: time.getUTCMonth(),
					date: time.getUTCDate(),
					clock: start.wall - Date.UTC(time.getUTCFullYear(), time.getUTCMonth(), time.getUTCDate()),
					from: minutes(part.TZOFFSETFROM?.value),
					to: minutes(part.TZOFFSETTO?.value),
					rule: part.RRULE ? ruleOf(part.RRULE.value) : null
				};
			}).sort((a, b) => a.wall - b.wall);
		});
		const made = [];
		raw.forEach(props => {
			const start = moment(props.DTSTART, zones);
			if (!start)
				return;
			const end = moment(props.DTEND, zones);
			const lasts = props.DURATION ? duration(props.DURATION.value) : null;
			const replaces = moment(props["RECURRENCE-ID"], zones);
			const event = {
				uid: props.UID?.value ?? "",
				summary: unescaped(props.SUMMARY?.value ?? "").replace(/\s*\n\s*/g, " ").trim() || "An event",
				allDay: start.kind === "date",
				kind: start.kind,
				zone: start.zone,
				wall: start.wall,
				// How many days one of whole days lasts, and how long one of a time does.
				days: 1,
				length: 0,
				rule: props.RRULE ? ruleOf(props.RRULE.value) : null,
				except: [],
				exceptDays: [],
				replaces: replaces ? instant(replaces, replaces.wall) : null,
				off: (props.STATUS?.value ?? "").trim().toUpperCase() === "CANCELLED",
				// Its first time, worked out once: for most that's the only one.
				at: 0,
				ends: 0
			};
			if (event.allDay)
				event.days = Math.max(1, Math.round(((end ? end.wall : start.wall + (lasts ?? oneDay)) - start.wall) / oneDay));
			else
				event.length = Math.max(0, end ? instant(end, end.wall) - instant(start, start.wall) : (lasts ?? 0));
			event.at = instant(event, event.wall);
			event.ends = event.allDay ? instant(event, event.wall + event.days * oneDay) : event.at + event.length;
			(props.EXDATE ?? []).forEach(one => one.value.split(",").forEach(value => {
				const left = moment(one, zones, value);
				if (left && left.kind === "date") {
					const time = new Date(left.wall);
					event.exceptDays.push(`${time.getUTCFullYear()}-${time.getUTCMonth()}-${time.getUTCDate()}`);
				} else if (left) {
					event.except.push(instant(left, left.wall));
				}
			}));
			made.push(event);
		});
		const moved = {};
		made.forEach(event => {
			if (event.replaces !== null)
				moved[event.uid] = (moved[event.uid] ?? []).concat([event.replaces]);
		});
		made.forEach(event => {
			if (event.rule && event.replaces === null && moved[event.uid])
				event.except = event.except.concat(moved[event.uid]);
		});
		return { name, events: made.filter(event => !event.off) };
	}

	// The times `event` happens that start before `to` and end after `from`, both
	// moments in milliseconds: [{ start, end }].
	function times(event, from, to) {
		const found = [];
		const rule = event.rule;
		if (!rule) {
			if (event.at < to && (event.ends > from || event.at >= from))
				found.push({ start: event.at, end: event.ends });
			return found;
		}
		const first = new Date(event.wall);
		const year = first.getUTCFullYear();
		const month = first.getUTCMonth();
		const date = first.getUTCDate();
		const weekday = first.getUTCDay();
		const clock = event.wall - Date.UTC(year, month, date);
		let counted = 0;
		// Each time it comes, in order: false once no more can matter.
		const take = wall => {
			if (wall < event.wall)
				return true;
			const start = instant(event, wall);
			if ((rule.until !== null && start > rule.until) || (rule.count > 0 && ++counted > rule.count) || start >= to)
				return false;
			const end = event.allDay ? instant(event, wall + event.days * oneDay) : start + event.length;
			if ((end > from || start >= from) && !event.except.includes(start) && (event.exceptDays.length === 0 || !event.exceptDays.includes(key(new Date(start)))))
				found.push({ start, end });
			return true;
		};
		const step = rule.interval;
		// The days of a week it's on, counted from the day the week starts.
		const offsets = (rule.days.length > 0 ? rule.days.map(one => (one.weekday - rule.weekStart + 7) % 7) : [(weekday - rule.weekStart + 7) % 7]).filter((one, index, all) => all.indexOf(one) === index).sort((a, b) => a - b);
		const months = rule.months.length > 0 ? rule.months.map(one => one - 1).sort((a, b) => a - b) : [month];
		// With no count to keep, the periods well before `from` aren't gone through.
		const span = ({ DAILY: 1, WEEKLY: 7, MONTHLY: 31, YEARLY: 366 })[rule.freq] * step;
		let period = rule.count > 0 ? 0 : Math.max(0, Math.floor((from - event.wall) / oneDay / span) - 2);
		for (let rounds = 0; rounds < 50000; rounds++, period++) {
			let begins = 0;
			const walls = [];
			if (rule.freq === "DAILY") {
				begins = Date.UTC(year, month, date + period * step);
				const that = new Date(begins);
				if ((rule.months.length === 0 || rule.months.includes(that.getUTCMonth() + 1)) && (rule.days.length === 0 || rule.days.some(one => one.weekday === that.getUTCDay())) && (rule.monthDays.length === 0 || rule.monthDays.includes(that.getUTCDate())))
					walls.push(begins + clock);
			} else if (rule.freq === "WEEKLY") {
				begins = Date.UTC(year, month, date - (weekday - rule.weekStart + 7) % 7 + period * step * 7);
				offsets.forEach(offset => {
					const that = begins + offset * oneDay;
					if (rule.months.length === 0 || rule.months.includes(new Date(that).getUTCMonth() + 1))
						walls.push(that + clock);
				});
			} else if (rule.freq === "MONTHLY") {
				begins = Date.UTC(year, month + period * step, 1);
				const that = new Date(begins);
				if (rule.months.length === 0 || rule.months.includes(that.getUTCMonth() + 1))
					daysIn(rule, that.getUTCFullYear(), that.getUTCMonth(), date).forEach(one => walls.push(Date.UTC(that.getUTCFullYear(), that.getUTCMonth(), one) + clock));
			} else {
				const that = year + period * step;
				begins = Date.UTC(that, 0, 1);
				months.forEach(one => daysIn(rule, that, one, date).forEach(other => walls.push(Date.UTC(that, one, other) + clock)));
			}
			// A day to spare: a wall time can be fourteen hours off its moment.
			if (begins - oneDay > to)
				break;
			for (const wall of walls) {
				if (!take(wall))
					return found;
			}
		}
		return found;
	}

	// The days from the day of `from` to that of `to` that have something on them,
	// by key(): for a dot under each. Where each day starts is worked out once: a
	// date of its own for each time would take long with many.
	function marked(from, to) {
		const starts = [];
		for (let that = new Date(from.getFullYear(), from.getMonth(), from.getDate()); that < to; that = new Date(that.getFullYear(), that.getMonth(), that.getDate() + 1))
			starts.push(that.getTime());
		const keys = starts.map(start => key(new Date(start)));
		const found = {};
		if (starts.length === 0)
			return found;
		const end = to.getTime();
		items.forEach(event => times(event, starts[0], end).forEach(time => {
			let index = Math.max(0, Math.min(starts.length - 1, Math.floor((time.start - starts[0]) / oneDay)));
			while (index > 0 && starts[index] > time.start)
				index--;
			while (index < starts.length - 1 && starts[index + 1] <= time.start)
				index++;
			do {
				found[keys[index]] = true;
				index++;
			} while (index < starts.length && starts[index] < time.end);
		}));
		return found;
	}

	// What's on `day`: [{ start, end, allDay, summary }], those of all of it first,
	// then by when they start.
	function happening(day) {
		const from = new Date(day.getFullYear(), day.getMonth(), day.getDate()).getTime();
		const to = new Date(day.getFullYear(), day.getMonth(), day.getDate() + 1).getTime();
		const found = [];
		items.forEach(event => times(event, from, to).forEach(time => found.push({
			start: new Date(time.start),
			end: new Date(time.end),
			allDay: event.allDay,
			summary: event.summary
		})));
		return found.sort((a, b) => (b.allDay - a.allDay) || (a.start - b.start) || a.summary.localeCompare(b.summary));
	}

	// What's gone goes, and what's new is asked for.
	onSourcesChanged: {
		const kept = {};
		const troubles = {};
		sources.forEach(source => {
			if (known[source])
				kept[source] = known[source];
			if (trouble[source])
				troubles[source] = trouble[source];
		});
		Object.keys(asked).filter(source => !sources.includes(source)).forEach(source => delete asked[source]);
		if (Object.keys(kept).length !== Object.keys(known).length)
			known = kept;
		if (Object.keys(troubles).length !== Object.keys(trouble).length)
			trouble = troubles;
		sources.filter(source => remote(source) && !asked[source]).forEach(source => ask(source));
	}

	Component.onCompleted: {
		tried = Date.now();
		sources.filter(source => remote(source)).forEach(source => ask(source));
	}

	// By the clock: a timer of half an hour would stand still through a sleep. After
	// trouble it's two minutes, as a file may yet come.
	Timer {
		running: events.on
		interval: 60 * 1000
		repeat: true
		onTriggered: {
			if (Date.now() - events.tried >= (events.troubled ? 2 : 30) * 60 * 1000)
				events.fetch();
		}
	}

	Variants {
		id: files

		model: events.sources.filter(source => !events.remote(source))

		FileView {
			required property string modelData

			path: events.pathOf(modelData)
			watchChanges: true
			printErrors: false
			onFileChanged: reload()
			onLoaded: events.got(modelData, text())
			onLoadFailed: events.failed(modelData, "It can't be read", true)
		}
	}
}
