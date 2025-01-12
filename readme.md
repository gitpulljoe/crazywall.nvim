*NOTE: Currently only works on MacOS & Linux*

# 📍crazywall.nvim📍

A Neovim wrapper of [crazywall](https://github.com/gitpushjoe/crazywall.lua).

Table of Contents
-----------------
 * [Installation](#installation)
    * [Requirements](#requirements)
    * [lazy.nvim](#lazynvim)
    * [packer.nvim](#packernvim)
 * [Examples](#examples)
 * [API](#api)
    * [Default Configuration](#default-configuration)
    * [User Commands](#user-commands)
         * [:Crazywall](#crazywall-output_style-on_unsaved-src_path-dest_path)
         * [:CrazywallDry](#crazywalldry-output_style-on_unsaved-src_path-dest_path)
         * [:CrazywallQuick](#crazywallquick-on_unsaved-src_path-dest_path)
         * [:CrazywallListConfigs](#crazywalllistconfigs)
         * [:CrazywallSetConfig](#crazywallsetconfig-config_name)
         * [:CrazywallFollowRef](#crazywallfollowref)
         * [:CrazywallVersion](#crazywallversion)
    * [Lua API](#lua-api)
         * [add_config](#requirecrazywalladd_configname-string-config-partialconfigtable)
         * [Crazywall Modules](#crazywall-modules)
    * [Highlight Groups](#highlight-groups) 

## Installation

### Requirements
> [!Note]
> crazywall itself is not a requirement, it comes bundled with the plugin.
 - neovim 0.9+ (I think)
 - A UNIX-based OS

You can install crazywall.nvim with the typical plugin managers.

### lazy.nvim
```lua
{
   "gitpulljoe/crazywall.nvim"
}
```

### packer.nvim
```lua
use {
   "gitpulljoe/crazywall.nvim"
}
```

## Examples

You can find examples in the [./core/examples/](./core/examples/) folder.

## API

### Default Configuration

```lua
require("crazywall").setup({ 
   --- crazywall configs go here
   configs = {
      --- See https://github.com/gitpushjoe/crazywall.lua/blob/main/core/defaults/config.lua.
      DEFAULT = {}
   },
   default_config_name = "DEFAULT",
   --- See :CrazywallFollowRef
   follow_ref = function(line, _column, _config, _config_name)
      ---@param path string
      local file_exists_and_is_not_directory = function(path)
         local stat = vim.loop.fs_stat(path)
         return stat ~= nil and stat.type == "file"
      end
      --- Find text within [[]]s.
      local match = string.match(line, "%[%[(.-)%]%]")
      if not match then
         return
      end
      local current_file_dir = vim.fn.expand("%:p:h")
      local extension = '.' .. vim.fn.expand("%:e")
      ---@param path string
      local expand_path = function(path)
         return vim.fn.fnamemodify(current_file_dir .. "/" .. path, ":p")
      end
      ---@param path string
      local open_path = function(path)
         vim.cmd("edit " .. vim.fn.fnameescape(path))
      end
      for _, path in ipairs({
         expand_path(match .. extension),
         expand_path(match),
         expand_path(match .. "/_index" .. extension),
         }) do
         if file_exists_and_is_not_directory(path) then
            open_path(path)
            return
         end
      end
      print(
         "Default :CrazywallFollowRef failed. Read the docs to see how you can customize its behavior: https://github.com/gitpulljoe/crazywall.nvim"
      )
   end
})
```

### User Commands

> [!Note]
>
> `<>` -> means required
> 
> `()` -> means optional

#### `:Crazywall (output_style) (on_unsaved) (src_path) (dest_path)`

Applies crazywall to a file, with a confirmation window. Use `:w` to confirm the action, and `:q` to decline. 

Equivalent of `$ cw {src_path} --out {dest_path} --plan-stream` `1`|`0` `--text-stream` `1|0`.

 * `output_style` 
      * `"both"|"planonly"|"textonly"`
      * **Default:** `"both"`
      * Display just the plan information, or just the final text, or both.

 * `on_unsaved`
      * `"warn"|"write"`
      * **Default:** `"warn"`
      * Emit a warning when the `src_path` is unsaved or automatically write the file, and then continue.

 * `src_path`
      * **Default:** `vim.fn.expand("%")` (the current file)

 * `dest_path`
      - **Default:** `vim.fn.expand("%")` (the current file)

#### `:CrazywallDry (output_style) (on_unsaved) (src_path) (dest_path)`

Runs crazywall in dry-run mode on a file.

Equivalent to `$ cw --dry-run {src_path} --out {dest_path} --plan-stream` `1`|`0` `--text-stream` `1|0`.

 - `output_style` 
   - `"both"|"planonly"|"textonly"`
   - **Default:** `"both"`
   - Display just the plan information, or just the final text, or both.

 - `on_unsaved`
   - `"warn"|"write"`
   - **Default:** `"warn"`
   - Emit a warning when the `src_path` is unsaved or automatically write the file, and then continue.

 - `src_path`
   - **Default:** `vim.fn.expand("%")` (the current file)

 - `dest_path`
   - **Default:** `vim.fn.expand("%")` (the current file)

#### `:CrazywallQuick (on_unsaved) (src_path) (dest_path)`

Applies crazywall to a file, skipping the confirmation window. 

Equivalent to `$ cw {src_path} --out {dest_path} --yes`.

 - `on_unsaved`
   - `"warn"|"write"`
   - **Default:** `"warn"`
   - Emit a warning when the `src_path` is unsaved or automatically write the file, and then continue.

 - `src_path`
   - **Default:** `vim.fn.expand("%")` (the current file)

 - `dest_path`
   - **Default:** `vim.fn.expand("%")` (the current file)

#### `:CrazywallListConfigs`

Lists all configs, indicating which one is currently active.

#### `:CrazywallSetConfig <config_name>`

Sets the currently active config to `<config_name>`.

#### `:CrazywallFollowRef`

Runs `follow_ref( line: string, column: integer, config: Config, current_config_name: string )` with the current `line`, `column`, `config`, and `current_config_name`. Can be used to navigate to different files from references.

#### `:CrazywallVersion`

Prints the current crazywall.nvim version and the version of crazywall.lua being used.

### Lua API

#### `require("crazywall").add_config(name: string, config: PartialConfigTable)`

Registers a new config with the name `name`. If there is already a config with name `name`, then the previous one will be overwritten.

#### Crazywall Modules

```lua
--- See https://github.com/gitpushjoe/crazywall.lua/blob/main/core/path.lua
local Path = require("crazywall").Path
--- See https://github.com/gitpushjoe/crazywall.lua/blob/main/core/utils.lua 
local utils = require("crazywall").utils
--- See https://github.com/gitpushjoe/crazywall.lua/blob/main/core/context.lua 
local Context = require("crazywall").Context
--- See https://github.com/gitpushjoe/crazywall.lua/blob/main/core/section.lua 
local Section = require("crazywall").Section
--- See https://github.com/gitpushjoe/crazywall.lua/blob/main/core/config.lua 
local Config = require("crazywall").Config
```

### Highlight Groups

```
CrazywallPlanHeading
CrazywallTextHeading
CrazywallPlanCreate
CrazywallPlanOverwrite
CrazywallPlanMkdir
CrazywallPlanIgnore
CrazywallPlanRename
CrazywallText
```
