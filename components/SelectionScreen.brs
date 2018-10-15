' Copyright (C) 2018 Rolando Islas. All Rights Reserved.

' Initialize the home screen component
function init() as void
    print("Selection screen started")
    ' Constants
    m.ITEMS_PER_PAGE = 10
    ' Components
    m.avocado_api = m.top.findNode("avocado_api")
    m.dialog = m.top.findNode("dialog")
    m.label_list = m.top.findNode("label_list")
    m.description_sidebar = m.top.findNode("description_sidebar")
    m.header = m.top.findNode("header")
    m.previous = m.top.findNode("previous")
    m.next = m.top.findNode("next")
    m.page = m.top.findNode("page")
    m.message = m.top.findNode("message")
    ' Events
    m.avocado_api.observeField("result", "on_callback")
    m.dialog.observeField("wasClosed", "on_dialog_closed")
    m.dialog.observeField("buttonSelected", "on_dialog_button_selected")
    m.label_list.observeField("itemSelected", "on_episode_selected")
    m.label_list.observeField("itemFocused", "on_episode_focused")
    m.previous.observeField("buttonSelected", "on_previous_selected")
    m.next.observeField("buttonSelected", "on_next_selected")
    m.top.observeField("start", "on_start_requested")
    m.top.observeField("stop", "on_stop_requested")
    m.top.observeField("auth", "on_authentication_data")
    ' Vars
    m.page_index = 0
    m.podcast_id = -1
    m.episode_id = -1
    m.podcast_description = invalid
    m.max_pages = 1
    m.loading_page = false
    ' Init
    init_logging()
end function

' Handle callback
function on_callback(event as object) as void
    callback = event.getData().callback
    if callback = "on_podcast_data"
        on_podcast_data(event)
    else if callback = "on_episode_data"
        on_episode_data(event)
    else
        if callback = invalid
            callback = ""
        end if
        printl(m.WARN, "on_callback: Unhandled callback: " + callback)
    end if
end function

' Handle a key press
function onKeyEvent(key as string, press as boolean) as boolean
    ' Show exit dialog
    if press and key = "back"
        m.top.back = []
        return true
    ' Move to previous page
    else if press and key = "rewind"
        load_previous_page()
        return true
    ' Move to next page
    else if press and key = "fastforward"
        load_next_page()
        return true
    ' Label list
    else if m.label_list.isInFocusChain()
        ' Move to left arrow
        if press and (key = "left" or key = "up")
            m.previous.setFocus(true)
            return true
        else if press and (key = "right" or key = "down")
            m.next.setFocus(true)
            return true
        ' Play
        else if press and key = "play"
            load_currently_focused_episode()
            return true
        end if
    ' Previous button
    else if m.previous.isInFocusChain()
        ' Move to Next button
        if press and key = "right"
            m.next.setFocus(true)
            return true
        ' Move to label list
        else if press and (key = "left" or key = "up" or key = "down")
            m.label_list.setFocus(true)
            return true
        end if
    ' Next button
    else if m.next.isInFocusChain()
        ' Move to Previous button
        if press and key = "left"
            m.previous.setFocus(true)
            return true
        else if press and (key = "right" or key = "up" or key = "down")
            m.label_list.setFocus(true)
            return true
        end if
    end if
    return false
end function

' Handle dialog close event
function on_dialog_closed(event as object) as void
    m.label_list.setFocus(true)
end function

' Handle dialog button selected
function on_dialog_button_selected(event as object) as void
    m.label_list.setFocus(true)
    m.dialog.close = true
end function

' Ready the screen
' @param event field event expected to be an array with podcast_id at index 0
' and episode id at index 1. If the episode id is not present, the list will
' start at the latest episode
function on_start_requested(event as object) as void
    ' General vars
    m.page_index = 0
    m.max_pages = 1
    m.loading_page = true
    m.podcast_description = invalid
    m.page.text = "1"
    m.podcast_id = event.getData()[0]
    m.episode_id = -1
    if event.getData().count() > 1
        m.episode_id = event.getData()[1]
    end if
    ' Clear lavel list
    m.label_list.content = createObject("roSGNode", "ContentNode")
    ' Clear sidebar
    m.description_sidebar.title = ""
    m.header.title = ""
    m.podcast_description = ""
    m.description_sidebar.author = ""
    m.description_sidebar.artwork = ""
    ' Start getting podacast data
    m.avocado_api.get_podcasts = [{ids: [m.podcast_id]}, "on_podcast_data"]
end function

