# DEM2CUT

Dem2Cut is a project initiated by Proessor Yoshinobu Miyamoto.  The intent is to automatically create paper cut patterns that make relief models of any point on earth.  An example can be found [here](http://www.flickr.com/photos/yoshinobu_miyamoto/6713516087/in/photostream/ "Mt. Fuji Papercut").

# Examples 
(SVG files can be zoomed in the browser)  
[Miyamoto's original model](examples/fuji-model-full-mt-1.pdf)  
[Miyamoto's original base](examples/fuji-model-full-base-simple.pdf)  
[Programmatically generated Fuji](examples/fuji_1.svg)  
[Programmatically generated Fuji](examples/fuji_1_frame.svg)  
[Mt. Hood, a volcanic peak near Portland, Oregon, USA](examples/hood_1.svg)  
[Mt. Rainier, a volcanic peak near Seattle, Washington, USA](examples/rainier_1.svg)  
[Steens Mountain, a fault-block mountain in barren land in SE Oregon, USA](examples/steens_1.svg)  
[Cosine Waves](examples/cosine_1.svg)  

## Current Implementations

### Ruby
A Ruby version is currently working, with some caveats.  

<pre>
Usage: dem2cut.rb  
    -l, --link LINK                  Google maps link, showing an area within a single 1x1 degree square  
    -o, --out_file OUT_FILE.svg      Path to output file    
    -d, --dem_file DEM_FILE          DEM file. Extension must be one of [.hgt, .pgm, .asc]  
    -t, --title TITLE                Title for SVG  
    -f, --frame                      If specified, output a second image for use as the frame for the cut pattern  
    -s, --slices NUM                 Number of slices in cut pattern  
    -p, --points_per_slice NUM       Number of data points in each slice  
    -c, --cardinal_dir [N|S|E|W]     Cardinal direction  
    -v, --vertical_scale FLOAT       Vertical scale factor  
    -h, --help                       Display this screen  
</pre>

Here's a 

### HTML 5
A work-in-progress is included in this repository. Current state of the art can be seen [here](http://etjones.webfactional.com/DEM2CUT/web/dem2cut.html)  

### Processing
Francesco De Comite has done some very pretty work in Processing to view DEM files. It may be added to this repository at a later date.  