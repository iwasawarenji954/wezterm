local wezterm = require("wezterm")
local config = wezterm.config_builder()

config.automatically_reload_config = true
config.font_size = 12.0
-- 視認性向上: 行間を少し広げる
config.line_height = 1.08
-- macOS Terminal のデフォルトに近いフォント構成
-- ベース: Menlo / フォールバック: Symbols Nerd Font でアイコン維持
config.font = wezterm.font_with_fallback({
  "Menlo",
  "Symbols Nerd Font Mono",
  "SF Mono",
  "Monaco",
  "Apple Color Emoji",
})
config.use_ime = true
-- 背景の透過を抑えてコントラストを上げる
config.window_background_opacity = 0.97
-- ぼかしを無効化してにじみを軽減
config.macos_window_background_blur = 0
-- 太字で極端に明るくしない
config.bold_brightens_ansi_colors = false
-- macOS のネイティブフルスクリーンを使用
config.native_macos_fullscreen_mode = true

----------------------------------------------------
-- Tab
----------------------------------------------------
-- タイトルバーを表示
config.window_decorations = "TITLE | RESIZE"
-- タブバーの表示
config.show_tabs_in_tab_bar = true
-- タブが一つの時は非表示
config.hide_tab_bar_if_only_one_tab = true
-- falseにするとタブバーの透過が効かなくなる
-- config.use_fancy_tab_bar = false

-- タブバーの透過
config.window_frame = {
  inactive_titlebar_bg = "none",
  active_titlebar_bg = "none",
}

-- タブバーを背景色に合わせる
config.window_background_gradient = {
  colors = { "#000000" },
}

-- タブの追加ボタンを非表示
config.show_new_tab_button_in_tab_bar = false
-- nightlyのみ使用可能
-- タブの閉じるボタンを非表示
config.show_close_tab_button_in_tabs = false

-- タブ同士の境界線を非表示
config.colors = {
  -- テキスト/背景のコントラストを高める
  foreground = "#e6e9ef",
  background = "#0f1115",
  -- カーソル視認性
  cursor_bg = "#e6e9ef",
  cursor_border = "#e6e9ef",
  cursor_fg = "#0f1115",
  -- 選択範囲のコントラスト
  selection_bg = "#334155",
  selection_fg = "#e6e9ef",
  -- タブバー境界線は非表示のまま
  tab_bar = {
    inactive_tab_edge = "none",
  },
}

-- タブの表示内容をカスタマイズ（プロセスアイコン + ディレクトリ名）
local function basename(path)
  if not path or path == "" then
    return ""
  end
  return path:gsub("(.*[/\\])", "")
end

-- 作業ディレクトリを短く見やすくする
-- 非アクティブ: 末尾2セグメントのみ (.../parent/repo)
-- アクティブ:   末尾3セグメントを左省略 (../grand/parent/repo)
local function compact_dir(path, opts)
  opts = opts or {}
  local is_active = opts.active or false
  if not path or path == "" then return "" end
  -- HOME を ~ に
  local home = os.getenv("HOME")
  if home and path:sub(1, #home) == home then
    path = "~" .. path:sub(#home + 1)
  end
  -- 末尾のスラッシュを除去
  path = path:gsub("/+%$", ""):gsub("/$", "")
  -- セグメント分割
  local parts = {}
  for part in path:gmatch("[^/]+") do
    table.insert(parts, part)
  end

  local function join_last(n)
    if #parts <= n then
      return table.concat(parts, "/")
    end
    local slice = {}
    for i = #parts - n + 1, #parts do
      table.insert(slice, parts[i])
    end
    return table.concat(slice, "/")
  end

  if is_active then
    local n = 3
    if parts[1] == "~" then
      if #parts > n + 1 then
        return "~/../" .. join_last(n)
      else
        -- ~ を残して残りを全表示
        return "~/" .. table.concat({table.unpack(parts, 2)}, "/")
      end
    else
      if #parts > n then
        return "../" .. join_last(n)
      else
        return table.concat(parts, "/")
      end
    end
  else
    if #parts <= 2 then
      return table.concat(parts, "/")
    end
    local last2 = parts[#parts - 1] .. "/" .. parts[#parts]
    if parts[1] == "~" then
      if #parts > 3 then
        return "~/.../" .. last2
      else
        return "~/" .. last2
      end
    end
    return ".../" .. last2
  end
end

local function process_icon(pane)
  local name = pane.foreground_process_name or ""
  name = name:match("([^/]+)$") or name
  -- Nerd Font アイコン（フォントが入っている前提）
  if name:find("n?vim") then return "" end
  if name:find("lazygit") then return "" end
  if name:find("node") then return "" end
  if name:find("python") then return "" end
  if name:find("ssh") then return "󰣀" end
  if name:find("zsh") or name:find("bash") or name:find("fish") or name == "sh" then return "" end
  return "" -- デフォルト: ターミナル
end

-- タイトルからファイルパスらしき文字列を抽出
local function extract_file_from_title(title)
  if not title or title == "" then return nil end
  -- 1) スラッシュを含むパス
  local p = title:match("([~%w%._%-%/%+]+/%S+)")
  if p then return p end
  -- 2) 拡張子付きファイル名（相対）
  p = title:match("([~%w%._%-%/]+%.[%w_%-]+)")
  if p then return p end
  -- 3) 最後のトークンがそれっぽければ
  p = title:match("([^%s]+)$")
  if p and (p:find("/") or p:find("%.") or p:find("~")) then return p end
  return nil
end

