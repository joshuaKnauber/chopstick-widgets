# Planes around the saved location, from adsb.lol (falls back to airplanes.live).
# Location lives in $CHOPSTICK_STORAGE/location.json; first run guesses it from the IP.
store="${CHOPSTICK_STORAGE:-$CHOPSTICK_TMP}"
loc="$store/location.json"
[ -n "$store" ] && mkdir -p "$store"

if [ ! -s "$loc" ]; then
  geo=$(curl -s -m 8 "http://ip-api.com/json/?fields=lat,lon,city")
  echo "$geo" | /usr/bin/jq -e '.lat' >/dev/null 2>&1 || { echo '{"error":"No location yet","summary":"Location not found","overhead":false,"count":0,"nearby":[]}'; exit 0; }
  echo "$geo" | /usr/bin/jq -c '{lat, lon, place: (.city // "Here"), radius_km: 4}' > "$loc"
fi

lat=$(/usr/bin/jq -r '.lat' "$loc")
lon=$(/usr/bin/jq -r '.lon' "$loc")

feed=$(curl -s -m 10 "https://api.adsb.lol/v2/point/$lat/$lon/25")
echo "$feed" | /usr/bin/jq -e '.ac' >/dev/null 2>&1 || feed=$(curl -s -m 10 "https://api.airplanes.live/v2/point/$lat/$lon/25")
echo "$feed" | /usr/bin/jq -e '.ac' >/dev/null 2>&1 || { /usr/bin/jq -c '. + {error: "Flight feed unreachable", summary: "Flight feed unreachable", overhead: false, count: 0, nearby: []}' "$loc"; exit 0; }

