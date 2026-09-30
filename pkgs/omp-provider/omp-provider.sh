#!/usr/bin/env bash

set -Eeuo pipefail

APP_NAME="OMP 中转站配置中心"
OMP_DIR="${PI_CODING_AGENT_DIR:-${HOME}/.omp/agent}"
MODELS_FILE="${OMP_DIR}/models.yml"
SECRETS_FILE="${OMP_DIR}/.env"
CONFIG_FILE="${OMP_DIR}/config.yml"
BACKUP_DIR="${OMP_DIR}/backups/providers"
EXPORT_DIR="${OMP_DIR}/exports"

export GUM_CHOOSE_CURSOR_FOREGROUND="212"
export GUM_CHOOSE_SELECTED_FOREGROUND="212"
export GUM_CONFIRM_SELECTED_BACKGROUND="212"
export GUM_INPUT_CURSOR_FOREGROUND="212"
export GUM_SPIN_SPINNER_FOREGROUND="212"

die() {
  gum style --foreground 196 "错误：$*" >&2
  exit 1
}

note() {
  gum style --foreground 245 "$*"
}

success() {
  gum style --foreground 42 "✓ $*"
}

warning() {
  gum style --foreground 214 "! $*"
}

pause() {
  gum input --placeholder "按 Enter 返回主菜单" >/dev/null || true
}

header() {
  clear
  gum style \
    --border rounded \
    --border-foreground 212 \
    --foreground 255 \
    --padding "0 2" \
    --margin "1 0" \
    "$APP_NAME" "管理 New API、Sub2API、One API 等 OpenAI/Anthropic 兼容站点"
}

ensure_layout() {
  mkdir -p "$OMP_DIR" "$BACKUP_DIR" "$EXPORT_DIR"
  if [[ ! -e $MODELS_FILE ]]; then
    printf 'providers: {}\n' >"$MODELS_FILE"
  fi
  if [[ ! -e $SECRETS_FILE ]]; then
    : >"$SECRETS_FILE"
  fi
  if [[ ! -e $CONFIG_FILE ]]; then
    printf '{}\n' >"$CONFIG_FILE"
  fi
  chmod 600 "$MODELS_FILE" "$SECRETS_FILE" "$CONFIG_FILE"
}

validate_yaml() {
  yq eval '.' "$MODELS_FILE" >/dev/null 2>&1 ||
    die "$MODELS_FILE 不是有效的 YAML，请先修复或从备份恢复。"
  yq eval '.' "$CONFIG_FILE" >/dev/null 2>&1 ||
    die "$CONFIG_FILE 不是有效的 YAML，请先修复或从备份恢复。"
}

backup_config() {
  local stamp backup
  stamp="$(date +%Y%m%d-%H%M%S)-$$"
  backup="${BACKUP_DIR}/${stamp}"
  mkdir -p "$backup"
  cp -a "$MODELS_FILE" "$backup/models.yml"
  cp -a "$SECRETS_FILE" "$backup/.env"
  cp -a "$CONFIG_FILE" "$backup/config.yml"
  printf '%s\n' "$backup"
}

provider_value() {
  local id="$1" expression="$2"
  PROVIDER_ID="$id" yq eval -r ".providers[strenv(PROVIDER_ID)]${expression}" "$MODELS_FILE"
}

provider_exists() {
  local id="$1"
  PROVIDER_ID="$id" yq eval -e '.providers[strenv(PROVIDER_ID)] != null' "$MODELS_FILE" >/dev/null 2>&1
}

provider_disabled() {
  local id="$1"
  PROVIDER_ID="$id" yq eval -e \
    '((.disabledProviders // []) | map(select(. == strenv(PROVIDER_ID))) | length) > 0' \
    "$CONFIG_FILE" >/dev/null 2>&1
}

set_provider_disabled() {
  local id="$1" disabled="$2"
  PROVIDER_ID="$id" yq eval -i \
    '.disabledProviders = (.disabledProviders // [] | map(select(. != strenv(PROVIDER_ID))))' "$CONFIG_FILE"
  if [[ $disabled == true ]]; then
    PROVIDER_ID="$id" yq eval -i '.disabledProviders += [strenv(PROVIDER_ID)]' "$CONFIG_FILE"
  fi
}

write_provider_core() {
  local id="$1" base_url="$2" api="$3" discovery="$4" auth_mode="$5" env_name="$6" strict="$7"
  local temp
  temp="$(mktemp "${OMP_DIR}/models-provider.XXXXXX")"
  cp "$MODELS_FILE" "$temp"

  PROVIDER_ID="$id" BASE_URL="$base_url" DISABLE_STRICT="$strict" yq eval -i '
    .providers[strenv(PROVIDER_ID)] = (.providers[strenv(PROVIDER_ID)] // {}) |
    .providers[strenv(PROVIDER_ID)].baseUrl = strenv(BASE_URL) |
    .providers[strenv(PROVIDER_ID)].disableStrictTools = (strenv(DISABLE_STRICT) == "true")
  ' "$temp" || {
    rm -f "$temp"
    return 1
  }

  if [[ -n $discovery ]]; then
    PROVIDER_ID="$id" DISCOVERY="$discovery" yq eval -i \
      '.providers[strenv(PROVIDER_ID)].discovery.type = strenv(DISCOVERY)' "$temp" || {
      rm -f "$temp"
      return 1
    }
  else
    PROVIDER_ID="$id" yq eval -i 'del(.providers[strenv(PROVIDER_ID)].discovery)' "$temp" || {
      rm -f "$temp"
      return 1
    }
  fi

  if [[ $auth_mode == none ]]; then
    PROVIDER_ID="$id" yq eval -i '
      .providers[strenv(PROVIDER_ID)].auth = "none" |
      del(.providers[strenv(PROVIDER_ID)].apiKey, .providers[strenv(PROVIDER_ID)].authHeader)
    ' "$temp" || {
      rm -f "$temp"
      return 1
    }
  else
    PROVIDER_ID="$id" ENV_NAME="$env_name" AUTH_HEADER="$([[ $auth_mode == bearer ]] && printf true || printf false)" \
      yq eval -i '
        .providers[strenv(PROVIDER_ID)].auth = "apiKey" |
        .providers[strenv(PROVIDER_ID)].apiKey = strenv(ENV_NAME) |
        .providers[strenv(PROVIDER_ID)].authHeader = (strenv(AUTH_HEADER) == "true")
      ' "$temp" || {
      rm -f "$temp"
      return 1
    }
  fi

  if [[ -n $api ]]; then
    PROVIDER_ID="$id" API_TYPE="$api" yq eval -i \
      '.providers[strenv(PROVIDER_ID)].api = strenv(API_TYPE)' "$temp" || {
      rm -f "$temp"
      return 1
    }
  else
    PROVIDER_ID="$id" yq eval -i 'del(.providers[strenv(PROVIDER_ID)].api)' "$temp" || {
      rm -f "$temp"
      return 1
    }
  fi

  yq eval '.' "$temp" >/dev/null || {
    rm -f "$temp"
    return 1
  }
  chmod 600 "$temp"
  mv "$temp" "$MODELS_FILE"
}

model_count() {
  local id="$1"
  PROVIDER_ID="$id" yq eval '.providers[strenv(PROVIDER_ID)].models // [] | length' "$MODELS_FILE"
}

manual_model_ids() {
  local id="$1"
  PROVIDER_ID="$id" yq eval -r '.providers[strenv(PROVIDER_ID)].models // [] | .[].id' "$MODELS_FILE"
}