local function last_segments(path, n)
  local parts = {}
  for part in tostring(path):gmatch("[^/]+") do table.insert(parts, part) end
  if #parts <= n then return table.concat(parts, "/") end
  local slice = {}
  for i = #parts - n + 1, #parts do table.insert(slice, parts[i]) end
  return table.concat(slice, "/")
end

local function expand_home(path)
  local home = os.getenv("HOME")
  if not path or path == "" then return path end
  if path:sub(1,1) == "~" and home then
    return home .. path:sub(2)
  end
  return path
end

local function relative_from_cwd(file, cwd)
  if not file or file == "" then return nil end
  -- normalize ./
  file = tostring(file):gsub("^%./", "")
  local cwd_abs = expand_home(cwd)
  local file_abs = file
  if file_abs:sub(1,1) == "~" then
    file_abs = expand_home(file_abs)
  end
  -- already relative
  if file_abs:sub(1,1) ~= "/" then
    return file
  end
  if cwd_abs and file_abs:find(cwd_abs .. "/", 1, true) == 1 then
    return file_abs:sub(#cwd_abs + 2)
  end
  return nil, file_abs
end

-- ルート探索とプロジェクトタグ推定 ------------------------------------------------
local function dirname(p)
  if not p or p == "" then return "" end
  local d = p:match("^(.*)/[^/]+/?$")
  return d or "/"
end

local function file_exists(p)
  local f = io.open(p, "r")
  if f then f:close() return true end
  return false
end

local function read_text(p, limit)
  local f = io.open(p, "r")
  if not f then return nil end
  local data = f:read(limit or 4096)
  f:close()
  return data
end

local project_cache = {}

local function detect_project_tag_from_root(root)
  -- ユーザーオーバーライド
  local tag_file = root .. "/.wezterm-tag"
  if file_exists(tag_file) then
    local t = read_text(tag_file, 128)
    if t then
      t = t:gsub("\r?\n.*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
      if #t > 0 then return t:upper(), "#ae8b2d" end
    end
  end

  -- 言語/スタックごとの判定
  local pkg = root .. "/package.json"
  if file_exists(pkg) then
    local txt = read_text(pkg, 16384) or ""
    if txt:find('"react"') or txt:find('"next"') then
      return "REACT", "#26c6da" -- cyan
    end
    return "NODE", "#6cc24a"
  end

  if file_exists(root .. "/pyproject.toml") or file_exists(root .. "/requirements.txt") or file_exists(root .. "/Pipfile") then
    return "PY", "#3776ab"
  end

  if file_exists(root .. "/Cargo.toml") then
    return "RUST", "#dea584"
  end

  if file_exists(root .. "/go.mod") then
    return "GO", "#00ADD8"
  end

  if file_exists(root .. "/main.tex") or file_exists(root .. "/paper.tex") or file_exists(root .. "/thesis.tex") then
    return "TEX", "#8f8f8f"
  end

  -- フォルダ名キーワード
  local root_name = basename(root)
  if root:lower():find("codex") or root_name:lower() == "codex" then
    return "CODEX", "#ae8b2d"
  end
  if root:lower():find("research") or root:lower():find("lab") then
    return "LAB", "#9b59b6"
  end

  -- デフォルト: ルート名
  return (root_name ~= "" and root_name:upper() or "PROJECT"), "#5c6d74"
end

local function find_project_root(cwd)
  local p = expand_home(cwd)
  if not p or p == "" then return nil end
  -- 末尾スラッシュ除去
  p = p:gsub("/$", "")
  local tries = 12
  while p and p ~= "" and tries > 0 do
    -- キャッシュ
    if project_cache[p] then return p end
    -- 判定: .git/HEAD, package.json, pyproject.toml など
    if file_exists(p .. "/.git/HEAD") or file_exists(p .. "/package.json") or file_exists(p .. "/pyproject.toml") or file_exists(p .. "/Cargo.toml") or file_exists(p .. "/go.mod") or file_exists(p .. "/.wezterm-tag") then
      return p
    end
    local up = dirname(p)
    if not up or up == p then break end
    p = up
    tries = tries - 1
  end
  return nil
end

local function project_tag(cwd)
  local root = find_project_root(cwd)
  local now = os.time()
  local ttl = 10 -- 秒
  if root then
    local entry = project_cache[root]
    if entry and (now - entry.ts) < ttl then
      return entry.tag, entry.color
    end
    local tag, color = detect_project_tag_from_root(root)
    project_cache[root] = { tag = tag, color = color, ts = now }
    return tag, color
  end
  -- ルート不明時: CWD名
  local fallback = basename(cwd)
  return (fallback ~= "" and fallback:upper() or "TERM"), "#5c6d74"
end

wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
  local bg = tab.is_active and "#ae8b2d" or "#5c6d74"
  local fg = "#FFFFFF"

  local pane = tab.active_pane
  local cwd = ""
  if pane and pane.current_working_dir then
    -- file:///Users/xxx/... -> /Users/xxx/...
    local uri = pane.current_working_dir
    cwd = uri.file_path or tostring(uri):gsub("^file://", "")
  end

  local icon = process_icon(pane)
  local folder = basename(cwd)
  if folder == "" then
    folder = pane and pane.title or ""
  end
  local text = wezterm.truncate_right("  " .. icon .. "  " .. folder .. "  ", math.max(0, max_width - 1))
  return {
    { Background = { Color = bg } },
    { Foreground = { Color = fg } },
    { Text = text },
  }
end)

----------------------------------------------------
-- keybinds
----------------------------------------------------
config.disable_default_key_bindings = true
config.keys = require("keybinds").keys
config.key_tables = require("keybinds").key_tables
config.leader = { key = "q", mods = "CTRL", timeout_milliseconds = 2000 }

return config
