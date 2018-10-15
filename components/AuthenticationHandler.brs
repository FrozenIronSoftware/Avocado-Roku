' Copyright (C) 2018 Rolando Islas. All Rights Reserved.

' Initialize the home screen component
function init() as void
    print("Home screen started")
    ' Constants
    ' Components
    m.registry = m.top.findNode("registry")
    m.avocado_api = m.top.findNode("avocado_api")
    m.dialog = m.top.findNode("dialog")
    ' Events
    m.registry.observeField("result", "on_callback")
    m.avocado_api.observeField("result", "on_callback")
    m.dialog.observeField("wasClosed", "on_dialog_closed")
    m.dialog.observeField("buttonSelected", "on_dialog_button_selected")
    m.top.observeField("start", "on_start_requested")
    m.top.observeField("stop", "on_stop_requested")
    ' Vars
    m.auth = {}
    ' Init
    init_logging()
end function

' Handle callback
function on_callback(event as object) as void
    callback = event.getData().callback
    if callback = "on_registry_read"
        on_registry_read(event)
    else if callback = "on_user_info"
        on_user_info(event)
    else if callback = "on_new_user_info"
        on_new_user_info(event)
    else
        if callback = invalid
            callback = ""
        end if
        printl(m.WARN, "on_callback: Unhandled callback: " + callback)
    end if
end function

' Start the Authentication flow
function on_start_requested(event as object) as void
    m.auth = {}
    ' Start registry read
    m.registry.read_multi = [
        m.global.REG_AVOCADO,
        [m.global.REG_AUTH],
        "on_registry_read"
    ]
end function

' Stop the Authentication flow and hide all dialogs
function on_stop_requested(event as object) as void
    m.avocado_api.cancel = true
    m.dialog.visible = false
end function

' Handle registry data that was read
function on_registry_read(event as object) as void
    reg_data = event.getData().result
    ' Read registry data
    if type(reg_data) = "roAssociativeArray"
        ' Token
        auth_json = reg_data[m.global.REG_AUTH]
        auth = invalid
        if type(auth_json, 3) = "roString"
            auth = parseJson(auth_json)
        end if
        if type(auth) = "roAssociativeArray"
            m.auth = auth
            m.top.auth = m.auth
        end if
    end if
    ' Read auth
    if type(m.auth.token, 3) = "roString" and m.auth.token <> ""
        m.avocado_api.auth = m.auth
        m.avocado_api.get_user_info = "on_user_info"
    ' There is no valid authentication. Create a new user.
    else
        m.avocado_api.create_anonymous_user = [{}, "on_new_user_info"]
    end if
end function

' Handle user info
function on_user_info(event as object) as void
    info = event.getData().result
    if type(info) <> "roAssociativeArray"
        error("error_api_fail", 2000)
        m.top.ready = true
    ' Check user info
    else
        ' The user authentication failed. Log out and create a new user.
        if info.error
            m.registry.write = [m.global.REG_AVOCADO, m.global.REG_AUTH, "",
                "on_reg_write"]
            m.avocado_api.create_anonymous_user = [{}, "on_new_user_info"]
        ' User auth is valid. Pass it to the application handler
        else
            m.auth.id = info.id
            m.auth.account_level = info.account_level
            m.auth.email = info.email
            m.top.auth = m.auth
            m.top.ready = true
        end if
    end if
end function

' Handle new user info
function on_new_user_info(event as object) as void
    info = event.getData().result
    if type(info) <> "roAssociativeArray"
        error("error_api_fail", 2001)
    ' Check user info
    else
        if type(info.token, 3) = "roString" and info.token <> ""
            auth = {
                token: info.token,
                account_level: info.account_level,
                email: info.email,
                id: info.id
            }
            m.registry.write = [m.global.REG_AVOCADO, m.global.REG_AUTH,
                formatJson(auth), "on_reg_write"]
            m.auth = auth
            m.top.auth = m.auth
        end if
    end if
    m.top.ready = true
end function

' Handle dialog closing
function on_dialog_closed(event as object) as void

end function

' Handle dialog button closing
function on_dialog_button_selected(event as object) as void
    m.dialog.close = true
end function
