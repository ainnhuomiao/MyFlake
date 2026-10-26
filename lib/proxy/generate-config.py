#!/usr/bin/env python3

import base64
import binascii
import json
import os
import re
import secrets
import subprocess
import sys
from pathlib import Path

import yaml

CONFIG_DIR = Path(os.environ["SINGBOX_CONFIG_DIR"])
SUBSCRIPTIONS_FILE = Path(os.environ["SINGBOX_SUBSCRIPTIONS_FILE"])
CONFIG_FILE = Path(os.environ["SINGBOX_CONFIG_FILE"])
PROVIDER_DIR = Path(os.environ["SINGBOX_PROVIDER_DIR"])
API_SECRET_FILE = Path(os.environ["SINGBOX_CLASH_API_SECRET_FILE"])
CHANGED_FILE = Path(os.environ["SINGBOX_CHANGED_FILE"])
DIRECT_RULES = json.loads(os.environ["SINGBOX_DIRECT_RULES"])
SING_BOX = os.environ["SINGBOX_BIN"]
DASHBOARD_DIR = os.environ["SINGBOX_DASHBOARD_DIR"]
GEOSITE_DIR = Path(os.environ["SINGBOX_GEOSITE_DIR"])
GEOIP_DIR = Path(os.environ["SINGBOX_GEOIP_DIR"])
STATE_DIR = Path(os.environ["SINGBOX_STATE_DIR"])
CHECK_URL = "https://cp.cloudflare.com/generate_204"
AUTO_ALL_TAG = "自动选择/全部"
AI_RULE_SETS = ["geosite-openai", "geosite-anthropic", "geosite-google-gemini"]
EXCLUDE_NODE = re.compile(r"剩余流量|下次重置|套餐到期|套餐.*过期|续费|流量已耗尽|购买后|官网|Telegram|建议每天|如果很少节点|欢迎加入|IPv6", re.I)
PORTAL_DOMAINS = [
    "connectivity-check.ubuntu.com",
    "nmcheck.gnome.org",
    "www.msftconnecttest.com",
    "dns.msftncsi.com",
    "captive.apple.com",
    "connectivitycheck.gstatic.com",
    "clients3.google.com",
    "detectportal.firefox.com",
]


class GenerateError(Exception):
    pass


def load_yaml(path):
    with path.open("r", encoding="utf-8") as file:
        return yaml.safe_load(file)


def atomic_write(path, content, mode=0o600):
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    try:
        temporary.write_text(content, encoding="utf-8")
        temporary.chmod(mode)
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def clash_api_secret():
    try:
        secret = API_SECRET_FILE.read_text(encoding="utf-8").strip()
    except FileNotFoundError:
        secret = ""
    if secret:
        return secret
    secret = secrets.token_hex(32)
    atomic_write(API_SECRET_FILE, secret + "\n", mode=0o640)
    return secret


def prune_providers(active_names):
    for cached in PROVIDER_DIR.glob("*.yaml"):
        if cached.stem not in active_names:
            cached.unlink()


def subscriptions():
    if not SUBSCRIPTIONS_FILE.exists() or SUBSCRIPTIONS_FILE.stat().st_size == 0:
        return {}
    data = load_yaml(SUBSCRIPTIONS_FILE) or {}
    entries = data.get("subscriptions", {})
    if not isinstance(entries, dict):
        raise GenerateError("subscriptions 必须是映射")
    result = {}
    for name, entry in entries.items():
        if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", name):
            raise GenerateError(f"订阅名称无效: {name}")
        url = (entry or {}).get("url", "")
        if not isinstance(url, str) or not url.startswith(("https://", "http://")):
            raise GenerateError(f"订阅 URL 无效: {name}")
        result[name] = url
    return result


