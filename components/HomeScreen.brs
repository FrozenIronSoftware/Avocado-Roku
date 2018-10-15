' Copyright (C) 2018 Rolando Islas. All Rights Reserved.

' Initialize the home screen component
function init() as void
    print("Home screen started")
    ' Constants
    m.DIALOG_INFO = 0
    m.DIALOG_EXIT = 1
    ' Components
    m.registry = m.top.findNode("registry")
    m.avocado_api = m.top.findNode("avocado_api")
    m.dialog = m.top.findNode("dialog")
    m.row_list = m.top.findNode("row_list")
    m.description_header = m.top.findNode("description_header")
    ' Events
    m.avocado_api.observeField("result", "on_callback")
    m.dialog.observeField("wasClosed", "on_dialog_closed")
    m.dialog.observeField("buttonSelected", "on_dialog_button_selected")
    m.row_list.observeField("rowItemFocused", "on_row_list_item_focused")
    m.row_list.observeField("rowItemSelected", "on_row_list_item_selected")
    m.top.observeField("start", "on_start_requested")
    m.top.observeField("stop", "on_stop_requested")
    m.top.observeField("auth", "on_authentication_data")
    ' Vars
    m.dialog_type = m.DIALOG_INFO
    ' Init
    init_logging()
end function

' Begin the screen initialization flow
function on_start_requested(event as object) as void
    populate_row_list()
    m.avocado_api.get_user_favorites = [{limit: 20}, "on_user_favorites"]
end function

' Stop any async calls and hide the dialog
function on_stop_requested(event as object) as void
    m.avocado_api.cancel = true
    m.dialog.visible = false
end function

' Clear the row list and populate it with a settings row
function populate_row_list() as void
    ' Clear row list
    m.row_list.content = createObject("roSGNode", "ContentNode")
    ' Menu row
    menu = m.row_list.content.createChild("ContentNode")
    menu_data = [
        {
            image: "pkg:/locale/default/images/icon_search.png",
            title: tr("title_search"),
            description: tr("message_search")
            id: 0
        },
        {
            image: "pkg:/locale/default/images/icon_settings.png",
            title: tr("title_settings"),
            description: tr("message_settings")
            id: 1
        }
    ]
    if type(m.top.auth) <> "roAssociativeArray" or type(m.top.auth.token, 3) <> "roString"  or m.top.auth.token = "" or m.top.auth.account_level = 0
        menu_data.push({
            image: "pkg:/locale/default/images/icon_sign_in.png",
            title: tr("title_sign_in"),
            description: tr("message_sign_in")
            id: 2
        })
    end if
    for each menu_item_data in menu_data
        add_podcast_to_row(menu, menu_item_data)
    end for
end function

' Handle a key press
function onKeyEvent(key as string, press as boolean) as boolean
    ' Show exit dialog
    if press and key = "back"
        show_exit_dialog()
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
    if callback = "on_popular_podcast_data"
        on_popular_podcast_data(event)
    else if callback = "on_user_favorites"
        on_user_favorites(event)
    else if callback = "on_user_recents"
        on_user_recents(event)
    else if callback = "on_authentication_data"
        on_authentication_data(event)
    else
        if callback = invalid
            callback = ""
        end if
        printl(m.WARN, "on_callback: Unhandled callback: " + callback)
    end if
end function

' Handle user favorite podcast data
function on_user_favorites(event as object) as void
    podcasts = event.getData().result
    if type(podcasts) <> "roArray"
        error("error_api_fail", 1000)
    else
        ' Populate favorites
        if podcasts.count() > 0
            favorites = m.row_list.content.createChild("ContentNode")
            favorites.title = tr("title_favorites")
            for each podcast in podcasts
                add_podcast_to_row(favorites, podcast)
            end for
        end if
    end if
    m.avocado_api.get_user_recents = [{limit: 20}, "on_user_recents"]
end function

