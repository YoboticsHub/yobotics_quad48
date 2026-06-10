#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Config
# =============================================================================
DEPLOY_PACKAGE_NAME="E15_Controller"
SDK_DIST_NAME="yobotics_sdk_e15_260408"
DEFAULT_REMOTE_USER="user"
DEFAULT_REMOTE_IP="192.168.1.134"
DEFAULT_REMOTE_BASE="~"

# =============================================================================
# Colors
# =============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

log_info() {
  echo -e "${CYAN}[INFO]${NC} $1"
}

log_ok() {
  echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_err() {
  echo -e "${RED}[ERR]${NC} $1"
}

log_step() {
  echo -e "\n${BOLD}${BLUE}============================================================${NC}"
  echo -e "${BOLD}${WHITE}$1${NC}"
  echo -e "${BOLD}${BLUE}============================================================${NC}\n"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDK_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_ROOT="${SDK_ROOT}/dist/${SDK_DIST_NAME}"
WORK_DIR="${SDK_ROOT}/build_deploy"
PKG_DIR="${WORK_DIR}/${DEPLOY_PACKAGE_NAME}"

REMOTE_USER="${1:-${DEFAULT_REMOTE_USER}}"
REMOTE_IP="${2:-${DEFAULT_REMOTE_IP}}"
REMOTE_BASE="${3:-${DEFAULT_REMOTE_BASE}}"

if ! command -v scp >/dev/null 2>&1; then
  log_err "scp not found. Please install openssh-client first."
  exit 1
fi

log_step "Prepare Minimal Deployment Package"

if [[ ! -d "${DIST_ROOT}" ]]; then
  log_warn "SDK dist not found: ${DIST_ROOT}"
  log_info "Generating clean SDK package first..."
  "${SCRIPT_DIR}/generate_clean_sdk.sh"
fi

if [[ ! -d "${DIST_ROOT}" ]]; then
  log_err "Failed to locate dist package: ${DIST_ROOT}"
  exit 1
fi

rm -rf "${PKG_DIR}"
mkdir -p "${PKG_DIR}"

log_info "Copy minimal files into ${DEPLOY_PACKAGE_NAME}"
cp -r "${DIST_ROOT}/include" "${PKG_DIR}/"
cp -r "${DIST_ROOT}/lib" "${PKG_DIR}/"
cp -r "${DIST_ROOT}/cmake" "${PKG_DIR}/"
cp "${DIST_ROOT}/CMakeLists.txt" "${PKG_DIR}/"
cp "${DIST_ROOT}/README.md" "${PKG_DIR}/"
cp "${DIST_ROOT}/SDK使用说明.md" "${PKG_DIR}/"

DATE_TAG="$(date +"%Y%m%d%H%M%S")"
ARCHIVE_NAME="${DEPLOY_PACKAGE_NAME}_${DATE_TAG}.tar.gz"
ARCHIVE_PATH="${WORK_DIR}/${ARCHIVE_NAME}"

log_info "Create archive: ${ARCHIVE_NAME}"
mkdir -p "${WORK_DIR}"
tar -czf "${ARCHIVE_PATH}" -C "${WORK_DIR}" "${DEPLOY_PACKAGE_NAME}"
log_ok "Archive created: ${ARCHIVE_PATH}"

log_step "Upload To Board"
log_info "Target: ${REMOTE_USER}@${REMOTE_IP}:${REMOTE_BASE}/"
scp -r "${PKG_DIR}" "${REMOTE_USER}@${REMOTE_IP}:${REMOTE_BASE}/"
scp "${ARCHIVE_PATH}" "${REMOTE_USER}@${REMOTE_IP}:${REMOTE_BASE}/"

log_ok "Deploy finished"
log_info "Uploaded directory: ${DEPLOY_PACKAGE_NAME}"
log_info "Uploaded archive: ${ARCHIVE_NAME}"

