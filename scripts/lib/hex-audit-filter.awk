# Filters `mix hex.audit` output against a project's .deps_audit_ignore file.
#
# Usage: mix hex.audit 2>&1 | awk -v ignore_file=.deps_audit_ignore -f this.awk
# Exits non-zero when any retired package or advisory is not waived.
    BEGIN {
      while ((getline line < ignore_file) > 0) {
        sub(/#.*/, "", line)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)

        if (line != "") {
          ignored[line] = 1
        }
      }
    }

    /^Retired:/ {
      flush_advisory()
      section = "retired"
      next
    }

    /^Advisories:/ {
      flush_advisory()
      section = "advisory"
      next
    }

    section == "retired" && /^  [^[:space:]]+ [^[:space:]]+ - / {
      package = $1

      if (!((package in ignored) || (("package:" package) in ignored) || (("retired:" package) in ignored))) {
        print "::error::unignored hex retired package: " package > "/dev/stderr"
        failed = 1
      }

      next
    }

    section == "advisory" && /^  [^[:space:]]+ [^[:space:]]+ - / {
      flush_advisory()
      advisory = $0
      next
    }

    section == "advisory" && advisory != "" {
      advisory = advisory "\n" $0
      next
    }

    END {
      flush_advisory()
      exit failed
    }

    function flush_advisory(  token, lines) {
      if (advisory == "") {
        return
      }

      for (token in ignored) {
        if (index(advisory, token) > 0) {
          advisory = ""
          return
        }
      }

      split(advisory, lines, "\n")
      print "::error::unignored hex advisory: " lines[1] > "/dev/stderr"
      failed = 1
      advisory = ""
    }
