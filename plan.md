# plan

## Moving forward

### Technical pre-work that needs doing

- [ ] Sort out glad headers for use in zig
- [ ] Find good candidate for GLM replacement for zig

### Dealing with OBJ files

- [ ] Figure out what different parts are.
  - [ ] Read `o` line (probably ignore?)
  - [ ] Read vertex lines (`v f32 f32 f32`)
  - [ ] Read index lines (`f usize/usize/usize usize/usize/usize usize/usize/usize`)
  - [ ] Research what `s off` means
  - [ ] Read normals (`vn f32 f32 f32`?)
  - [ ] Read textures(?) (`vt f32 f32`?)
  - [ ] Research what `l usize usize` means
- [ ] Read file into internal object/model structure.
- [ ] Render this efficiently with respect to index maps, etc.

### Graphics work

- [ ] Figure out basic (M)odel(V)iew(P)rojection stuff