def download(name, url):
    temporary = PROVIDER_DIR / f".{name}.{os.getpid()}.download"
    try:
        subprocess.run(
            [
                "curl",
                "--fail",
                "--silent",
                "--show-error",
                "--location",
                "--retry",
                "2",
                "--connect-timeout",
                "10",
                "--max-time",
                "60",
                "--user-agent",
                "mihomo",
                "--output",
                str(temporary),
                url,
            ],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        data = load_yaml(temporary)
        if not isinstance(data, dict) or not isinstance(data.get("proxies"), list):
            raise GenerateError(f"订阅不是 Clash/Mihomo YAML: {name}")
        atomic_write(PROVIDER_DIR / f"{name}.yaml", yaml.safe_dump(data, allow_unicode=True, sort_keys=False))
        return data["proxies"]
    except (OSError, subprocess.CalledProcessError, GenerateError, yaml.YAMLError):
        cached = PROVIDER_DIR / f"{name}.yaml"
        if cached.exists():
            print(f"订阅更新失败，使用缓存: {name}", file=sys.stderr)
            data = load_yaml(cached) or {}
            if isinstance(data.get("proxies"), list):
                return data["proxies"]
        raise GenerateError(f"订阅下载失败且无可用缓存: {name}")
    finally:
        temporary.unlink(missing_ok=True)


def string_list(value):
    if value is None:
        return None
    return [str(item) for item in (value if isinstance(value, list) else [value])]


def ech_config(value):
    text = "\n".join(string_list(value)).strip()
    if text.startswith("-----BEGIN ECH CONFIGS-----"):
        return text.splitlines()
    encoded = "".join(text.split())
    try:
        decoded = base64.b64decode(encoded, validate=True)
    except binascii.Error as error:
        raise ValueError("invalid ECH config") from error
    canonical = base64.b64encode(decoded).decode("ascii")
    return ["-----BEGIN ECH CONFIGS-----", *(canonical[index : index + 64] for index in range(0, len(canonical), 64)), "-----END ECH CONFIGS-----"]


def tls_config(proxy, force=False):
    reality = proxy.get("reality-opts") or {}
    ech = proxy.get("ech-opts") or {}
    enabled = force or bool(proxy.get("tls")) or bool(reality) or bool(ech.get("enable"))
    if not enabled:
        return None
    tls = {"enabled": True}
    server_name = proxy.get("sni") or proxy.get("servername")
    if not server_name:
        headers = (proxy.get("ws-opts") or {}).get("headers") or {}
        server_name = headers.get("Host") or headers.get("host")
    if server_name:
        tls["server_name"] = str(server_name)
    if proxy.get("skip-cert-verify"):
        tls["insecure"] = True
    alpn = string_list(proxy.get("alpn"))
    if alpn:
        tls["alpn"] = alpn
    fingerprint = proxy.get("client-fingerprint") or proxy.get("fingerprint")
    if fingerprint:
        tls["utls"] = {"enabled": True, "fingerprint": str(fingerprint)}
    if ech.get("enable"):
        tls["ech"] = {"enabled": True}
        if ech.get("config"):
            tls["ech"]["config"] = ech_config(ech["config"])
        if ech.get("query-server-name"):
            tls["ech"]["query_server_name"] = str(ech["query-server-name"])
    if reality:
        public_key = reality.get("public-key")
        if not public_key:
            raise ValueError("missing reality public key")
        if "utls" not in tls:
            tls["utls"] = {"enabled": True, "fingerprint": "chrome"}
        tls["reality"] = {"enabled": True, "public_key": str(public_key)}
        if reality.get("short-id") is not None:
            tls["reality"]["short_id"] = str(reality["short-id"])
    return tls


def transport_config(proxy):
    network = proxy.get("network", "tcp")
    if network in (None, "tcp"):
        return None
    if network == "ws":
        options = proxy.get("ws-opts") or {}
        transport = {"type": "ws"}
        if options.get("path"):
            transport["path"] = str(options["path"])
        headers = options.get("headers") or {}
        host = headers.get("Host") or headers.get("host")
        if host:
            transport["headers"] = {"Host": str(host)}
        if options.get("max-early-data") is not None:
            transport["max_early_data"] = int(options["max-early-data"])
        if options.get("early-data-header-name"):
            transport["early_data_header_name"] = str(options["early-data-header-name"])
        return transport
    if network == "grpc":
        options = proxy.get("grpc-opts") or {}
        return {
            "type": "grpc",
            "service_name": str(options.get("grpc-service-name") or options.get("service-name") or ""),
        }
    if network in ("h2", "http"):
        options = proxy.get("h2-opts") or proxy.get("http-opts") or {}
        transport = {"type": "http"}
        hosts = string_list(options.get("host"))
        if hosts:
            transport["host"] = hosts
        paths = options.get("path")
        if isinstance(paths, list):
            paths = paths[0] if paths else None
        if paths:
            transport["path"] = str(paths)
        return transport
    if network == "httpupgrade":
        options = proxy.get("httpupgrade-opts") or {}
        transport = {"type": "httpupgrade"}
        if options.get("path"):
            transport["path"] = str(options["path"])
        if options.get("host"):
            transport["headers"] = {"Host": str(options["host"])}
        return transport
    raise ValueError("unsupported transport")


def base_outbound(proxy, outbound_type):
    server = proxy.get("server")
    port = proxy.get("port")
    if not server or port is None:
        raise ValueError("missing server or port")
    return {
        "type": outbound_type,
        "server": str(server),
        "server_port": int(str(port).split("-")[0]),
        "domain_resolver": "ali",
    }


def hysteria2_server_ports(value):
    result = []
    for item in str(value).split(","):
        match = re.fullmatch(r"(\d+)(?:-(\d+))?", item.strip())
        if not match:
            raise ValueError("invalid hysteria2 ports")
        start = int(match.group(1))
        end = int(match.group(2) or start)
        if not 1 <= start <= end <= 65535:
            raise ValueError("invalid hysteria2 ports")
        result.append(f"{start}:{end}")
    if not result:
        raise ValueError("invalid hysteria2 ports")
    return result


def hysteria2_hop_interval(value):
    match = re.fullmatch(r"(\d+)(?:-(\d+))?", str(value).strip())
    if not match:
        raise ValueError("invalid hysteria2 hop interval")
    start = int(match.group(1))
    end = int(match.group(2) or start)
    if start == 0:
        return {}
    start = max(start, 5)
    end = max(end, start)
    result = {"hop_interval": f"{start}s"}
    if end > start:
        result["hop_interval_max"] = f"{end}s"
    return result


def convert_proxy(proxy):
    if not isinstance(proxy, dict):
        raise ValueError("invalid proxy")
    kind = str(proxy.get("type", "")).lower()
    if kind == "ss":
        result = base_outbound(proxy, "shadowsocks")
        result.update({"method": str(proxy.get("cipher") or proxy.get("method") or ""), "password": str(proxy.get("password") or "")})
        if proxy.get("udp-over-tcp"):
            version = int(proxy.get("udp-over-tcp-version") or 1)
            if version not in (1, 2):
                raise ValueError("unsupported shadowsocks UDP over TCP version")
            result["udp_over_tcp"] = {"enabled": True, "version": version}
        plugin = proxy.get("plugin")
        if plugin:
            options = proxy.get("plugin-opts") or {}
            if plugin == "obfs":
                result["plugin"] = "obfs-local"
                result["plugin_opts"] = f"obfs={options.get('mode', 'http')};obfs-host={options.get('host', 'bing.com')}"
            elif plugin == "v2ray-plugin":
                opts = [f"mode={options.get('mode', 'websocket')}"]
                if options.get("tls"):
                    opts.append("tls")
                if options.get("host"):
                    opts.append(f"host={options['host']}")
                if options.get("path"):
                    opts.append(f"path={options['path']}")
                result["plugin"] = "v2ray-plugin"
                result["plugin_opts"] = ";".join(opts)
            else:
                raise ValueError("unsupported shadowsocks plugin")
        return result
    if kind in ("socks", "socks5"):
        result = base_outbound(proxy, "socks")
        if proxy.get("username") is not None:
            result["username"] = str(proxy["username"])
        if proxy.get("password") is not None:
            result["password"] = str(proxy["password"])
        tls = tls_config(proxy)
        if tls:
            result["tls"] = tls
        return result
    if kind == "http":
        result = base_outbound(proxy, "http")
        if proxy.get("username") is not None:
            result["username"] = str(proxy["username"])
        if proxy.get("password") is not None:
            result["password"] = str(proxy["password"])
        tls = tls_config(proxy)
        if tls:
            result["tls"] = tls
        return result
    if kind in ("vmess", "vless"):
        result = base_outbound(proxy, kind)
        result["uuid"] = str(proxy.get("uuid") or "")
        if kind == "vmess":
            result["security"] = str(proxy.get("cipher") or "auto")
            result["alter_id"] = int(proxy.get("alterId") or proxy.get("alter_id") or 0)
        else:
            if proxy.get("flow"):
                result["flow"] = str(proxy["flow"])
            if proxy.get("packet-encoding"):
                result["packet_encoding"] = str(proxy["packet-encoding"])
        tls = tls_config(proxy)
        if tls:
            result["tls"] = tls
        transport = transport_config(proxy)
        if transport:
            result["transport"] = transport
        return result
    if kind == "trojan":
        result = base_outbound(proxy, "trojan")
        result["password"] = str(proxy.get("password") or "")
        result["tls"] = tls_config(proxy, force=True)
        transport = transport_config(proxy)
        if transport:
            result["transport"] = transport
        return result
    if kind in ("hysteria2", "hy2"):
        result = base_outbound(proxy, "hysteria2")
        result["password"] = str(proxy.get("password") or "")
        result["tls"] = tls_config(proxy, force=True)
        if proxy.get("ports"):
            result["server_ports"] = hysteria2_server_ports(proxy["ports"])
            if proxy.get("hop-interval") is not None:
                result.update(hysteria2_hop_interval(proxy["hop-interval"]))
        if proxy.get("obfs"):
            result["obfs"] = {"type": str(proxy["obfs"]), "password": str(proxy.get("obfs-password") or "")}
        for source, target in (("up", "up_mbps"), ("down", "down_mbps")):
            if proxy.get(source) is not None:
                result[target] = int(str(proxy[source]).split()[0])
        return result
    if kind == "tuic":
        result = base_outbound(proxy, "tuic")
        result["uuid"] = str(proxy.get("uuid") or "")
        result["password"] = str(proxy.get("password") or "")
        result["tls"] = tls_config(proxy, force=True)
        if proxy.get("congestion-controller"):
            result["congestion_control"] = str(proxy["congestion-controller"])
        if proxy.get("udp-relay-mode"):
            result["udp_relay_mode"] = str(proxy["udp-relay-mode"])
        if proxy.get("reduce-rtt"):
            result["zero_rtt_handshake"] = True
        return result
    if kind == "anytls":
        result = base_outbound(proxy, "anytls")
        result["password"] = str(proxy.get("password") or "")
        result["tls"] = tls_config(proxy, force=True)
        return result
    raise ValueError("unsupported proxy type")


def unique_tag(base, used):
    base = base.strip() or "unnamed"
    if base in ("GLOBAL", "proxy", "direct", "dns-out"):
        base = f"node-{base}"
    tag = base
    index = 2
    while tag in used:
        tag = f"{base} #{index}"
        index += 1
    used.add(tag)
    return tag


def build_config(node_outbounds, groups):
    outbounds = []
    group_tags = []
    auto_group_tags = []
    for name, tags in groups:
        if not tags:
            continue
        tag = f"订阅/{name}"
        auto_tag = f"自动选择/{name}"
        outbounds.append(
            {
                "type": "urltest",
                "tag": auto_tag,
                "outbounds": tags,
                "url": CHECK_URL,
                "interval": "30m",
                "tolerance": 100,
                "idle_timeout": "30m",
                "interrupt_exist_connections": False,
            }
        )
        outbounds.append(
            {
                "type": "selector",
                "tag": tag,
                "outbounds": [auto_tag] + tags,
                "default": auto_tag,
                "interrupt_exist_connections": True,
            }
        )
        group_tags.append(tag)
        auto_group_tags.append(auto_tag)

    node_tags = [item["tag"] for item in node_outbounds]
    if auto_group_tags:
        outbounds.append(
            {
                "type": "urltest",
                "tag": AUTO_ALL_TAG,
                "outbounds": auto_group_tags,
                "url": CHECK_URL,
                "interval": "30m",
                "tolerance": 100,
                "idle_timeout": "30m",
                "interrupt_exist_connections": False,
            }
        )
        outbounds.append(
            {
                "type": "selector",
                "tag": "AI",
                "outbounds": node_tags,
                "default": node_tags[0],
                "interrupt_exist_connections": True,
            }
        )

    proxy_choices = ([AUTO_ALL_TAG] if auto_group_tags else []) + group_tags + ["direct"] + node_tags
    outbounds.append(
        {
            "type": "selector",
            "tag": "proxy",
            "outbounds": proxy_choices,
            "default": AUTO_ALL_TAG if auto_group_tags else "direct",
            "interrupt_exist_connections": True,
        }
    )
    global_choices = ["proxy"] + ([AUTO_ALL_TAG, "AI"] if auto_group_tags else []) + group_tags + ["direct"] + node_tags
    outbounds.append(
        {
            "type": "selector",
            "tag": "GLOBAL",
            "outbounds": global_choices,
            "default": "proxy",
            "interrupt_exist_connections": True,
        }
    )
    outbounds.append({"type": "direct", "tag": "direct"})
    outbounds.extend(node_outbounds)

    direct_domains = DIRECT_RULES["domains"]
    direct_ip_cidrs = DIRECT_RULES["ipCidrs"]
    dns_rules = [
        {"domain_suffix": [".lan", ".local", ".home.arpa"], "server": "dhcp"},
        {"domain": PORTAL_DOMAINS, "server": "dhcp"},
    ]
    if direct_domains:
        dns_rules.append({"domain": direct_domains, "server": "ali"})
    if auto_group_tags:
        dns_rules.append({"rule_set": AI_RULE_SETS, "server": "google"})
    dns_rules.append({"rule_set": ["geosite-cn"], "server": "ali"})

    route_rules = [
        {"action": "sniff"},
        {"protocol": "dns", "action": "hijack-dns"},
        {"process_name": ["NetworkManager"], "action": "route", "outbound": "direct"},
        {"ip_is_private": True, "action": "route", "outbound": "direct"},
        {"ip_cidr": ["224.0.0.0/3", "ff00::/8"], "action": "route", "outbound": "direct"},
        {"domain": PORTAL_DOMAINS, "action": "route", "outbound": "direct"},
    ]
    if direct_domains:
        route_rules.append({"domain": direct_domains, "action": "route", "outbound": "direct"})
    if direct_ip_cidrs:
        route_rules.append({"ip_cidr": direct_ip_cidrs, "action": "route", "outbound": "direct"})
    route_rules.extend(
        [
            {"domain": ["cm.bilibili.com", "data.bilibili.com", "dataflow.bilibili.com"], "action": "reject"},
            {"domain_suffix": [".mcdn.bilivideo.cn"], "action": "reject"},
            {"rule_set": ["geosite-category-ads-all"], "action": "reject"},
        ]
    )
    if auto_group_tags:
        route_rules.append({"rule_set": AI_RULE_SETS, "action": "route", "outbound": "AI"})
    route_rules.append({"rule_set": ["geosite-cn", "geoip-cn"], "action": "route", "outbound": "direct"})

    rule_sets = [
        {"type": "local", "tag": "geosite-cn", "format": "binary", "path": str(GEOSITE_DIR / "geosite-cn.srs")},
        {"type": "local", "tag": "geosite-category-ads-all", "format": "binary", "path": str(GEOSITE_DIR / "geosite-category-ads-all.srs")},
        {"type": "local", "tag": "geoip-cn", "format": "binary", "path": str(GEOIP_DIR / "geoip-cn.srs")},
    ]
    if auto_group_tags:
        rule_sets.extend(
            {"type": "local", "tag": tag, "format": "binary", "path": str(GEOSITE_DIR / f"{tag}.srs")}
            for tag in AI_RULE_SETS
        )

    return {
        "log": {"level": "warn", "timestamp": True},
        "dns": {
            "servers": [
                {
                    "type": "https",
                    "tag": "ali",
                    "server": "223.5.5.5",
                    "path": "/dns-query",
                    "tls": {"enabled": True, "server_name": "dns.alidns.com"},
                },
                {
                    "type": "https",
                    "tag": "google",
                    "server": "8.8.8.8",
                    "path": "/dns-query",
                    "tls": {"enabled": True, "server_name": "dns.google"},
                    "detour": AUTO_ALL_TAG if auto_group_tags else "direct",
                },
                {"type": "dhcp", "tag": "dhcp"},
            ],
            "rules": dns_rules,
            "final": "google",
            "strategy": "prefer_ipv4",
        },
        "inbounds": [
            {
                "type": "tun",
                "tag": "tun-in",
                "interface_name": "singbox0",
                "address": ["198.18.0.1/30", "fdfe:dcba:9876::1/126"],
                "mtu": 9000,
                "auto_route": True,
                "auto_redirect": True,
                "strict_route": True,
                "route_exclude_address": ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "fc00::/7"],
                "dns_mode": "hijack",
            },
            {"type": "mixed", "tag": "mixed-in", "listen": "127.0.0.1", "listen_port": 7890},
        ],
        "outbounds": outbounds,
        "route": {
            "rules": route_rules,
            "rule_set": rule_sets,
            "final": "proxy",
            "auto_detect_interface": True,
            "default_domain_resolver": "ali",
        },
        "experimental": {
            "cache_file": {"enabled": True, "path": str(STATE_DIR / "cache.db"), "store_fakeip": False},
            "clash_api": {
                "external_controller": "127.0.0.1:9090",
                "external_ui": DASHBOARD_DIR,
                "secret": clash_api_secret(),
                "default_mode": "rule",
                "access_control_allow_private_network": False,
            },
        },
    }


