"""Heavy flail hit based on the old plasma sound selected by the user."""
from pathlib import Path
import numpy as np
from scipy.io import wavfile
from combat_audio_revision_round2 import RATE, meteor_from_old_plasma

root = Path(__file__).resolve().parents[2]
destination = root / "assets/audio/sfx/combat/meteor_flail_hit.wav"
wavfile.write(destination, RATE, np.round(meteor_from_old_plasma()*32767).astype(np.int16))
print(destination)
