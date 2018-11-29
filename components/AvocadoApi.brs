' Copyright (C) 2018 Rolando Islas. All Rights Reserved.

' Initialize API component
function init() as void
    m.port = createObject("roMessagePort")
    ' Constants
    m.API = m.global.secret.api_domain
    ' HTTP Api
    m.http = createHttp()
    ' Variables
    m.callback = invalid
    m.request_url = invalid
    m.request_data = invalid
    m.request_type = invalid
    m.cache_uuid = invalid
    m.rerequest_count = invalid
    ' Events
    m.top.observeField("cancel", m.port)
    m.top.observeField("get_podcasts", m.port)
    m.top.observeField("get_popular_podcasts", m.port)
    m.top.observeField("auth", m.port)
    m.top.observeField("get_user_favorites", m.port)
    m.top.observeField("get_user_recents", m.port)
    m.top.observeField("create_anonymous_user", m.port)
    m.top.observeField("get_episodes", m.port)
    m.top.observeField("get_user_info", m.port)
    ' Task init
    m.top.functionName = "run"
    m.top.control = "RUN"
end function

' Main task loop
function run() as void
    print("Avocado API task started")
    while true
        msg = wait(0, m.port)
        if type(msg) = "roUrlEvent"
            on_http_response(msg)
        else if type(msg) = "roSGNodeEvent"
            params = msg.getData()
            if msg.getField() = "cancel"
                m.http.asyncCancel()
                m.callback = invalid
                m.request_url = invalid
                m.request_data = invalid
                m.request_type = invalid
                m.cache_uuid = invalid
                m.rerequest_count = invalid
            else if msg.getField() = "auth"
                authenticate(params)
            else if msg.getField() = "get_podcasts"
                get_podcasts(params)
            else if msg.getField() = "get_popular_podcasts"
                get_popular_podcasts(params)
            else if msg.getField() = "get_user_favorites"
                get_user_favorites(params)
            else if msg.getField() = "get_user_recents"
                get_user_recents(params)
            else if msg.getField() = "create_anonymous_user"
                create_anonymous_user(params)
            else if msg.getField() = "get_episodes"
                get_episodes(params)
            else if msg.getField() = "get_user_info"
                get_user_info(params)
            end if
        end if
    end while
end function

' Handle authentication data
function authenticate(auth_data as object) as void
    m.http = createHttp(auth_data)
end function

' Create an roUrlTransfer object with optional auth_data
function createHttp(auth_data = invalid as object) as object
    http = createObject("roUrlTransfer")
    http.setMessagePort(m.port)
    http.setCertificatesFile("common:/certs/ca-bundle.crt")
    http.addHeader("X-Roku-Reserved-Dev-Id", "") ' Automatically populated
    http.addHeader("Client-ID", m.global.secret.client_id)
    app_info = createObject("roAppInfo")
    http.addHeader("X-Avocado-Version", app_info.getVersion())
    ' Add auth
    if type(auth_data) = "roAssociativeArray"
        if type(auth_data.token, 3) = "roString" and type(auth_data.id, 3) = "roInt"
            ba = createObject("roByteArray")
            ba.fromAsciiString(auth_data.id.toStr() + ":" + auth_data.token)
            http.addHeader("Authorization", "Basic " + ba.toBase64String())
        end if
    end if
    http.enableCookies()
    http.initClientCertificates()
    return http
end function

' Event callback for an http response
' set the result data if the status is not an error
function on_http_response(event as object) as void
    ' Transfer not complete
    if event.getInt() <> 1 or m.callback = invalid then return
    ' Canceled
    if event.getResponseCode() = -10001 or event.getFailureReason() = "Cancelled"
        return
    ' Page has not been cached. Retry after a delay
    else if event.getResponseCode() = 218
        device_info = createObject("roDeviceInfo")
        uuid = device_info.getRandomUuid()
        m.cache_uuid = uuid
        sleep(1000)
        if m.cache_uuid <> invalid and m.cache_uuid = uuid
            request_url = m.request_url
            if m.rerequest_count = invalid
                m.rerequest_count = {
                    url: request_url,
                    count: 0
                }
            end if
            if (m.rerequest_count.url = request_url and m.rerequest_count.count >= 10)
                m.rerequest_count = invalid
            else if m.rerequest_count.url = request_url
                if request_url.instr("?") > -1
                    request_url += "&waiting=true"
                else
                    request_url += "?waiting=true"
                end if
                m.rerequest_count.count += 1
            end if
            request(m.request_type, m.request_url, [], m.callback, m.request_data)
        end if
        return
    ' Fail
    else if event.getResponseCode() <> 200
        print "HTTP request failed:"
        print tab(2)"URL: " + m.http.getUrl()
        print tab(2)"Status Code: " + event.getResponseCode().toStr()
        print tab(2)"Reason: " + event.getFailureReason()
    end if
    ' Response
    response = event.getString()
    ' Parse
    json = parseJson(response)
    ' Send result event
    m.top.setField("result", {
        callback: m.callback
        result: json
    })
    m.callback = invalid
    m.request_url = invalid
    m.request_data = invalid
    m.request_type = invalid
