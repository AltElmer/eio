# eio

EIO is the Elmer I/O library: the component that reads and writes an Elmer model directory — the mesh, its geometry, the solver and material sections, and the partitioning used for parallel runs. It was written by Harri Hakula in 1998 and maintained as part of [Elmer FEM](https://github.com/ElmerCSC/elmerfem) until 2016.

**Elmer does not use it any more, and this repository does not pretend otherwise.** Elmer 8.0's release notes record that the internal `LoadMesh` work "eliminates the need of old 'eio' library", and its replacement is `fem/src/MeshIO.F90`, which still carries the comment *"This is a Fortran replacement for the old C++ eio library."* EIO was removed from the Elmer tree on 30 November 2016.

What this repository does is make EIO a component in its own right: it builds standalone on Linux, macOS and Windows with four compilers, it has tests, and it can be consumed by a parent project unchanged. That is worth doing because EIO still defines and implements the on-disk format that Elmer reads and that `ElmerGrid` and `Mesh2D` write, and because a format implementation that only exists inside one program is hard to check, hard to reuse and easy to break.

## Provenance, and where the history came from

EIO appears in ElmerCSC/elmerfem with only eight commits, because GitHub is not where it was developed. Elmer's history before the 2014 GitHub migration lives in a Subversion repository that is still online at [sourceforge.net/p/elmerfem](https://sourceforge.net/p/elmerfem/), and `trunk/eio` has 69 revisions there going back to 19 April 2005.

The history in this repository is those 69 Subversion revisions, converted with `git svn`, followed by the GitHub-era commits replayed on top. **The join is proven rather than assumed:** the last Subversion revision and elmerfem `3d60e132f` have the same eio tree hash, `02c5b889a46d588c44de853847984360e8381a49`, and the replayed history ends at `939bdcdd92fd13c7d894e8558d7078fbda409dea`, which is byte for byte the eio tree Elmer deleted in 2016. 76 commits, 2005 to 2016.

Two caveats worth stating rather than hiding:

- **Author names are Subversion usernames**, mapped to `<username>@users.sourceforge.net`. Guessing at real identities from a handle would put wrong names on other people's commits, so the handles are kept as they are. Anyone who knows the mapping is welcome to correct it.
- **One commit is a linearisation.** `257bd6c53` sits on a side branch and reached Elmer's `devel` through a merge, so what is recorded here is its net effect on `eio/`. The commit message says so.

The Subversion repository is not a curiosity: it is the only public record of what happened to these components between 2005 and 2014, and the same is true of `front`, `matc` and `meshgen2d`.

## Licence: LGPL 2.1, with an inconsistency upstream should fix

Peter Råback moved EIO from GPL to LGPL on 30 April 2012, in commit `68f3ed9` — *"Moved eio library under LGPL license (was GPL)"*. That is the licence this repository is under.

The inconsistency: **that commit changed only `src/*.cpp`.** All twelve headers under `include/` still carry a plain GPL notice, so the implementation is LGPL and the headers that declare it are not. Upstream's own `license_texts/LICENSES_GPL.txt` still lists `eio` among the GPL modules, and `ElmerLicensePolicy.md` names `matc` and `fhutiter` as LGPL without mentioning `eio`. For a library the distinction is not cosmetic, because it decides what may link against it.

Nothing here changes any licence notice. The finding belongs upstream, and the headers are left exactly as they were found.

## Building

Requires CMake 3.12 or newer and a C++ compiler. A Fortran compiler is optional.

```
cmake -S . -B build
cmake --build build
ctest --test-dir build --output-on-failure
```

Two libraries are produced:

| target | what it is | needs Fortran |
| --- | --- | --- |
| `eioc` | the C++ binding, and the whole implementation | no |
| `eiof` | the Fortran binding, module `EIOFortranAPI` — the one Elmer's solver linked against | yes |

`eiof` is skipped, with a message, when no Fortran compiler is found, which is the normal case under MSVC. That is a degraded build, not a broken one, and CI asserts which targets each job produced so a job cannot go green having quietly built half the library.

Binaries for each platform and compiler are on the [releases page](https://github.com/AltElmer/eio/releases). There is no single artifact that works everywhere: this is native code, and a Fortran `.mod` file is specific to the compiler that produced it, so each archive names its compiler as well as its platform.

## Tests

EIO's own `TODO` file has said `- write tests` since 2005. It now has two.

- **`eio_roundtrip`** writes a four-node mesh through the C++ binding, closes it, reopens it and reads it back, asserting the counts, the node tags and the coordinates. It checks the `info` out parameter of every call, because every EIO entry point reports through one and returning is not the same as succeeding.
- **`eio_read_fortran`** reads a mesh checked into `tests/square/` through `eiof`, so the binding Elmer actually used is exercised rather than merely built. It deliberately reads a fixture rather than the file the other test just wrote: a reader that agrees only with its own writer would pass a round trip while being wrong about Elmer's format.

Both assert on printed output as well as exit status, and CI counts the registered tests per job, so a skipped test cannot be mistaken for a passing one.

## What had to change to build outside Elmer

The same pattern that showed up extracting `ElmerGrid`, `matc` and `meshgen2d`: the component had absorbed assumptions from the top of the Elmer tree, and they only become visible once it is on its own.

- **`#if defined(MINGW32)`** guarded every Windows branch in `EIOModelManager.cpp`. `MINGW32` is not defined by any compiler; Elmer's root build passed it. Under MSVC the guard therefore fell through to `#include <unistd.h>` and the build stopped. The Windows branch was already written and correct — `_mkdir`, `_stat`, `_access`, `_getcwd`, `_umask` — so the fix is to key on `_WIN32`, which both MinGW and MSVC define themselves, and which no parent has to remember to pass.
- **`#include "../config.h"`**, in six files, only ever resolved because Elmer added `${PROJECT_BINARY_DIR}/eio/src` to the include path so that `../config.h` climbed back out to the generated header. The generated header is now `eio_build_config.h`, included by name. The rename also removes a real hazard: Elmer has a `fem/config.h` too, and two directories both offering `config.h` on the include path is a coin toss.
- **`USE_ISO_C_BINDINGS`** was commented out in the config template and had to be supplied by the caller, but it is not optional: the Fortran side binds to explicitly named lowercase C symbols, so `FC_FUNC` has to be the identity mapping. Getting it wrong produces link errors rather than a diagnostic, so the build sets it.

## Things found along the way

These are reported rather than fixed, because they are upstream's to decide.

**`eio_api.h` has not been parseable since 7 March 2014.** Commit `3a5b171ee`, "Corrected EIO mesh reading.", added a `part` parameter to `eio_get_mesh_element_conns` and dropped the semicolon at the end of the declaration. The header sat broken for twelve years because nothing includes it — the library's own sources include the individual agent headers instead, and `eio_api.h` is documentation that never gets compiled. Writing a test that includes it is what found this. The semicolon is restored here.

**`EIOPartReader.cpp` has never compiled, in twenty years.** It calls `sprintf(newdir, "%s/partitioning.%d", meshdir, parts)` and `meshdir` is not a member of the class and is not declared anywhere in the tree; the identifier appears in the initial commit of April 2005 and nowhere since. `EIOPartReader` has never appeared in any of EIO's build files, autotools or CMake. It is excluded from the build here and kept in the tree: it is the only description of how reading a partitioned mesh was meant to work, and deciding its fate is upstream's call, not this repository's.

**`eio_api.cpp` is the superseded single-binding API**, replaced by `eio_api_c.cpp` and `eio_api_f.cpp`. It no longer compiles either. Same treatment, same reasoning.

**Autotools is not the question it looks like.** EIO gained a CMake build in October 2013 (`a3399bf`, "First public beta version of CMake configuration scripts") and Peter Råback deleted its autotools files in November 2016 (`e42473d52`, `abbf31fc0`). The project answered this one itself, nine years ago; this repository follows it.

## Using it inside Elmer

The CMake here works both ways. As the top level project it supplies its own `project()`, language settings and tests; added with `ADD_SUBDIRECTORY(eio)` it takes those from the parent, registers no tests, and produces the same `eioc` and `eiof` targets under the same names Elmer linked against. CI builds it both ways, and asserts that the subdirectory build adds nothing to its parent.

## Related

Part of an effort to make Elmer's components separable, discussed upstream in [ElmerCSC/elmerfem#202](https://github.com/ElmerCSC/elmerfem/issues/202). The other extractions: [AltElmer/matc](https://github.com/AltElmer/matc), [AltElmer/meshgen2d](https://github.com/AltElmer/meshgen2d), and [AltElmer/elmerfront](https://github.com/AltElmer/elmerfront), which is an archive rather than a module and says so.

This is not an official CSC distribution.
