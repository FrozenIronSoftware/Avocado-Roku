' Copyright (C) 2018 Rolando Islas. All Rights Reserved.

Library "Roku_Ads.brs"

' Ads entry point
function init() as void
    ' Constants
    m.PORT = createObject("roMessagePort")
    ' Ads
    m.ads = Roku_Ads()
    m.ads.enableNielsenDar(true)
    m.ads.setNielsenAppId(m.global.secret.ad_nielsen_id)
    ' Components
    m.avocado_api = m.top.findNode("avocado_api")
    ' Events
    m.top.observeField("show_ads", m.PORT)
    m.avocado_api.observeField("result", m.PORT)
    ' Variables
    m.did_fetch_server = false
    ' Init
    init_logging()
    m.avocado_api.get_ad_server = "on_ad_server"
    ' Task init
    m.top.functionName = "run"
    m.top.control = "RUN"
end function

' Handle an async callback result
' The event data is expected to be an associative array with a callback field
' The callback should expect the event passed to it with the result in the
' result field of the data assocarray
' Callbacks are hard-coded instead of called using eval() because it causes
' issues
function on_callback(event as object) as void
    callback = event.getData().callback
    if callback = "on_ad_server"
        on_ad_server(event)
    else
        if callback = invalid
            callback = ""
        end if
        printl(m.WARN, "on_callback: Unhandled callback: " + callback)
    end if
end function

' Set the ad url of the Roku_Ads instance
function set_ad_url(ad_url as string) as void
    m.ads.setAdUrl(ad_url.replace("ROKU_ADS_TRACKING_ID_OBEY_LIMIT", get_ad_id()))
end function

' Handle ad server request data from Twitched's API
function on_ad_server(event as object) as void
    ad_server = event.getData().result
    if type(ad_server) <> "roAssociativeArray" or type(ad_server.ad_server, 3) <> "roString"
        printl(m.DEBUG, "Ads: Failed to fetch ad server from Avocado API")
        return
    end if
    printl(m.DEBUG, "Ads: Fetched ad server from Twitched API")
    m.did_fetch_server = true
    set_ad_url(ad_server.ad_server)
end function

' Get the ad id for the device, obeying limited ad tracking
function get_ad_id() as string
    ad_id = ""
    device_info = createObject("roDeviceInfo")
    if not device_info.isAdIdTrackingDisabled()
        ad_id = device_info.getAdvertisingId()
    end if
    return ad_id
end function

' Main task function
function run() as void
    printl(m.DEBUG, "Ads: Ads task started")
    while true
        msg = wait(0, m.PORT)
        ' Field event
        if type(msg) = "roSGNodeEvent"
            if msg.getField() = "show_ads"
                show_ads(msg.getData())
            else if msg.getField() = "result"
                on_callback(msg)
            end if
        end if
    end while
end function

' Async show ads call
' Sets the status to the result of the ad call
' @param params roArray [nielsen_id  as string, genre as string, content_length as integer]
function show_ads(params as object) as void
    if not m.did_fetch_server
        m.avocado_api.get_ad_server = "on_ad_server"
    end if
    nielsen_id = params[0]
    genre = params[1]
    content_length = params[2]
    m.ads.setNielsenProgramId(nielsen_id) ' Streamer
    m.ads.setNielsenGenre(genre) ' General variety
    m.ads.setContentLength(content_length) ' Seconds
    ads = m.ads.getAds()
    if ads = invalid or ads.count() = 0
        printl(m.DEBUG, "Ads: No ads loaded")
        m.top.setField("status", true)
        return
    end if
    printl(m.DEBUG, "Ads: Showing ads")
    m.top.setField("status", m.ads.showAds(ads, invalid, m.top.view))
end function
