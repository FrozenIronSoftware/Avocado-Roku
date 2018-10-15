' Copyright (C) 2018 Rolando Islas. All Rights Reserved.

' Create a new instance of the RowListItem component
function init() as void
    ' Constants
    ' Components
    m.image = m.top.findNode("image")
    ' Variables
    ' Init
    ' Events
    m.top.observeField("itemContent", "on_item_content_change")
    m.top.observeField("itemHasFocus", "on_focus_change")
end function

' Handle focus change
function on_focus_change(event as object) as void
    if event.getData()
        
    else
        
    end if
end function

' Handle a content change
function on_item_content_change(event as object) as void
    m.image.uri = event.getData().image_url
end function