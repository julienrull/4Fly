# TODO

## IMPLEMENTATIONS
- [x] Create encoder test ENV
- [x] Create fragmenter script 
## BUGS
- [ ] During fragmentation process video is faster than audio and even block, only audio remain (it's seems comming from timescale and sample duration that need to be multiply by 
      25,6. But how does 25,6 calculated ?
    - video too fast )-:<
    - video block itself after couple of second )-:<
    - audio work (-:|
- [ ] Mdat fragment data hasn't the good size with specific videos

# NOTES
Hello World ! Here is a safe space to express yourself !
---
- One of my video has a sort of delay after play it from the start. In this elapsed time, the time stay at 0 seconds
