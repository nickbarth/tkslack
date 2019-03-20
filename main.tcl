#!/usr/local/opt/tcl-tk/bin/wish

package require Tk
package require websocket
package require http
package require tls
package require json

# app
wm title . "Slack"
wm geometry . 1000x700

# components
set font {Courier 15 normal}

frame .lfrm
entry .lfrm.chat -textvariable chat_message -font $font -highlightthickness 0 -borderwidth 2 -foreground #222222 -background #dddddd -relief flat
text .lfrm.log -yscrollcommand {.lfrm.log_scroll set} -highlightthickness 0 -font $font -undo 1  -foreground #222222 -selectbackground #bcbcbc -selectforeground #000000 -border 10 -relief flat
scrollbar .lfrm.log_scroll -command {.log yview}

frame .rfrm
entry .rfrm.filter -textvariable current -font $font -highlightthickness 0 -borderwidth 1 -foreground #222222 -background #dddddd -relief flat -justify left
listbox .rfrm.channels -listvariable select_channels -borderwidth 0 -font $font -yscrollcommand {.rfrm.channels_scroll set} -highlightcolor #ffffff -selectborderwidth 0 -selectforeground #222222 -selectbackground #dddddd -selectmode single
scrollbar .rfrm.channels_scroll -command {.rfrm.channels yview}

# layout
pack .lfrm -side left -fill both -expand 1
pack .lfrm.log_scroll -side right -fill y
pack .lfrm.chat -side bottom -fill both
pack .lfrm.log -side left -fill both -expand y -anchor n

pack .rfrm -side right -fill y
pack .rfrm.channels_scroll -side right -fill y
pack .rfrm.filter -side top -fill x
pack .rfrm.channels -side right -fill both -expand y

# menu
menu .menu
menu .menu.apple -tearoff 0
.menu.apple add command -label "About" -command {
  tk_messageBox -title "About tkslack" -message "tkslack v1.0.0" -detail "By Nick Barth 2019"
}
.menu add cascade -menu .menu.apple
. configure -menu .menu

# enable https
http::register https 443 [list ::tls::socket -tls1 1]
# websocket::loglevel debug

# globals
set token_file "~/.tkslack"
set token ""
set sock {}

set id ""
set current "slackbot"
set current_id ""
set chat_message ""

set select_channels []

set messages []
set members []
set channels []

array set members_by_hash {}
array set channels_by_name {}

# procs
proc request { url {data ""} } {
  global token

  set request [http::geturl "${url}&token=${token}" -query $data]
  set body [http::data $request]
  return [json::json2dict $body]
}

proc handler { sock type data } {
  global current_id

  switch -- $type {
    "connect" { puts "Connected on $sock" }
    "text" {
      puts $data
      set json [json::json2dict $data]
      dict with json {
        if {$type == "message" && $channel == $current_id} {
          add_message $ts $user $text end
          .lfrm.log see end
        }
      }
    }
  }
}

proc set_token {} {
  global token_file token

  if { $token != "" } {
    return true
  }

  if { [file exists $token_file] } {
    set fp [open $token_file r]
    set token [string trim [read $fp]]
    close $fp
    return true
  }

  return false
}

proc connect {} {
  global id sock
  set data [request "https://slack.com/api/rtm.start?"]
  set ws_url [dict get $data url]
  set sock [websocket::open $ws_url handler]
  set id [dict get [dict get $data self] id]
}

proc socket_send { sock type channel text } {
  websocket::send $sock text [subst {{
    "type":    "${type}",
    "channel": "${channel}",
    "text":    "${text}"
  }}]
}

proc post_message { channel message } {
  set query [http::formatQuery channel $channel text $message as_user true]
  return [request "https://slack.com/api/chat.postMessage?" $query]
}

proc get_messages { channel } {
  set data [request "https://slack.com/api/conversations.history?channel=${channel}"]

  if {[dict get $data ok] == false} {
    tk_messageBox -title "Error" -message "Channel not found." -icon error
    puts "Error - Channel not found: `${channel}`."
    return []
  }

  return [dict get $data messages]
}

proc add_message {ts user_id msg pos} {
  global members_by_hash

  set user $members_by_hash($user_id)
  set date [clock format [expr int($ts)] -format %T]
  .lfrm.log insert $pos "\[$date\] <$user> $msg\n"
}

proc draw_messages { channel } {
  global messages

  .lfrm.log delete 1.0 end

  foreach message $messages {
    dict with message {
      if {$type == "message"} {
        add_message $ts $user $text 1.0
      }
    }
  }

  .lfrm.log see end
}

proc pull_messages { channel } {
  global messages current

  set messages [get_messages $channel]
  draw_messages $channel
}

proc get_channels {} {
  set data [request "https://slack.com/api/conversations.list?types=im,public_channel&exclude_archived=true"]
  return [dict get $data channels]
}

proc get_members {} {
  set data [request "https://slack.com/api/users.list?"]
  return [dict get $data members]
}

proc draw_channels {} {
  global channels_by_name select_channels
  set select_channels [lsort [lmap n [array names channels_by_name] {expr $n}]]
}

proc pull_channels {} {
  global channels members select_channels members_by_hash channels_by_name

  set channels [get_channels]
  set members [get_members]

  # setup hashes for quick lookups
  foreach member $members {
    dict with member {
      set members_by_hash($id) $name
    }
  }

  # set channel name - id
  foreach channel $channels {
    dict with channel {
      if {$is_im} {
        set channels_by_name("$members_by_hash($user)") $id
      } else {
        set channels_by_name("#${name}") $id
      }
    }
  }

  draw_channels
}

proc set_channel { name } {
  global current current_id channels_by_name select_channels

  if {! [info exists channels_by_name("${name}")]} {
    # reset current
    set index [.rfrm.channels curselection]
    set current [lindex $select_channels $index]

    tk_messageBox -title "Error" -message "Channel `${name}` not found." -icon error
    return
  }

  set id $channels_by_name("${name}")
  set current $name
  set current_id $id

  pull_messages $id

  # set selected channel
  .rfrm.channels selection clear 0 end
  .rfrm.channels selection set [lsearch $select_channels $name]
}

proc ping { sock } {
  global id

  websocket::send $sock text [subst {{
    "id":   "${id}",
    "type": "ping"
  }}]

  after 60000 ping $sock
}

proc initialize {} {
  global sock current token

  if { [set_token] } {
    connect
    pull_channels
    set_channel $current

    after 60000 ping $sock

    focus .lfrm.chat
  } else {
    tk_messageBox -title "Invalid Token Error" -message "You require a valid token file." -detail "Please add one http://safdasdf." -icon error
  }
}

# keyboard bindings
bind .lfrm.chat <Return> {
  post_message $current_id $chat_message
  set chat_message ""
}

bind . <Command-k> {
  set current ""
  focus .rfrm.filter
}

bind . <Command-l> {
  set index [.rfrm.channels curselection]
  set current [lindex $select_channels $index]

  set chat_message ""
  focus .lfrm.chat
}

bind .rfrm.filter <Return> {
  if { $current != "" } {
    set_channel $current
  }

  focus .lfrm.chat
}

bind .rfrm.filter <Escape> {
  set index [.rfrm.channels curselection]
  set current [lindex $select_channels $index]
  focus .lfrm.chat
}

# bind .lfrm.log <KeyPress> { break }

bind .rfrm.channels <<ListboxSelect>> {
  set index [%W curselection]

  if { $index != "" } {
    set_channel [lindex $select_channels $index]
  }

  focus .lfrm.chat
}

# init
initialize
