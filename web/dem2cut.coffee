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
    
    # global values that determine the shape of the 
    # frame cutout
    window.frame_params = {
        section_w:  0
        section_h:  0
        per_section_h: 0
        notch_d:    20
        notch_h:    2
        notch_rad:  5
        cut_offset: 6
        frame_h:    12
        edge_inset : 5
    }
    wf = window.frame_params
    wf.notch_flat = wf.notch_d - wf.notch_rad - wf.notch_h/2.0

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
        section_w = window.canvas.width - 2*( p.notch_d + 2*p.cut_offset + p.frame_h + edge_inset) 
        section_h = aspect_ratio * section_w
    else
        section_h = window.canvas.height - 60
        section_w = section_h/aspect_ratio
    
    window.frame_params.section_h = section_h    
    window.frame_params.section_w = section_w    
  
    # Draw the folds of the frame.  This has to be done 
    # before any transforms are active
    frame_folds( ctx, section_h, window.canvas.height)
    
    # transform to section origin to draw sections
    section_origin_x = (w-section_w)/2
    section_origin_y = (h-section_h)/2 + 20
    ctx.translate( section_origin_x, section_origin_y)
    
    w = section_w
    h = section_h
    
    # scale to fit in a w, h box
    scale_x = w/(arr2d[0].length - 1)
    scale_y = scale()
    per_section_h = (h)/(arr2d.length + 1)
    
    window.frame_params.per_section_h = per_section_h
    
    ctx.lineWidth = 1
    
    # draw each section
    for row, y in arr2d
        vert_trans = per_section_h*(y + 0.5)
        single_notch( ctx, window.frame_params, -section_origin_x + window.frame_params.edge_inset, vert_trans, true)
        single_notch( ctx, window.frame_params, -section_origin_x + window.frame_params.edge_inset, vert_trans, false)
        # vertical transform
        ctx.translate( 0, vert_trans)
        
        # draw the fold lines
        # fold_notches( ctx, section_w, per_section_h)
                
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
    notch_border_cuts( ctx, window.frame_params, section_origin_y)

notch_border_cuts = (ctx, params, y_margins) ->
    p = params
    # cut lines to top and bottom of notches
    ctx.beginPath()
    ctx.strokeStyle = window.cut_color
    # UL
    ctx.moveTo( p.edge_inset, 0)
    ctx.lineTo( p.edge_inset, y_margins)   
    # LL
    ctx.moveTo( p.edge_inset, window.canvas.height)
    ctx.lineTo( p.edge_inset, window.canvas.height - y_margins)      
    # UR
    ctx.moveTo( window.canvas.width - p.edge_inset, 0)
    ctx.lineTo( window.canvas.width - p.edge_inset, y_margins)   
    # LR
    ctx.moveTo( window.canvas.width - p.edge_inset, window.canvas.height)
    ctx.lineTo( window.canvas.width - p.edge_inset, window.canvas.height - y_margins)      
    
    ctx.stroke()

frame_folds = ( ctx, section_w, total_h) ->
    # assumes there's no active transform right now
    ctx.beginPath
    ctx.lineWidth = 1
    ctx.strokeStyle = window.valley_color
    wf = window.frame_params
    fold_inset = wf.edge_inset + wf.notch_d + wf.cut_offset
    x_locs = [  fold_inset, 
                fold_inset + wf.frame_h,
                window.canvas.width - fold_inset,
                window.canvas.width - fold_inset - wf.frame_h]
    for x in x_locs
        ctx.moveTo( x, 0)
        ctx.lineTo( x, total_h)
    ctx.stroke()

single_notch = ( ctx, params, origin_x, origin_y, notch_left =true) ->
    p = params
    
    ctx.beginPath()
    ctx.strokeStyle = window.cut_color
    ctx.translate( origin_x, origin_y)
    
    #   reflection
    #   cos( 2*theta)   sin(2*theta)
    #   sin( 2*theta)   -cos(2*theta)
    
    # vertical mirror
    if not notch_left
        reflection_translation = window.canvas.width - 2*p.edge_inset
        ctx.transform(-1, 0, 0, 1,  reflection_translation, 0)
    
    ctx.moveTo( 0, -p.per_section_h/2.0)
    ctx.lineTo( 0, -p.notch_h/2.0 - p.notch_rad)
    ctx.arcTo( 0,-p.notch_h/2.0, p.notch_rad, -p.notch_h/2, p.notch_rad)
    ctx.lineTo( p.notch_d - p.notch_h/2, -p.notch_h/2)
    ctx.arc( p.notch_d - p.notch_h/2, 0, p.notch_h/2, 1.5*Math.PI, 0.5*Math.PI, false)
    ctx.lineTo( p.notch_rad, p.notch_h/2)
    ctx.arcTo( 0, p.notch_h/2.0, 0, p.per_section_h/2.0, p.notch_rad)
    ctx.lineTo( 0, p.per_section_h/2)
    # invert vertical mirror
    if not notch_left
        ctx.transform(-1, 0, 0, 1, reflection_translation, 0) 
    
    # invert transform
    ctx.translate( -origin_x, -origin_y)
    
    ctx.stroke()

fold_notches = ( ctx, section_w, per_section_h) ->
    notch_w = 15
    # notch_w = 0
    notch_h = per_section_h - 5
    
    ctx.lineWidth = 1
    
    # left profile side
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
    
    #right profile side
    ctx.beginPath()
    ctx.strokeStyle = window.cut_color
    ctx.moveTo( section_w+notch_w, notch_h)
    ctx.lineTo( section_w, 0)
    ctx.stroke()
    
    # frame valley folds (4)
    frame_offset = notch_w + 5
    frame_h = notch_h
    
    # for i in [0...window.slices]
    #     single_notch( ctx, window.frame_params, 0, notch_h*( i+ 0.5), true)
    
    # right frame tab 
    # right_edge = section_w - left_edge # assumes left_edge < 0

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