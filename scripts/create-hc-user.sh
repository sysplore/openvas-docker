#!/usr/bin/env bash
echo "Starting script"
set -euo pipefail

# --------------------------------------------------------------------
# setup-gvm-healthcheck-user.sh
#
# Creates/maintains a least-privilege GVM/GVMD user for container
# health checks over the gvmd Unix socket.
# --------------------------------------------------------------------
echo "Variable setup"
GVMD_SOCKET="${GVMD_SOCKET:-/run/gvmd/gvmd.sock}"

GVM_ADMIN_USER="${GVM_ADMIN_USER:-admin}"
GVM_ADMIN_PASS="$1"
: "${GVM_ADMIN_PASS:?GVM_ADMIN_PASS is required}"

GVM_HEALTH_USER="${GVM_HEALTH_USER:-healthcheck}"
GVM_HEALTH_ROLE="${GVM_HEALTH_ROLE:-Healthcheck}"
GVM_HEALTH_PASS_FILE="${GVM_HEALTH_PASS_FILE:-/etc/gvm/healthcheck.pass}"

GVM_LOCAL_USER="${GVM_LOCAL_USER:-gvm}"
GVM_LOCAL_GROUP="${GVM_LOCAL_GROUP:-gvm}"

GVM_HEALTH_SETUP_RETRIES="${GVM_HEALTH_SETUP_RETRIES:-60}"
GVM_HEALTH_SETUP_SLEEP="${GVM_HEALTH_SETUP_SLEEP:-5}"

ADMIN_CFG=""
HEALTH_CFG=""
echo "Setup some functions"

cleanup() {
  [ -n "${ADMIN_CFG:-}" ] && [ -f "$ADMIN_CFG" ] && rm -f "$ADMIN_CFG"
  [ -n "${HEALTH_CFG:-}" ] && [ -f "$HEALTH_CFG" ] && rm -f "$HEALTH_CFG"
}
trap cleanup EXIT

random_password_19() {
  LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 19 || true
}

write_health_password_file() {
  local pass="$1"
  local tmpfile
  tmpfile="$(mktemp)"
  printf '%s\n' "$pass" > "$tmpfile"
  chown "$GVM_LOCAL_USER:$GVM_LOCAL_GROUP" "$tmpfile"
  chmod 0600 "$tmpfile"
  mv "$tmpfile" "$GVM_HEALTH_PASS_FILE"
  chown "$GVM_LOCAL_USER:$GVM_LOCAL_GROUP" "$GVM_HEALTH_PASS_FILE"
  chmod 0600 "$GVM_HEALTH_PASS_FILE"
}

wait_for_gvmd_socket() {
  local i
  echo "Waiting for GVMD Socket"
  for i in $(seq 1 "$GVM_HEALTH_SETUP_RETRIES"); do
    if [ -S "$GVMD_SOCKET" ]; then
      return 0
    fi
    sleep "$GVM_HEALTH_SETUP_SLEEP"
  done
  echo "ERROR: gvmd socket not found: $GVMD_SOCKET" >&2
  return 1
}

wait_for_gvmd_gmp() {
  local i
  echo "Waiting for GMP"
  # First wait for socket to exist
  wait_for_gvmd_socket || return 1

  for i in $(seq 1 "$GVM_HEALTH_SETUP_RETRIES"); do
    echo "Loop iteration $i for $GVM_HEALTH_SETUP_RETRIES"
    if gvmd --get-users >/dev/null 2>&1; then
      return 0
    fi
    sleep "$GVM_HEALTH_SETUP_SLEEP"
  done

  echo "ERROR: gvmd did not respond to GMP get_version over socket: $GVMD_SOCKET" >&2
  return 1
}

# --------------------------------------------------------------------
# Main
# --------------------------------------------------------------------
wait_for_gvmd_gmp || true

# Check if healthcheck user exists
# NOTE: this script is invoked via "su -c ... gvm", so it already runs as the
# gvm user. Nested "su -c ... gvm" calls would require a password and fail,
# silently breaking healthcheck user setup - so plain gvmd calls are used.
if gvmd --get-users --verbose 2>/dev/null | grep -qw "$GVM_HEALTH_USER"; then
  echo "GVM healthcheck user already exists: $GVM_HEALTH_USER"

  # Check existing password file
  if [ -s "$GVM_HEALTH_PASS_FILE" ]; then
    existing_pass=$(cat "$GVM_HEALTH_PASS_FILE")
    # Try to verify by resetting to same password
    if gvmd --user="$GVM_HEALTH_USER" --new-password="$existing_pass" >/dev/null 2>&1; then
      write_health_password_file "$existing_pass"
      echo "Healthcheck password unchanged."
      ls -l /$GVM_HEALTH_PASS_FILE
      exit 0
    fi
  fi

  echo "Setting new password for healthcheck user."
  new_pass="$(random_password_19)"
  gvmd --user="$GVM_HEALTH_USER" --new-password="$new_pass"
  write_health_password_file "$new_pass"
  echo "Healthcheck password updated."
else
  echo "Creating healthcheck user: $GVM_HEALTH_USER"
  new_pass="$(random_password_19)"
  gvmd --create-user="$GVM_HEALTH_USER" --password="$new_pass"
  write_health_password_file "$new_pass"
  echo "Healthcheck user created."
fi

ls -l /$GVM_HEALTH_PASS_FILE
echo "Set owner/permissions of password file"
chown "$GVM_LOCAL_USER:$GVM_LOCAL_GROUP" "$GVM_HEALTH_PASS_FILE"
chmod 0600 "$GVM_HEALTH_PASS_FILE"
echo "GVM healthcheck user is ready."
echo "Password file: $GVM_HEALTH_PASS_FILE"
