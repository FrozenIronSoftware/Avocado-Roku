' Copyright (C) 2018 Rolando Islas. All Rights Reserved.

' Create a new instance of the DescriptionHeader component
function init() as void
    ' Constants
    ' Components
    m.title = m.top.findNode("title")
    m.description = m.top.findNode("description")
    ' Variables
    ' Events
    m.top.observeField("width", "on_width_change")
    m.top.observeField("height", "on_height_change")
    m.top.observeField("title", "on_title_change")
    m.top.observeField("description", "on_description_change")
    ' Init
    resize()
end function

' Handle width change
function on_width_change(event as object) as void
    resize()
end function

' Handle height change
function on_height_change(event as object) as void
    resize()
end function

' Resize the component based on the defined width and height
function resize() as void
    m.title.width = m.top.width
    m.title.height = m.top.height * .25
    m.description.width = m.top.width
    m.description.height = m.top.height * .7
    m.description.translation = [0, m.title.height + m.title.height * .05]
end function

' Handle title string change
function on_title_change(event as object) as void
    m.title.text = event.getData()
end function

' Handle description string change
function on_description_change(event as object) as void
    m.description.text = event.getData()
end function
