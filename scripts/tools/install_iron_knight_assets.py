"""Install/check approved Boss textures and matching SpriteFrames."""
import argparse
from install_combat_picxel_assets import check_installed as check, install_assets as install


def check_installed():
    return check(('boss',))


def install_assets():
    install(('boss',))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    check_installed() if args.check else install_assets()
