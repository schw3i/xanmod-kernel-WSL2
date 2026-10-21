#!/bin/bash

shopt -s nullglob

# Function to display usage
usage() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  -a|--arch <architecture>  - Specify the architecture to build. (Default: GENERIC_CPU3)"
  echo "  -b|--branch <LTS|MAIN>    - Specify the Xanmod kernel branch to build. (Default: MAIN)"
  echo "  --no-download             - Don't download kernel source, assume it's already in ./linux"
  echo "  -h|--help                 - Show this help message."
}

# Parse options with getopt
temp=$(getopt -o 'b:a:h' --long 'branch:,arch:,help,no-download' -n 'setup.sh' -- "$@")
if [ $? -ne 0 ]; then
  # unsupported options provided
  usage
  exit 1
fi
eval set -- "$temp"
unset temp
while true; do
  case "$1" in
    '-b'|'--branch')
      BRANCH="$2"
      shift 2
      # check if branch is LTS or MAIN
      if [ "$BRANCH" != "LTS" ] && [ "$BRANCH" != "MAIN" ]; then
        echo "Invalid branch: $BRANCH"
        exit 2
      fi
      continue
      ;;
    '-a'|'--arch')
      ARCH="$2"
      shift 2
      continue
      ;;
    '-h'|'--help')
      usage
      exit 0
      ;;
    '--no-download')
      SKIP_DOWNLOAD="YES"
      shift
      continue
      ;;
    '--')
      shift
      break
      ;;
    *)
      # should not happen
      echo "Unhandled option: $1"
      usage
      exit 1
      ;;
  esac
done
# Default values
ARCH=${ARCH:-GENERIC_CPU3}
BRANCH=${BRANCH:-MAIN}
SKIP_DOWNLOAD=${SKIP_DOWNLOAD:-NO}

if [ "$SKIP_DOWNLOAD" = "NO" ]; then
  LOWERCASE_BRANCH="${BRANCH,,}"
  RSS_URL="https://sourceforge.net/projects/xanmod/rss?path=/releases/$LOWERCASE_BRANCH"
  RSS_CONTENT=$(curl -sSfL "$RSS_URL")
  if [ $? -ne 0 ] || [ -z "$RSS_CONTENT" ]; then
    echo "Failed to fetch SourceForge RSS feed from $RSS_URL"
    exit 2
  fi

  VERSION_TAG=$(
    echo "$RSS_CONTENT" |
    sed -n "s|.*/releases/$LOWERCASE_BRANCH/\([0-9][^/]*\)/.*|\1|p" |
    sort -uV |
    tail -n 1
  )

  XANMOD_REPO="https://gitlab.com/xanmod/linux.git"

  if [ -z "$VERSION_TAG" ]; then
    echo "Failed to resolve Xanmod version for branch $BRANCH from RSS feed!"
    exit 2
  fi
  if [ -d linux ]; then
    echo "Directory 'linux' already exists. Use --no-download to build from existing sources, or remove it before downloading."
    exit 1
  fi

  echo "Fetching Xanmod $BRANCH ($VERSION_TAG) source..."
  if ! git clone "$XANMOD_REPO" -b "$VERSION_TAG" --depth 1 linux; then
    echo "Failed to clone Xanmod source tag $VERSION_TAG from $XANMOD_REPO"
    exit 1
  fi
fi

if [ ! -d linux ]; then
  echo "Xanmod $BRANCH source directory 'linux' not found."
  exit 1
fi

cd linux || exit 1
PATCH_DIR=${PATCH_DIR:-"../patches"}
../scripts/apply-patches.py "$PATCH_DIR" "$BRANCH"
if [ $? -ne 0 ]; then
  echo "Failed to apply patches. Please check the patch directory and try again."
  exit 1
fi

CONFIG_FILE="../configs/config-wsl.$BRANCH"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Config file $CONFIG_FILE not found."
  exit 1
fi

cp "$CONFIG_FILE" .config || exit 1

scripts/config -d CONFIG_GENERIC_CPU || exit 1
scripts/config -u CONFIG_X86_64_VERSION || exit 1
case "$ARCH" in
  GENERIC_CPU3)
    scripts/config -e CONFIG_GENERIC_CPU || exit 1
    scripts/config --set-val CONFIG_X86_64_VERSION 3 || exit 1
    ;;
  GENERIC_CPU2)
    scripts/config -e CONFIG_GENERIC_CPU || exit 1
    scripts/config --set-val CONFIG_X86_64_VERSION 2 || exit 1
    ;;
  *) 
    scripts/config -e "$ARCH" || exit 1
    ;;
esac

make LLVM=1 LLVM_IAS=1 olddefconfig || exit 1
