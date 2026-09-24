from pathlib import Path
import shutil

source = Path(__file__).resolve().parents[2]
target = Path.home() / '.codex' / 'reviews' / 'capital-dependency-20260924' / 'project'
target.mkdir(parents=True, exist_ok=True)
for directory in ('scripts', 'scenes', 'autoloads', 'data_config', 'assets', 'shaders'):
    shutil.copytree(source / directory, target / directory, dirs_exist_ok=True)
for filename in ('icon.svg', 'project.godot'):
    shutil.copy2(source / filename, target / filename)
project = (target / 'project.godot').read_text(encoding='utf-8')
project = project.replace('[application]', '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="CapitalDependencyValidation20260924"')
(target / 'project.godot').write_text(project, encoding='utf-8')
print(target)
