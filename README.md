TF2 Throwable Sapper
===============

This plugin allows you to throw your sapper and sap buildings in a radius around the thrown sapper.

Similar to "Meet the Spy".

# 2023 update
* Fix a bug where throwing the sapper after a round ends broke the sapper until server restart or map change
* Added a convar "sap_type" which allows server owners to choose which sapper they want throwable, 0 for normal sapper, 1 for red tape recorder, 2 for both. Defaults to 1
* Added a convar "sap_count" which allows server owners to change the amount of throwable sappers the spy has. Defaults to 1
* Added a convar "throwsap_keep_disguise" which allows server owners to change whether the spy keeps his disguise while throwing a sapper, 0 for false, 1 for true. Defaults to 1
* Added a convar "throwsap_damage" which allows server owners to change the amount of damage the sapper does per tick to buildings. Defaults to 2