choose_manual_model() {
  local id="$1" prompt="${2:-选择手动模型}" models selected
  mapfile -t models < <(manual_model_ids "$id")
  ((${#models[@]} > 0)) || return 1
  selected="$(printf '%s\n' "${models[@]}" | gum filter --placeholder "$prompt" --height 15)" || return 1
  [[ -n $selected ]] || return 1
  printf '%s\n' "$selected"
}

provider_ids() {
  yq eval -r '.providers // {} | keys | .[]' "$MODELS_FILE" 2>/dev/null || true
}

choose_provider() {
  local prompt="${1:-选择中转站}" providers selected
  mapfile -t providers < <(provider_ids)
  ((${#providers[@]} > 0)) || return 1
  selected="$(printf '%s\n' "${providers[@]}" | gum choose --header "$prompt")" || return 1
  printf '%s\n' "$selected"
}

env_name_for_provider() {
  local id="$1" normalized
  normalized="$(printf '%s' "$id" | tr '[:lower:]-.' '[:upper:]__' | tr -cd 'A-Z0-9_')"
  [[ $normalized == [A-Z_]* ]] || normalized="OMP_${normalized}"
  printf '%s_API_KEY\n' "$normalized"
}

read_secret() {
  local name="$1" line
  while IFS= read -r line || [[ -n $line ]]; do
    [[ $line == "${name}="* ]] || continue
    printf '%s' "${line#*=}"
    return 0
  done <"$SECRETS_FILE"
  return 1
}

write_secret() {
  local name="$1" value="$2" temp line found=0
  [[ $name =~ ^[A-Z_][A-Z0-9_]*$ ]] || die "环境变量名不合法：$name"
  [[ $value != *$'\n'* && $value != *$'\r'* ]] || die "API Key 不能包含换行。"
  temp="$(mktemp "${OMP_DIR}/.env.XXXXXX")"
  chmod 600 "$temp"
  while IFS= read -r line || [[ -n $line ]]; do
    if [[ $line == "${name}="* ]]; then
      printf '%s=%s\n' "$name" "$value" >>"$temp"
      found=1
    else
      printf '%s\n' "$line" >>"$temp"
    fi
  done <"$SECRETS_FILE"
  ((found)) || printf '%s=%s\n' "$name" "$value" >>"$temp"
  mv "$temp" "$SECRETS_FILE"
  chmod 600 "$SECRETS_FILE"
}

delete_secret() {
  local name="$1" temp line
  temp="$(mktemp "${OMP_DIR}/.env.XXXXXX")"
  chmod 600 "$temp"
  while IFS= read -r line || [[ -n $line ]]; do
    [[ $line == "${name}="* ]] && continue
    printf '%s\n' "$line" >>"$temp"
  done <"$SECRETS_FILE"
  mv "$temp" "$SECRETS_FILE"
  chmod 600 "$SECRETS_FILE"
}

normalize_base_url() {
  local url="$1"
  url="${url%/}"
  [[ $url =~ ^https?://[^[:space:]]+$ ]] || return 1
  if [[ $url != */v1 ]]; then
    if gum confirm "Base URL 没有以 /v1 结尾，自动补上吗？"; then
      url="${url}/v1"
    fi
  fi
  printf '%s\n' "$url"
}

fetch_models() {
  local base_url="$1" secret="$2" auth_mode="$3" body_file="$4" status header_file
  local -a args=(--silent --show-error --location --connect-timeout 10 --max-time 30 --output "$body_file" --write-out '%{http_code}')

  [[ $secret != *$'\n'* && $secret != *$'\r'* ]] || return 2
  header_file="$(mktemp "${OMP_DIR}/headers.XXXXXX")"
  chmod 600 "$header_file"
  case "$auth_mode" in
  bearer) printf 'Authorization: Bearer %s\n' "$secret" >"$header_file" ;;
  x-api-key)
    printf 'x-api-key: %s\nanthropic-version: 2023-06-01\n' "$secret" >"$header_file"
    ;;
  none) ;;
  *)
    rm -f "$header_file"
    return 2
    ;;
  esac

  status="$(curl --header "@${header_file}" "${args[@]}" "${base_url}/models")" || {
    rm -f "$header_file"
    return 1
  }
  rm -f "$header_file"
  [[ $status =~ ^2[0-9][0-9]$ ]] || {
    printf '%s' "$status"
    return 22
  }
}

show_model_summary() {
  local file="$1" count
  if ! jq -e '(.data // .models) | type == "array"' "$file" >/dev/null 2>&1; then
    warning "响应成功，但未识别出标准模型列表。仍可保存配置并由 OMP 尝试发现。"
    jq -C 'if type == "array" then .[:20] else . end' "$file" 2>/dev/null || sed -n '1,20p' "$file"
    return 0
  fi
  count="$(jq '(.data // .models) | length' "$file")"
  success "发现 ${count} 个模型"
  if ((count > 0)); then
    jq -r '(.data // .models)[:12][] | [(.id // .name // "unknown"), ((.supported_endpoint_types // []) | join(","))] | @tsv' "$file" |
      gum table --columns "模型 ID,协议标记" --separator $'\t' --print
  fi
  if ((count > 12)); then
    note "这里只显示前 12 个，保存后可用 omp models 查看全部。"
  fi
  return 0
}

upsert_provider() {
  header
  gum style --bold --foreground 212 "新增或更新中转站"

  local id base_url env_name current_env_name secret auth_label auth_mode credential_label credential_source credential_summary
  local api_label api_type strict_tools backup response
  id="$(gum input --prompt "标识  › " --placeholder "newapi（仅字母、数字、点、下划线、连字符）")" || return 0
  [[ $id =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || die "中转站标识不合法。"

  base_url="$(gum input --prompt "地址  › " --placeholder "https://api.example.com/v1")" || return 0
  base_url="$(normalize_base_url "$base_url")" || die "请输入完整的 http(s) URL。"

  auth_label="$(gum choose --header "认证方式" \
    "Authorization: Bearer（New API / One API / OpenAI 兼容）" \
    "x-api-key（Anthropic 原生兼容）" \
    "无需认证")" || return 0
  case "$auth_label" in
  Authorization*) auth_mode="bearer" ;;
  x-api-key*) auth_mode="x-api-key" ;;
  *) auth_mode="none" ;;
  esac

  env_name=""
  secret=""
  if [[ $auth_mode != "none" ]]; then
    credential_label="$(gum choose --header "API Key 配置方式" \
      "直接输入 API Key（推荐，安全保存到 OMP .env）" \
      "引用已有环境变量（不在此保存 API Key）")" || return 0
    env_name="$(env_name_for_provider "$id")"
    if provider_exists "$id"; then
      current_env_name="$(provider_value "$id" '.apiKey // ""')"
      [[ -z $current_env_name || $current_env_name == null ]] || env_name="$current_env_name"
    fi
    case "$credential_label" in
    直接*)
      credential_source="stored"
      secret="$(gum input --password --prompt "API Key › " --placeholder "粘贴 sk-...（输入内容不会显示）")" || return 0
      if [[ -z $secret ]]; then
        secret="${!env_name:-}"
        [[ -n $secret ]] || secret="$(read_secret "$env_name" || true)"
        [[ -n $secret ]] || die "API Key 不能为空。"
        note "未输入新 Key，将沿用已有密钥。"
      fi
      ;;
    引用*)
      credential_source="environment"
      env_name="$(gum input --prompt "环境变量名 › " --value "$env_name" --placeholder "OPENAI_API_KEY")" || return 0
      [[ $env_name =~ ^[A-Z_][A-Z0-9_]*$ ]] || die "环境变量名只能包含大写字母、数字和下划线。"
      secret="${!env_name:-}"
      if [[ -z $secret ]]; then
        warning "当前进程中没有 ${env_name}，暂时无法使用它探测模型。"
      fi
      ;;
    esac
  fi

  response="$(mktemp)"
  note "正在请求 ${base_url}/models…"
  if fetch_models "$base_url" "$secret" "$auth_mode" "$response"; then
    show_model_summary "$response"
  else
    warning "模型探测失败。常见原因：URL、密钥、认证方式或中转站网络不可用。"
    if [[ -s $response ]]; then
      jq -r '[.error.message // .message // empty][:2][]' "$response" 2>/dev/null || true
    fi
    if ! gum confirm "仍然继续保存配置吗？"; then
      rm -f "$response"
      return 0
    fi
  fi
  rm -f "$response"

  api_label="$(gum choose --header "OMP 调用协议" \
    "自动识别（推荐，按模型协议标记选择）" \
    "OpenAI Chat Completions" \
    "OpenAI Responses" \
    "OpenAI Codex Responses" \
    "Anthropic Messages")" || return 0
  case "$api_label" in
  自动*) api_type="" ;;
  "OpenAI Chat"*) api_type="openai-completions" ;;
  "OpenAI Responses") api_type="openai-responses" ;;
  "OpenAI Codex"*) api_type="openai-codex-responses" ;;
  *) api_type="anthropic-messages" ;;
  esac

  strict_tools="false"
  if gum confirm "启用宽松工具调用兼容？（多数中转站推荐）" --default=true; then
    strict_tools="true"
  fi

  if [[ $auth_mode == none ]]; then
    credential_summary="无需认证"
  elif [[ $credential_source == stored ]]; then
    credential_summary="API Key 已安全保存"
  else
    credential_summary="引用环境变量 ${env_name}"
  fi

  gum style --foreground 250 \
    "标识：${id}" \
    "地址：${base_url}" \
    "密钥：${credential_summary}" \
    "协议：${api_type:-自动识别}" \
    "宽松工具：${strict_tools}"
  gum confirm "确认写入配置？" || return 0

  if [[ $auth_mode != none ]]; then
    [[ $env_name =~ ^[A-Z_][A-Z0-9_]*$ ]] || die "自动生成的密钥变量名不合法：${env_name}"
    [[ $secret != *$'\n'* && $secret != *$'\r'* ]] || die "API Key 不能包含换行。"
  fi
  backup="$(backup_config)"
  write_provider_core "$id" "$base_url" "$api_type" proxy "$auth_mode" "$env_name" "$strict_tools" ||
    die "写入中转站配置失败，原配置未改变。备份：${backup}"
  [[ $auth_mode == "none" || $credential_source == "environment" ]] || write_secret "$env_name" "$secret"
  chmod 600 "$MODELS_FILE" "$SECRETS_FILE" "$CONFIG_FILE"

  success "已保存 ${id}"
  note "备份：${backup}"
  if gum confirm "立即刷新 OMP 模型缓存？" --default=true; then
    if gum spin --spinner dot --title "正在刷新模型缓存" -- omp models refresh >/dev/null 2>&1; then
      success "模型缓存已刷新"
      omp models "$id" || true
    else
      warning "OMP 刷新失败。配置已保留，可稍后运行：omp models refresh"
    fi
  fi
  pause
}

