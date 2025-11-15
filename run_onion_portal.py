#!/usr/bin/env python3
import os
import shutil
import subprocess
import sys
import time
import textwrap
from pathlib import Path
from typing import List, Optional, Sequence, Tuple


def supports_color() -> bool:
    if not sys.stdout.isatty():
        return False
    if shutil.which("tput") is None:
        return False
    try:
        result = subprocess.run(
            ["tput", "colors"], check=False, capture_output=True, text=True
        )
    except Exception:
        return False
    if result.returncode != 0:
        return False
    try:
        count = int((result.stdout or "").strip() or "0")
    except ValueError:
        return False
    return count >= 8


if supports_color():
    C_RESET = "\033[0m"
    C_BOLD = "\033[1m"
    C_MAGENTA = "\033[35m"
    C_CYAN = "\033[36m"
    C_YELLOW = "\033[33m"
    C_GREEN = "\033[32m"
    C_RED = "\033[31m"
else:
    C_RESET = ""
    C_BOLD = ""
    C_MAGENTA = ""
    C_CYAN = ""
    C_YELLOW = ""
    C_GREEN = ""
    C_RED = ""


PROJECT_NAME = "darkweb_portal"
SERVICE_URLS: Sequence[Tuple[str, str]] = (
    ("Tor Browser (noVNC)", "http://localhost:5800"),
    ("I2P Browser (noVNC)", "http://localhost:5801"),
    ("I2P Router Console", "http://localhost:7657"),
)
I2P_SERVICE_NAME = "i2p-browser"
I2P_PROXY_PREFS = {
    "network.proxy.http": "127.0.0.1",
    "network.proxy.http_port": 4444,
    "network.proxy.share_proxy_settings": False,
    "network.proxy.socks": "",
    "network.proxy.socks_port": 0,
    "network.proxy.socks_version": 5,
    "network.proxy.ssl": "127.0.0.1",
    "network.proxy.ssl_port": 4444,
    "network.proxy.type": 1,
    "network.proxy.no_proxies_on": "localhost,127.0.0.1",
    "network.proxy.allow_hijacking_localhost": True,
    "network.proxy.socks_remote_dns": False,
    "media.peerconnection.ice.proxy_only": True,
    "keyword.enabled": False,
}
_COMPOSE_CMD: Optional[List[str]] = None


def log_info(msg: str) -> None:
    print(f"{C_CYAN}[INFO]{C_RESET} {msg}")


def log_ok(msg: str) -> None:
    print(f"{C_GREEN}[OK]{C_RESET}  {msg}")


def log_err(msg: str) -> None:
    print(f"{C_RED}[ERR]{C_RESET} {msg}", file=sys.stderr)


def run_command(args: Sequence[str], capture: bool = False) -> subprocess.CompletedProcess:
    return subprocess.run(args, check=False, capture_output=capture, text=True)


def get_compose_base_cmd() -> Optional[List[str]]:
    global _COMPOSE_CMD
    if _COMPOSE_CMD is not None:
        return _COMPOSE_CMD

    docker_bin = shutil.which("docker")
    if docker_bin:
        result = run_command([docker_bin, "compose", "version"], capture=True)
        if result.returncode == 0:
            _COMPOSE_CMD = [docker_bin, "compose"]
            return _COMPOSE_CMD

    docker_compose_bin = shutil.which("docker-compose")
    if docker_compose_bin:
        _COMPOSE_CMD = [docker_compose_bin]
        return _COMPOSE_CMD

    return None


def run_compose(
    compose_file: Path,
    args: Sequence[str],
    capture: bool = False,
) -> Optional[subprocess.CompletedProcess]:
    cmd = get_compose_base_cmd()
    if not cmd:
        log_err(
            "Docker Compose no está disponible. Instala Docker Compose V2 "
            "(docker compose) o V1 (docker-compose)."
        )
        return None

    full_cmd = [
        *cmd,
        "-f",
        str(compose_file),
        "--project-name",
        PROJECT_NAME,
        *args,
    ]
    return run_command(full_cmd, capture=capture)


