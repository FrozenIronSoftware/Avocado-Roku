' Copyright (C) 2018 Rolando Islas. All Rights Reserved.

' Determine if the key should be singular or plural based on the amount and
' find the correct translation
function trs(key as string, amount as integer) as string
    if amount = 1 or amount = -1
        return tr(key + "_singular")
    end if
    return tr(key + "_plural")
end function

' Clean a string that may have invalid characters.
function clean(dirty as object) as string
    if m._clean_regex = invalid
        m._clean_regex = createObject("roRegex", "[^A-Za-z0-9\s!@#$%^&*()_\-+=<,>\./\?';\:\[\]\{\}\\\|" + chr(34) + "]", "")
    end if
    if type(dirty) <> "roString" and type(dirty) <> "String" and type(dirty) <> "string"
        return ""
    end if
    return m._clean_regex.replaceAll(dirty, "")
end function

' Log a message
' @param level log level string or integer
' @param msg message to print
function printl(level as object, msg as object) as void
    if _parse_level(level) > m.log_level
        return
    end if
    print(msg)
end function

' Parse level to an integer
' @param level string or integer level
function _parse_level(level as object) as integer
    level_string = level.toStr()
    log_level = 0
    if level_string = "INFO" or level_string = "0"
        log_level = m.INFO
    else if level_string = "DEBUG" or level_string = "1"
        log_level = m.DEBUG
    else if level_string = "EXTRA" or level_string = "2"
        log_level = m.EXTRA
    else if level_string = "VERBOSE" or level_string = "3"
        log_level = m.VERBOSE
    end if
    return log_level
end function

' Initialize logging
function init_logging() as void
    m.INFO = 0
    m.DEBUG = 1
    m.EXTRA = 2
    m.VERBOSE = 3
    level_string = m.global.secret.log_level
    log_level = 0
    if level_string = "INFO" or level_string = "0"
        log_level = m.INFO
    else if level_string = "DEBUG" or level_string = "1"
        log_level = m.DEBUG
    else if level_string = "EXTRA" or level_string = "2"
        log_level = m.EXTRA
    else if level_string = "VERBOSE" or level_string = "3"
        log_level = m.VERBOSE
    end if
    m.log_level = log_level
end function

' Returns a string representation of a number, with delimiters added for
' readability
function pretty_number(ugly_number as dynamic) as string
    ' Check if the number is large enough for a delimiter
    if ugly_number < 1000
        return ugly_number.toStr()
    end if
    ' Determine delimiter
    delimiter = get_regional_number_delimiter()
    ' Construct the string with the delimiter
    ugly = ugly_number.toStr().split("")
    ugly_reversed = []
    for digit = ugly.count() - 1 to 0 step -1
        ugly_reversed.Push(ugly[digit])
    end for
    ugly = ugly_reversed
    pretty = ""
    digit_count = 0
    for each digit in ugly
        if digit_count = 3
            pretty = delimiter + pretty
            digit_count = 0
        end if
        pretty = digit + pretty
        digit_count++
    end for
    return pretty
end function

' Return the character used to delimit thousands in a number
function get_regional_number_delimiter() as string
    device_info = createObject("roDeviceInfo")
    country_code = device_info.getCountryCode()
    if country_code = "US" or country_code = "GB" or country_code = "IE"
        return ","
    else if country_code = "CA" or country_code = "FR"
        return " "
    else if country_code = "MX"
        return "."
    else if country_code = "OT"
        return " "
    end if
    return " "
end function

' Show an error message
' Expects the component calling this to have the following global fields: dialog
' Expects the component calling this to have the following internal variables: dialog, dialog_type
' Expects the logger to have been initialized
function error(msg as string, error_code = invalid as object, title = "" as string, buttons = [tr("button_confirm")] as object) as void
    msg = tr(msg)
    printl(m.WARN, msg)
    if title = ""
        title = tr("title_error")
    else
        title = tr(title)
    end if
    ' Show error
    m.dialog.title = title
    m.dialog.message = msg
    if error_code <> invalid
        m.dialog.message += chr(10) + tr("title_error_code") + ": " + error_code.toStr()
        printl(m.WARN, "Error Code: " + error_code.toStr())
    end if
    m.dialog.buttons = buttons
    m.dialog.visible = true
    m.dialog_type = m.DIALOG_INFO
    m.top.dialog = m.dialog
end function

' Handle registry being written to
' Prints an error if the write was not successful
' Expects logging to be initialized
' @param event Registry result event
function on_reg_write(event as object) as void
    success = event.getData().result.result
    if not success
        printl(m.WARN, "Failed to " + event.getData().result.type + " registry value: " + event.getData().result.section + ": ")
        keys = event.getData().result.key
        if type(keys, 3) = "roString"
            printl(m.WARN, "  " + keys)
        else if type(keys) = "roAssociativeArray"
            for each key in keys
                printl(m.WARN, "  " + key)
            end for
        end if
    end if
end function