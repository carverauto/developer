"""Bazel rules for running Mix commands with hermetic Elixir toolchains."""

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

def _mix_task_impl(ctx):
    toolchain = ctx.toolchains["@rules_elixir//:toolchain_type"]
    otp = toolchain.otpinfo
    elixir = toolchain.elixirinfo
    out = ctx.outputs.out

    otp_tar = getattr(otp, "release_dir_tar", None)
    elixir_home = elixir.elixir_home or elixir.release_dir.short_path
    toolchain_inputs = _toolchain_inputs(toolchain)

    ctx.actions.run_shell(
        mnemonic = "MixTask",
        inputs = depset(
            direct = toolchain_inputs + ctx.files.srcs + ctx.files.bootstrap_srcs,
        ),
        outputs = [out],
        progress_message = "mix task ({})".format(ctx.label.name),
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

export HOME="$WORKDIR/.home"
export MIX_HOME="$HOME/.mix"
export HEX_HOME="$HOME/.hex"
export REBAR_BASE_DIR="$HOME/.cache/rebar3"
export MIX_ENV="{mix_env}"
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

mix deps.get
{command}
mkdir -p "$(dirname "$EXECROOT/{out_path}")"
printf 'ok\\n' > "$EXECROOT/{out_path}"
""".format(
            elixir_home = elixir_home,
            otp_tar = otp_tar.path if otp_tar else "",
            erlang_home = otp.erlang_home,
            mix_env = ctx.attr.mix_env,
            src_dir = ctx.attr.src_dir,
            command = ctx.attr.command,
            out_path = out.path,
        ),
        use_default_shell_env = False,
    )

    return [
        DefaultInfo(files = depset([out])),
    ]

mix_task = rule(
    implementation = _mix_task_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True),
        "bootstrap_srcs": attr.label_list(allow_files = True),
        "src_dir": attr.string(default = "."),
        "command": attr.string(mandatory = True),
        "mix_env": attr.string(default = "dev"),
        "out": attr.output(mandatory = True),
    },
    toolchains = ["@rules_elixir//:toolchain_type"],
)
