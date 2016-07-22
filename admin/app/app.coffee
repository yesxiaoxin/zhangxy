
sync_gateway = '/service/gateway/sync'

when_image_inserted = (base64_content) ->
    # upload the image first
    image_path = '/_image/'+get_now('path')+'.jpg'

    # insert into textarea
    to_insert = '![Image]('+image_path+')\n'
    dom = $('textarea#content')
    if not dom
        return false
    cursorPos = dom.prop('selectionStart')
    old_value = dom.val()
    text_before = old_value.substring(0,  cursorPos )
    text_after = old_value.substring(cursorPos, old_value.length)
    dom.val(text_before+to_insert+text_after)
    dom.focus()


    image_data = {path: image_path, base64: base64_content}
    $.post sync_gateway, image_data, (response_data, status)->
        if status == 'success' and Essage
            Essage.show({message: 'Image Uploaded, Done!', status: 'success'}, 5000)


save_contents = =>
    path = $('#path').val()
    if Essage
        Essage.show({message: "Saving Now..."}, 3000)
    $.post sync_gateway, {path: path, raw_content: $('#content').val()}, ->
        if Essage
            Essage.show({message: "Contents Saved", status: 'success'}, 3000)



$(document).ready ->
    drag_image_into_dom('#content', when_image_inserted)
    $('#save').click(save_contents)