list_providers() {
  header
  gum style --bold --foreground 212 "已配置的中转站"
  local count
  count="$(yq eval '.providers // {} | length' "$MODELS_FILE")"
  if ((count == 0)); then
    note "尚未配置中转站。"
  else
    yq eval -o=json '.providers // {}' "$MODELS_FILE" |
      jq -r 'to_entries[] | [.key, .value.baseUrl, (.value.api // "自动"), (.value.discovery.type // "关闭"), ((.value.models // []) | length), (.value.apiKey // "无")] | @tsv' |
      gum table --columns "标识,Base URL,协议,发现,手动模型,密钥变量" --separator $'\t' --print
  fi
  printf '\n'
  note "配置文件：${MODELS_FILE}"
  note "密钥文件：${SECRETS_FILE}（值已隐藏）"
  pause
}

delete_provider() {
  header
  local id env_name backup
  id="$(choose_provider "选择要删除的中转站")" || {
    note "没有可删除的中转站。"
    pause
    return 0
  }
  env_name="$(PROVIDER_ID="$id" yq eval -r '.providers[strenv(PROVIDER_ID)].apiKey // ""' "$MODELS_FILE")"
  gum confirm "确定删除 ${id}？" || return 0
  backup="$(backup_config)"
  PROVIDER_ID="$id" yq eval -i 'del(.providers[strenv(PROVIDER_ID)])' "$MODELS_FILE"
  if [[ -n $env_name ]] && gum confirm "同时删除 .env 中的 ${env_name}？"; then
    delete_secret "$env_name"
  fi
  success "已删除 ${id}"
  note "备份：${backup}"
  pause
}

clone_provider() {
  header
  local source target env_name backup
  source="$(choose_provider "选择要复制的中转站")" || return 0
  target="$(gum input --prompt "新标识 › " --placeholder "${source}-backup")" || return 0
  [[ $target =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || die "中转站标识不合法。"
  provider_exists "$target" && die "${target} 已存在。"
  env_name="$(env_name_for_provider "$target")"
  backup="$(backup_config)"
  SOURCE_ID="$source" TARGET_ID="$target" ENV_NAME="$env_name" yq eval -i '
    .providers[strenv(TARGET_ID)] = .providers[strenv(SOURCE_ID)]
  ' "$MODELS_FILE"
  if [[ -n $(provider_value "$target" '.apiKey // ""') ]]; then
    PROVIDER_ID="$target" ENV_NAME="$env_name" yq eval -i \
      '.providers[strenv(PROVIDER_ID)].apiKey = strenv(ENV_NAME)' "$MODELS_FILE"
  fi
  warning "配置已复制；出于安全考虑，密钥没有复制。"
  note "请在密钥管理中为 ${env_name} 设置新密钥。"
  note "备份：${backup}"
  pause
}

toggle_provider() {
  header
  local id state backup
  id="$(choose_provider "选择要启用或停用的中转站")" || return 0
  backup="$(backup_config)"
  if provider_disabled "$id"; then
    set_provider_disabled "$id" false
    state="已启用"
  else
    set_provider_disabled "$id" true
    state="已停用"
  fi
  success "${id} ${state}"
  note "停用只影响模型选择，不会删除配置和密钥。备份：${backup}"
  pause
}

choose_api_type() {
  local current="${1:-}" label
  label="$(gum choose --header "调用协议（当前：${current:-自动}）" \
    "自动（仅 proxy 发现支持）" \
    "openai-completions" \
    "openai-responses" \
    "openai-codex-responses" \
    "azure-openai-responses" \
    "anthropic-messages" \
    "google-generative-ai" \
    "google-gemini-cli" \
    "google-vertex")" || return 1
  [[ $label == 自动* ]] && printf '\n' || printf '%s\n' "$label"
}

choose_discovery_type() {
  local current="${1:-关闭}" label
  label="$(gum choose --header "模型发现方式（当前：${current}）" \
    "关闭" "proxy" "openai-models-list" "litellm" "ollama" "llama.cpp" "lm-studio")" || return 1
  [[ $label == "关闭" ]] && printf '\n' || printf '%s\n' "$label"
}

edit_provider_core() {
  header
  local id base_url current api discovery auth_label auth_mode env_name secret strict backup
  id="$(choose_provider "选择要编辑的中转站")" || return 0
  base_url="$(provider_value "$id" '.baseUrl // ""')"
  base_url="$(gum input --prompt "地址 › " --value "$base_url")" || return 0
  base_url="$(normalize_base_url "$base_url")" || die "Base URL 不合法。"
  current="$(provider_value "$id" '.api // ""')"
  api="$(choose_api_type "$current")" || return 0
  current="$(provider_value "$id" '.discovery.type // ""')"
  discovery="$(choose_discovery_type "$current")" || return 0
  [[ -n $api || $discovery == "proxy" ]] || die "非 proxy 发现必须指定调用协议。"

  auth_label="$(gum choose --header "认证模式" \
    "Bearer API Key" "SDK 原生 API Key Header" "无密钥 auth:none")" || return 0
  case "$auth_label" in
  Bearer*) auth_mode="bearer" ;;
  SDK*) auth_mode="native" ;;
  *) auth_mode="none" ;;
  esac
  env_name="$(provider_value "$id" '.apiKey // ""')"
  [[ -n $env_name && $env_name != "null" ]] || env_name="$(env_name_for_provider "$id")"
  secret=""
  if [[ $auth_mode != none ]]; then
    env_name="$(gum input --prompt "密钥变量 › " --value "$env_name")" || return 0
    [[ $env_name =~ ^[A-Z_][A-Z0-9_]*$ ]] || die "密钥变量名不合法。"
    secret="$(gum input --password --prompt "新密钥 › " --placeholder "留空则沿用已有密钥")" || return 0
  fi
  strict="false"
  gum confirm "禁用严格工具 Schema？（第三方代理推荐）" --default=true && strict="true"
  gum confirm "保存这些高级设置？" || return 0
  backup="$(backup_config)"
  write_provider_core "$id" "$base_url" "$api" "$discovery" "$auth_mode" "$env_name" "$strict" ||
    die "更新中转站配置失败，原配置未改变。备份：${backup}"
  [[ -z $secret ]] || write_secret "$env_name" "$secret"
  success "已更新 ${id}"
  note "备份：${backup}"
  pause
}

