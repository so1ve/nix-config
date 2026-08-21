local mainMod = "SUPER"
local noctalia = "noctalia msg "

hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = "auto",
})

hl.config({
	general = {
		gaps_in = 5,
		gaps_out = 10,
		border_size = 2,
		layout = "dwindle",
	},
	decoration = {
		rounding = 20,
		rounding_power = 2,
		shadow = {
			enabled = true,
			range = 4,
			render_power = 3,
			color = 0xee1a1a1a,
		},
		blur = {
			enabled = true,
			size = 3,
			passes = 2,
			vibrancy = 0.1696,
		},
	},
	input = {
		follow_mouse = 1,
		touchpad = {
			natural_scroll = true,
		},
	},
	misc = {
		disable_hyprland_logo = true,
		force_default_wallpaper = 0,
	},
})

hl.on("hyprland.start", function()
	hl.exec_cmd("noctalia")
end)

-- Keep empty workspaces visible in Noctalia.
for workspace = 1, 9 do
	hl.workspace_rule({ workspace = tostring(workspace), persistent = true })
end

-- Applications and window management.
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("kitty"), { description = "Open Kitty" })
hl.bind(mainMod .. " + Q", hl.dsp.window.close(), { description = "Close window" })
hl.bind(mainMod .. " + SHIFT + SPACE", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ action = "toggle" }))

hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))

for workspace = 1, 9 do
	hl.bind(mainMod .. " + " .. workspace, hl.dsp.focus({ workspace = workspace }))
	hl.bind(mainMod .. " + CTRL + " .. workspace, hl.dsp.window.move({ workspace = workspace }))
end

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Latchshot.
hl.bind("F9", hl.dsp.exec_cmd("latchshot"))
hl.bind("Print", hl.dsp.exec_cmd("latchshot"))

-- Noctalia shell and IPC integration.
hl.bind("ALT + SPACE", hl.dsp.exec_cmd(noctalia .. "panel-toggle launcher"))
hl.bind(mainMod .. " + period", hl.dsp.exec_cmd(noctalia .. "panel-toggle launcher '/emo '"))
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd(noctalia .. "panel-toggle control-center"))
hl.bind(mainMod .. " + comma", hl.dsp.exec_cmd(noctalia .. "settings-toggle"))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd(noctalia .. "panel-toggle clipboard"))
hl.bind("ALT + Tab", hl.dsp.exec_cmd(noctalia .. "window-switcher"))
hl.bind("SUPER + ALT + L", hl.dsp.exec_cmd(noctalia .. "session lock"))
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd(noctalia .. "session logout"))

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(noctalia .. "volume-up"), {
	locked = true,
	repeating = true,
})
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(noctalia .. "volume-down"), {
	locked = true,
	repeating = true,
})
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(noctalia .. "volume-mute"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(noctalia .. "brightness-up"), {
	locked = true,
	repeating = true,
})
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(noctalia .. "brightness-down"), {
	locked = true,
	repeating = true,
})

hl.bind(
	"switch:on:Lid Switch",
	hl.dsp.exec_cmd(
		"sh -c 'if systemd-ac-power; then exec noctalia msg session lock; else exec noctalia msg session lock-and-suspend; fi'"
	),
	{ locked = true }
)

hl.window_rule({
	match = { class = "dev.noctalia.Noctalia" },
	float = true,
	size = { 1080, 920 },
	center = true,
})

hl.layer_rule({
	name = "noctalia",
	match = {
		namespace = "^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd|window-switcher)$",
	},
	no_anim = true,
	ignore_alpha = 0.5,
	blur = true,
	blur_popups = true,
})
