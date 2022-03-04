# Clang Toolbox
**A python script to extract documented internal Clang tools from their official
binary builds.**

> NOTICE: This project is on hiatus.

This is intended to serve the purpose of version management for the most part.
Clang's internal "formatter" `clang-format` has many versions with breaking
changes that make older configuration files inoperable. Clang's "linter"
`clang-tidy` can only operate using preexisting style conventions like Google,
LLVM, GNU, so on and so forth; which limits it's use for people like myself
because we get a headache when operating on code not formatted "properly".

> Yes, I care about formatting that much. I don't like having constant headaches
  when I'm trying to write code. Probably OCD / my autistic need for consistency
	or something. Regardless it's an issue.

Neither have true configuration backwards compatibility; though `clang-tidy`
does have less opportunities to run into issues as a result.

Outside version management, I also work on a laptop with EMMC Flash of 32GB.
So I don't want multiple full Clang+LLVM builds clustering my system which
currently has around 2GB of internal space left for me to work with. I've added
a stream extraction option to this script which yanks things directly out of the
air instead of using intermediate caching. However, for security reasons, this
will not happen without explicit authorization and if you have the RAM to spare,
It's better to use a ramdisk with PGP verification.

While writing this script to extract `clang-format` versions, I discovered
static analysis tools and that Clang also has an internal tool for this called
`clang-check`. So I expanded the scope of this project to include all internal
Clang tools with the goal of having this script embed-able into any C project's
tool chest.

*I though this would be easy, but apparently I couldn't have been more mistaken.*
the `proof-of-concept.sh` script was written to generate a heuristic profile
for the binary builds hosted on the [LLVM Clang builds][llvm-clang-github-releases].
I discovered that though the project uses CMake, the binary builds still follow
an Autotools-like output structure. All binaries will be in the `bin` directory,
so I didn't have to make a for OS specific configuration jargon. ***That was easy!***

When I initially looked at the LLVM Clang build names, I noticed that they were
very close in structure to the [Rust Language platform triple specification][rust-platform-triple-spec].
I assumed this meant that I could use the Python interpreter's ELF header,
to generate a target triple to match a binary build with *some light modification*
However, automating fetching the clang builds for the proper version of Linux is
virtually impossible ***right now*** due to the following:
 * Clang builds are distributed by volunteers without oversight and
   as a consequence, build naming isn't moderated. While the build names
   vaguely reflect the [Rust Target Triple spec][rust-platform-triple-spec]
   It's clear this was likely unintentional. Most clang releases use *Linux* as
   vendor. The OS type is usually the name of a distro, which I could work around
   if there was any consistency to that; some distro versions are put in the
   environment section, and some are attatched directly to the distro name.
   Even the architecture name isn't consistent. Some use `x86_64` properly, others
   use a limited `amd64` when the build actually supports `x86_64`.

 * The only method for fetching OS information is the `/etc/os-release` file, which
   isn't 100% cross platform. While limiting the scope of this project to 90% of
   available binary builds is something I'm willing to do, because the
   [freedesktop.org `os-release` Specification][os-release-spec] doesn't even
   have a configuration option for specifying parent distro *version* compatibility,
   There's no reliable enough way to ensure OS compatibility **or** even ABI
   compatibility between the local machine and any target cloud build.

So while I'm waiting on my inquiries to pass through the freedesktop.org and
LLVM volunteer email pipelines, this project will be on indefinite hiatus.

When prototyping this script, I wrote a tiny curses GUI for selecting a binary
build yourself, which is still in the code so it *should* still usable. Just not
without manual intervention.


Best regards,
Ruby Allison Rose


[rust-platform-support]: https://doc.rust-lang.org/nightly/rustc/platform-support.html
[rust-platform-triple-spec]: https://rust-lang.github.io/rfcs/0131-target-specification.html
[llvm-clang-github-releases]: https://github.com/llvm/llvm-project/releases/tag/llvmorg-13.0.1
[os-release-spec]: https://www.freedesktop.org/software/systemd/man/os-release.html
