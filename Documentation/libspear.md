
# How to build LibSpear

To build Libspear, simply type the following commands:

```sh
git submodule init
cd LibSpear
scons
```

After reloading the project the changes should be visible in the editor.

If you want to have autocompletion in your LSP/IDE, you can generate CompileDB (compile_commands.json) with a following command:

```sh
scons cdb
```

If you want to debug LibSpear, use the following build command:

```sh
scons debug_symbols=yes optimize=debug
```

After that you can use your favourite debugger and run Godot inside Polyspear's root directory to debug it.

# Cross-compilation

## On Linux

SCons allows for easy cross-compilation. If you have MinGW-w64 installed (probably available in your distro's repositories under `mingw-w64` name or similar) the following command should *just work*:
```sh
scons target=windows
```

## On Windows

TODO (might be worth looking into WSL or MSYS2)

# Diagnostics

BattleManager currently has a variable called `debug_check_fast_bm_integrity` which checks each time a move is done whether results of a move replicated in BattleManagerFast match results in a regular BM.
