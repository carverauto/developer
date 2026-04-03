"""Rule to assemble a Phoenix release tarball with Bazel-managed Elixir toolchains."""

def _toolchain_inputs(toolchain):
    otp = toolchain.otpinfo
    elixir = toolchain.elixirinfo

    inputs = [otp.version_file, elixir.version_file]

    otp_tar = getattr(otp, "release_dir_tar", None)
    if otp_tar:
        inputs.append(otp_tar)
    elif getattr(otp, "release_dir", None):
        inputs.append(otp.release_dir)

    if getattr(elixir, "release_dir", None):
        inputs.append(elixir.release_dir)

    return inputs

def _mix_release_impl(ctx):
    toolchain = ctx.toolchains["@rules_elixir//:toolchain_type"]
    otp = toolchain.otpinfo
    elixir = toolchain.elixirinfo
    tar_out = ctx.outputs.out

    otp_tar = getattr(otp, "release_dir_tar", None)
    elixir_home = elixir.elixir_home or elixir.release_dir.short_path
    bootstrap_inputs = "\\n".join(sorted([f.short_path for f in ctx.files.bootstrap_srcs]))

    ctx.actions.run_shell(
        mnemonic = "MixRelease",
        inputs = depset(
            direct = _toolchain_inputs(toolchain) + ctx.files.srcs + ctx.files.bootstrap_srcs,
        ),
        outputs = [tar_out],
        progress_message = "mix release ({})".format(ctx.label.name),
        command = """
set -euo pipefail

EXECROOT=$PWD
WORKDIR=$(mktemp -d)

ELIXIR_HOME_RAW="{elixir_home}"
ELIXIR_HOME=$(cd "$EXECROOT" && cd "$ELIXIR_HOME_RAW" && pwd)

if [ -n "{otp_tar}" ] && [ -f "{otp_tar}" ]; then
  OTP_ROOT=$(mktemp -d)
  tar -xf "{otp_tar}" -C "$OTP_ROOT"
  if [ -d "$OTP_ROOT/lib/erlang" ]; then
    ERLANG_HOME="$OTP_ROOT/lib/erlang"
  else
    ERLANG_HOME=$(find "$OTP_ROOT" -maxdepth 2 -type d -name erlang -print | head -n1 | xargs dirname)
  fi
else
  ERLANG_HOME="{erlang_home}"
fi

copy_dir() {{
  local src="$1"
  local dest="$2"
  if command -v rsync >/dev/null 2>&1; then
    rsync -aL "$src" "$dest"
  else
    mkdir -p "$dest"
    cp -aL "${{src%/}}/." "$dest"
  fi
}}

SYS_TMP=$(python3 - <<'PY'
import tempfile
print(tempfile.gettempdir())
PY
)

CACHE_VERSION="mix_release_v1"
BOOTSTRAP_HASH=$(
  while IFS= read -r relpath; do
    [ -n "$relpath" ] || continue
    if [ -f "$EXECROOT/$relpath" ]; then
      if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$EXECROOT/$relpath"
      else
        shasum -a 256 "$EXECROOT/$relpath"
      fi
    fi
  done <<'EOF'
{bootstrap_inputs}
EOF
)

TARGET_HASH_INPUT="$CACHE_VERSION|{src_dir}|$BOOTSTRAP_HASH"
if command -v sha256sum >/dev/null 2>&1; then
  TARGET_HASH=$(printf '%s' "$TARGET_HASH_INPUT" | sha256sum | cut -d' ' -f1)
else
  TARGET_HASH=$(printf '%s' "$TARGET_HASH_INPUT" | shasum -a 256 | cut -d' ' -f1)
fi

if [ -d /cache ] && [ -w /cache ]; then
  MIX_GLOBAL_CACHE="/cache/mix_bazel_$TARGET_HASH"
else
  MIX_GLOBAL_CACHE="$SYS_TMP/mix_bazel_$TARGET_HASH"
fi

mkdir -p "$MIX_GLOBAL_CACHE/.mix_home"
mkdir -p "$MIX_GLOBAL_CACHE/assets_cache"

export HOME="$MIX_GLOBAL_CACHE/.mix_home"
export MIX_HOME="$HOME/.mix"
export HEX_HOME="$HOME/.hex"
export REBAR_BASE_DIR="$HOME/.cache/rebar3"
export MIX_ENV=prod
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export ELIXIR_ERL_OPTIONS="+fnu"
export PATH="$ELIXIR_HOME/bin:$ERLANG_HOME/bin:$PATH"

copy_dir "$EXECROOT/{src_dir}/" "$WORKDIR/"
cd "$WORKDIR"
chmod -R u+w .

if ! ls "$MIX_HOME/archives/hex-"* >/dev/null 2>&1; then
  mix local.hex --force
fi
if [ ! -x "$MIX_HOME/rebar3" ]; then
  mix local.rebar --force
fi

mix deps.get --only prod
mix deps.compile
mix assets.deploy

RELEASE_DIR=$(mktemp -d)
mix release --path "$RELEASE_DIR"

if [ -n "{app_name}" ] && [ -d priv ]; then
  RELEASE_APP_DIR=$(find "$RELEASE_DIR/lib" -maxdepth 1 -mindepth 1 -type d -name "{app_name}-*" -print -quit)
  if [ -n "$RELEASE_APP_DIR" ]; then
    RELEASE_APP_PRIV="$RELEASE_APP_DIR/priv"
    rm -rf "$RELEASE_APP_PRIV"
    mkdir -p "$RELEASE_APP_PRIV"
    cp -aL priv/. "$RELEASE_APP_PRIV/"
  fi
fi

PACKAGED_RELEASE_DIR=$(mktemp -d)
copy_dir "$RELEASE_DIR/" "$PACKAGED_RELEASE_DIR/"
mkdir -p "$(dirname "$EXECROOT/{tar_out}")"
tar -czf "$EXECROOT/{tar_out}" -C "$PACKAGED_RELEASE_DIR" .
""".format(
            elixir_home = elixir_home,
            otp_tar = otp_tar.path if otp_tar else "",
            erlang_home = otp.erlang_home,
            src_dir = ctx.attr.src_dir,
            bootstrap_inputs = bootstrap_inputs,
            app_name = ctx.attr.app_name,
            tar_out = tar_out.path,
        ),
        use_default_shell_env = False,
    )

    return [
        DefaultInfo(files = depset([tar_out])),
    ]

mix_release = rule(
    implementation = _mix_release_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True),
        "bootstrap_srcs": attr.label_list(allow_files = True),
        "src_dir": attr.string(default = "."),
        "app_name": attr.string(mandatory = True),
        "out": attr.output(mandatory = True),
    },
    toolchains = ["@rules_elixir//:toolchain_type"],
)
