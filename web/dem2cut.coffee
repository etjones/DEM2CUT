# TODO: do these top variables need to be attached to window?
# var map = null;
# var slice_ctx;
# var canvas

# Supplied by Google; just keep this literal
`
    function initializeMap() {
        var myOptions = {
            center: new google.maps.LatLng(-34.397, 150.644),
            zoom: 8,
            mapTypeId: google.maps.MapTypeId.TERRAIN
        };
        window.map = new google.maps.Map(document.getElementById("map_canvas"), myOptions);
}
`
outlineCanvas = ->
    window.canvas=document.getElementById("cut_canvas");
    window.slice_ctx= window.canvas.getContext("2d");
    # Show lat/long on slice side:
    # Note: When run on page load, ll hasn't been generate yet. 
    # How to wait until it's available?
    ll = window.map.getBounds()
    # alert "map bounds not found" unless ll?
    if (ll)
        sw = ll.getSouthWest()
        ne = ll.getNorthEast()
        out_s = "(#{sw.toUrlValue(3)}, #{ne.toUrlValue(3)})"
    else
        out_s = "( ?, ?)"
    document.getElementById("lat_long").innerHTML= out_s
    # Note:  this below doesn't seem to work.  Why?
    # $('#lat_long').innerText = out_s
    reSlice()

saveAsPNG = ->
    # TODO: Better to open a new tab with this?          
    window.location = window.canvas.toDataURL("image/png");  

showValue = (newValue, id)  -> 
    document.getElementById( id).innerHTML=newValue

reSlice = ->
    w = window.canvas.width
    h = window.canvas.height
    slices = parseInt(document.getElementById("slice_count").value, 10)
    arr = cosArr( Math.floor(w/3), slices )    
    c = window.slice_ctx
    # Blank the whole context first
    c.fillStyle="white"
    c.fillRect( 0,0, w, h)
    c.fillStyle = "black"
    drawPaths( c, arr, w, h)      

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
  # TODO: figure how to call showValue from slices
  # $("#slice_count").live( 'change', showValue(this.value, &quot;slices&quot;); reSlice)
  

#END:ready