# DEM2CUT

Dem2Cut is a project initiated by Proessor Yoshinobu Miyamoto.  The intent is to automatically create paper cut patterns that make relief models of any point on earth.  ![Mitani's South Side of Mt. FujiModel ](http://etjones.webfactional.com/DEM2CUT/examples/Mitani_Fuji_South_side_6713516087.jpg)

The Fuji cut pattern:
![Mt. Fuji Cut Pattern](http://etjones.webfactional.com/DEM2CUT/examples/fuji-model-full-mt-1.jpg)

Further examples can be found [here](http://www.flickr.com/photos/yoshinobu_miyamoto/6713516087/in/photostream/ "Mt. Fuji Papercut").

# Examples 
(SVG files can be zoomed in the browser)  
[Miyamoto's original model](http://etjones.webfactional.com/DEM2CUT/examples/fuji-model-full-mt-1.pdf)  
[Miyamoto's original base](http://etjones.webfactional.com/DEM2CUT/examples/fuji-model-full-base-simple.pdf)  
[Programmatically generated Fuji](http://etjones.webfactional.com/DEM2CUT/examples/fuji_1.svg)  
[Programmatically generated Fuji](http://etjones.webfactional.com/DEM2CUT/examples/fuji_1_frame.svg)  
[Mt. Hood, a volcanic peak near Portland, Oregon, USA](http://etjones.webfactional.com/DEM2CUT/examples/hood_1.svg)  
[Mt. Rainier, a volcanic peak near Seattle, Washington, USA](http://etjones.webfactional.com/DEM2CUT/examples/rainier_1.svg)  
[Steens Mountain, a fault-block mountain in barren land in SE Oregon, USA](http://etjones.webfactional.com/DEM2CUT/examples/steens_1.svg)  
[Cosine Waves](http://etjones.webfactional.com/DEM2CUT/examples/cosine_1.svg)  

## Current Implementations

### HTML 5
A work-in-progress is included in this repository. Current state of the art can be seen [here](http://etjones.webfactional.com/DEM2CUT/web/dem2cut.html)  

### Ruby
A Ruby version is currently working, with some caveats.  

**NOTE:** Use the following command to check out the repository; because it 
includes a submodule, Github's HTTP download won't run correctly.  

    git clone --recursive git://github.com/etjones/DEM2CUT.git

#### Usage: dem2cut.rb  
<pre>

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

Example DEM files in pgm format can be found [here.](http://etjones.webfactional.com/DEM2CUT/dems/ASTGTM2/)
You'll have to download them to your computer before using them with dem2cut.  

Here's an example command line used to create [this cut pattern](http://etjones.webfactional.com/DEM2CUT/examples/cli_cut.svg)
 and [this base.](http://etjones.webfactional.com/DEM2CUT/examples/cli_cut_frame.svg)  
 
<pre>
    cd $PATH_TO/DEM2CUT/ruby
    ruby ./dem2cut.rb -l "http://maps.google.com/?ll=45.369635,-121.698475&spn=0.081885,0.11982&z=13&vpsrc=6" -d "$HOME/Desktop/ASTGTM2_N45W122_dem.pgm" -o "$HOME/Desktop/cli_cut.svg" -f -t "Mt. Hood"
</pre>
