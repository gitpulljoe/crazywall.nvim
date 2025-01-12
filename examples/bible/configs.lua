local Path = require("core.path")
local utils = require("core.utils")

---@type table<string, PartialConfigTable>
local configs = {

	bible = {
		note_schema = {
			{ "verses", "{{ ", " }}" },
		},

		resolve_path = function()
			return Path.void()
		end,

		transform_lines = function()
			return {}
		end,

		resolve_reference = function(section)
			local line = section:get_lines()[1]
			local book, chapter, starting_verse, ending_verse, version =
				line:match("(%d*%s*%w*) (%d+):(%d+)-(%d+) ?(%w*)")
			if not book then
				book, chapter, starting_verse, version = line:match("(%d*%s*%w*) (%d+):(%d+) ?(%w*)")
				ending_verse = starting_verse
			end
			if not book then
				--- Restore the section if it was unable to be parsed.
				return section:open_tag() .. section:get_lines() .. section:close_tag()
			end
			version = #version > 0 and version or "ASV"
			local check_jq = "(jq --version >/dev/null 2>/dev/null)"
			local jq_not_installed_msg = "echo 'Error: `jq` needs to be installed for this example.'"
			local curl_cmd = "(curl https://raw.githubusercontent.com/wldeh/bible-api/refs/heads/main/bibles/en-"
				.. version:lower()
				.. "/books/"
				.. book:lower():gsub(" ", "")
				.. "/chapters/"
				.. chapter
				.. ".json 2>/dev/null)"
			local jq_parse_json = "(jq -M -r '.data[] | select((.verse | tonumber) >= "
				.. starting_verse
				.. " and (.verse | tonumber) <= "
				.. ending_verse
				.. ") | .text' 2>/dev/null) | head -"
				.. (ending_verse - starting_verse + 1)
				.. ""
			local curl_cmd_failed = "echo 'Error: Curl command failed.'"
			local jq_cmd_failed = "echo 'Error: `jq` command failed.'"
			local cmd = string.format(
				"(%s || (%s && false)) && ((%s || (%s >&2 && false)) | (%s && true || %s)) 2>&1",
				check_jq,
				jq_not_installed_msg,
				curl_cmd,
				curl_cmd_failed,
				jq_parse_json,
				jq_cmd_failed
			)
			local handle = io.popen(cmd)
			local result = utils.read_from_handle(handle) or ""
			local output = "> **" .. line .. "**" .. "\n> "
			if utils.str.starts_with(result, "Error") or starting_verse == ending_verse then
				output = output .. result
				return output
			end
			local verse = starting_verse
			for verse_txt in utils.str.split_lines(result) do
				output = output .. "[" .. verse .. "] " .. verse_txt .. " "
				verse = verse + 1
				if verse > math.tointeger(ending_verse) then
					break
				end
			end
			output = output:sub(1, #output - 1)
			return output
		end,

		allow_overwrite = true,
	},
}

return configs
