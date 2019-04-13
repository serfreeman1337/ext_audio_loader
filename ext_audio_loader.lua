audio_ext = ".mka .ogg .ac3"
sub_ext = ".ass .srt"
exclude_with = ".unwanted" -- skip qBittorrent dummy files

is_linux = true

function descriptor()
	return {
		title = "Ext audio and subtitles loader",
		author = "serfreeman1337",
		shortdesc = "Autoload external audio track and subtitles",
		description = "This script searches in folder for audio and subtitles for video and loads them",
		url = "https://github.com/serfreeman1337/ext_audio_loader",
		version = "1.1",
		capabilities = {"input-listener"}
	}
end

function activate()
	if os.getenv("OS") then
		is_linux = false
	end
end

function deactivate()
end

function meta_changed()
end

function input_changed()
	if not vlc.input.is_playing() then
		return
	end

	-- lol what is this
	if vlc.input.item():metas()["sf_autoloaded_from"] == "yes" then
		return
	end

	if vlc.input.item():metas()["sf_autoloaded"] == "yes" then
		local itemid = vlc.input.item():metas()["sf_autoloaded_itemid"]

		if not(itemid:len() == 0) then
			itemid = tonumber(itemid)

			-- playlist order fix
			-- vlc.playlist.move(vlc.playlist.current(), itemid)
			vlc.playlist.delete(itemid)
			vlc.playlist.sort("title")
			-- vlc.playlist.sort("id")
			vlc.input.item():set_meta("sf_autoloaded_itemid", "")
		end

		return
	end

	local uri = vlc.strings.decode_uri(vlc.input.item():uri())

	if not uri:match("file:///") then return end

	local file = vlc.input.item():metas()["filename"]
	local name = file:sub(0, (file:len() - getFileExtension(file):len()))

	local dir = ""
	if is_linux then
		dir = uri:sub(8, (uri:len() - file:len()  - 1))
	else
		dir = uri:sub(9, (uri:len() - file:len() - 1))
	end

	local path = dir .. file;

	local opts = {}
	local found_audio = false
	local found_sub = false

	local r = search(dir, name)

	if r ~= nil then
		for k, v in pairs(r) do
			-- fix windows path
			if not is_linux then v = v:gsub("/", "\\") end

			if k == "extaudio" then
				found_audio = true
				table.insert(opts, "input-slave=" .. vlc.strings.make_uri(v))
			elseif k == "subtitles" then
				found_sub = true
				table.insert(opts, "sub-file=" .. v)
			end
		end
	end

	if not found_audio and not found_sub then
		return
	end

	-- count tracks so we can select our autoloaded ones
	local total_audio = 0
	local total_sub = 0
	for k, v in pairs(vlc.input.item():info()) do
		-- TODO: figure out how to get input streams info
		if (v["Type"] == "Audio" or v["Тип"] == "Аудио") then
			total_audio = total_audio + 1
		elseif (v["Type"] == "Subtitle" or v["Тип"] == "Субтитры") then
			total_sub = total_sub + 1
		end
	end

	if found_sub then
		-- select subtitles
		table.insert(opts, "sub-track=" .. total_sub)
	end

	if found_audio then
		-- what
		if total_audio == 0 then total_audio = 1 end
		-- select external audio track
		table.insert(opts, "audio-track=" .. total_audio)
	end

	local item = {{
		path = vlc.input.item():uri(),
		options = opts,
		meta = {
			["sf_autoloaded"] = "yes",
			["sf_autoloaded_itemid"] = tostring(vlc.playlist.current())
		}
	}}

	-- lol what is this
	vlc.input.item():set_meta("sf_autoloaded_from", "yes")

	vlc.playlist.add(item)
end

function getFileExtension(url)
	return url:match("^.+(%..+)$")
end

function is_dir(path)
	if is_linux then
		local f = io.open(path, "r")
		local ok, err, code = f:read(1)
		f:close()
		return code == 21
	else -- dir is nil on windows
		local f = vlc.io.open(path, "r")
		if f == nil then
			return true
		else
			f:close()
			return false
		end
	end
end

function is_matched(name, with)
	for what in with:gmatch("%S+") do
		if name:find(what, 0, true) ~= nil then
			return true	end
	end
	return false
end

function search(dir, name)
	local dr = vlc.io.readdir(dir)

	if dr == nil then
		return nil
	end

	local r = {}
	local found = false
	local path = ""

	for k, content in pairs(dr) do
		-- skip top level and excluded dirs
		if content ~= "." and content ~= ".." and not is_matched(content, exclude_with) then
			path = dir .. [[/]] .. content

			if not is_dir(path) then
				-- look for file with the same name
				if content:find(name, 0, true) then

					-- search for external audio tracks
					if is_matched(content, audio_ext) then
						r["extaudio"] = path
						found = true
					elseif is_matched(content, sub_ext) then
						r["subtitles"] = path
						found = true
					end
				end
			else -- recursive directory scan
				local rr = search(path, name)

				if rr ~= nil then
					for k, v in pairs(rr) do r[k] = v end
					found = true
				end
			end
		end
	end

	if found then return r else return nil end
end
