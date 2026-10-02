"""Install/check the latest approved beginner and capitalist assets."""
from install_combat_picxel_assets import check_installed as check, install_assets as install, run_cli


def check_installed():
    return check(('beginner', 'capitalist'))


def install_assets(source=None):
    install(('beginner', 'capitalist'), source=source)


if __name__ == "__main__":
    run_cli(('beginner', 'capitalist'))
