# === Resolve plugin directory ===
plugin_dir="${${(%):-%x}:A:h}"

# === Autocomplete: AWS profiles ===
_aws_profiles() {
  local profiles
  profiles=($(aws configure list-profiles 2>/dev/null))
  compadd "${profiles[@]}"
}
compdef _aws_profiles awslogin

# === Main awslogin function ===
awslogin() {
  local profile="$1"
  local config_file="${plugin_dir}/awsloginrc"
  local profile_file="${plugin_dir}/awsloginrc.d/${profile}.env"

  if [[ -z "$profile" ]]; then
    echo "Usage: awslogin <aws-profile>"
    return 1
  fi

  if ! aws configure list-profiles | grep -qx "$profile"; then
    echo "❌ Profile '$profile' not found in AWS config."
    return 1
  fi

  export AWS_PROFILE="$profile"
  echo "✅ Set AWS_PROFILE=$AWS_PROFILE"

  # --- Load per-profile .env file ---
  if [[ -f "$profile_file" ]]; then
    echo "📄 Loading env from: $profile_file"
    while IFS='=' read -r key value; do
      [[ -z "$key" || "$key" == \#* ]] && continue
      key=$(echo "$key" | xargs)
      value=$(echo "$value" | xargs)
      export "$key"="$value"
      echo "📦 Exported $key=$value"
    done < "$profile_file"
  else
    echo "⚠️  No env config found for profile '$profile'"
  fi

  # --- Detect if SSO profile by inspecting ~/.aws/config ---
  local aws_config="$HOME/.aws/config"
  local config_entry="[profile $profile]"
  local is_sso=0

  if grep -A 10 "$config_entry" "$aws_config" 2>/dev/null | grep -q "sso_start_url"; then
    is_sso=1
  fi

  if [[ "$is_sso" == "1" ]]; then
    echo "🔐 SSO profile detected. Logging in..."
    aws sso login --profile "$profile"
  else
    echo "🔓 Credential-based profile. No login required."
  fi

  # --- Optional Pulumi login if backend is defined ---
  if [[ -n "$PULUMI_BACKEND_URL" ]]; then
    echo "📦 Logging into Pulumi backend: $PULUMI_BACKEND_URL"
    pulumi logout &>/dev/null  # Clean logout to avoid stale session (optional)
    pulumi login
  fi
}

# === Main awslogout function ===
awslogout() {
  echo "🚪 Logging out of AWS and Pulumi..."

  # --- Determine plugin directory and profile ---
  local plugin_dir="${${(%):-%x}:A:h}"
  local profile="${AWS_PROFILE:-default}"
  local profile_file="${plugin_dir}/awsloginrc.d/${profile}.env"
  local config_file="${plugin_dir}/awsloginrc"

  # --- Pulumi logout if backend env var is set ---
  if [[ -n "$PULUMI_S3_BACKEND" || -n "$PULUMI_BACKEND_URL" ]]; then
    if command -v pulumi >/dev/null 2>&1; then
      echo "📦 Logging out of Pulumi"
      pulumi logout &>/dev/null
    fi
  fi

  # --- AWS SSO logout if SSO-based profile ---
  local aws_config="$HOME/.aws/config"
  local config_entry="[profile $profile]"
  if grep -A 10 "$config_entry" "$aws_config" 2>/dev/null | grep -q "sso_start_url"; then
    echo "🔐 Logging out of AWS SSO ($profile)"
    aws sso logout
  fi

  # --- Unset variables defined in .env file ---
  echo "🧼 Unsetting environment variables from profile: $profile"

  if [[ -f "$profile_file" ]]; then
    while IFS='=' read -r key _ || [[ -n "$key" ]]; do
      key="${key%%=*}"
      key="${key#"${key%%[![:space:]]*}"}"
      key="${key%"${key##*[![:space:]]}"}"
      [[ -n "$key" && "$key" != \#* ]] && unset "$key" && echo "❌ Unset $key"
    done < "$profile_file"
  else
    echo "⚠️  No per-profile env file found: $profile_file"
  fi

  # Always unset AWS_PROFILE itself
  unset AWS_PROFILE
  echo "✅ Logout complete."
}