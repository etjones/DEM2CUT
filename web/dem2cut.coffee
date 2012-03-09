# Hi CoffeeScript!
initializeMap = ->
    myOptions =
        zoom: 14        
        center: new google.maps.LatLng(45.38, -121.7)
        mapTypeId: google.maps.MapTypeId.TERRAIN
    window.map = new google.maps.Map(document.getElementById("map_canvas"), myOptions);
;

outlineCanvas = ->
    # Set up variables we want global access to
    window.canvas=document.getElementById("cut_canvas");
    window.slice_ctx= window.canvas.getContext("2d");
    window.slice_arr = cosArr( 30, 10)
    # A place to store any errors we get, for debugging
    window.error_return = 0
    # reSlice()

showLatLng = ->
    # Show lat/lng on slice side:
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
    
    c = window.slice_ctx
    # Blank the whole context first
    c.fillStyle="white"
    c.fillRect( 0,0, w, h)
    c.fillStyle = "black"
    drawPaths( c, window.slice_arr, w, h)      

cosArr = (w, h) ->
    arr2d = []
    for y in [0...h]
        arr2d[y] = []
        for x in [0...w]
            arr2d[y][x] = Math.cos(  (4*y + x*3)/w  *4 *Math.PI)
    arr2d

drawPaths = (ctx, arr2d, w, h) ->
    scale_x = w/arr2d[0].length
    scale_y = parseFloat( $("#scale")[0].value)
    trans_y = (h)/(arr2d.length + 1)
    # scale to fit in a w, h box
    # ctx.scale( scale_x, scale_y)
    # ctx.lineWidth = 1 / scale_y
    ctx.lineWidth = 1
    # for y in [0...arr2d.length]
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
    
    # undo scaling
    # ctx.scale( 1/scale_x, 1/scale_y)
    # console.log( arr2d)

getDemData = ->
    span = window.map.getBounds().toSpan()
    ll = window.map.getCenter()
    
    testing=false
    if testing
        input = { 
            lat: 45.33
            lng: -121.7
            lat_span: 0.1
            lng_span: 0.1
            lat_samples: slices()
            lng_samples: 30
            map_w: window.canvas.width
            map_h: window.canvas.height
            cardinal: cardinal_direction()            
            # Local testing:
            dem_file_dir: "/Users/jonese/Sites/DEM2CUT/dems/SRTM_90m_global/"
        }
    else
        # TODO: lng_samples should be defined on a more global level
        input = { 
            lat: ll.lat()
            lng: ll.lng()
            lat_span: span.lat()
            lng_span: span.lng()
            lat_samples: slices()
            lng_samples: 50
            map_w: window.canvas.width
            map_h: window.canvas.height
            cardinal: cardinal_direction()
            # For use on WebFaction
            dem_file_dir: "/home/etjones/webapps/htdocs/DEM2CUT/dems/SRTM_90m_global/"

        }
    console.log( "Sending input:")
    # for p, v of input
    #     console.log("#{p} : #{v}")
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
  $('#useLoc').live 'click', outlineCanvas
  $("#saveToPng").live 'click', saveAsPNG
  $("#reSlice").live 'click', reSlice
  $("#scale").live 'change', reSlice
  # TODO: html still contains showValue call.  Good to figure out how
  # to do that here as well...
  $("#slice_count").live( 'change', reSlice)
  
  # Add a button at bottom to test cgi
  
  cgi_test = document.createElement("input")
  cgi_test.type = "button"
  cgi_test.value = "my cgi_test"
  cgi_test.id = "cgi_test"
  
  

#END:ready