' Handle podcast data
function on_podcast_data(event as object) as void
    podcasts = event.getData().result
    offset = 0
    if type(podcasts) <> "roArray"
        error("error_api_fail", 3000)
    else
        for each podcast in podcasts
            if type(podcast) = "roAssociativeArray" and podcast.id = m.podcast_id
                m.description_sidebar.title = podcast.title
                m.header.title = podcast.title
                m.podcast_description = podcast.description
                m.description_sidebar.author = podcast.author
                m.description_sidebar.artwork = podcast.image
                if m.episode_id > -1
                    offset = fix((m.episode_id + 1) / m.ITEMS_PER_PAGE) - 1
                end if
            end if
        end for
    end if

    m.avocado_api.get_episodes = [{
        id: m.podcast_id,
        offset: 0,
        limit: m.ITEMS_PER_PAGE,
        order: "descending"
    }, "on_episode_data"]
end function

' Handle episode data
function on_episode_data(event as object) as void
    episodes = event.getData().result
    if type(episodes) <> "roArray"
        error("error_api_fail", 3001)
    else
        m.max_pages = int(episodes.count() / m.ITEMS_PER_PAGE)
        if episodes.count() / m.ITEMS_PER_PAGE - m.max_pages > 0
            m.max_pages += 1
        end if
        for each episode in episodes
            if type(episode) = "roAssociativeArray"
                ' Set item details
                item = m.label_list.content.createChild("ContentNode")
                item.title = episode.title
                item.episode_id = episode.episode_id
                item.description = episode.description
                ' Set Icon
                icon = "pkg:/locale/default/images/icon_empty.png"
                if episode.progress >= 95
                    icon = "pkg:/locale/default/images/icon_done.png"
                else if episode.progress >= 1
                    icon = icon = "pkg:/locale/default/images/icon_in_progress.png"
                end if
                item.hdlistitemiconurl = icon
                item.hdlistitemiconselectedurl = icon
            end if
        end for
    end if

    ' Signify loading stopped
    m.loading_page = false
    ' Set page text
    m.page.text = (m.page_index + 1).toStr()
    ' Check if no episodes were added
    hide_message()
    if m.label_list.content.getChildCount() = 0
        show_message("message_no_data")
    end if
    ' Focus label list
    m.label_list.setFocus(true)
    m.top.ready = true
end function

' Hide the message behind the label list.
function hide_message()
    m.message.text = ""
end function

' Show a message behind the label list, first clearing it
function show_message(message as string) as void
    m.label_list.content = createObject("roSGNode", "ContentNode")
    m.message.text = tr(message)
end function

' Destroy the screen
function on_stop_requested(event as object) as void
    m.avocado_api.cancel = true
    m.dialog.visible = false
end function

' Handle authentication data
function on_authentication_data(event as object) as void
    m.avocado_api.auth = event.getData()
end function

' An episode from the list was selected
function on_episode_selected(event as object) as void
    episode = m.label_list.content.getChild(event.getData())
    if episode <> invalid
        m.top.episode_selected = [m.podcast_id, episode.episode_id]
    end if
end function

' An episode was focused
function on_episode_focused(event as object) as void
    episode = m.label_list.content.getChild(event.getData())
    if episode <> invalid
        m.description_sidebar.description = episode.description
    end if
end function

' Load previous podcast page
function on_previous_selected(event = invalid as object) as void
    if (not m.loading_page) and m.page_index > 0
        m.page_index -= 1
        show_message("message_loading")
        m.loading_page = true
        m.avocado_api.get_episodes = [{
            id: m.podcast_id,
            offset: m.page_index,
            limit: m.ITEMS_PER_PAGE,
            order: "descending"
        }, "on_episode_data"]
    end if
end function

' Load next podcast page
function on_next_selected(event = invalid as object) as void
    if (not m.loading_page) and m.page_index < m.max_pages - 1
        m.page_index += 1
        show_message("message_loading")
        m.loading_page = true
        m.avocado_api.get_episodes = [{
            id: m.podcast_id,
            offset: m.page_index,
            limit: m.ITEMS_PER_PAGE,
            order: "descending"
        }, "on_episode_data"]
    end if
end function

' Load the episdoe in the label list that is focused
function load_currently_focused_episode() as void
    episode = m.label_list.content.getChild(m.label_list.itemFocused)
    if episode <> invalid
        m.top.episode_selected = [m.podcast_id, episode.episode_id]
    end if
end function

' Load previous podcast page
function load_previous_page() as void
    on_previous_selected()
end function

' Load next podcast page
function load_next_page() as void
    on_next_selected()
end function
