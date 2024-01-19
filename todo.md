# IMPLEMENTATIONS
- [x] Create encoder test ENV
- [x] Create fragmenter script 
- [x] Last segment case
- [x] All cmd
# BUGS
- [ ] Some memory leaks make the program crash when there are a lot of fragment
- [ ] During fragmentation process video is faster than audio and even block, only audio remain (it's seems comming from timescale and sample duration that need to be multiply by 
      25,6. But how does 25,6 calculated ?
    - video too fast )-:<
    - video block itself after couple of second )-:<
    - audio work (-:|
- [x] Mdat fragment data hasn't the good size with specific videos

# NOTES


