#!/usr/bin/env bash
# waybar custom/battery — text is icon + capacity, tooltip has the electrical detail.
# Framework 13 (BAT1) exposes charge_*/current_now (µAh/µA); some batteries expose
# energy_*/power_now (µWh/µW) instead, so handle both.

BAT=${BAT_OVERRIDE:-$(echo /sys/class/power_supply/BAT*)}
[ -d "$BAT" ] || { jq -cn '{"text":"󰂑","tooltip":"No battery found"}'; exit 0; }

r() { cat "$BAT/$1" 2>/dev/null; }

status=$(r status)
cap=$(r capacity)
volt=$(r voltage_now)             # µV
cyc=$(r cycle_count)
tech=$(r technology)
model=$(r model_name)

charge_now=$(r charge_now)        # µAh
charge_full=$(r charge_full)
charge_design=$(r charge_full_design)
curr=$(r current_now)             # µA
energy_now=$(r energy_now)        # µWh
energy_full=$(r energy_full)
energy_design=$(r energy_full_design)
power_now=$(r power_now)          # µW

# Normalise to: amps A, volts V, watts W, charge Ah, energy Wh, and the same for full/design.
read -r A V W AH WH AH_FULL WH_FULL AH_DES WH_DES <<EOF
$(awk -v v="${volt:-0}" -v c="${curr:-}" -v p="${power_now:-}" \
      -v cn="${charge_now:-}" -v cf="${charge_full:-}" -v cd="${charge_design:-}" \
      -v en="${energy_now:-}" -v ef="${energy_full:-}" -v ed="${energy_design:-}" '
BEGIN {
  V = v/1e6
  if (c != "") { A = c/1e6; W = (c*v)/1e12 }
  else if (p != "" && V > 0) { W = p/1e6; A = W/V }
  else { A = 0; W = 0 }

  if (cn != "") { AH = cn/1e6; WH = (cn*v)/1e12 }
  else if (en != "") { WH = en/1e6; AH = (V>0) ? WH/V : 0 }
  if (cf != "") { AF = cf/1e6; WF = (cf*v)/1e12 }
  else if (ef != "") { WF = ef/1e6; AF = (V>0) ? WF/V : 0 }
  if (cd != "") { AD = cd/1e6; WD = (cd*v)/1e12 }
  else if (ed != "") { WD = ed/1e6; AD = (V>0) ? WD/V : 0 }

  printf "%.3f %.3f %.2f %.3f %.2f %.3f %.2f %.3f %.2f", A, V, W, AH, WH, AF, WF, AD, WD
}')
EOF

# Remaining time from the same numbers waybar would use.
eta=""
if [ "$(awk -v a="$A" 'BEGIN{print (a>0.02)?1:0}')" = 1 ]; then
  case "$status" in
    Discharging) hrs=$(awk -v n="$AH" -v a="$A" 'BEGIN{print n/a}'); label="until empty" ;;
    Charging)    hrs=$(awk -v f="$AH_FULL" -v n="$AH" -v a="$A" 'BEGIN{print (f-n)/a}'); label="until full" ;;
    *) hrs="" ;;
  esac
  [ -n "$hrs" ] && eta=$(awk -v h="$hrs" -v l="$label" \
    'BEGIN{m=int(h*60+0.5); printf "%dh %02dm %s", int(m/60), m%60, l}')
fi

health=$(awk -v f="$AH_FULL" -v d="$AH_DES" 'BEGIN{ if (d>0) printf "%.1f", 100*f/d; else printf "?" }')

# Icons are written as \u escapes so the glyph bytes survive any editor or
# heredoc round-trip. U+F240..F244 are the Font Awesome battery ramp
# (full -> empty).
if   [ "${cap:-0}" -ge 90 ]; then icon=$''
elif [ "${cap:-0}" -ge 70 ]; then icon=$''
elif [ "${cap:-0}" -ge 45 ]; then icon=$''
elif [ "${cap:-0}" -ge 20 ]; then icon=$''
else                              icon=$''
fi

case "$status" in
  Charging)     flow="charging at" ;;
  Discharging)  flow="drawing" ;;
  *)            flow="idle" ;;
esac

class="normal"
[ "$status" = "Charging" ] && class="charging"
if [ "$status" != "Charging" ]; then
  [ "${cap:-100}" -le 30 ] && class="warning"
  [ "${cap:-100}" -le 15 ] && class="critical"
fi

ac=$(cat /sys/class/power_supply/A*/online 2>/dev/null | head -1)
[ "$ac" = "1" ] && plug="plugged in" || plug="on battery"

tip=$(printf '%s\n' \
  "$(printf '%-11s %s%%  (%s)' 'Charge' "$cap" "$plug")" \
  "$(printf '%-11s %s W  (%s)' 'Power' "$W" "${flow:-idle}")" \
  "$(printf '%-11s %s A' 'Current' "$A")" \
  "$(printf '%-11s %s V' 'Voltage' "$V")" \
  "$(printf '%-11s %s Wh of %s Wh   (%s Ah)' 'Energy' "$WH" "$WH_FULL" "$AH")" \
  ${eta:+"$(printf '%-11s %s' 'Remaining' "$eta")"} \
  "" \
  "$(printf '%-11s %s%% of design   (%s / %s Wh)' 'Health' "$health" "$WH_FULL" "$WH_DES")" \
  "$(printf '%-11s %s' 'Cycles' "${cyc:-?}")" \
  "$(printf '%-11s %s %s' 'Cell' "${tech:-?}" "${model:-?}")")

jq -cn --arg t "$icon $cap%" --arg tt "$tip" --arg c "$class" --argjson p "${cap:-0}" \
  '{"text":$t,"tooltip":$tt,"class":$c,"percentage":$p}'
