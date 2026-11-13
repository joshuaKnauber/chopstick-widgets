# Save the spot to watch: CHOPSTICK_NEW_LAT / CHOPSTICK_NEW_LON (empty = guess from IP),
# CHOPSTICK_NEW_RADIUS in km (empty = keep).
store="$CHOPSTICK_STORAGE"; mkdir -p "$store"; loc="$store/location.json"
[ -s "$loc" ] || echo '{"radius_km":4}' > "$loc"
if [ -n "$CHOPSTICK_NEW_LAT" ] && [ -n "$CHOPSTICK_NEW_LON" ]; then
  /usr/bin/jq -c --argjson a "$CHOPSTICK_NEW_LAT" --argjson o "$CHOPSTICK_NEW_LON" '.lat=$a | .lon=$o | .place="Custom spot"' "$loc" > "$loc.tmp" || { echo "Latitude/longitude must be numbers" >&2; exit 1; }
  mv "$loc.tmp" "$loc"
elif [ "$CHOPSTICK_NEW_LAT" = "" ] && [ -z "$CHOPSTICK_NEW_RADIUS" ]; then
  geo=$(curl -s -m 8 "http://ip-api.com/json/?fields=lat,lon,city")
  echo "$geo" | /usr/bin/jq -e '.lat' >/dev/null 2>&1 || { echo "Couldn't find your location" >&2; exit 1; }
  /usr/bin/jq -c --argjson g "$geo" '.lat=$g.lat | .lon=$g.lon | .place=($g.city // "Here")' "$loc" > "$loc.tmp" && mv "$loc.tmp" "$loc"
fi
if [ -n "$CHOPSTICK_NEW_RADIUS" ]; then
  /usr/bin/jq -c --argjson r "$CHOPSTICK_NEW_RADIUS" '.radius_km=$r' "$loc" > "$loc.tmp" || { echo "Radius must be a number" >&2; exit 1; }
  mv "$loc.tmp" "$loc"
fi
exit 0