' Handle user recent podcast data
function on_user_recents(event as object) as void
    podcasts = event.getData().result
    if type(podcasts) <> "roArray"
        error("error_api_fail", 1001)
    else
        ' Populate Recent
        if podcasts.count() > 0
            recent = m.row_list.content.createChild("ContentNode")
            recent.title = tr("title_recent")
            for each podcast in podcasts
                add_podcast_to_row(recent, podcast)
            end for
        end if
    end if
    m.avocado_api.get_popular_podcasts = [{limit: 50}, "on_popular_podcast_data"]
end function

' Populate a row with podcasts
' @param row ContentNode row to populate
' @param ids roArray ids of podcast that should be added to the row
' @param podcasts roArray podcast array that may or may not contain the podcasts identified in the ids array
function populate_row_with_matching_podcasts(row as object, ids as object, podcasts as object)
        for each id in ids
            for each podcast in podcasts
                if podcast.id = id
                    add_podcast_to_row(row, podcast)
                end if
            end for
        end for
end function

' Handle popular podcast data
' Populates the home screen
function on_popular_podcast_data(event as object) as void
    podcasts = event.getData().result
    if type(podcasts) <> "roArray"
        error("error_api_fail", 1002)
    else
        ' Populate Popular
        if podcasts.count() > 0
            popular = m.row_list.content.createChild("ContentNode")
            popular.title = tr("title_popular")
            for each podcast in podcasts
                add_podcast_to_row(popular, podcast)
            end for
        end if
    end if

    m.row_list.setFocus(true)
    m.top.ready = true
end function

' Attempt to add a podcast to a row
' @param row ContentNode row to add podcast to
' @param podcast roAssociativeArray this should have the values image, title, description, and id
function add_podcast_to_row(row as object, podcast as object) as void
    if type(podcast) = "roAssociativeArray"
        item = row.createChild("RowListItemData")
        item.image_url = podcast.image
        item.title = podcast.title
        item.description = podcast.description
        item.item_id = podcast.id
    end if
end function

' Show exit confirm dialog
function show_exit_dialog() as void
    m.dialog.title = tr("title_exit_confirm")
    m.dialog.message = tr("message_exit_confirm")
    m.dialog.buttons = [tr("button_cancel"), tr("button_confirm")]
    m.dialog.focusButton = 1
    m.dialog.visible = true
    m.dialog_type = m.DIALOG_EXIT
    m.top.dialog = m.dialog
end function

' Handle dialog closing
function on_dialog_closed(event as object) as void
    m.row_list.setFocus(true)
end function

' Handle dialog button selection
function on_dialog_button_selected(event as object) as void
    if m.dialog_type = m.DIALOG_EXIT
        ' Canceled
        if event.getData() = 0
            m.dialog.close = true
            m.row_list.setFocus(true)
        ' Confirmed
        else if event.getData() = 1
            m.top.do_exit = true
        else
            print("Unknown button selected on dialog:" + event.getData().toStr())
        end if
    else
        m.dialog.close = true
        m.row_list.setFocus(true)
    end if
end function

' Handle row list item being focused
function on_row_list_item_focused(event as object) as void
    coords = event.getData()
    m.description_header.title = invalid
    m.description_header.description = invalid
    if coords[0] >= 0 and coords[1] >= 0
        item = m.row_list.content.getChild(coords[0]).getChild(coords[1])
        m.description_header.title = item.title
        m.description_header.description = item.description
    end if
end function

' Handle row list item being selected
function on_row_list_item_selected(event as object) as void
    coords = event.getData()
    if coords[0] >= 0 and coords[1] >= 0
        item = m.row_list.content.getChild(coords[0]).getChild(coords[1])
        ' Handle menu item
        if coords[0] = 0
            ' Search
            if item.item_id = 0
            ' Settings
            else if item.item_id = 1
            ' Log In
            else if item.item_id = 2
            end if
        ' Handle podcast item
        else
            m.top.podcast_selected = item.item_id
        end if
    end if
end function

' Handle authentication data
function on_authentication_data(event as object) as void
    m.avocado_api.auth = event.getData()
end function
