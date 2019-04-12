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
		version = "1.0",
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

	if not uri:match("file:///") then
		return
	end

	local file = vlc.input.item():metas()["filename"]
	local name = file:sub(0, (file:len() - getFileExtension(file):len()))

	local dir = ""
	if is_linux then
		dir = uri:sub(8, (uri:len() - file:len()  - 1))
	else
		dir = uri:sub(9, (uri:len() - file:len())):gsub("/", "\\")
	end

	local path = dir .. file;

	local opts = {}
	local found_audio = false
	local found_sub = false

	local cmd = ""
	if is_linux then
		-- find "/media/serfreeman1337/Datacore/anilib/Mirai Nikki [BDRip 720]" -name "*\[Sensetivity-raws\] Mirai Nikki - 11*"
		cmd = [[find "]] .. dir .. [[" -name "*]] .. name:gsub("%[", "\\["):gsub("%]", "\\]") .. [[*"]] -- lol linux ???

		for exclude in exclude_with:gmatch("%S+") do
			cmd = cmd .. [[ | grep -v "]] .. exclude .. [["]]
		end
	else
		-- dir /s /b "E:\anilib\Mirai Nikki [BDRip 720]\*[Sensetivity-raws] Mirai Nikki - 13*"
		cmd = [[dir /s /b "]] .. dir .. [[*]] .. name .. [[*"]]

		for exclude in exclude_with:gmatch("%S+") do
			cmd = cmd .. [[ | find /V "]] .. exclude .. [["]]
		end
	end

	for f in io.popen(cmd):lines() do
		if not is_linux then
			-- windows encoding fix
			f = vlc.strings.from_charset("cp866", f)
		end

		-- skip current file
		if f ~= path then
			local f_ext = getFileExtension(f)

			-- search for external audio tracks
			for a_ext in audio_ext:gmatch("%S+") do
				if f_ext:find(a_ext) then
					found_audio = true
					table.insert(opts, "input-slave=" .. vlc.strings.make_uri(f))
					break
				end
			end

			-- search for sub files
			for a_ext in sub_ext:gmatch("%S+") do
				if f_ext:find(a_ext) then
					found_sub = true
					table.insert(opts, "sub-file=" .. f)
					break
				end
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
		if v["Type"] == "Audio" then
			total_audio = total_audio + 1
		elseif v["Type"] == "Subtitle" then
			total_sub = total_sub + 1
		end
	end

	if found_sub then
		-- select subtitles
		table.insert(opts, "sub-track=" .. total_sub)
	end

	if found_audio then
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
