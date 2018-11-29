' Copyright (C) 2018 Rolando Islas. All Rights Reserved.

' Initialize the home screen component
function init() as void
    print("Media screen started")
    ' Constants
    m.TYPE_AUDIO = 0
    m.TYPE_VIDEO = 1
    m.TYPE_IMAGE = 2
    ' Components
    m.registry = m.top.findNode("registry")
    m.avocado_api = m.top.findNode("avocado_api")
    m.dialog = m.top.findNode("dialog")
    m.background = m.top.findNode("background")
    m.ad_container = m.top.findNode("ad_container")
    m.ads = m.top.findNode("ads")
    m.podcast_title = m.top.findNode("podcast_title")
    m.episode_title = m.top.findNode("episode_title")
    m.video = m.top.findNode("video")
    m.audio = m.top.findNode("audio")
    m.image = m.top.findNode("image")
    m.podcast_artwork = m.top.findNode("podcast_artwork")
    ' Events
    m.registry.observeField("result", "on_callback")
    m.avocado_api.observeField("result", "on_callback")
    m.dialog.observeField("wasClosed", "on_dialog_closed")
    m.dialog.observeField("buttonSelected", "on_dialog_button_selected")
    m.ads.observeField("status", "on_ads_end")
    m.top.observeField("start", "on_start_requested")
    m.top.observeField("stop", "on_stop_requested")
    m.top.observeField("auth", "on_authentication_data")
    ' Vars
    m.podcast_id = invalid
    m.episode_id = invalid
    m.continuous_play = false
    m.media_type = invalid
    m.nielsen_genre = invalid
    m.exit_after_message = false
    m.show_ads = true ' Do not set on start. This is set only when there is auth data
    ' Init
    init_logging()
end function

' Handle a key press
function onKeyEvent(key as string, press as boolean) as boolean
    ' Show exit dialog
    if press and key = "back"
        m.top.back = [m.podcast_id, m.episode_id]
        return true
    end if
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
    if callback = "on_registry_read"
        on_registry_read(event)
    else if callback = "on_episode_data"
        on_episode_data(event)
    else if callback = "on_podcast_data"
        on_podcast_data(event)
    else
        if callback = invalid
            callback = ""
        end if
        printl(m.WARN, "on_callback: Unhandled callback: " + callback)
    end if
end function

' Ready the screen
function on_start_requested(event as object) as void
    load_episode(event.getData()[0], event.getData()[1])
end function

' Reset and load an episode
' Entry point
function load_episode(podcast_id, episode_id) as void
    m.podcast_id = podcast_id
    m.episode_id = episode_id
    m.continuous_play = false
    m.media_type = invalid
    m.podcast_artwork.uri = ""
    m.nielsen_genre = invalid
    m.exit_after_message = false
    m.ad_container.visible = false
    m.image.visible = false
    m.video.visible = false
    m.podcast_title.visible = false
    m.episode_title.visible = false
    m.podcast_artwork.visible = false
    ' Start registry read
    m.registry.read_multi = [
        m.global.REG_AVOCADO,
        [m.global.REG_SETTING_CONTINUOUS_PLAY],
        "on_registry_read"
    ]
end function

' Stop the screen
function on_stop_requested(event as object) as void
    m.audio.control = "stop"
    m.video.control = "stop"
    m.avocado_api.cancel = true
    m.dialog.visible = false
end function

' Handle registry data being read
' Calls the API for podcast data
function on_registry_read(event as object) as void
    reg_data = event.getData().result
    ' Read registry data
    if type(reg_data) = "roAssociativeArray"
        ' Continuous play
        if type(reg_data[m.global.REG_SETTING_CONTINUOUS_PLAY]) = "roBoolean"
            m.continuous_play = true
        else
            m.continuous_play = false
        end if
    end if
    ' Get podcast data
    m.avocado_api.get_podcasts = [{ids: [m.podcast_id]}, "on_podcast_data"]
end function

' Handle podcast data
function on_podcast_data(event as object) as void
    podcasts = event.getData().result
    if type(podcasts) <> "roArray"
        error("error_api_fail", 4000)
    else
        for each podcast in podcasts
            if type(podcast) = "roAssociativeArray" and podcast.id = m.podcast_id
                m.podcast_title.text = podcast.title
                m.podcast_artwork.uri = podcast.image
            end if
        end for
    end if

    ' Get episode data
    m.avocado_api.get_episodes = [{
        id: m.podcast_id,
        episode: m.episode_id,
    }, "on_episode_data"]
