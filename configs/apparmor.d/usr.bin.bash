#include <tunables/global>

profile bash /bin/bash {
  # Standard shell
  capability sys_ptrace,
  capability chroot,
  capability setuid,
  capability setgid,

  # Allow home dir and essential system files
  /home/** rw,
  /tmp/** rw,
  /etc/passwd r,
  /etc/shadow r,
  /etc/group r,

  # Limit network access
  deny network raw,
  deny network inet6,

  # Deny everything else
  deny /**,
}