def main():
    os.umask(0o077)
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    PROVIDER_DIR.mkdir(parents=True, exist_ok=True)
    current_subscriptions = subscriptions()
    prune_providers(current_subscriptions)
    used_tags = set()
    node_outbounds = []
    groups = []
    skipped = 0
    for name, url in current_subscriptions.items():
        tags = []
        for proxy in download(name, url):
            if not isinstance(proxy, dict) or EXCLUDE_NODE.search(str(proxy.get("name", ""))):
                continue
            try:
                converted = convert_proxy(proxy)
            except (ValueError, TypeError):
                skipped += 1
                continue
            converted["tag"] = unique_tag(f"[{name}] {proxy.get('name', 'unnamed')}", used_tags)
            node_outbounds.append(converted)
            tags.append(converted["tag"])
        groups.append((name, tags))
    if skipped:
        print(f"已跳过 {skipped} 个不支持或字段不完整的节点", file=sys.stderr)
    config = build_config(node_outbounds, groups)
    temporary = CONFIG_FILE.with_name(f".{CONFIG_FILE.name}.{os.getpid()}.tmp")
    try:
        temporary.write_text(json.dumps(config, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        temporary.chmod(0o640)
        result = subprocess.run(
            [SING_BOX, "check", "-c", str(temporary)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            text=True,
        )
        if result.returncode != 0:
            atomic_write(CONFIG_DIR / "check.log", result.stderr)
            raise GenerateError("配置校验失败，已保留旧配置；详情见 check.log")
        try:
            unchanged = json.loads(CONFIG_FILE.read_text(encoding="utf-8")) == config
        except (FileNotFoundError, json.JSONDecodeError):
            unchanged = False
        if not unchanged:
            CHANGED_FILE.touch(mode=0o600)
            os.replace(temporary, CONFIG_FILE)
        (CONFIG_DIR / "check.log").unlink(missing_ok=True)
    finally:
        temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    try:
        main()
    except (GenerateError, OSError, yaml.YAMLError) as error:
        print(f"sing-box 配置生成失败: {error}", file=sys.stderr)
        sys.exit(1)