end function

' Handle episode data
function on_episode_data(event as object) as void
    episodes = event.getData().result
    duration = 0
    description = ""
    if type(episodes) <> "roArray"
        m.exit_after_message = true
        error("error_api_fail", 4001)
        m.top.ready = true
        return
    else
        if episodes.count() = 1
            episode = episodes[0]
            if episode.type = "audio"
                m.media_type = m.TYPE_AUDIO
            else if episode.type = "video"
                m.media_type = m.TYPE_VIDEO
            else if episode.type = "image"
                m.media_type = m.TYPE_IMAGE
            end if
            m.episode_title.text = episode.title
            m.media_url = episode.url
            m.artwork = episode.image
            m.nielsen_genre = episode.genre
            description = episode.description
        else
            m.exit_after_message = true
            error("error_api_fail", 4002)
            m.top.ready = true
            return
        end if
    end if

    preload_media(description)
    if m.show_ads
        show_ads(m.podcast_title.text, m.nielsen_genre, duration)
    else
        play_media()
    end if
    m.top.ready = true
end function

' Buffers the media
function preload_media(description = invalid as string) as void
    media = createObject("roSGNode", "ContentNode")
    ' HTTPS
    http_agent = createObject("roHttpAgent")
    media.setHttpAgent(http_agent)
    media.httpCertificatesFile = "common:/certs/ca-bundle.crt"
    ' Info
    media.url = m.media_url
    media.title = m.episode_title.text
    media.titleSeason = m.podcast_title.text
    media.description = description
    ' Audio
    if m.media_type = m.TYPE_AUDIO
        media.streamFormat = "mp3"
        m.audio.content = media
        m.audio.control = "prebuffer"
    ' Video
    else if m.media_type = m.TYPE_VIDEO
        m.video.content = media
        m.video.control = "prebuffer"
    ' Image
    else if m.media_type = m.TYPE_IMAGE
        m.image.uri = m.media_url
    end if
end function

' Plays the media
function play_media() as void
    ' Audio
    if m.media_type = m.TYPE_AUDIO
        ' TODO Set audio controls focus
        m.audio.control = "play"
        ' Show audio elements
        m.episode_title.visible = true
        m.podcast_title.visible = true
        m.podcast_artwork.visible = true
        m.background.uri = "pkg:/locale/default/images/audio_background.png"
    ' Video
    else if m.media_type = m.TYPE_VIDEO
        m.video.setFocus(true)
        m.video.visible = true
        m.video.control = "play"
    ' Image
    else if m.media_type = m.TYPE_IMAGE
        m.image.visible = true
    end if
end function

' Show ads
' @param media_name string podcast name
' @param category string nielsen genre
' @param duration episode duration
function show_ads(media_name = "" as dynamic, category = "GV" as dynamic, duration = 0 as dynamic) as void
    if media_name = invalid media_name = ""
    if category = invalid category = "GV"
    if duration = invalid duration = 0
    m.ads.view = m.ad_container
    m.ads.show_ads = [media_name, category, duration]
    m.ad_container.visible = true
end function

function on_ads_end(event as object) as void
    m.ad_container.visible = false
    success = event.getData()
    if success
        play_media()
    else
        m.top.back = [m.podcast_id, m.episode_id]
    end if
end function

' Handle dialog close event
function on_dialog_closed(event as object) as void
    if m.exit_after_message
        m.top.back = [m.podcast_id, m.episode_id]
    else
        ' TODO focus
    end if
end function

' Handle dialog button selected
function on_dialog_button_selected(event as object) as void
    if m.exit_after_message
        m.top.back = [m.podcast_id, m.episode_id]
    else
        ' TODO focus
    end if
    m.dialog.close = true
end function

' Handle auth data
function on_authentication_data(event as object) as void
    auth = event.getData()
    m.avocado_api.auth = auth
    ' Check for premium status
    m.show_ads = type(auth) <> "roAssociativeArray" or auth.account_level < 2
end function
