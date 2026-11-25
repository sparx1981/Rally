# Recorded vehicle audio

Paper Rally edits these source recordings into short mono game sounds. Edits include cropping, pitch stabilisation, equalisation, level changes and seamless overlaps. Product names identify the source vehicles.

| Source file for the preparation script | Original recording | Creator and licence | Game sounds |
| --- | --- | --- | --- |
| mini.mp3 | [Car Engine Contact Recording-Mini Cooper S 2019.wav](https://freesound.org/people/TheLittleCrow/sounds/669618/) | TheLittleCrow, [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Compact bank |
| wrx.mp3 | [WRX - Exhaust sounds](https://freesound.org/people/ulose2piranha/sounds/273334/) | ulose2piranha, [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Boxer idle and low RPM |
| brz.mp3 | [FR-S BRZ GT-86 Vortech Supercharged Dyno Run](https://freesound.org/people/dezoris/sounds/191194/) | dezoris, [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) | Boxer mid/high RPM and overrun |
| supra.mp3 | [Import car revs on Chassis Dyno with Turbo.wav](https://freesound.org/people/editboy23/sounds/496171/) | editboy23, [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Turbo bank |
| cortina.mp3 | [DR09DynoRun70ishFordCortina328HP-finalA.wav](https://freesound.org/people/Ears68/sounds/177183/) | Ears68, [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Heavy bank |
| gravel.mp3 | [Car driving on a gravel dirt road, close recording of front wheel from outside](https://freesound.org/people/felix.blume/sounds/685231/) | felix.blume, [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Gravel loop |
| gravel_tires.mp3 | [Car Tires Start and Stop on Gravel Shoulder.wav](https://freesound.org/people/UnplugTheFridge/sounds/529225/) | UnplugTheFridge, [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Sliding and braking on gravel |
| wet_pass.mp3 | [Passing Car (Wet road)](https://freesound.org/people/Breviceps/sounds/462862/) | Breviceps, [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Wet tyre loop |
| antilag.mp3 | [Car Antilag (No cleanup, 32float)](https://freesound.org/people/modusmogulus/sounds/797835/) | modusmogulus, [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | Three high-RPM lift-off bursts |

To regenerate the game assets, obtain the high-quality MP3 previews of the linked recordings, name them as above, then run `python3 tools/prepare_recorded_audio.py /path/to/sources`. The driver reference clips supplied to Paper Rally were used to compare the mix.
