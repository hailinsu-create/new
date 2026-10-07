"""Install the shared public key on Beijing B with a one-time password login.

Used only when key login says "Permission denied (publickey)" and a root password has
been shared. The password is read from BJB_SSH_PASSWORD or the shared env files and is
never printed or stored in the repo. Appending is idempotent. After this, key login is
used again for everything else.

    python install_ssh_key.py
Exit codes: 0 key installed or already present, 4 no password, 5 password login failed.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import autodl_power as power  # noqa: E402

PASSWORD_FILES = (
    Path("/cursor/stores/user/bjb-ssh-password.env"),
    Path("/workspace/cred-handoff/bjb-ssh-password.env"),
    Path("/cursor/stores/user/bjb-ssh.env"),
)


def read_password() -> str | None:
    value = os.environ.get("BJB_SSH_PASSWORD")
    if value:
        return value
    for path in PASSWORD_FILES:
        value = power.read_env_file(path).get("BJB_SSH_PASSWORD")
        if value:
            return value
    return None


def append_command(pub_line: str) -> str:
    quoted = pub_line.replace("'", "'\\''")
    return (
        "umask 077; mkdir -p /root/.ssh && touch /root/.ssh/authorized_keys && "
        f"(grep -qxF '{quoted}' /root/.ssh/authorized_keys || echo '{quoted}' >> /root/.ssh/authorized_keys) && "
        "chmod 700 /root/.ssh && chmod 600 /root/.ssh/authorized_keys && echo KEY_INSTALLED"
    )


def main() -> int:
    env = power.read_env_file(power.SSH_ENV)
    host = env.get("BJB_SSH_HOST", "connect.bjb2.seetacloud.com")
    port = int(env.get("BJB_SSH_PORT", "34711"))
    user = env.get("BJB_SSH_USER", "root")
    key = Path(env.get("BJB_SSH_KEY_PATH", "/cursor/stores/user/bjb791"))
    pub_line = Path(str(key) + ".pub").read_text(encoding="utf-8").strip()
    password = read_password()
    if not password:
        print("NEED_SSH_PASSWORD no BJB_SSH_PASSWORD in the environment or the shared env files.")
        return 4
    import paramiko

    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        client.connect(
            host, port=port, username=user, password=password,
            look_for_keys=False, allow_agent=False, timeout=20, banner_timeout=30, auth_timeout=30,
        )
    except Exception as exc:  # noqa: BLE001
        print(f"PASSWORD_LOGIN_FAILED {type(exc).__name__}")
        return 5
    try:
        _, stdout, stderr = client.exec_command(append_command(pub_line), timeout=30)
        out = stdout.read().decode("utf-8", "replace")
        err = stderr.read().decode("utf-8", "replace")
    finally:
        client.close()
    if "KEY_INSTALLED" not in out:
        print(f"KEY_INSTALL_FAILED {err[:200]}")
        return 5
    print("KEY_INSTALLED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
