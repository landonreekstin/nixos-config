# ~/nixos-config/modules/home-manager/development/cpp-practice.nix
{ lib, config, customConfig, ... }:

let
  cfg = customConfig.profiles.development.cpp-practice;
  dir = "${config.home.homeDirectory}/cpp_practice";

  envrcContent = ''
    # Managed by your NixOS config. Activates the C++ practice dev shell.
    use flake ~/nixos-config#cpp-practice
  '';

  makefileContent = ''
    # Single-file exercise builds.
    #   make   c FILE=bit_drills     -> builds exercises/bit_drills.c   -> ./bit_drills
    #   make run-c FILE=bit_drills   -> builds and runs it
    #   make     FILE=two_sum        -> builds exercises/two_sum.cpp    -> ./two_sum
    #   make run FILE=two_sum        -> builds and runs it

    CC       = gcc
    CFLAGS   = -std=c11 -Wall -Wextra -Wconversion -g

    CXX      = g++
    CXXFLAGS = -std=c++17 -Wall -Wextra -g

    FILE ?= solution
    SRCDIR ?= exercises

    .PHONY: all c run run-c clean

    all: $(FILE)

    # ---- C++ ----
    $(FILE): $(SRCDIR)/$(FILE).cpp
    	$(CXX) $(CXXFLAGS) -o $@ $<

    run: $(FILE)
    	./$(FILE)

    # ---- C ----
    # -Wconversion is deliberate: it flags the implicit narrowing that Phase E1 exists to eliminate.
    # Do not remove it to silence a warning -- the warning is the lesson.
    c:
    	$(CC) $(CFLAGS) -o $(FILE) $(SRCDIR)/$(FILE).c

    run-c: c
    	./$(FILE)

    clean:
    	rm -f $(FILE) *.o
  '';

  # Binaries land at the repo root (the Makefile builds -o $(FILE) from $(SRCDIR)/$(FILE).<ext>),
  # so FILE is the bare basename and the debugger looks for the binary at the workspace root.
  tasksJson = ''
    {
      "version": "2.0.0",
      "tasks": [
        {
          "label": "Build Active File",
          "type": "shell",
          "command": "if [ \"''${fileExtname}\" = \".c\" ]; then make c FILE=''${fileBasenameNoExtension}; else make FILE=''${fileBasenameNoExtension}; fi",
          "group": { "kind": "build", "isDefault": true },
          "presentation": { "reveal": "always", "panel": "shared", "clear": true },
          "problemMatcher": "$gcc"
        }
      ]
    }
  '';

  launchJson = ''
    {
      "version": "0.2.0",
      "configurations": [
        {
          "name": "Build and Debug Active File",
          "type": "cppdbg",
          "request": "launch",
          "program": "''${workspaceFolder}/''${fileBasenameNoExtension}",
          "args": [],
          "stopAtEntry": false,
          "cwd": "''${workspaceFolder}",
          "externalConsole": false,
          "MIMode": "gdb",
          "miDebuggerPath": "gdb",
          "preLaunchTask": "Build Active File",
          "setupCommands": [
            { "text": "-enable-pretty-printing", "ignoreFailures": true }
          ]
        }
      ]
    }
  '';

  writeIfChanged = path: content: ''
    content=${lib.escapeShellArg content}
    if [ ! -f "${path}" ] || [ "$(cat "${path}")" != "$content" ]; then
      [ -L "${path}" ] && rm "${path}"
      printf '%s' "$content" > "${path}"
    fi
  '';
in
{
  config = lib.mkIf cfg.enable {
    home.activation.createCppPracticeFiles = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "${dir}/.vscode"

      ${writeIfChanged "${dir}/.envrc" envrcContent}
      ${writeIfChanged "${dir}/Makefile" makefileContent}
      ${writeIfChanged "${dir}/.vscode/tasks.json" tasksJson}
      ${writeIfChanged "${dir}/.vscode/launch.json" launchJson}
    '';
  };
}
