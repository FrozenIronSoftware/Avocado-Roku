' Copyright (C) 2018 Rolando Islas. All Rights Reserved.

' Main entry point
function init() as void
    loading_text = m.top.findNode("loading_text")
    loading_text.text = tr("title_loading")
    m.top.observeField("start", "on_start_requested")
end function

' Start the stage
function on_start_requested(event as object) as void
    m.top.ready = true
end function