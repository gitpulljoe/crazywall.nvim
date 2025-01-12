*NOTE: Currently only works on MacOS & Linux*

# 📌crazywall📌

**crazywall** is a fast, fully-customizable command-line tool for organizing your notes, refactoring code, moving text in and out of files, and more!

You can create your own schema to define how a text file should be split into sections, and write your own callbacks to decide how to handle these sections.

Table of Contents
-----------------
 * [Features](#features)
 * [Installation](#installation)
    * [Requirements](#requirements)
 * [Getting Started](#getting-started)
 * [Examples](#examples)
 * [Usage](#usage)
    * [Main Workflow](#main-workflow)
    * [Arguments](#arguments)
    * [Collision Resolution](#collision-resolution)
 * [The SUS Pattern](#the-sus-pattern)
 * [Assumptions](#assumptions)

## Features

- **custom schema**
    - define your own section "types" and decide which strings should open/close them
- **custom collision handling**
    - write your own callbacks to resolve:
         - local collisions (two sections mapped to the same file)
         - nonlocal collisions (a section mapped to an existing file)
    - choose how many collision retries to allow
- **plans & actions**
     - see which files/directories *will* be made before executing
- support for nested notes and various indent levels
- toggleable dry-run mode (no filesystem changes)
- toggling local/nonlocal overwrites
- multiple configs for different workflows
- robust type validation (no foot-guns here)
- readable, user-friendly error messages

## Installation

### Requirements
 - Lua 5.3+
 - A UNIX-based OS

You can install `crazywall` using the following commands:

```bash
cd ~ # or wherever you wish to install
git clone https://github.com/gitpushjoe/crazywall.lua.git crazywall
cd crazywall
sudo ln -s $(realpath ./cw.sh) /usr/bin/cw
```

## Getting Started

crazywall includes built-in global defaults, geared towards use in Markdown notes. You can gain a better understanding of the default behavior [here](./core/defaults/config.lua). For example, the first item of the `note_schema` is `{ "h1", "# ", "[!h1]" }`, which means that if you create a file `./foo.md`:

```md
<!-- foo.md --!>
# My Note
(Important stuff) [!h1]

Something else!
```

then the first two lines will be parsed as a section, since the first line starts with `"# "` and the second line ends with `"[!h1]"`. So, this would be the result if you ran `$ cw foo.md` with default settings:

```md
<!-- foo.md --!>
[[ My Note ]]

Something else!
```
```md
<!-- My Note.md --!>
# My Note
(Important stuff)
```

Let's say you wanted just `"[!h]"` to end all sections. Instead of modifying `./core/defaults/config.lua`, you can create a custom configuration in `./configs.lua`. The file should export a table where each config is mapped to a string. If you have a config mapped to `"DEFAULT"` (caps-sensitive), then crazywall will give this config priority over the other one, and fall back to the global defaults only when necessary. To use a specific custom config (e.g. `"foo"`), run `$ cw --config foo` or `$ cw -c foo`.

Here's an example `./configs.lua` setup to use `"[!h]"` for all close tags.

```lua
--- ./configs.lua
local utils = require("core.utils")
local Path = require("core.path")

---@type table<string, PartialConfigTable>
local configs = {

  DEFAULT = {
    note_schema = {
      { "h1", "# ", "[!h]" },
      { "h2", "## ", "[!h]" },
      { "h3", "### ", "[!h]" },
      { "h4", "#### ", "[!h]" },
      { " - h1", "- # ", "[!h]" },
      { " - h2", "- ## ", "[!h]" },
      { " - h3", "- ### ", "[!h]" },
      { " - h4", "- #### ", "[!h]" },
    },
  },

}

return configs
```

## Examples

There are currently five custom config examples in the [examples folder](./examples/). These examples, however, are primarily meant as a reference and starting point, as you are highly encouraged to write your own configs that are tailored to your particular workflow.

## Usage

To understand what each config option does, it's helpful to explain what happens when you run `cw`.

### Main Workflow

1. **Command-line arguments are parsed**
    - See [Arguments](#arguments).
2. **Some initialization is done.**
    - A [`Config`](./core/config.lua) object is created, based on the specified `--config` or `"DEFAULT"`. Missing options are filled in using global defaults from `./core/defaults/config.lua`.
    - A [`Context`](./core/context.lua) object is created using the config, the text of the source file, and the command line arguments.
3. **The source text is parsed (see [`fold.parse`](./core/fold.lua)).**
    - The entire source file is modeled as a doubly-linked tree of `Section` nodes, which can be traversed via `section.parent` and `section.children`.
    - A [`Section`](./core/section.lua) object is created with note type `{ "ROOT" }`, representing the entire source text. 
    - crazywall then parses the file using `config.note_schema`. `config.note_schema` should be a list of "note types", where each "note type" is a list of 3 strings:
        - the name of the note type
        - the open tag
        - the close tag
    - If the open tag is at the beginning of a line (excluding whitespace) it will create a new section, and if the close tag is at the end of a line, it will close the current section.
        - If the entire section is indented (e.g. each line of the section starts with at least 3 tabs), then crazywall will automatically remove these tabs whenever `section:get_lines()` is called.
    - Below is an example document, and the structure of the tree that will be created (using the default config).

```md
# Fruits
    - Bananas
    ## Apples
        - Red Delicious
        - Granny Smith
    [!h2]
    - Orange
    - Grapes
[!h1]

# Vegetables [!h1]
```

```txt
* ROOT section (lines 1 - 11)
├── * h1 section (lines 1 - 9)
│   └── * h2 section (lines 3 - 6)
└── * h1 section (lines 11 - 11)
```

4. **Some preparation is done (see [`fold.prepare`](./core/fold.lua)).**
   - First, paths are resolved for each section.
      - The root section has its `section.path` manually set to the destination path speciffied by the command-line arguments (defaults to the same path as the source file).
      - All other sections are visited [in preorder](https://commons.wikimedia.org/wiki/File:Preorder-traversal.gif) (i.e. outtermost-in). For each section,
          - crazywall will try to assign the `Path` object returned from `config.resolve_path( read_only(section), read_only(ctx) ) -> Path` to `section.path`.
              - If the `Path` is `Path.void()`, then the section will not be saved to a file.
              - If the `Path` returned has already been assigned to a different section
                  - and `config.allow_local_overwrite == true`, then the current section will be assigned the path, and the other section will be assigned `Path.void()`.
                  - Otherwise, crazywall will save the path as `original_path` and try to resolve the collision up to `config.local_retry_count` times. See [Collison Resolution](#collision-resolution).

    - Then, the output for each section and references are determined.
        - The sections are visited [in postorder](https://commons.wikimedia.org/wiki/File:Postorder-traversal.gif) (i.e. innermost-out). For each section,
            - crazywall will assign the lines returned from `config.transform_lines ( read_only(section), read_only(ctx) ) -> string[]` to `section.lines`. The function should return an **array of strings.** During the "execute" step, this text will be joined together with newlines and saved to `section.path`. 
            - *If this section is a parent section, then all child sections nested within it, will be converted to references (see below).*
            - Then, crazywall will call `config.resolve_reference( read_only(section), read_only(ctx) ) -> string|false`. 
                - If the function returns a string, then the first line of the section in the source text will be replaced with the string, and all other lines will be deleted. (If the entire section is indented, then the reference will be indented as well.)
                - If the function returns `false`, then *all* of the lines of the section will be deleted in the source text.
        - `config.transform_lines(...)` will not be called on the root sectoin.

5. **crazywall executes the fold in dry-run mode (see [`fold.prepare`](./core/fold.lua)).**
    - Regardless of whether or not `--dry-run` was actually passed, crazywall will always do a dry-run before executing. In this step, a [`Plan`](./core/plan/plan.lua) gets created, detailing all the filesystem changes that will be made.
    - The sections are preorder traversed. For each section:
        - If a file or directory already exists at `section.path`
            - and `config.allow_overwrite == true`, then crazywall will continue to the next step.
            - Otherwise, crazywall will save `section.path` as `original_path` and try to resolve the collision up to `config.retry_count` times. See [Collision Resolution](#collision-resolution). If the collision resolution is successful, a `"RENAME"` action will be added to the plan.
        - If the directory of `section.path` exists, then a `"WRITE"` or `"OVERWRITE"` action is added to the plan.
            - If the directory does not exist and `config.allow_makedir == false`, then an error will be thrown.
            - Otherwise, a `"MKDIR"` action will be added first, to create the neceessary directories and subdirectories.
            - Any `section` that was assigned the path `Path.void()` will get an `"IGNORE"` action.
    - Finally, the `Plan` object is returned.

6. If `--dry-run` was passed, then crazywall will exit here, otherwise step 5 will be repeated in non-dry-run mode, so every time an action (such as `"MKDIR"` or `"WRITE"`) is added to the plan, it will be executed.

### Arguments

To run crazywall on a file, you can simply run `$ cw <file>`. You can add any of the following arguments before or after the source file.

|Argument|Description|
|-|-|
|`--config <config>`, `-c <config>`|Uses the config named <config> in `configs.lua`. Defaults to `"DEFAULT"`.
|`--dry-run`, `-dr`|Enable dry-run, which will not modify or add any new files or directories.
|`--help`, `-h`|Prints the helptext.
|`--no-ansi`, `-na`|Disables ANSI coloring.
|`--out <file>`, `-o <file>`|Sets the destination for the new source text to `<file>`. Defaults to the path to the source file.
|`--plan_stream <stream>`, `-ps <stream>`|The stream to print the crazywall plan object to. (0 for none, 1 for stdout, 2 for stderr.)  Defaults to 1.
|`--preserve`, `-p`|Will not edit the source file.
|`--text-stream <stream>`, `-ts <stream>`|The stream to print the updated source text to. (0 for none, 1 for stdout, 2 for stderr.)  Defaults to 1.
|`--version`, `-v`|Prints the current version.
|`--yes`, `-y`|Automatically confirm all prompts.

### Collision Resolution

crazywall offers two types of collision resolution:
 - **Local collisions:** two sections are assigned the same path by `config.resolve_path`.
 - **Nonlocal collisions:** a file is assigned the same path as an existing file.

In both cases, the strategy is similar:

> a. Save the path as `original_path`.
> 
> b. Set `retry_count` to 0.
> 
> c. If `config.local_retry_count` (in the local case) or `config.retry_count` (in the nonlocal case) has been reached, throw an error.
> 
> d. Call `config.resolve_collision( original_path:copy(), read_only(section), read_only(ctx), retry_count ) -> Path`.
> 
> e. For local collisions, check if another section has that path. For nonlocal sections, check if the path is occupied by another file.
>  - If the path is "free", then the section will be assigned the path.
>  - Otherwise increment `retry_count` and go back to step (c).

## The SUS Pattern

Interestingly, the following two things are possible with sections:

 - `config.resolve_path(section, ctx)` can return `Path.void()`, which means that the section will not be written to another file.
- `config.resolve_reference(section, ctx)` can return a string that contains newlines in it.

So, for example, if a section was assigned the path `Path.void()` and the reference `section:open_tag() .. section:get_text() .. section:close_tag()`, then it would appear as though the section was not changed. More importantly, you can use this to create a **Self-Updating Section**, where you return from `config.resolve_reference` the text you want the section to be updated to. For an example of this, see the "execute" note type in [./examples/code/](./examples/code/configs.lua). The section runs the command inside it in the terminal, and updates itself with the output. Some of the other examples use this pattern as well.

## Assumptions

crazywall makes two important assumptions to keep behavior simple and predictable:

- Two paths with the same string reprsentation are the same, and two paths with different string representations are different. Because of this, **the [`Path`](./core/path.lua) class used only works with absolute paths**, and will throw an error if a relative path is given. To use `"~/"` and `"./"`, see [`Path:join()`](./core/path.lua).
- No relevant filesystem changes occur between running `cw` and confirming. As stated previously, regardless of whether `--dry-run` was passed, crazywall will always do a dry-run before making any filesystem changes. If you run `cw`, then add or delete files, and then confirm, crazywall might nto be able to stick to the plan object it presented to you.