manage_provider_headers() {
  header
  local id action name value backup
  id="$(choose_provider "选择中转站")" || return 0
  while true; do
    header
    gum style --bold --foreground 212 "请求头 · ${id}"
    PROVIDER_ID="$id" yq eval -r '.providers[strenv(PROVIDER_ID)].headers // {} | to_entries | .[] | [.key, .value] | @tsv' "$MODELS_FILE" |
      gum table --columns "Header,配置值" --separator $'\t' --print || true
    action="$(gum choose "添加或更新 Header" "删除 Header" "返回")" || return 0
    case "$action" in
    添加*)
      name="$(gum input --prompt "Header › " --placeholder "X-Team")" || continue
      [[ $name =~ ^[A-Za-z0-9-]+$ ]] || {
        warning "Header 名不合法。"
        continue
      }
      value="$(gum input --prompt "配置值 › " --placeholder "固定值、环境变量名，或 !secret-command")" || continue
      [[ -n $value ]] || continue
      backup="$(backup_config)"
      PROVIDER_ID="$id" HEADER_NAME="$name" HEADER_VALUE="$value" yq eval -i \
        '.providers[strenv(PROVIDER_ID)].headers[strenv(HEADER_NAME)] = strenv(HEADER_VALUE)' "$MODELS_FILE"
      success "Header 已保存（备份：${backup}）"
      ;;
    删除*)
      mapfile -t headers < <(PROVIDER_ID="$id" yq eval -r '.providers[strenv(PROVIDER_ID)].headers // {} | keys | .[]' "$MODELS_FILE")
      ((${#headers[@]} > 0)) || {
        warning "没有可删除的 Header。"
        continue
      }
      name="$(printf '%s\n' "${headers[@]}" | gum choose)" || continue
      backup="$(backup_config)"
      PROVIDER_ID="$id" HEADER_NAME="$name" yq eval -i \
        'del(.providers[strenv(PROVIDER_ID)].headers[strenv(HEADER_NAME)])' "$MODELS_FILE"
      success "已删除 ${name}（备份：${backup}）"
      ;;
    返回) return 0 ;;
    esac
  done
}

provider_workspace() {
  while true; do
    header
    local action
    action="$(gum choose --height 12 --header "中转站管理" \
      "快速接入 New API / Sub2API" \
      "高级编辑连接与协议" \
      "管理自定义请求头" \
      "查看中转站列表" \
      "复制中转站" \
      "启用 / 停用中转站" \
      "删除中转站" \
      "返回主菜单")" || return 0
    case "$action" in
    快速*) upsert_provider ;;
    高级*) edit_provider_core ;;
    管理*) manage_provider_headers ;;
    查看*) list_providers ;;
    复制*) clone_provider ;;
    启用*) toggle_provider ;;
    删除*) delete_provider ;;
    返回*) return 0 ;;
    esac
  done
}

model_ids_for_provider() {
  local id="$1" output
  output="$(omp models "$id" --json 2>/dev/null || true)"
  jq -r '.. | objects | select(has("id")) | .id' <<<"$output" 2>/dev/null | sed '/^null$/d' | sort -u
}

provider_secret_and_auth() {
  local id="$1" env_name api auth_header secret=""
  env_name="$(provider_value "$id" '.apiKey // ""')"
  api="$(provider_value "$id" '.api // ""')"
  auth_header="$(provider_value "$id" '.authHeader // false')"
  if [[ -n $env_name && $env_name != null ]]; then
    secret="${!env_name:-}"
    [[ -n $secret ]] || secret="$(read_secret "$env_name" || true)"
  fi
  if [[ $(provider_value "$id" '.auth // "apiKey"') == none ]]; then
    printf 'none\t\n'
  elif [[ $auth_header == true || $api != anthropic-messages ]]; then
    printf 'bearer\t%s\n' "$secret"
  else
    printf 'x-api-key\t%s\n' "$secret"
  fi
}

fetch_provider_catalog() {
  local id="$1" output_file="$2" base_url auth_mode secret
  base_url="$(provider_value "$id" '.baseUrl')"
  IFS=$'\t' read -r auth_mode secret < <(provider_secret_and_auth "$id")
  fetch_models "$base_url" "$secret" "$auth_mode" "$output_file"
}

positive_number() {
  local value="$1"
  [[ $value =~ ^[0-9]+([.][0-9]+)?$ ]] && awk -v value="$value" 'BEGIN { exit !(value > 0) }'
}

