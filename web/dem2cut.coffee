# Hi CoffeeScript!
initializeMap = ->
    myOptions =
        zoom: 14        
        center: new google.maps.LatLng(35.36, 138.73)
        mapTypeId: google.maps.MapTypeId.TERRAIN
    window.map = new google.maps.Map(document.getElementById("map_canvas"), myOptions);
;

outlineCanvas = ->
    # Set up variables we want global access to
    window.canvas=document.getElementById("cut_canvas");
    window.slice_ctx= window.canvas.getContext("2d");
    window.slice_arr = cosArr( 100, slices())
    # A place to store any errors we get, for debugging
    window.error_return = 0
    
    window.last_cgi_time = 0
    window.min_cgi_gap = 200
    
    # Paper-cutting globals.  Should probably be stored in another object
    window.valley_color     = "#007299"
    window.mountain_color   = "#30c05a"
    window.cut_color        = "#7f3f00"

showLatLng = ->
    # Show latw/lng on slice side:
    # FIXME: When run on page load, ll hasn't been generated yet. 
    # How to wait until it's available?
    ll = window.map.getBounds()
    # alert "map bounds not found" unless ll?
    if (ll)
        sw = ll.getSouthWest()
        ne = ll.getNorthEast()
        out_s = "(#{sw.toUrlValue(2)}, #{ne.toUrlValue(2)})"
    else
        out_s = "( ?, ?)"
    $("#lat_lng")[0].innerHTML= out_s

saveAsPNG = ->
    window.open( window.canvas.toDataURL("image/png"))

showValue = (newValue, id)  -> 
    document.getElementById( id).innerHTML=newValue

updateSlices = ->
    $("#slices")[0].innerHTML = slices()
    reSlice()

slices = -> parseInt($("#slice_count")[0].value, 10)
scale = -> parseFloat( $("#scale")[0].value)
cardinal_direction = -> 
    switch $("#cardinal_direction")[0].value
        when "North" then 0
        when "South" then 1
        when "East"  then 2
        when "West"  then 3

reSlice = ->
    showLatLng()
    
    w = window.canvas.width
    h = window.canvas.height
    # window.slice_arr = cosArr( Math.floor(w/3), slices() )    
    getDemData() 
    drawPaths()  

cosArr = (w, h) ->
    arr2d = []
    for y in [0...h]
        arr2d[y] = []
        for x in [0...w]
            arr2d[y][x] = Math.cos(  (4*y + x*3)/w  *4 *Math.PI)
    arr2d

drawPaths = ->
    ctx = window.slice_ctx
    arr2d = window.slice_arr
    w = window.canvas.width
    h = window.canvas.height
    
    # Blank the whole context first
    ctx.fillStyle="white"
    ctx.fillRect( 0,0, window.canvas.width, window.canvas.height)
    
    # figure the area we'll be drawing sections into
    # and adjust for aspect ratio of map
    span = window.map.getBounds().toSpan()    
    aspect_ratio = span.lat()/ span.lng()
    if aspect_ratio <= 1
        section_w = window.canvas.width - 60
        section_h = aspect_ratio * section_w
    else
        section_h = window.canvas.height - 60
        section_w = section_h/aspect_ratio
    
    # transform to section origin to draw sections
    section_origin_x = (w-section_w)/2
    section_origin_y = (h-section_h)/2 + 20
    ctx.translate( section_origin_x, section_origin_y)
    
    w = section_w
    h = section_h
    
    # scale to fit in a w, h box
    scale_x = w/arr2d[0].length
    scale_y = scale()
    per_section_h = (h)/(arr2d.length + 1)
    ctx.lineWidth = 1
    
    # draw each section
    for row, y in arr2d
        vert_trans = per_section_h*(y + 0.5)
        # vertical transform
        ctx.translate( 0, vert_trans)
        
        # draw the fold lines
        fold_notches( ctx, section_w, per_section_h)
                
        # draw the cross-section
        ctx.beginPath()
        ctx.strokeStyle = window.cut_color 
        ctx.moveTo( 0, 0)
        for elt, x in row
            ctx.lineTo( scale_x * x, -scale_y * elt)
        ctx.lineTo( w, 0)
        ctx.fill()
        ctx.stroke()
        
        # undo vertical transform.  
        ctx.translate( 0, -vert_trans)
    
    # undo transform to section origin
    ctx.translate( -section_origin_x, -section_origin_y)
    
    # ETJ DEBUG
    # console.log( arr2d.concat())
    # log2DArray( arr2d)
    # END DEBUG

