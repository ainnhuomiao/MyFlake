umask 007

if [[ ! -s ${subscriptionsFile} ]]; then
  echo "Mihomo subscriptions file is missing: ${subscriptionsFile}" >&2
  exit 1
fi

yq eval '.subscriptions = (.subscriptions // {})' "${subscriptionsFile}" >/dev/null

tmp_file="$(mktemp "${configDirectory}/.config.yaml.XXXXXX")"
trap 'rm -f "$tmp_file"' EXIT

cat >"$tmp_file" <<'YAML'
allow-lan: false
bind-address: 127.0.0.1
mode: rule
log-level: warning
ipv6: false
external-controller: 127.0.0.1:9090
secret: ""
profile:
  store-selected: true
listeners:
  - name: dae-proxy
    type: socks
    listen: 127.0.0.1
    port: 12346
    udp: true
    proxy: DAE-PROXY
  - name: dae-mining
    type: socks
    listen: 127.0.0.1
    port: 12347
    udp: true
    proxy: DAE-MINING
proxy-providers: {}
proxy-groups:
  - name: DAE-PROXY
    type: select
    proxies:
      - DIRECT
  - name: DAE-MINING
    type: select
    proxies:
      - DIRECT
rules:
  - MATCH,DIRECT
YAML

while IFS= read -r name; do
  [[ -n $name ]] || continue
  if [[ ! $name =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
    echo "Invalid subscription name: $name" >&2
    exit 1
  fi

  url="$(SUBSCRIPTION_NAME="$name" yq eval -r '.subscriptions[strenv(SUBSCRIPTION_NAME)].url // ""' "${subscriptionsFile}")"
  if [[ -z $url ]]; then
    echo "Subscription URL is empty: $name" >&2
    exit 1
  fi

  provider_name="subscription-$name"
  provider_group="订阅/$name"
  provider_path="${providerDirectory}/$name.yaml"
  provider_prefix="[$name] "

  PROVIDER_NAME="$provider_name" \
    PROVIDER_URL="$url" \
    PROVIDER_GROUP="$provider_group" \
    PROVIDER_PATH="$provider_path" \
    PROVIDER_PREFIX="$provider_prefix" \
    yq eval -i '
            .["proxy-providers"][strenv(PROVIDER_NAME)] = {
              "type": "http",
              "url": strenv(PROVIDER_URL),
              "path": strenv(PROVIDER_PATH),
              "interval": 21600,
              "header": {"User-Agent": ["mihomo"]},
              "exclude-filter": "(?i)剩余流量|下次重置|套餐到期|官网|Telegram|建议每天|如果很少节点|欢迎加入|IPv6",
              "health-check": {
                "enable": true,
                "url": "https://cp.cloudflare.com/generate_204",
                "interval": 1800,
                "timeout": 5000,
                "lazy": true
              },
              "override": {"additional-prefix": strenv(PROVIDER_PREFIX)}
            } |
            .["proxy-groups"] += [{
              "name": strenv(PROVIDER_GROUP),
              "type": "url-test",
              "use": [strenv(PROVIDER_NAME)],
              "url": "https://cp.cloudflare.com/generate_204",
              "interval": 1800,
              "tolerance": 100,
              "lazy": true
            }] |
            .["proxy-groups"][0].proxies += [strenv(PROVIDER_GROUP)] |
            .["proxy-groups"][1].proxies += [strenv(PROVIDER_GROUP)]
          ' "$tmp_file"
done < <(yq eval -r '.subscriptions | keys | .[]' "${subscriptionsFile}")

first_provider_group="$(yq eval -r '.["proxy-groups"] | map(select(.type == "url-test")) | .[0].name // ""' "$tmp_file")"
if [[ -n $first_provider_group ]]; then
  PROVIDER_GROUP="$first_provider_group" yq eval -i '
          .["proxy-groups"][0].proxies = [strenv(PROVIDER_GROUP), "DIRECT"] +
            (.["proxy-groups"][0].proxies | map(select(. != strenv(PROVIDER_GROUP) and . != "DIRECT"))) |
          .["proxy-groups"][1].proxies = [strenv(PROVIDER_GROUP), "DIRECT"] +
            (.["proxy-groups"][1].proxies | map(select(. != strenv(PROVIDER_GROUP) and . != "DIRECT")))
        ' "$tmp_file"
fi

yq eval '.' "$tmp_file" >/dev/null
mihomo -t -d "${configDirectory}" -f "$tmp_file"
chmod 0640 "$tmp_file"
mv -f "$tmp_file" "${configFile}"
trap - EXIT