edit_manual_model() {
  header
  local id model_id existing name api reasoning tools input_json context max_tokens cost_input cost_output cost_read cost_write
  local compat backup model_json temp
  id="$(choose_provider "选择模型所属中转站")" || return 0
  existing=""
  if (("$(model_count "$id")" > 0)) && gum confirm "编辑已有手动模型？"; then
    existing="$(choose_manual_model "$id")" || return 0
  fi
  model_id="$(gum input --prompt "模型 ID › " --value "$existing" --placeholder "claude-sonnet-4-6")" || return 0
  [[ -n $model_id && $model_id != *$'\n'* ]] || die "模型 ID 不能为空。"
  name="$(PROVIDER_ID="$id" MODEL_ID="$existing" yq eval -r \
    '(.providers[strenv(PROVIDER_ID)].models // [] | map(select(.id == strenv(MODEL_ID))) | .[0].name) // ""' "$MODELS_FILE")"
  name="$(gum input --prompt "显示名称 › " --value "$name" --placeholder "$model_id")" || return 0
  [[ -n $name ]] || name="$model_id"
  api="$(PROVIDER_ID="$id" MODEL_ID="$existing" yq eval -r \
    '(.providers[strenv(PROVIDER_ID)].models // [] | map(select(.id == strenv(MODEL_ID))) | .[0].api) // ""' "$MODELS_FILE")"
  api="$(choose_api_type "$api")" || return 0
  [[ -n $api || $(provider_value "$id" '.api // ""') != "" ]] || die "模型或中转站必须指定调用协议。"

  reasoning="false"
  gum confirm "该模型支持推理 / Thinking？" && reasoning="true"
  tools="true"
  gum confirm "该模型支持工具调用？" --default=true || tools="false"
  mapfile -t capabilities < <(gum choose --no-limit --header "输入能力（空格勾选，Enter 确认）" "text" "image" "audio" || true)
  ((${#capabilities[@]} > 0)) || capabilities=(text)
  input_json="$(printf '%s\n' "${capabilities[@]}" | jq -R . | jq -s -c .)"

  context="$(gum input --prompt "上下文窗口 › " --placeholder "200000（可留空）")" || return 0
  max_tokens="$(gum input --prompt "最大输出 › " --placeholder "64000（可留空）")" || return 0
  [[ -z $context ]] || positive_number "$context" || die "上下文窗口必须是正数。"
  [[ -z $max_tokens ]] || positive_number "$max_tokens" || die "最大输出必须是正数。"

  note "成本单位为每百万 Token；不了解可全部留空。"
  cost_input="$(gum input --prompt "输入成本 › " --placeholder "3")" || return 0
  cost_output="$(gum input --prompt "输出成本 › " --placeholder "15")" || return 0
  cost_read="$(gum input --prompt "缓存读取 › " --placeholder "0.3")" || return 0
  cost_write="$(gum input --prompt "缓存写入 › " --placeholder "3.75")" || return 0
  for value in "$cost_input" "$cost_output" "$cost_read" "$cost_write"; do
    [[ -z $value || $value =~ ^[0-9]+([.][0-9]+)?$ ]] || die "成本必须是非负数。"
  done

  compat=""
  if gum confirm "配置高级 compat JSON？"; then
    compat="$(gum write --header "输入 JSON 对象；可配置 supportsReasoningEffort、maxTokensField、extraBody 等" \
      --placeholder '{"supportsReasoningEffort":true,"maxTokensField":"max_completion_tokens"}' --height 8)" || return 0
    jq -e 'type == "object"' <<<"$compat" >/dev/null 2>&1 || die "compat 必须是有效 JSON 对象。"
  fi
  gum confirm "保存模型 ${id}/${model_id}？" || return 0
  backup="$(backup_config)"
  model_json="$(jq -cn \
    --arg id "$model_id" --arg name "$name" --arg api "$api" \
    --arg reasoning "$reasoning" --arg tools "$tools" --argjson input "$input_json" \
    --arg context "$context" --arg maxTokens "$max_tokens" \
    --arg costInput "$cost_input" --arg costOutput "$cost_output" \
    --arg costRead "$cost_read" --arg costWrite "$cost_write" --arg compat "$compat" '
      {
        id: $id,
        name: $name,
        reasoning: ($reasoning == "true"),
        supportsTools: ($tools == "true"),
        input: $input
      }
      + (if $api != "" then {api: $api} else {} end)
      + (if $context != "" then {contextWindow: ($context | tonumber)} else {} end)
      + (if $maxTokens != "" then {maxTokens: ($maxTokens | tonumber)} else {} end)
      + (if [$costInput, $costOutput, $costRead, $costWrite] | any(. != "") then {
          cost: {
            input: (if $costInput != "" then ($costInput | tonumber) else 0 end),
            output: (if $costOutput != "" then ($costOutput | tonumber) else 0 end),
            cacheRead: (if $costRead != "" then ($costRead | tonumber) else 0 end),
            cacheWrite: (if $costWrite != "" then ($costWrite | tonumber) else 0 end)
          }
        } else {} end)
      + (if $compat != "" then {compat: ($compat | fromjson)} else {} end)
    ')" || die "模型数据构造失败，原配置未改变。"
  temp="$(mktemp "${OMP_DIR}/models-model.XXXXXX")"
  cp "$MODELS_FILE" "$temp"
  PROVIDER_ID="$id" OLD_MODEL_ID="$existing" MODEL_ID="$model_id" MODEL_JSON="$model_json" yq eval -i '
    .providers[strenv(PROVIDER_ID)].models = (
      (.providers[strenv(PROVIDER_ID)].models // [] |
        map(select(.id != strenv(OLD_MODEL_ID) and .id != strenv(MODEL_ID)))) +
      [(strenv(MODEL_JSON) | from_json)]
    )
  ' "$temp" || {
    rm -f "$temp"
    die "模型写入失败，原配置未改变。"
  }
  yq eval '.' "$temp" >/dev/null || {
    rm -f "$temp"
    die "模型配置验证失败，原配置未改变。"
  }
  chmod 600 "$temp"
  mv "$temp" "$MODELS_FILE"
  success "已保存 ${id}/${model_id}"
  note "备份：${backup}"
  pause
}

import_models_from_endpoint() {
  header
  local id response backup count model_json model_id
  id="$(choose_provider "选择要导入模型的中转站")" || return 0
  response="$(mktemp)"
  note "正在读取远程模型目录…"
  if ! fetch_provider_catalog "$id" "$response"; then
    rm -f "$response"
    warning "读取失败，请检查地址、认证方式和密钥。"
    pause
    return 0
  fi
  mapfile -t remote_models < <(jq -r '(.data // .models // [])[] | .id // .name // empty' "$response" | sort -u)
  ((${#remote_models[@]} > 0)) || {
    rm -f "$response"
    warning "响应中没有模型。"
    pause
    return 0
  }
  mapfile -t selected < <(printf '%s\n' "${remote_models[@]}" | gum choose --no-limit --height 20 \
    --header "空格勾选要固化到 models.yml 的模型；不固化也可使用运行时发现" || true)
  ((${#selected[@]} > 0)) || {
    rm -f "$response"
    return 0
  }
  backup="$(backup_config)"
  count=0
  for model_id in "${selected[@]}"; do
    model_json="$(MODEL_ID="$model_id" jq -c '
      first((.data // .models // [])[] | select((.id // .name) == env.MODEL_ID)) as $m |
      {
        id: ($m.id // $m.name),
        name: ($m.name // $m.id),
        reasoning: ($m.reasoning // false),
        input: ($m.input // ["text"])
      } +
      (if ($m.supported_endpoint_types // [] | index("anthropic")) then {api:"anthropic-messages"}
       elif ($m.supported_endpoint_types // [] | index("openai")) then {api:"openai-completions"} else {} end) +
      (if ($m.contextWindow // $m.context_length // $m.max_model_len) then {contextWindow:($m.contextWindow // $m.context_length // $m.max_model_len)} else {} end) +
      (if ($m.maxTokens // $m.max_tokens) then {maxTokens:($m.maxTokens // $m.max_tokens)} else {} end)
    ' "$response")"
    PROVIDER_ID="$id" MODEL_ID="$model_id" MODEL_JSON="$model_json" yq eval -i '
      .providers[strenv(PROVIDER_ID)].models = (
        (.providers[strenv(PROVIDER_ID)].models // [] | map(select(.id != strenv(MODEL_ID)))) +
        [(strenv(MODEL_JSON) | from_json)]
      )
    ' "$MODELS_FILE"
    ((count += 1))
  done
  rm -f "$response"
  success "已导入 ${count} 个模型"
  note "备份：${backup}"
  pause
}

delete_manual_model() {
  header
  local id model backup
  id="$(choose_provider "选择中转站")" || return 0
  model="$(choose_manual_model "$id" "搜索要删除的手动模型")" || {
    warning "没有手动模型。"
    pause
    return 0
  }
  gum confirm "删除 ${id}/${model}？" || return 0
  backup="$(backup_config)"
  PROVIDER_ID="$id" MODEL_ID="$model" yq eval -i \
    '.providers[strenv(PROVIDER_ID)].models |= map(select(.id != strenv(MODEL_ID)))' "$MODELS_FILE"
  success "已删除 ${id}/${model}"
  note "备份：${backup}"
  pause
}

manage_equivalence() {
  header
  local action concrete canonical backup
  action="$(gum choose "添加或更新等价映射" "排除模型的自动等价" "删除等价设置" "查看当前设置" "返回")" || return 0
  case "$action" in
  添加*)
    concrete="$(gum input --prompt "具体模型 › " --placeholder "newapi/codex")" || return 0
    canonical="$(gum input --prompt "官方模型 ID › " --placeholder "gpt-5.3-codex")" || return 0
    [[ $concrete == */* && -n $canonical ]] || die "具体模型必须是 provider/model-id。"
    backup="$(backup_config)"
    CONCRETE="$concrete" CANONICAL="$canonical" yq eval -i \
      '.equivalence.overrides[strenv(CONCRETE)] = strenv(CANONICAL)' "$MODELS_FILE"
    success "等价映射已保存（备份：${backup}）"
    ;;
  排除*)
    concrete="$(gum input --prompt "具体模型 › " --placeholder "demo/codex-preview")" || return 0
    backup="$(backup_config)"
    CONCRETE="$concrete" yq eval -i \
      '.equivalence.exclude = ((.equivalence.exclude // []) + [strenv(CONCRETE)] | unique)' "$MODELS_FILE"
    success "已排除（备份：${backup}）"
    ;;
  删除*)
    concrete="$(gum input --prompt "具体模型 › " --placeholder "provider/model-id")" || return 0
    backup="$(backup_config)"
    CONCRETE="$concrete" yq eval -i '
      del(.equivalence.overrides[strenv(CONCRETE)]) |
      .equivalence.exclude = (.equivalence.exclude // [] | map(select(. != strenv(CONCRETE))))
    ' "$MODELS_FILE"
    success "已清理该模型的等价设置（备份：${backup}）"
    ;;
  查看*)
    yq eval '.equivalence // {}' "$MODELS_FILE"
    pause
    ;;
  返回) return 0 ;;
  esac
}

model_workspace() {
  while true; do
    header
    local action
    action="$(gum choose --height 10 --header "模型目录管理" \
      "从中转站批量导入模型" \
      "添加或编辑手动模型" \
      "删除手动模型" \
      "管理模型等价映射" \
      "刷新并查看 OMP 模型目录" \
      "返回主菜单")" || return 0
    case "$action" in
    从中转站*) import_models_from_endpoint ;;
    添加*) edit_manual_model ;;
    删除*) delete_manual_model ;;
    管理*) manage_equivalence ;;
    刷新*) refresh_and_test ;;
    返回*) return 0 ;;
    esac
  done
}

configure_roles() {
  header
  local id role model selected thinking backup
  id="$(choose_provider "选择模型所属中转站")" || {
    note "请先添加中转站。"
    pause
    return 0
  }
  gum spin --spinner dot --title "读取 ${id} 模型" -- omp models refresh >/dev/null 2>&1 || true
  mapfile -t models < <(model_ids_for_provider "$id")
  if ((${#models[@]} == 0)); then
    mapfile -t models < <(manual_model_ids "$id")
  fi
  ((${#models[@]} > 0)) || {
    warning "没有从 OMP 缓存读取到模型，请先检查站点连接。"
    pause
    return 0
  }
  role="$(gum choose --header "选择要设置的模型角色" \
    "default（主模型）" \
    "smol（快速/便宜）" \
    "slow（深度推理）" \
    "vision（视觉）" \
    "plan（规划）" \
    "designer（界面设计）" \
    "commit（提交信息）" \
    "tiny（轻量后台任务）" \
    "task（子任务）" \
    "advisor（审查顾问）")" || return 0
  role="${role%%（*}"
  selected="$(printf '%s\n' "${models[@]}" | gum filter --placeholder "搜索模型 ID" --height 15)" || return 0
  [[ -n $selected ]] || return 0
  model="$selected"
  [[ $model == "${id}/"* ]] || model="${id}/${model}"
  thinking="$(gum choose --header "该角色的 Thinking 等级" \
    "继承默认" "off" "minimal" "low" "medium" "high" "xhigh" "max")" || return 0
  [[ $thinking == "继承默认" ]] || model="${model}:${thinking}"
  backup="$(backup_config)"
  ROLE="$role" MODEL="$model" yq eval -i '.modelRoles[strenv(ROLE)] = strenv(MODEL)' "$CONFIG_FILE"
  success "modelRoles.${role} = ${model}"
  note "备份：${backup}"
  pause
}

configure_provider_order() {
  header
  local backup
  mapfile -t providers < <(provider_ids)
  ((${#providers[@]} > 0)) || {
    warning "请先配置中转站。"
    pause
    return 0
  }
  mapfile -t selected < <(printf '%s\n' "${providers[@]}" | gum choose --no-limit \
    --header "选择 provider 优先级；结果按当前显示顺序保存" || true)
  backup="$(backup_config)"
  if ((${#selected[@]} == 0)); then
    yq eval -i '.modelProviderOrder = []' "$CONFIG_FILE"
  else
    order_json="$(printf '%s\n' "${selected[@]}" | jq -R . | jq -s -c .)"
    ORDER_JSON="$order_json" yq eval -i '.modelProviderOrder = (strenv(ORDER_JSON) | from_json)' "$CONFIG_FILE"
  fi
  success "模型 provider 优先级已更新"
  note "需要精确调整顺序时，可重复选择或使用高级 YAML 编辑。备份：${backup}"
  pause
}

configure_enabled_models() {
  header
  local patterns backup
  note "空列表表示允许所有可用模型；支持精确 ID、provider/model、canonical ID 和 glob。"
  patterns="$(gum write --height 10 --header "每行一个模型模式，例如 newapi/* 或 *sonnet*" \
    --placeholder $'newapi/*\n*sonnet*')" || return 0
  backup="$(backup_config)"
  if [[ -z $patterns ]]; then
    yq eval -i '.enabledModels = []' "$CONFIG_FILE"
  else
    patterns_json="$(sed '/^[[:space:]]*$/d' <<<"$patterns" | jq -R . | jq -s -c .)"
    PATTERNS_JSON="$patterns_json" yq eval -i '.enabledModels = (strenv(PATTERNS_JSON) | from_json)' "$CONFIG_FILE"
  fi
  success "模型白名单已更新"
  note "备份：${backup}"
  pause
}

configure_cycle_order() {
  header
  local backup roles_json
  mapfile -t roles < <(printf '%s\n' default smol slow vision plan designer commit tiny task advisor)
  mapfile -t selected < <(printf '%s\n' "${roles[@]}" | gum choose --no-limit \
    --header "选择 Ctrl+P 模型切换角色；按显示顺序保存" || true)
  ((${#selected[@]} > 0)) || {
    warning "至少选择一个角色。"
    pause
    return 0
  }
  roles_json="$(printf '%s\n' "${selected[@]}" | jq -R . | jq -s -c .)"
  backup="$(backup_config)"
  ROLES_JSON="$roles_json" yq eval -i '.cycleOrder = (strenv(ROLES_JSON) | from_json)' "$CONFIG_FILE"
  success "切换顺序已更新"
  note "备份：${backup}"
  pause
}

configure_thinking() {
  header
  local level backup
  level="$(gum choose --header "全局默认 Thinking 等级" minimal low medium high xhigh max auto)" || return 0
  backup="$(backup_config)"
  LEVEL="$level" yq eval -i '.defaultThinkingLevel = strenv(LEVEL)' "$CONFIG_FILE"
  success "defaultThinkingLevel = ${level}"
  note "单个角色仍可用 :low、:high 等后缀覆盖。备份：${backup}"
  pause
}

show_model_policy() {
  header
  yq eval '{"modelRoles": .modelRoles, "modelProviderOrder": .modelProviderOrder, "cycleOrder": .cycleOrder, "enabledModels": .enabledModels, "defaultThinkingLevel": .defaultThinkingLevel}' "$CONFIG_FILE"
  pause
}

policy_workspace() {
  while true; do
    header
    local action
    action="$(gum choose --height 10 --header "模型策略与角色" \
      "设置模型角色（全部 10 个角色）" \
      "设置 Provider 优先级" \
      "设置可用模型白名单" \
      "设置模型切换顺序" \
      "设置默认 Thinking 等级" \
      "查看当前模型策略" \
      "返回主菜单")" || return 0
    case "$action" in
    设置模型角色*) configure_roles ;;
    设置\ Provider*) configure_provider_order ;;
    设置可用*) configure_enabled_models ;;
    设置模型切换*) configure_cycle_order ;;
    设置默认*) configure_thinking ;;
    查看*) show_model_policy ;;
    返回*) return 0 ;;
    esac
  done
}

refresh_and_test() {
  header
  local id model output
  id="$(choose_provider "选择要验证的中转站")" || {
    note "请先添加中转站。"
    pause
    return 0
  }
  if gum spin --spinner dot --title "刷新 OMP 模型目录" -- omp models refresh >/dev/null 2>&1; then
    success "模型目录刷新成功"
  else
    warning "模型目录刷新失败"
  fi
  omp models "$id" || true
  gum confirm "发送一次最小模型请求进行端到端测试？（可能产生少量费用）" || {
    pause
    return 0
  }
  mapfile -t models < <(model_ids_for_provider "$id")
  ((${#models[@]} > 0)) || {
    warning "找不到可测试模型。"
    pause
    return 0
  }
  model="$(printf '%s\n' "${models[@]}" | gum filter --placeholder "选择测试模型" --height 15)" || return 0
  [[ $model == "${id}/"* ]] || model="${id}/${model}"
  note "正在请求 ${model}，期望只返回 OK…"
  if output="$(omp --model "$model" --no-session --no-tools -p "只回复 OK" 2>&1)"; then
    success "端到端测试成功"
    gum style --border rounded --padding "0 1" "$output"
  else
    warning "端到端测试失败"
    tail -n 12 <<<"$output"
  fi
  pause
}

show_secret_status() {
  header
  local env_name status length table_file secret provider_total
  provider_total="$(yq eval '.providers // {} | length' "$MODELS_FILE")"
  if ((provider_total == 0)); then
    note "尚未配置中转站，因此没有密钥状态可显示。"
    pause
    return 0
  fi
  table_file="$(mktemp "${OMP_DIR}/secret-status.XXXXXX")"
  printf '中转站\t密钥变量\t状态\t长度\n' >"$table_file"
  while IFS= read -r id; do
    env_name="$(provider_value "$id" '.apiKey // ""')"
    if [[ $(provider_value "$id" '.auth // "apiKey"') == none ]]; then
      printf '%s\t%s\t%s\t%s\n' "$id" "-" "无需密钥" "-" >>"$table_file"
    elif [[ -z $env_name || $env_name == null ]]; then
      printf '%s\t%s\t%s\t%s\n' "$id" "-" "未配置引用" "-" >>"$table_file"
    elif
      secret="${!env_name:-}"
      [[ -n $secret ]] || secret="$(read_secret "$env_name" || true)"
      [[ -n $secret ]]
    then
      length="${#secret}"
      status="已保存"
      [[ -z ${!env_name:-} ]] || status="由进程环境提供"
      printf '%s\t%s\t%s\t%s\n' "$id" "$env_name" "$status" "$length" >>"$table_file"
    else
      status="缺失"
      printf '%s\t%s\t%s\t%s\n' "$id" "$env_name" "$status" "-" >>"$table_file"
    fi
  done < <(provider_ids)
  tail -n +2 "$table_file" |
    gum table --columns "中转站,密钥变量,状态,长度" --separator $'\t' --print
  rm -f "$table_file"
  note "密钥内容不会显示。项目目录 .env 或 shell 环境可能覆盖这里保存的值。"
  pause
}

rotate_secret() {
  header
  local id env_name secret backup
  id="$(choose_provider "选择要轮换密钥的中转站")" || return 0
  [[ $(provider_value "$id" '.auth // "apiKey"') != none ]] || {
    warning "${id} 是无密钥模式。"
    pause
    return 0
  }
  env_name="$(provider_value "$id" '.apiKey // ""')"
  [[ -n $env_name && $env_name != null ]] || env_name="$(env_name_for_provider "$id")"
  env_name="$(gum input --prompt "密钥变量 › " --value "$env_name")" || return 0
  [[ $env_name =~ ^[A-Z_][A-Z0-9_]*$ ]] || die "密钥变量名不合法。"
  secret="$(gum input --password --prompt "新密钥 › ")" || return 0
  [[ -n $secret ]] || die "新密钥不能为空。"
  backup="$(backup_config)"
  PROVIDER_ID="$id" ENV_NAME="$env_name" yq eval -i \
    '.providers[strenv(PROVIDER_ID)].apiKey = strenv(ENV_NAME)' "$MODELS_FILE"
  write_secret "$env_name" "$secret"
  success "${id} 的密钥已轮换"
  note "备份：${backup}"
  pause
}

clean_orphan_secrets() {
  header
  local name backup
  mapfile -t referenced < <(yq eval -r \
    '.providers // {} | to_entries | .[].value.apiKey | select(. != null and . != "")' "$MODELS_FILE" | sort -u)
  mapfile -t stored < <(sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p' "$SECRETS_FILE" | sort -u)
  mapfile -t orphaned < <(comm -23 \
    <(printf '%s\n' "${stored[@]}" | sed '/^$/d' | sort -u) \
    <(printf '%s\n' "${referenced[@]}" | sed '/^$/d' | sort -u))
  ((${#orphaned[@]} > 0)) || {
    success "没有孤立密钥。"
    pause
    return 0
  }
  mapfile -t selected < <(printf '%s\n' "${orphaned[@]}" | gum choose --no-limit \
    --header "这些变量未被任何 provider 引用；选择要删除的项" || true)
  ((${#selected[@]} > 0)) || return 0
  gum confirm "确定删除所选密钥？" || return 0
  backup="$(backup_config)"
  for name in "${selected[@]}"; do delete_secret "$name"; done
  success "已删除 ${#selected[@]} 个孤立密钥"
  note "备份：${backup}"
  pause
}

diagnose_provider() {
  header
  local id env_name base_url auth response start elapsed result=0
  id="$(choose_provider "选择要诊断的中转站")" || return 0
  gum style --bold --foreground 212 "分层诊断 · ${id}"
  base_url="$(provider_value "$id" '.baseUrl // ""')"
  if [[ $base_url =~ ^https?:// ]]; then success "Base URL 格式正常：${base_url}"; else
    warning "Base URL 格式异常"
    result=1
  fi
  if provider_disabled "$id"; then
    warning "该 provider 当前被 disabledProviders 停用"
    result=1
  else success "provider 已启用"; fi
  auth="$(provider_value "$id" '.auth // "apiKey"')"
  env_name="$(provider_value "$id" '.apiKey // ""')"
  if [[ $auth == none ]]; then
    success "认证：无密钥"
  elif [[ -n $env_name && $env_name != null ]] && { [[ -n $(read_secret "$env_name" || true) ]] || [[ -n ${!env_name:-} ]]; }; then
    success "认证引用可解析：${env_name}"
  else
    warning "认证引用缺失或没有值：${env_name:-未配置}"
    result=1
  fi
  response="$(mktemp)"
  start="$(date +%s%3N)"
  if fetch_provider_catalog "$id" "$response"; then
    elapsed=$(($(date +%s%3N) - start))
    count="$(jq '(.data // .models // []) | length' "$response" 2>/dev/null || printf 0)"
    success "HTTP /models 成功：${count} 个模型，${elapsed}ms"
  else
    warning "HTTP /models 失败"
    jq -r '.error.message // .message // empty' "$response" 2>/dev/null || true
    result=1
  fi
  rm -f "$response"
  note "OMP schema/缓存检查："
  if omp models refresh >/dev/null 2>&1; then
    success "OMP 已接受配置并刷新缓存"
  else
    warning "OMP 模型刷新失败；运行 omp models refresh 查看完整错误"
    result=1
  fi
  if ((result == 0)); then
    success "基础诊断全部通过"
  else
    warning "诊断发现问题，请按上面的失败层修复。"
  fi
  if ((result == 0)) && gum confirm "继续发送一次真实模型请求？（可能产生费用）"; then
    refresh_and_test
    return 0
  fi
  pause
}

benchmark_models() {
  header
  local id runs max_tokens models_json
  id="$(choose_provider "选择要测速的中转站")" || return 0
  mapfile -t models < <(model_ids_for_provider "$id")
  ((${#models[@]} > 0)) || mapfile -t models < <(manual_model_ids "$id")
  ((${#models[@]} > 0)) || {
    warning "没有可测速模型。"
    pause
    return 0
  }
  mapfile -t selected < <(printf '%s\n' "${models[@]}" | gum choose --no-limit --height 18 \
    --header "选择要比较的模型（每次请求会产生费用）" || true)
  ((${#selected[@]} > 0)) || return 0
  runs="$(gum input --prompt "每模型次数 › " --value "1")" || return 0
  max_tokens="$(gum input --prompt "最大输出 Token › " --value "128")" || return 0
  [[ $runs =~ ^[1-9][0-9]*$ && $max_tokens =~ ^[1-9][0-9]*$ ]] || die "次数和 Token 必须是正整数。"
  for index in "${!selected[@]}"; do
    [[ ${selected[index]} == "${id}/"* ]] || selected[index]="${id}/${selected[index]}"
  done
  gum confirm "开始 ${#selected[@]} 个模型的付费测速？" || return 0
  models_json="$(omp bench "${selected[@]}" --runs "$runs" --max-tokens "$max_tokens" --par 1 --json 2>&1)" || {
    warning "测速失败"
    tail -n 20 <<<"$models_json"
    pause
    return 0
  }
  jq -C '.' <<<"$models_json" || printf '%s\n' "$models_json"
  pause
}

export_redacted() {
  header
  local stamp target
  stamp="$(date +%Y%m%d-%H%M%S)"
  target="${EXPORT_DIR}/omp-provider-${stamp}"
  mkdir -p "$target"
  cp "$MODELS_FILE" "$target/models.yml"
  cp "$CONFIG_FILE" "$target/config.yml"
  yq eval -r '.providers // {} | to_entries | .[] | select(.value.apiKey) | .value.apiKey' "$MODELS_FILE" |
    sed '/^$/d; s/$/=REPLACE_ME/' >"$target/.env.example"
  chmod 600 "$target/models.yml" "$target/config.yml" "$target/.env.example"
  success "已生成脱敏导出：${target}"
  note "导出不包含任何真实密钥，可用于迁移或版本控制。"
  pause
}

export_full_archive() {
  header
  local stamp target
  warning "完整归档包含 API Key，泄露后可直接调用你的中转站。"
  gum confirm "确认创建含密钥归档？" || return 0
  gum confirm "再次确认：归档必须存放在可信位置。" || return 0
  stamp="$(date +%Y%m%d-%H%M%S)"
  target="${EXPORT_DIR}/omp-provider-private-${stamp}.tar.gz"
  tar -C "$OMP_DIR" -czf "$target" models.yml config.yml .env
  chmod 600 "$target"
  success "已创建私密归档：${target}"
  pause
}

import_models_config() {
  header
  local source mode backup temp
  source="$(gum input --prompt "配置路径 › " --placeholder "/path/to/models.yml")" || return 0
  source="${source/#\~/$HOME}"
  [[ -f $source ]] || die "文件不存在：${source}"
  yq eval -e 'type == "!!map" and (.providers == null or (.providers | type == "!!map"))' "$source" >/dev/null 2>&1 ||
    die "导入文件不是有效的 OMP models.yml。"
  mode="$(gum choose --header "导入方式" "合并（同名 provider 由导入文件覆盖）" "完全替换")" || return 0
  gum confirm "执行导入？当前配置会先备份。" || return 0
  backup="$(backup_config)"
  if [[ $mode == 合并* ]]; then
    temp="$(mktemp "${OMP_DIR}/models-import.XXXXXX")"
    yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' "$MODELS_FILE" "$source" >"$temp"
    mv "$temp" "$MODELS_FILE"
  else
    cp "$source" "$MODELS_FILE"
  fi
  chmod 600 "$MODELS_FILE"
  success "配置导入完成"
  note "密钥不会从脱敏导入中恢复，请使用密钥管理补充。备份：${backup}"
  pause
}

backup_workspace() {
  header
  local action backup
  action="$(gum choose "立即创建完整内部备份" "恢复历史备份" "脱敏导出" "含密钥私密归档" "导入 models.yml" "返回")" || return 0
  case "$action" in
  立即*)
    backup="$(backup_config)"
    success "备份：${backup}"
    pause
    ;;
  恢复*) restore_backup ;;
  脱敏*) export_redacted ;;
  含密钥*) export_full_archive ;;
  导入*) import_models_config ;;
  返回) return 0 ;;
  esac
}

operations_workspace() {
  while true; do
    header
    local action
    action="$(gum choose --height 12 --header "诊断、安全与迁移" \
      "查看密钥状态" \
      "轮换中转站密钥" \
      "清理孤立密钥" \
      "分层诊断中转站" \
      "模型性能基准测试" \
      "备份 / 恢复 / 导入导出" \
      "返回主菜单")" || return 0
    case "$action" in
    查看密钥*) show_secret_status ;;
    轮换*) rotate_secret ;;
    清理*) clean_orphan_secrets ;;
    分层*) diagnose_provider ;;
    模型性能*) benchmark_models ;;
    备份*) backup_workspace ;;
    返回*) return 0 ;;
    esac
  done
}

restore_backup() {
  header
  local backups selected
  mapfile -t backups < <(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -r)
  ((${#backups[@]} > 0)) || {
    note "暂无备份。"
    pause
    return 0
  }
  selected="$(printf '%s\n' "${backups[@]}" | gum choose --header "选择要恢复的备份")" || return 0
  gum confirm "当前配置会先自动备份，然后恢复 ${selected}，继续？" || return 0
  backup_config >/dev/null
  cp "${BACKUP_DIR}/${selected}/models.yml" "$MODELS_FILE"
  cp "${BACKUP_DIR}/${selected}/.env" "$SECRETS_FILE"
  [[ ! -e ${BACKUP_DIR}/${selected}/config.yml ]] || cp "${BACKUP_DIR}/${selected}/config.yml" "$CONFIG_FILE"
  chmod 600 "$MODELS_FILE" "$SECRETS_FILE" "$CONFIG_FILE"
  success "已恢复 ${selected}"
  pause
}

doctor() {
  ensure_layout
  validate_yaml
  local providers disabled models backups missing=0 env_name id permissions="正常"
  providers="$(yq eval '.providers // {} | length' "$MODELS_FILE")"
  disabled="$(yq eval '.disabledProviders // [] | length' "$CONFIG_FILE")"
  models="$(yq eval '[.providers // {} | .[] | (.models // [])[]] | length' "$MODELS_FILE")"
  backups="$(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l)"
  while IFS= read -r id; do
    [[ $(provider_value "$id" '.auth // "apiKey"') == none ]] && continue
    env_name="$(provider_value "$id" '.apiKey // ""')"
    if [[ -z $env_name || $env_name == null ]] ||
      { [[ -z ${!env_name:-} ]] && [[ -z $(read_secret "$env_name" || true) ]]; }; then
      ((missing += 1))
    fi
  done < <(provider_ids)
  for file in "$MODELS_FILE" "$SECRETS_FILE" "$CONFIG_FILE"; do
    [[ $(stat -c '%a' "$file") == 600 ]] || permissions="需修复"
  done
  printf 'OMP 中转站配置健康检查\n'
  printf '  OMP 版本:      %s\n' "$(omp --version 2>/dev/null | head -n 1 || printf '未找到')"
  printf '  配置目录:      %s\n' "$OMP_DIR"
  printf '  YAML:          有效\n'
  printf '  文件权限:      %s (期望 600)\n' "$permissions"
  printf '  中转站:        %s（停用 %s）\n' "$providers" "$disabled"
  printf '  手动模型:      %s\n' "$models"
  printf '  缺失密钥引用:  %s\n' "$missing"
  printf '  历史备份:      %s\n' "$backups"
  ((missing == 0))
}

usage() {
  cat <<EOF
用法：omp-provider [选项]

不带参数启动中文交互式配置中心。

  --doctor    检查 OMP、YAML、权限、中转站、模型和密钥
  --help      显示此帮助
EOF
}

main() {
  case "${1:-}" in
  --doctor)
    doctor
    exit
    ;;
  -h | --help)
    usage
    exit
    ;;
  "") ;;
  *)
    usage >&2
    exit 2
    ;;
  esac

  command -v omp >/dev/null || die "找不到 omp，请先安装 Oh My Pi。"
  ensure_layout
  validate_yaml

  while true; do
    header
    local action
    action="$(gum choose --height 12 --cursor-prefix "› " --selected-prefix "✓ " \
      "中转站管理" \
      "模型目录管理" \
      "模型策略与角色" \
      "诊断、安全与迁移" \
      "总览与健康检查" \
      "退出")" || exit 0
    case "$action" in
    中转站*) provider_workspace ;;
    模型目录*) model_workspace ;;
    模型策略*) policy_workspace ;;
    诊断*) operations_workspace ;;
    总览*) list_providers ;;
    退出) exit 0 ;;
    esac
  done
}

if [[ ${OMP_PROVIDER_SOURCE_ONLY:-0} != 1 ]]; then
  main "$@"
fi
