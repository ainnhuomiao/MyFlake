# Shared service ordering and GUI-client exclusion for dae + Mihomo.
PROXY_UNITS=(dae.service mihomo.service)
PROXY_FLAG="${XDG_RUNTIME_DIR:-/tmp}/v2rayN-managed-services"

proxy_unit_state() {
  local state
  state="$(systemctl is-active "$1" 2>/dev/null)" || true
  printf '%s' "${state:-inactive}"
}

proxy_status() {
  local unit
  for unit in "${PROXY_UNITS[@]}"; do
    printf '%-14s %s\n' "$unit" "$(proxy_unit_state "$unit")"
  done
}

proxy_start() {
  if [[ -f $PROXY_FLAG ]]; then
    echo 'v2rayN 正在接管代理，请先退出 v2rayN' >&2
    return 1
  fi
  systemctl start mihomo.service || return 1
  systemctl start dae.service
}

proxy_stop() {
  systemctl stop dae.service 2>/dev/null || true
  systemctl stop mihomo.service 2>/dev/null || true
}

proxy_suspend() {
  HAD_DAE=0
  HAD_MIHOMO=0
  if systemctl is-active --quiet dae.service 2>/dev/null; then HAD_DAE=1; fi
  if systemctl is-active --quiet mihomo.service 2>/dev/null; then HAD_MIHOMO=1; fi
  touch "$PROXY_FLAG"
  proxy_stop
}

proxy_restore() {
  [[ -f $PROXY_FLAG ]] || return 0
  rm -f "$PROXY_FLAG"
  if [[ ${HAD_MIHOMO:-0} == 1 ]]; then systemctl start mihomo.service || true; fi
  if [[ ${HAD_DAE:-0} == 1 ]]; then systemctl start dae.service || true; fi
}

proxy_watchdog() {
  while [[ -f $PROXY_FLAG && -d "/proc/$PPID" ]]; do
    if systemctl is-active --quiet dae.service 2>/dev/null ||
      systemctl is-active --quiet mihomo.service 2>/dev/null; then
      [[ -f $PROXY_FLAG ]] && proxy_stop
    fi
    sleep 5
  done
}