fold_notches = ( ctx, section_w, per_section_h) ->
    
    notch_w = 15
    notch_h = per_section_h - 5
    
    ctx.lineWidth = 1
    
    ctx.beginPath()
    ctx.moveTo( 0,0)
    ctx.strokeStyle = window.cut_color
    ctx.lineTo( -notch_w, notch_h)
    ctx.stroke()
    
    # horizontal fold line
    ctx.beginPath()
    ctx.strokeStyle = window.valley_color
    ctx.moveTo( -notch_w, notch_h)    
    ctx.lineTo( section_w+notch_w, notch_h)
    ctx.stroke()
    
    ctx.beginPath()
    ctx.strokeStyle = window.cut_color
    ctx.moveTo( section_w+notch_w, notch_h)
    ctx.lineTo( section_w, 0)
    ctx.stroke()

log2DArray = (arr2d) ->
    console.log( "**** 2d Arr ****")
    for row, y in arr2d
        line = row.join(" ")
        console.log(line)

    
getDemData = ->
    span = window.map.getBounds().toSpan()
    ll = window.map.getCenter()
    
    # Only fire off the CGI script every window.min_cgi_gap millis
    cur_time = new Date().getTime()
    if cur_time - window.last_cgi_time < window.min_cgi_gap  
        return null
    else
        window.last_cgi_time = cur_time
    
    testing=false
    # testing = true
    if testing
        lat = 45.33
        lng =  -121.7
        lat_span =  0.1
        lng_span =  0.1
    else
        lat = ll.lat()
        lng =  ll.lng()
        lat_span =  span.lat()
        lng_span =  span.lng()
    
    # NOTE: sending window.canvas.[height|width] isn't really 
    # correct, since we'll be drawing into a smaller area than the
    # canvas itself.  But since those values aren't actually used 
    # by the cgi program, shouldn't be a problem. -ETJ 06 Apr 2012
    # TODO: lng_samples should be defined on a more global level
    input = { 
        lat: lat
        lng: lng
        lat_span: lat_span
        lng_span: lng_span
        lat_samples: slices()
        lng_samples: 50
        map_w: window.canvas.width
        map_h: window.canvas.height
        cardinal: cardinal_direction()
        dem_file_dir: "../../dems/SRTM_90m_global/"
    }
    # # ETJ DEBUG
    # console.log( "Sending input:")
    # query_string = 'export QUERY_STRING=\"'
    # for p, v of input
    #     console.log("#{p} : #{v}")
    #     query_string += "#{p}=#{v}&"
    # query_string = query_string.replace /&$/, '"'
    # console.log(query_string)
    # # END DEBUG
            
    success_ = (result,status,xhr) ->
        window.slice_arr = result;
    
    error_response = (result, status, xhr) -> 
        console.log( status + ": " + xhr + "\nError results are stored in window.error_return")
        window.error_return = [result, status, xhr  ]
        
    
    $.ajax({
        url:"cgi-bin/dem_extractor.cgi",
        dataType: 'json',
        data: input,
        success: success_,
        error:   error_response
    })
    

#START:ready
$(document).ready ->
  initializeMap()
  outlineCanvas()
  # FIXME: several of these buttons seem to only take effect
  # after being pressed twice.  I suspect this may be because 
  # the CGI doesn't return until drawPaths has returned, meaning
  # that reSlice/drawPaths needs to be called a second time to
  # show the updated data from the asynchronous CGI call. -ETJ 23 Mar 2012
  $("#saveToPng").live( 'click', saveAsPNG)
  $("#scale"    ).live( 'change', drawPaths) 
  $("#reSlice"  ).live( 'click', reSlice) 
  $("#cardinal_direction").live( 'change', reSlice)
  $("#slice_count").live( 'change', updateSlices)
  
  
  

#END:ready