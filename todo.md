# IMPLEMENTATIONS

- [x] Create encoder test ENV
- [x] Create fragmenter script 
- [x] Last segment case
- [x] All cmd
- [ ] Big function to handle any box reading
- [ ] Rewrite new_segment() and create_fragment()
- [ ] Rewrite create_manifest()
- [ ] Rewrite create_init(), must copy src file by substraction
- [ ] add lvl to Atom wrapper

# BUGS

- [x] Mdat fragment data hasn't the good size with specific videos
- [ ] Some memory leaks make the program crash when there are a lot of fragment
- [ ] During fragmentation process video is faster than audio and even block, only audio remain (it's seems comming from timescale and sample duration that need to be multiply by 25,6. But how does 25,6 calculated ?
- [ ] There is a frame drop at 5 seconds since I rewrite get_first_sample(),
  this drop may be the cause of a shift that cut the end of the video.

# NOTES

