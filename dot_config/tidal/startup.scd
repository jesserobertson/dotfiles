s.waitForBoot {
        ~dirt = DuperDirt(2, s);
        ~dirt.loadSoundFiles;
        s.sync;
        ~dirt.start(57120, 0!12)
    }
