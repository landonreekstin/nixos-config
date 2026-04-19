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
    CXX      = g++
    CXXFLAGS = -std=c++17 -Wall -Wextra -g

    # Override with: make FILE=two_sum
    FILE ?= solution

    .PHONY: all run clean

    all: $(FILE)

    $(FILE): $(FILE).cpp
    	$(CXX) $(CXXFLAGS) -o $@ $<

    run: $(FILE)
    	./$(FILE)

    clean:
    	rm -f $(FILE)
  '';

  tasksJson = ''
    {
      "version": "2.0.0",
      "tasks": [
        {
          "label": "Build Active File",
          "type": "shell",
          "command": "make",
          "args": ["FILE=''${fileBasenameNoExtension}"],
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
      echo "$content" > "${path}"
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
