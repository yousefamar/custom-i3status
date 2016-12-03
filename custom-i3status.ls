#!/usr/bin/lsc

/**
 * @author Yousef Amar / http://yousefamar.com
 * @description A LiveScript i3status replacement
 * @requires ttf-font-icons (AUR)
 * @version 1.0.0
 */

require! [fs, child_process, moment]


const username     = \amar
const en-interface = \enp2s0f0
const wl-interface = \wlp3s0
#const wl-interface = \wlp3s0b1
#const wl-interface = \wlp0s20u1
const battery-file = \BAT0
const adaptor-file = \ADP1


bar =
  # MPV now playing; Artist - Title
  playing =
    full_text: ''

  # TODO: Maybe bluetooth? 

  dropbox =
    full_text: ''

  # Network stuff (separated for potential color)
  net-icon =
    full_text: ''
    separator: false
  net-quality =
    full_text: ''
    separator: false
  net-upload =
    full_text: ''
    #min_width: ' 00.00'
    separator: false
  net-download =
    full_text: ''
    #min_width: ' 00.00'

  # Basic info
  volume =
    full_text: \-
  battery =
    full_text: \-
  time =
    full_text: \-


# TODO: Use fs.watch (although unstable) instead of polling files

# Define update functions; called from set-timeout

update-playing = !->
  err, playing.full_text <-! fs.read-file "/home/#username/.local/share/mpv/scrobble.txt", \UTF-8

update-dropbox = do ->
  statuses =
    "Idle"
    "Couldn't get status: daemon isn't responding"
    "Couldn't get status: "
    "Dropbox isn't responding!"
    "Dropbox daemon stopped."
    "Dropbox isn't running!"

  !->
    err, status, stderr <-! child_process.exec "dropbox-cli status", _
    if err or stderr then return
    status .= trim!

    dropbox.full_text = if status in statuses then '' else if status is "Up to date" then \ else \

    # TODO: Maybe parse status and show how many files are syncing?
    #       NB: Language matches locale; currently German but could change.

update-network = do ->
  build-speed-getter = (intface, is-upload) ->
    direction = if is-upload then \t else \r
    prev-time = moment!
    prev-bytes = 0
    (callback) !->
      err, bytes <-! fs.read-file "/sys/class/net/#{intface}/statistics/#{direction}x_bytes", \UTF-8, _
      if err then return
      bytes .= trim!
      now = moment!
      speed = (bytes - prev-bytes) * (1/131072) / (now.diff prev-time, \seconds, true)
      prev-time := now
      prev-bytes := parse-int bytes
      callback? speed

  do get-upload-en = build-speed-getter en-interface, true
  do get-upload-wl = build-speed-getter wl-interface, true
  do get-download-en = build-speed-getter en-interface, false
  do get-download-wl = build-speed-getter wl-interface, false

  !->
    err, is-ethernet <-! fs.read-file "/sys/class/net/#{en-interface}/carrier", \UTF-8, _
    if err then return
    is-ethernet = is-ethernet.trim! ~= 1
    if is-ethernet
      net-icon.full_text = \
      net-quality.full_text = ''

      do
        up-speed <-! get-upload-en
        net-upload.full_text = "  #{up-speed.to-fixed 2}"

      do
        down-speed <-! get-download-en
        net-download.full_text = "  #{down-speed.to-fixed 2}"

      return

    err, is-wireless <-! fs.read-file "/sys/class/net/#{wl-interface}/carrier", \UTF-8, _
    if err then return
    is-wireless = is-wireless.trim! ~= 1
    if is-wireless
      net-icon.full_text = \

      do
        up-speed <-! get-upload-wl
        net-upload.full_text = "  #{up-speed.to-fixed 2}"

      do
        down-speed <-! get-download-wl
        net-download.full_text = "  #{down-speed.to-fixed 2}"

      err, quality, stderr <-! child_process.exec "iwlist #{wl-interface} scan | grep Quality | awk '{print $1}' | awk -F '=' '{print $2}'", _
      if err or stderr then return
      quality = quality.trim!.split \/
      quality = (quality[0]*100/quality[1]).<<.0
      net-quality.full_text = "#quality"

update-volume = !->
  err, is-mute, stderr <-! child_process.exec "amixer sget Master | awk -F'[][]' '/dB/ {print $6}'", _
  if err or stderr then return
  is-mute = is-mute.trim! == \off
  err, vol, stderr <-! child_process.exec "amixer sget Master | awk -F'[[%]' '/dB/ { print $2 }'", _
  if err or stderr then return
  vol = vol.trim!

  icon = ''
  if is-mute or vol < 1
    icon = \
  else if vol < 34
    icon = \
  else if vol < 67
    icon = \
  else
    icon = \
  volume.full_text = "#icon  #vol"

update-battery = !->
  err, capacity <-! fs.read-file "/sys/class/power_supply/#{battery-file}/capacity", \UTF-8, _
  if err then return
  capacity = capacity.trim!
  err, is-charging <-! fs.read-file "/sys/class/power_supply/#{adaptor-file}/online", \UTF-8, _
  if err then return
  is-charging = is-charging.trim! ~= 1

  icon = ''
  if is-charging
    icon = \
  else if capacity < 25
    icon = \
  else if capacity < 50
    icon = \
  else if capacity < 75
    icon = \
  else
    icon = \
  battery.full_text = "#icon  #capacity"

  red = (((100-capacity)/100 * 255).<<.0).toString 16
  green = ((capacity/100 * 255).<<.0).toString 16

  if red.length < 2 then red = "0#red"
  if green.length < 2 then green = "0#green"

  battery.color = \# + red + green + \00

update-time = !-> time.full_text = moment!.format 'dd D/M H:mm'

update-bar = !-> console.log "#{JSON.stringify bar},"


# Update network info every second
update-playing!
set-interval update-playing, 1000

# Update dropbox info every second
update-dropbox!
set-interval update-dropbox, 1000

# Update network info every second
update-network!
set-interval update-network, 1000

# Update volume info 10 times per second
update-volume!
set-interval update-volume, 100

# Update battery info every second (because of icon)#10 minutes
# TODO: Consider separating icon from info to reduce polling frequency
update-battery!
set-interval update-battery, 1000

# Update time every minute
update-time!
set-interval update-time, 60000

# Update bar 10 times per second (max frequency of change)
console.log '{ "version": 1 }['
update-bar!
set-interval update-bar, 100
