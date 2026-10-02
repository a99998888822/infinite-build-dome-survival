"""Install/check approved Boss textures and matching SpriteFrames."""
from install_combat_picxel_assets import check_installed as check, install_assets as install, run_cli


def check_installed():
    return check(('boss',))


def install_assets(source=None):
    install(('boss',), source=source)


if __name__ == "__main__":
    run_cli(('boss',))
