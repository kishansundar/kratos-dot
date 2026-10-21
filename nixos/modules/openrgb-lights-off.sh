# Wait for the OpenRGB server to finish detecting devices, then turn every one off except the keyboard, which gets
# dim white. Run by openrgb-lights-off.service (accessories.nix) at boot.
cfg=${RUNTIME_DIRECTORY:-$(mktemp -d)}
rgb() { openrgb --config "$cfg" --nodetect "$@"; }

# The server writes "Detection completed" to the log it opened at start; logs are named by start time.
start=$(date -d "$(systemctl show -p ExecMainStartTimestamp --value openrgb.service)" +%Y%m%d_%H%M%S)
for _ in $(seq 120); do
  log=$(find /var/lib/OpenRGB/logs -name 'OpenRGB_*.log' 2>/dev/null | sort | tail -n 1)
  stamp=$(basename "${log:-x}" .log); stamp=${stamp#OpenRGB_}
  if [[ -n $log && ! $stamp < $start ]] && grep -q 'Detection completed' "$log"; then break; fi
  sleep 1
done

# One line per device: index, type, modes. The keyboard (the Razer) white at 5 % (0D of FF), as OpenRazer had it;
# every other device "Off" where it has that mode, black otherwise.
args=()
while IFS=$'\t' read -r idx type modes; do
  if [[ $type == Keyboard ]]; then args+=(-d "$idx" -m Direct -c 0D0D0D); continue; fi
  modes=${modes//[][]/}                    # "[Off]" marks the current mode
  if [[ " $modes " == *" Off "* ]]; then
    args+=(-d "$idx" -m Off)
  else
    args+=(-d "$idx" -m Direct -c 000000)
  fi
done < <(rgb --list-detailed | awk '
  /^[0-9]+: / { idx = $1; sub(/:/, "", idx) }
  /^  Type:/  { type = $0; sub(/^  Type: +/, "", type) }
  /^  Modes:/ { modes = $0; sub(/^  Modes: +/, "", modes); print idx "\t" type "\t" modes }')

if (( ${#args[@]} == 0 )); then echo "OpenRGB lists no devices" >&2; exit 1; fi
echo "openrgb ${args[*]}"
rgb "${args[@]}"