def print_service_urls() -> None:
    print()
    print(f"{C_YELLOW}URLs de acceso a los servicios:{C_RESET}")
    for label, url in SERVICE_URLS:
        print(f"  {C_BOLD}{label}:{C_RESET} {url}")
    print()


def start_stack(compose_file: Path) -> None:
    log_info("Iniciando Darkweb Portal (Tor + I2P)...")
    result = run_compose(compose_file, ["up", "-d", "--build"])
    if result is None:
        return
    if result.returncode == 0:
        log_ok("Darkweb Portal en ejecución.")
        if wait_for_service(compose_file, I2P_SERVICE_NAME, timeout=120):
            ensure_i2p_proxy_settings(compose_file)
        else:
            log_err(
                "No fue posible verificar el navegador I2P en ejecución; "
                "no se aplicaron los ajustes de proxy."
            )
        print_service_urls()
    else:
        log_err(f"No se pudo iniciar Darkweb Portal (código {result.returncode}).")


def stop_stack(compose_file: Path) -> None:
    log_info("Deteniendo Darkweb Portal...")
    result = run_compose(compose_file, ["down"])
    if result is None:
        return
    if result.returncode == 0:
        log_ok("Darkweb Portal detenido.")
    else:
        log_err(f"No se pudo detener Darkweb Portal (código {result.returncode}).")


def show_status(compose_file: Path) -> None:
    log_info("Estado actual del Darkweb Portal:")
    result = run_compose(compose_file, ["ps"])
    if result is None:
        return
    if result.returncode != 0:
        log_err(f"No se pudo obtener el estado (código {result.returncode}).")


def show_logs(compose_file: Path) -> None:
    log_info("Mostrando últimos logs (Ctrl+C para salir)...")
    try:
        result = run_compose(compose_file, ["logs", "--tail", "50", "-f"])
    except KeyboardInterrupt:
        print()
        log_info("Logs detenidos por el usuario.")
        return

    if result is None:
        return
    if result.returncode != 0:
        log_err(f"No se pudieron mostrar los logs (código {result.returncode}).")


def wait_for_service(
    compose_file: Path,
    service: str,
    timeout: int = 120,
    poll_interval: float = 2.0,
) -> bool:
    deadline = time.time() + timeout
    while time.time() < deadline:
        result = run_compose(
            compose_file,
            ["ps", "--services", "--filter", "status=running"],
            capture=True,
        )
        if result is not None and result.returncode == 0:
            names = [line.strip() for line in (result.stdout or "").splitlines()]
            if service in names:
                return True
        time.sleep(poll_interval)
    return False


def ensure_i2p_proxy_settings(compose_file: Path) -> None:
    python_script = textwrap.dedent(
        f"""
        from pathlib import Path

        prefs_path = Path("/config/firefox/i2p.default/user.js")
        if not prefs_path.exists():
            raise SystemExit(0)

        desired = {repr(I2P_PROXY_PREFS)}

        def format_value(value):
            if isinstance(value, str):
                return '"{{}}".format(value)'
            if isinstance(value, bool):
                return "true" if value else "false"
            return str(value)

        def build_line(key, value):
            return 'user_pref("{{0}}", {{1}});'.format(key, format_value(value))

        lines = prefs_path.read_text().splitlines()
        updated_lines = []
        seen = set()

        for line in lines:
            stripped = line.strip()
            if stripped.startswith('user_pref("'):
                key = stripped.split('"', 2)[1]
                if key in desired:
                    updated_lines.append(build_line(key, desired[key]))
                    seen.add(key)
                    continue
            updated_lines.append(line)

        for key, value in desired.items():
            if key not in seen:
                updated_lines.append(build_line(key, value))

        prefs_path.write_text("\\n".join(updated_lines) + "\\n")
        """
    ).strip()

    shell_script = (
        "set -e\n"
        'prefs_file="/config/firefox/i2p.default/user.js"\n'
        'if [ ! -f "$prefs_file" ]; then\n'
        "  exit 0\n"
        "fi\n"
        "python3 - <<'PY'\n"
        f"{python_script}\n"
        "PY\n"
    )

    result = run_compose(
        compose_file,
        ["exec", "-T", I2P_SERVICE_NAME, "sh", "-c", shell_script],
    )
    if result is None:
        return
    if result.returncode == 0:
        log_ok("Configuración de proxy de I2P sincronizada.")
    else:
        log_err(
            "No se pudo actualizar la configuración de proxy de I2P. "
            "Revisa el contenedor manualmente."
        )


