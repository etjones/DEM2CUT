# Hi CoffeeScript!
initializeMap = ->
    myOptions =
        zoom: 6        
        center: new google.maps.LatLng(-30.397, 140.644)
        mapTypeId: google.maps.MapTypeId.TERRAIN
    window.map = new google.maps.Map(document.getElementById("map_canvas"), myOptions);

outlineCanvas = ->
    # Set up variables we want global access to
    window.canvas=document.getElementById("cut_canvas");
    window.slice_ctx= window.canvas.getContext("2d");
    window.slice_arr = cosArr( 30, 10)
    # reSlice()

showLatLng = ->
    # Show lat/lng on slice side:
    # Note: When run on page load, ll hasn't been generate yet. 
    # How to wait until it's available?
    ll = window.map.getBounds()
    # alert "map bounds not found" unless ll?
    if (ll)
        sw = ll.getSouthWest()
        ne = ll.getNorthEast()
        out_s = "(#{sw.toUrlValue(2)}, #{ne.toUrlValue(2)})"
    else
        out_s = "( ?, ?)"
    document.getElementById("lat_lng").innerHTML= out_s
    # Note:  this below doesn't seem to work.  Why?
    # $('#lat_lng').innerHTML( out_s)

saveAsPNG = ->
    # FIXME: Better to open a new tab with this?          
    window.location = window.canvas.toDataURL("image/png");  

showValue = (newValue, id)  -> 
    document.getElementById( id).innerHTML=newValue

slices = -> parseInt(document.getElementById("slice_count").value, 10)
reSlice = ->
    showLatLng()
    
    w = window.canvas.width
    h = window.canvas.height
    # window.slice_arr = cosArr( Math.floor(w/3), slices() )    
    getDemData()
    # ETJ DEBUG
    console.log( "getDemData returned array of size (#{window.slice_arr.length}, #{window.slice_arr[0].length})")
    # END DEBUG
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
    scale_y = parseFloat( document.getElementById("scale").value)
    trans_y = (h/scale_y)/(arr2d.length + 1)
    # scale to fit in a w, h box
    ctx.scale( scale_x, scale_y)
    ctx.lineWidth = 1 / scale_y
    # for y in [0...arr2d.length]
    for row, y in arr2d
        # vertical transform
        ctx.translate( 0, trans_y*(y + 0.5))
        ctx.beginPath()
        for elt, x in row
            ctx.lineTo( x, elt)
        ctx.stroke()
        # undo vertical transform.  
        ctx.translate( 0, -trans_y*(y + 0.5))
    
    # undo scaling
    ctx.scale( 1/scale_x, 1/scale_y)

getDemData = ->
    span = window.map.getBounds().toSpan()
    ll = window.map.getCenter()
    
    testing=true
    if testing
        # lat=0.62&lng=16.47&lat_span=0.15&lng_span=0.15&lat_samples=10&lng_samples=30&dem_file_dir=%2FUsers%2Fjonese%2FSites%2FDEM2CUT%2Fdems%2FSRTM_90m_global%2F
        input = { 
            lat: 0.62
            lng: 16.47
            lat_span: 0.15
            lng_span: 0.15
            lat_samples: slices()
            lng_samples: 30
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
            # For use on WebFaction
            dem_file_dir: "/home/etjones/webapps/htdocs/DEM2CUT/dems/SRTM_90m_global/"
        }
    
    success_ = (result,status,xhr) ->
        window.slice_arr = result;
    
    error_response = (result, status, xhr) -> 
        alert( status + ": " + result + ": " + xhr)        
    
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