base=$(echo "$feed" | /usr/bin/jq -c --slurpfile l "$loc" '
  ($l[0]) as $loc |
  def comma: tostring | [scan("\\d")] | reverse | [range(0; length; 3) as $i | .[$i:$i+3] | reverse | join("")] | reverse | join(",");
  def compass: ["N","NE","E","SE","S","SW","W","NW"][((. + 22.5) / 45 | floor) % 8];
  [ .ac[]
    | select((.alt_baro | type) == "number" and .lat != null)
    | (.flight // "" | gsub(" "; "")) as $cs
    | ((.dst // 0) * 1.852) as $km
    # Closest approach in the next 90 s (until the next poll), from track and ground speed.
    | ((.dir // 0) * 3.14159265 / 180) as $b | ((.track // 0) * 3.14159265 / 180) as $t
    | ($km * ($b | sin)) as $px | ($km * ($b | cos)) as $py
    | ((.gs // 0) * 1.852 / 3600) as $v
    | ($v * ($t | sin)) as $vx | ($v * ($t | cos)) as $vy
    | (if $v > 0 then ([0, ([90, (-($px * $vx + $py * $vy) / ($v * $v))] | min)] | max) else 0 end) as $eta
    | ((($px + $vx * $eta) as $x | ($py + $vy * $eta) as $y | ($x * $x + $y * $y) | sqrt)) as $closest
    | {
        hex, lat, lon,
        heading: (if .track then "Heading \(.track | compass)" else "" end),
        track: (.track // null),
        callsign: (if $cs == "" then (.r // .hex | ascii_upcase) else $cs end),
        type: (.t // "Unknown type"),
        reg: (.r // ""),
        alt_ft: .alt_baro,
        alt: "\(.alt_baro | comma) ft",
        speed: (if .gs then "\(.gs | round) kt" else "–" end),
        km: ($km * 10 | round / 10),
        dist: "\($km * 10 | round / 10) km \((.dir // 0) | compass)",
        closest_km: $closest,
        when: (if $eta < 10 then "Overhead now" else "Overhead in ~\($eta / 10 | round * 10) s" end),
        url: "https://www.flightradar24.com/\(if $cs == "" then (.r // .hex) else $cs end)"
      }
  ] | sort_by(.km) as $planes
  | ($planes | map(select(.closest_km <= ($loc.radius_km // 4))) | sort_by(.closest_km)) as $over
  | {
      place: $loc.place, lat: $loc.lat, lon: $loc.lon, radius_km: ($loc.radius_km // 4),
      count: ($planes | length),
      overhead: (($over | length) > 0),
      plane: ($over[0] // null),
      overhead_id: ($over[0].hex // ""),
      nearest: ($planes[0] // null),
      nearby: $planes[0:6],
      summary: (if ($planes | length) == 0 then "No planes within 46 km"
                else "\($planes | length) plane\(if ($planes | length) == 1 then "" else "s" end) within 46 km" end)
    }')

# Routes (origin → destination) from adsbdb.com, cached per callsign for a day.
routes="$store/routes"; mkdir -p "$routes"
for cs in $(echo "$base" | /usr/bin/jq -r '[.plane.callsign?, .nearby[].callsign] | map(select(. != null)) | unique | .[]'); do
  case "$cs" in *[!A-Za-z0-9]*) continue;; esac
  f="$routes/$cs.json"
  if [ ! -s "$f" ] || [ -n "$(find "$f" -mtime +0 2>/dev/null)" ]; then
    ( r=$(curl -s -m 6 "https://api.adsbdb.com/v0/callsign/$cs"); echo "$r" | /usr/bin/jq -e '.response' >/dev/null 2>&1 && echo "$r" > "$f" ) &
  fi
done
wait

map=$(cd "$routes" && for f in *.json; do [ -s "$f" ] && /usr/bin/jq -c --arg k "${f%.json}" '{($k): .}' "$f" 2>/dev/null; done | /usr/bin/jq -cs 'add // {}')

echo "$base" | /usr/bin/jq -c --argjson routes "${map:-{\}}" '
  def rad: . * 3.14159265 / 180;
  def km($a; $b): (($b[0] - $a[0]) | rad) as $dl | (($b[1] - $a[1]) | rad) as $dn
    | (($dl / 2 | sin) * ($dl / 2 | sin) + ($a[0] | rad | cos) * ($b[0] | rad | cos) * ($dn / 2 | sin) * ($dn / 2 | sin))
    | 12742 * (sqrt | asin);
  def city: (.municipality // .name // "") | split("/")[0] | split(",")[0];
  def code: .iata_code // .icao_code;
  def way: ["north","northeast","east","southeast","south","southwest","west","northwest"][((. + 22.5) / 45 | floor) % 8];
  def desc: [.airline, .type, .reg] | map(select(. != null and . != "")) | join(" ");
  def comma: tostring | [scan("\\d")] | reverse | [range(0; length; 3) as $i | .[$i:$i+3] | reverse | join("")] | reverse | join(",");
  def route:
    if . == null then null
    elif ($routes[.callsign].response | type) == "object" and (
      $routes[.callsign].response.flightroute as $f
      | km([$f.origin.latitude, $f.origin.longitude]; [.lat, .lon]) + km([.lat, .lon]; [$f.destination.latitude, $f.destination.longitude])
        <= km([$f.origin.latitude, $f.origin.longitude]; [$f.destination.latitude, $f.destination.longitude]) * 1.25 + 150) then
      $routes[.callsign].response.flightroute as $f
      | km([$f.origin.latitude, $f.origin.longitude]; [.lat, .lon]) as $done
      | km([.lat, .lon]; [$f.destination.latitude, $f.destination.longitude]) as $left
      | . + {
          from: ($f.origin | code), from_city: ($f.origin | city),
          to: ($f.destination | code), to_city: ($f.destination | city),
          airline: ($f.airline.name // ""),
          route: "\($f.origin | code) → \($f.destination | code)",
          progress: (if ($done + $left) > 0 then ($done / ($done + $left) * 100 | round) / 100 else 0 end),
          trip: "\($done | round | comma) km flown · \($left | round | comma) km to go"
        } | . + { desc: desc }
    elif .track != null then
      . + { route: "Flying \(.track | way)", from_city: "From the \((.track + 180) | way)", to_city: "Toward the \(.track | way)",
            progress: 0.5, trip: "Route not published", desc: desc }
    else . + { route: "Route unknown", trip: "Route not published", desc: desc } end;
  .plane |= route | .nearest |= route | .nearby |= map(route)'
