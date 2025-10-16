// Increase server memory to handle SuperDirt's effects
s.options.memSize = 8192 * 32; // 256 MB
s.options.numBuffers = 1024 * 64;

s.waitForBoot {
        ~dirt = SuperDirt(2, s);
        ~dirt.loadSoundFiles;
        s.sync;
        ~dirt.start(57120, 0!12);
        "SuperDirt started on port 57120".postln;
    }
