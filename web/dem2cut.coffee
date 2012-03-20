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
    # reSlice()

showLatLng = ->
    # Show latw/lng on slice side:
    # Note: When run on page load, ll hasn't been generated yet. 
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
    # FIXME: Better to open a new tab with this?          
    window.location = window.canvas.toDataURL("image/png");  

showValue = (newValue, id)  -> 
    document.getElementById( id).innerHTML=newValue

cardinal_direction = -> 
    switch $("#cardinal_direction")[0].value
        when "North" then 0
        when "South" then 1
        when "East"  then 2
        when "West"  then 3

slices = -> parseInt($("#slice_count")[0].value, 10)
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
    ctx.fillRect( 0,0, w, h)
    ctx.fillStyle = "black"
    
    # scale to fit in a w, h box
    scale_x = w/arr2d[0].length
    scale_y = parseFloat( $("#scale")[0].value)
    trans_y = (h)/(arr2d.length + 1)
    ctx.lineWidth = 1
    for row, y in arr2d
        # vertical transform
        ctx.translate( 0, trans_y*(y + 0.5))
        ctx.lineWidth = 1
        ctx.beginPath()
        for elt, x in row
            ctx.lineTo( scale_x * x, -scale_y * elt)
        ctx.stroke()
        # undo vertical transform.  
        ctx.translate( 0, -trans_y*(y + 0.5))
    
    # ETJ DEBUG
    # console.log( arr2d.concat())
    # log2DArray( arr2d)
    # END DEBUG

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
    # ETJ DEBUG
    # console.log( "lat: #{lat}  lng: #{lng} lat_span: #{lat_span} lng_span: #{lng_span}")    
    # END DEBUG
    
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
    # ETJ DEBUG
    # console.log( "Sending input:")
    # for p, v of input
    #     console.log("#{p} : #{v}")
    # END DEBUG
            
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
  # Hook buttons to actions.  Haven't figured out namespacing to 
  # be able to do this from the HTML yet -ETJ 08 Feb 2012
  $('#useLoc'   ).live( 'click', outlineCanvas)
  $("#saveToPng").live( 'click', saveAsPNG)
  $("#reSlice"  ).live( 'click', reSlice)
  $("#scale"    ).live( 'change', drawPaths)
  # TODO: html still contains showValue call.  Good to figure out how
  # to do that here as well...
  $("#slice_count").live( 'change', reSlice)
  
  # Add a button at bottom to test cgi
  
  cgi_test = document.createElement("input")
  cgi_test.type = "button"
  cgi_test.value = "my cgi_test"
  cgi_test.id = "cgi_test"
  
  

#END:ready