def print_menu() -> None:
    os.system("clear" if os.name == "posix" else "cls")
    logo_lines = r"""
________                __     __      __      ___.     __________              __         .__   
\______ \ _____ _______|  | __/  \    /  \ ____\_ |__   \______   \____________/  |______  |  |  
 |    |  \\__  \\_  __ \  |/ /\   \/\/   // __ \| __ \   |     ___/  _ \_  __ \   __\__  \ |  |  
 |    `   \/ __ \|  | \/    <  \        /\  ___/| \_\ \  |    |  (  <_> )  | \/|  |  / __ \|  |__
/_______  (____  /__|  |__|_ \  \__/\  /  \___  >___  /  |____|   \____/|__|   |__| (____  /____/
        \/     \/           \/       \/       \/    \/                                   \/      
    """
    print(f"    {C_MAGENTA}{logo_lines}{C_RESET}")
    print(f"                {C_BOLD}{C_MAGENTA}+-----------------------------------------+{C_RESET}")
    print(f"                {C_MAGENTA}|{C_RESET}     [1] Iniciar Darkweb Portal          {C_MAGENTA}|{C_RESET}")
    print(f"                {C_MAGENTA}|{C_RESET}     [2] Detener Darkweb Portal          {C_MAGENTA}|{C_RESET}")
    print(f"                {C_MAGENTA}|{C_RESET}     [3] Mostrar estado actual           {C_MAGENTA}|{C_RESET}")
    print(f"                {C_MAGENTA}|{C_RESET}     [4] Ver logs en vivo                {C_MAGENTA}|{C_RESET}")
    print(f"                {C_MAGENTA}|{C_RESET}     [5] Mostrar URLs de acceso          {C_MAGENTA}|{C_RESET}")
    print(f"                {C_MAGENTA}|{C_RESET}     [6] Salir                           {C_MAGENTA}|{C_RESET}")
    print(f"                {C_BOLD}{C_MAGENTA}+-----------------------------------------+{C_RESET}")


def back_to_menu() -> None:
    back = input("¿Quieres volver al menú principal? (s/n): ").strip().lower()
    if back not in {"s", "si", "y", "yes"}:
        print("Hasta pronto.")
        sys.exit(0)


def main() -> None:
    compose_path = Path(
        os.environ.get(
            "DARKWEB_PORTAL_COMPOSE_FILE",
            Path(__file__).resolve().parent / "docker-compose.yml",
        )
    ).resolve()
    if not compose_path.exists():
        log_err(f"No se encontró el archivo docker-compose.yml en {compose_path}.")
        return

    while True:
        print_menu()
        try:
            choice = input("Selecciona una opción [1-6]: ").strip().lower()
        except EOFError:
            print()
            return

        if choice == "1":
            start_stack(compose_path)
            back_to_menu()
        elif choice == "2":
            stop_stack(compose_path)
            back_to_menu()
        elif choice == "3":
            show_status(compose_path)
            back_to_menu()
        elif choice == "4":
            show_logs(compose_path)
            back_to_menu()
        elif choice == "5":
            print_service_urls()
            back_to_menu()
        elif choice == "6" or choice in {"q", "quit", "salir", "exit"}:
            print("Hasta pronto.")
            return
        else:
            log_info("Opción no reconocida.")
            back_to_menu()


if __name__ == "__main__":
    main()
