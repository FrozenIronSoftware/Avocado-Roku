' Copyright (C) 2018 Rolando Islas. All Rights Reserved.

' Create a new instance of the DescriptionSidebar component
function init() as void
    ' Constants
    ' Components
    m.title = m.top.findNode("title")
    m.description = m.top.findNode("description")
    m.author = m.top.findNode("author")
    m.artwork = m.top.findNode("artwork")
    ' Variables
    ' Events
    m.top.observeField("width", "on_width_change")
    m.top.observeField("height", "on_height_change")
    m.top.observeField("title", "on_title_change")
    m.top.observeField("description", "on_description_change")
    m.top.observeField("author", "on_author_change")
    m.top.observeField("artwork", "on_artwork_change")
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
    text_margin = m.top.width * .05
    text_width = m.top.width - text_margin * 2
    ' Artwork
    m.artwork.width = m.top.width * .63
    m.artwork.height = m.artwork.width
    m.artwork.translation = [m.top.width / 2 - m.artwork.width / 2, 0]
    ' Title
    m.title.maxWidth = text_width
    m.title.height = m.top.height * .064
    m.title.translation = [text_margin, m.artwork.height + text_margin]
    ' Author
    m.author.maxWidth = text_width
    m.author.height = m.top.height * .064
    m.author.translation = [text_margin, 
        m.title.translation[1] + text_margin + m.title.height]
    ' Description
    m.description.width = text_width
    m.description.height = m.top.height - m.author.translation[1]
    m.description.translation = [text_margin, 
        m.author.translation[1] + text_margin + m.author.height]
end function

' Handle title string change
function on_title_change(event as object) as void
    m.title.text = event.getData()
end function

' Handle description string change
function on_description_change(event as object) as void
    m.description.text = event.getData()
end function

' Handle author string change
function on_author_change(event as object) as void
    m.author.text = event.getData()
end function

' Handle artwork url change
function on_artwork_change(event as object) as void
    m.artwork.uri = event.getData()
end function