end function

' Make an async request, automatically handling the callback result and setting it to
' the result field
' A JSON parse is attempted, so the expected data should be JSON
' @param req type of request GET or POST
' @param request_url base URL to call with no parameters
' @param paramas array of string parameters to append in the format "key=value"
' @param callback callback string to embed in result
' @param data optional post body to send
function request(req as string, request_url as string, params as object, callback as string, data = "" as string) as void
    ' Construct URL from parameter array
    separator = "?"
    if not params.isEmpty()
        for each param in params
            request_url += separator + param
            separator = "&"
        end for
    end if
    ' Make the HTTP request
    m.callback = callback
    m.request_url = request_url
    m.request_data = data
    m.request_type = req
    if req = "GET"
        get(request_url)
    else if req = "POST"
        'response = post(request_url, data)
        ' TODO handle post
    end if
end function

' Helper function to request a URL in an asynchronous fashion
function get(request_url as string) as void
    print "Get request to " + request_url
    m.http.setRequest("GET")
    m.http.setUrl(request_url)
    m.http.asyncGetToString()
end function

' Get podcasts from the Avocado API
' @param params roArray [roAssociativeArray url_params, string callback]
function get_podcasts(params as object) as void
    request_url = m.API + "/podcasts"
    ' Construct parameter array
    passed_params = params[0]
    url_params = []
    if passed_params.ids <> invalid
        for each id in passed_params.ids
            url_params.push("id=" + m.http.escape(id.toStr()))
        end for
    end if
    request("GET", request_url, url_params, params[1])
end function

' Retrieve popular podcasts from the API
' @param params roAssociativeArray {{query_options}, callback}
function get_popular_podcasts(params as object) as void
    request_url = m.API + "/podcasts/popular"
    ' Construct parameter array
    passed_params = params[0]
    url_params = []
    if passed_params.limit <> invalid
        url_params.push("limit=" + m.http.escape(passed_params.limit.toStr()))
    end if
    if passed_params.language <> invalid
        url_params.push("language=" + m.http.escape(passed_params.language.toStr()))
    end if
    if passed_params.time <> invalid
        url_params.push("time=" + m.http.escape(passed_params.time.toStr()))
    end if
    request("GET", request_url, url_params, params[1])
end function

' Retrieve user favorited podcasts from the API
' @param params roAssociativeArray {{query_options}, callback}
function get_user_favorites(params as object) as void
    request_url = m.API + "/podcasts/favorites"
    ' Construct parameter array
    passed_params = params[0]
    url_params = []
    if passed_params.limit <> invalid
        url_params.push("limit=" + m.http.escape(passed_params.limit.toStr()))
    end if
    request("GET", request_url, url_params, params[1])
end function

' Retrieve user recently viewed podcasts from the API
' @param params roAssociativeArray {{query_options}, callback}
function get_user_recents(params as object) as void
    request_url = m.API + "/podcasts/recents"
    ' Construct parameter array
    passed_params = params[0]
    url_params = []
    if passed_params.limit <> invalid
        url_params.push("limit=" + m.http.escape(passed_params.limit.toStr()))
    end if
    request("GET", request_url, url_params, params[1])
end function

' Attempt to get an new user from the API
' @param params roAssociativeArray {{query_options}, callback}
function create_anonymous_user(params as object) as void
    request_url = m.API + "/user/create"
    request("GET", request_url, [], params[1])
end function

' Request podcast episodes from the API
' @param params roAssociativeArray {{query_options}, callback}
function get_episodes(params as object) as void
    request_url = m.API + "/podcasts/episodes"
    ' Construct parameter array
    passed_params = params[0]
    url_params = []
    if passed_params.id <> invalid
        url_params.push("podcast_id=" + m.http.escape(passed_params.id.toStr()))
    end if
    if passed_params.offset <> invalid
        url_params.push("offset=" + m.http.escape(passed_params.offset.toStr()))
    end if
    if passed_params.limit <> invalid
        url_params.push("limit=" + m.http.escape(passed_params.limit.toStr()))
    end if
    if passed_params.order <> invalid
        url_params.push("order=" + m.http.escape(passed_params.order.toStr()))
    end if
    if passed_params.episode <> invalid
        url_params.push("episode_id=" + m.http.escape(passed_params.episode.toStr()))
    end if
    request("GET", request_url, url_params, params[1])
end function

' Request user info
' @param params roString callback
function get_user_info(callback as string) as void
    request_url = m.API + "/user"
    ' Comstruct params
    request("GET", request_url, [], callback)
end function

' Request ad servers from Avocado's API
' @param params field event expected to be an event with data being a string callback
function get_ad_server(params) as void
    request_url = m.API + "/ad/server"
    ' Params
    url_params = [
        "type=roku"
    ]
    request("GET", request_url, url_params, params.getData())
end function
