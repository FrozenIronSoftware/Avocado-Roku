' Copyright (C) 2018 Rolando Islas. All Rights Reserved.

' Main entry point for the application.
' Starts the main scene
function main(args as dynamic) as void
    print("Avocado started")
    ' Load secret keys
    secret = parseJson(readAsciiFile("pkg:/secret.json"))
    ' Initialize the main screen
    screen = createObject("roSGScreen")
    port = createObject("roMessagePort")
    screen.setMessagePort(port)
    scene = screen.createScene("Avocado")
    scene.backgroundColor = "0x19171c"
    scene.backgroundURI = ""
    scene.backExitsScene = false
    ' Set globals
    m.global = screen.getGlobalNode()
    m.global.addFields({
       args: args,
       secret: secret,
       REG_AVOCADO: "AVOCADO",
       REG_AUTH: "AUTH",
       REG_SETTING_CONTINUOUS_PLAY: "S_CONTINUE_PLAY"
       ARROW: "»"
    })
    ' Events
    screen.show()
    scene.observeField("do_exit", port)
    ' Main loop
    while true
       msg = wait(0, port)
       if type(msg) = "roSGScreenEvent"
           if msg.isScreenClosed()
               return
           end if
       else if type(msg) = "roSGNodeEvent"
           if msg.getField() = "do_exit"
               if msg.getData()
                   screen.close()
                   return
               end if
           end if
       end if
    end while
end function

' Entry point for the main scene
function init() as void
    print("Main scene started")
    ' Constants
    ' Components
    m.loading_screen = m.top.findNode("loading_screen")
    m.home_screen = m.top.findNode("home_screen")
    m.selection_screen = m.top.findNode("selection_screen")
    m.authentication_handler = m.top.findNode("authentication_handler")
    m.media_screen = m.top.findNode("media_screen")
    ' Events
    m.home_screen.observeField("do_exit", "do_exit")
    m.home_screen.observeField("dialog", "on_dialog")
    m.home_screen.observeField("ready", "on_home_screen_ready")
    m.home_screen.observeField("podcast_selected", "on_podcast_selected")
    m.selection_screen.observeField("ready", "on_selection_screen_ready")
    m.selection_screen.observeField("dialog", "on_dialog")
    m.selection_screen.observeField("episode_selected", "on_episode_selected")
    m.selection_screen.observeField("back", "on_selection_screen_closed")
    m.authentication_handler.observeField("dialog", "on_dialog")
    m.authentication_handler.observeField("auth", "on_authentication_data")
    m.authentication_handler.observeField("ready", "on_authentication_handler_ready")
    m.media_screen.observeField("dialog", "on_dialog")
    m.media_screen.observeField("ready", "on_media_screen_ready")
    m.media_screen.observeField("back", "on_media_screen_closed")
    ' Vars
    ' Init
    init_logging()
    start_stage(m.authentication_handler)
end function

' Starts a stage, requesting all other stages stop before starting the new one
' @param stage Stage node with the field start
function start_stage(stage as object, param = true as dynamic) as void
    printl(m.DEBUG, "Loading screen: " + stage.id.toStr())
    ' Send stop event to all screens
    'm.loading_screen.stop = true
    m.home_screen.stop = true
    m.selection_screen.stop = true
    m.authentication_handler.stop = true
    m.media_screen.stop = true
    ' Hide screens
    m.loading_screen.visible = true
    m.home_screen.visible = false
    m.selection_screen.visible = false
    m.authentication_handler.visible = false
    m.media_screen.visible = false
    ' Close dialog
    if m.top.dialog <> invalid
        m.top.dialog.close = true
        m.top.dialog = invalid
    end if
    ' Start stage
    m.top.setFocus(true)
    if type(param) <> "roArray"
        param = [param]
    end if
    stage.start = param
end function

' Handle a key press
function onKeyEvent(key as string, press as boolean) as boolean
    printl(m.EXTRA, "Key: " + key + " Press: " + press.toStr())
    return false
end function

' Handle an async callback result
' The event data is expected to be an associative array with a callback field
' The callback should expect the event passed to it with the result in the
' result field of the data assocarray
' Callbacks are hard-coded instead of called using eval() because it causes
' issues
function on_callback(event as object) as void
    callback = event.getData().callback
    if callback = "todo"

    else
        if callback = invalid
            callback = ""
        end if
        printl(m.WARN, "on_callback: Unhandled callback: " + callback)
    end if
end function

' Checks for deep link parameters and attempts to use them
' or starts the application normally
function deep_link_or_start() as void
    args = m.global.args
    if args.contentId <> invalid and args.mediaType <> invalid
        args.contentId = invalid
        args.mediaType = invalid
        ' TODO handle deep link
    else
        start_stage(m.home_screen)
    end if
end function

' Exits the application
function do_exit(event as object) as void
    m.top.setField("do_exit", true)
end function

' Set the dialog
function on_dialog(event as object) as void
    m.top.dialog = event.getData()
end function

' Show the home screen and hide the loading screen
function on_home_screen_ready(event as object) as void
    m.loading_screen.visible = false
    m.home_screen.visible = true
    m.home_screen.setFocus(true)
end function

' Handle a podcast selection from the home screen
function on_podcast_selected(event as object) as void
    id = event.getData()
    start_stage(m.selection_screen, id)
end function

' Handle the authentication data
function on_authentication_data(event as object) as void
    auth = event.getData()
    m.loading_screen.auth = auth
    m.home_screen.auth = auth
    m.selection_screen.auth = auth
    m.media_screen.auth = auth
end function

' Handle authentication handler being ready
function on_authentication_handler_ready(event as object) as void
    deep_link_or_start()
end function

' Handle selection screen ready event
function on_selection_screen_ready(event as object) as void
    m.loading_screen.visible = false
    m.selection_screen.visible = true
    m.selection_screen.setFocus(true)
end function

' Handle podcast episode selection
' @param event field event The event's data contain an array of podcast id and
' episode id
function on_episode_selected(event as object) as void
    start_stage(m.media_screen, event.getData())
end function

' Handle selection screen closing
function on_selection_screen_closed(event as object) as void
    start_stage(m.home_screen)
end function

' Handle media screen ready event
function on_media_screen_ready(event as object) as void
    m.loading_screen.visible = false
    m.media_screen.visible = true
    m.media_screen.setFocus(true)
end function

' Handle media screen close event
function on_media_screen_closed(event as object) as void
    episode = event.getData()
    if type(episode) = "roArray" and episode.count() = 2
        start_stage(m.selection_screen, episode)
    end if
end function
