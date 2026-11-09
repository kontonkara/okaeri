pragma Singleton

import QtQuick
import Quickshell
import qs

// The weather where Settings.weather puts you, from open-meteo.com, which asks
// for no key: now, and the next few days. It asks every half hour while it's on,
// and as the place or the units change. locate() finds a place by its name.
Singleton {
	id: weather

	readonly property var own: Settings.weather
	readonly property bool on: own.on && own.place !== ""
	readonly property string api: Quickshell.env("OKAERI_WEATHER_URL") || "https://api.open-meteo.com"
	readonly property string places: Quickshell.env("OKAERI_PLACES_URL") || "https://geocoding-api.open-meteo.com"
	// { temperature, code, day }, or null before it's known.
	property var current: null
	// [{ date, code, high, low }], today first.
	property var days: []
	// What went wrong the last time it asked, or "".
	property string trouble: ""
	readonly property string unit: own.units === "fahrenheit" ? "°F" : "°C"
	// What it asks by: a change of any other setting doesn't ask again.
	readonly property string query: on ? `${own.latitude},${own.longitude},${own.units}` : ""

	// A place by its name, in the settings: its name as it's known, and where it is.
	signal located(string name)
	signal notFound(string why)

	function get(url, then) {
		const request = new XMLHttpRequest();
		request.onreadystatechange = () => {
			if (request.readyState !== XMLHttpRequest.DONE)
				return;
			if (request.status !== 200) {
				then(null, request.status ? `It answered ${request.status}` : "It can't be reached");
				return;
			}
			try {
				then(JSON.parse(request.responseText), "");
			} catch (error) {
				then(null, "It said something else");
			}
		};
		request.open("GET", url);
		request.send();
	}

	function fetch() {
		if (!on)
			return;
		const url = `${api}/v1/forecast?latitude=${own.latitude}&longitude=${own.longitude}&current=temperature_2m,weather_code,is_day&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=4${own.units === "fahrenheit" ? "&temperature_unit=fahrenheit" : ""}`;
		get(url, (answer, why) => {
			if (!answer?.current || !answer?.daily) {
				trouble = why || "It said something else";
				return;
			}
			trouble = "";
			current = {
				temperature: Math.round(answer.current.temperature_2m),
				code: answer.current.weather_code,
				day: answer.current.is_day === 1
			};
			days = answer.daily.time.map((date, index) => ({
				date: new Date(`${date}T12:00:00`),
				code: answer.daily.weather_code[index],
				high: Math.round(answer.daily.temperature_2m_max[index]),
				low: Math.round(answer.daily.temperature_2m_min[index])
			}));
		});
	}

	function locate(name) {
		get(`${places}/v1/search?count=1&name=${encodeURIComponent(name)}`, (answer, why) => {
			const found = answer?.results?.[0];
			if (!found) {
				notFound(why || "No place by that name");
				return;
			}
			const named = [found.name, found.admin1, found.country].filter(part => !!part).filter((part, index, all) => all.indexOf(part) === index).join(", ");
			Settings.set("weather", "latitude", found.latitude);
			Settings.set("weather", "longitude", found.longitude);
			Settings.set("weather", "place", named);
			located(named);
		});
	}

	// What WMO's code says, and an icon for it.
	function about(code) {
		if (code === 0)
			return "Clear";
		if (code <= 2)
			return "Partly cloudy";
		if (code === 3)
			return "Overcast";
		if (code === 45 || code === 48)
			return "Fog";
		if (code >= 51 && code <= 57)
			return "Drizzle";
		if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82))
			return "Rain";
		if ((code >= 71 && code <= 77) || code === 85 || code === 86)
			return "Snow";
		if (code >= 95)
			return "Thunderstorm";
		return "";
	}

	function icon(code, day) {
		if (code === 0)
			return day === false ? "moon" : "sun";
		if (code <= 3)
			return "cloud";
		if (code === 45 || code === 48)
			return "fog";
		if ((code >= 71 && code <= 77) || code === 85 || code === 86)
			return "snow";
		if (code >= 95)
			return "storm";
		return "rain";
	}

	onQueryChanged: {
		current = null;
		days = [];
		fetch();
	}

	Timer {
		running: weather.on
		interval: 30 * 60 * 1000
		repeat: true
		onTriggered: weather.fetch()
	}
}
