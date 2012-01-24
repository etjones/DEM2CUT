#!/usr/bin/env ruby -KU
require 'rubygems'
require 'rasem'

def read_pgm_header( pgm_path)
   pgm_header_re = /P(\d)\n(\d+)\s+(\d+)\n(\d+)\n/
   header = ""
   data = []
   lines_found = 0
   filetype, width, height, range, header_bytes = [nil] *5
   open( pgm_path, "r") do |f|
        while lines_found < 3 do
            l = f.readline
            # ignore comment lines
            next if l[0...1] == "#"
            header << l
            lines_found += 1
        end
        match = pgm_header_re.match(header)
        # NOTE: should raise exception if the header wasn't recognized?
        if not match; return false; end
        filetype, width, height, range = match.captures.map { |e| e.to_i }
        header_bytes = f.pos
    end
    return [filetype, width, height, range, header_bytes]
end
def pgm_header( width, height, range=255, filetype=5)
    header = %Q{P#{filetype}\n#{width} #{height}\n#{range}\n}
end
def pgm_2_8bps( pgm_path, max_elevation=8500)
    filetype, width, height, range, header_bytes = read_pgm_header( pgm_path)
    data = pgm_2_arr( pgm_path, max_elevation)    
    
    # We're scaling all values in data by the same factor. So
    # rather than recalculate this factor thousands of times (with associated
    # expensive divisions), just do it once
    scale_factor = 1.0/(max_elevation/ 256.0)
    
    height.times { |y| 
        width.times { |x|  
            d = data[y][x]
            # We're scaling to max_elevation, but it wouldn't be unreasonable
            # to scale to the actual max value in the file
            # data[y][x] = scale( d, 0, max_elevation, 0, 255).to_i
            data[y][x] = (data[y][x] * scale_factor).to_i
        } 
    }
    out = pgm_header( width, height, 255, 5)
    height.times { |y|  out << data[y].pack("C*")}
    
    
    dirname, basename = File.split( File.expand_path(pgm_path))
    file_8bps = dirname + "/" + File.basename(basename, ".*") + "_8bps.pgm"
    open( file_8bps, "w"){|f| f.write(out)}
end
def pgm_2_arr( pgm_path, max_elevation=8500)
   data = []

   filetype, width, height, range, header_bytes = read_pgm_header( pgm_path)
   return false unless filetype == 5
   open( pgm_path, "r") do |f|
        # we've already read the header. skip it.
        f.read( header_bytes)

        if range > 255
            token_key = 'n*' 
            bytes_per_token = 2
        else
            token_key = 'C*'
            bytes_per_token = 1
        end
        height.times { |y|  
            data[y] = f.read( bytes_per_token*width).unpack( token_key)
            # Set any data higher than max_elevation to zero
            data[y].map!{|e| e > max_elevation ? 0 : e}
        }
   end
   
   data
   
end

class LatLong
    attr_reader :lat, :long
    def initialize( lat, long)
        @lat = lat
        @long = long
    end
    def is_in_region( region)
        region.includes_point?( self)
    end
    def to_s
        "(%.2f, %.2f)"%[lat, long]
    end
end
class LatLongRegion
    attr_reader :min_lat_long, :max_lat_long, :min_lat, :max_lat, :min_long, :max_long
    def initialize( min_lat_long, max_lat_long)
        @min_lat_long = min_lat_long
        @max_lat_long = max_lat_long

        min_lat, max_lat   = [@min_lat_long, @max_lat_long].map { |e| e.lat }.sort
        min_long, max_long = [@min_lat_long, @max_lat_long].map { |e| e.long }.sort

        # handle wraparound, so regions straddling +/-180 degrees work
        # FIXME: logic here isn't right.  Needs tests -ETJ 20 Jan 2012
        if   (max_lat-min_lat).abs > 180: min_lat, max_lat = max_lat, min_lat end
        if (max_long-min_long).abs > 180: min_long, max_long = max_long, min_long end
        @min_lat = min_lat
        @min_long = min_long
        @max_lat = max_lat
        @max_long = max_long
        @min_lat_long = LatLong.new(@min_lat, @min_long)
        @max_lat_long = LatLong.new(@max_lat, @max_long)
    end
    def to_s
        "#{min_lat_long} to #{max_lat_long}"
    end
    def LatLongRegion.region_from_google_maps_link( gm_link)
        # Parse region from links like:
        # "http://maps.google.com/?ll=45.369635,-121.698475&spn=0.081885,0.11982&z=13&vpsrc=6"
        found_groups = /ll=(-?\d+\.\d+),(-?\d+\.\d+)&spn=(\d+\.\d+),(\d+\.\d+)/.match( gm_link)
        # TODO: error checking
        lat, long, lat_span, long_span = found_groups.captures.map { |e| e.to_f }
        min = LatLong.new( lat - lat_span/2, long - long_span/2)
        max = LatLong.new( lat + lat_span/2, long + long_span/2)
        LatLongRegion.new( min, max)
    end
    def LatLongRegion.region_from_ASTER_filename( aster_file)
        # parse filenames like: ASTGTM2_N45W122_dem for lat/long data.
        # these files are all one degree wide & high
        found_groups = /ASTGTM2_(\w)(\d+)(\w)(\d+)_dem/.match( aster_file) 
        north_south, lat, east_west, long = found_groups.captures
        long = long.to_i * (east_west == "E" ? 1 : -1)
        lat = lat.to_i * (north_south == "N" ? 1 : -1)
        
        min = LatLong.new( lat, long)
        max = LatLong.new( lat + 1, long + 1)
        LatLongRegion.new( min, max)
    end
    def contains_point?( lat_long)
        ((min_lat..max_lat).include?(lat_long.lat) and
        (min_long..max_long).include?(lat_long.long))
    end
    def four_corners
        [min_lat_long, LatLong.new( @min_lat, @max_long), LatLong.new(@max_lat, @min_long), max_lat_long]
    end
    def contains_region?( region)
       region.four_corners.all? { |e| self.contains_point? e } 
    end
end
class DemData
    attr_reader :region, :data
    def initialize( region, data=nil)
        """DemData represents a rectangular region on earth,
        and can be queried about the elevation at any particular point
        within its bounds""" # !> unused literal ignored
        @region = nil
        @data = data # for now, assume data is a 2D array of elevations
        set_region( region)
    end
    def set_region( region)
        @region = region
    end
    def sample( vert_points, horiz_points, orientation=:north, sub_region=nil)
        # if sub_region is supplied and is valid, temporarily use it
        should_switch = sub_region and region.contains_region?( sub_region)
        if should_switch
            old_region = region
            set_region( sub_region)
        end
        llr = region
        
        # TODO raise error if not [:north, :south, :east, :west].include? orientation
        
        x1, x2, y1, y2, x_samples, y_count = case orientation
           when :north
               [llr.min_long, llr.max_long, llr.min_lat, llr.max_lat, horiz_points, vert_points]
           when :south 
               [llr.max_long, llr.min_long, llr.max_lat, llr.min_lat, horiz_points, vert_points]
           when :east
               [llr.min_lat, llr.max_lat, llr.max_long, llr.min_long, vert_points, horiz_points]
           when :west
               [llr.max_lat, llr.min_lat, llr.min_long, llr.max_long, vert_points, horiz_points]
           else puts "orientation: #{orientation} but should be in " + [:north, :south, :east, :west].to_s
        end

        # # ETJ DEBUG
        # puts "x1 = #{x1}"
        # puts "x2 = #{x2}"
        # puts "y1 = #{y1}"
        # puts "y2 = #{y2}"
        # puts "x_samples = #{x_samples}"
        # puts "y_count = #{y_count}"
        # # END DEBUG

        x_gap = (x2 - x1).to_f / (x_samples - 1)
        y_gap = (y2 - y1).to_f / (y_count - 1)
        
        invert_lat_long = [:east, :west].include?( orientation)

        # Switch region back if needed
        if should_switch
            set_region( old_region)
        end
        
        sections = []
        vert_points.times { |i| 
            lat = y1 + y_gap*i
            sections[i] = []
            horiz_points.times { |j| 
                long = x1 + x_gap*j
                lat_long = LatLong.new( *(invert_lat_long ? [long, lat] : [lat, long])) 
                # ETJ DEBUG
                if i%10 == 0 and j %10 == 0
                    puts "(#{j}, #{i}) at lat/long: #{lat_long}"
                end
                # END DEBUG
                sections[i] << elevation_at_location( lat_long)
            }
        }
        

        sections
    end
    def elevation_at_location( lat_long)
        # find the indices of the four data points 
        # closest to lat_long
        # then interpolate between them to find the elevation
        
        x, y = lat_long.long, lat_long.lat
        
        min_x_ind = 0
        min_y_ind = 0
        max_y_ind = @data.length - 1
        max_x_ind = @data[0].length - 1        
        
        # Find where in the data we want to look
        y_fractional_index = scale( y, region.min_lat,  region.max_lat,  min_y_ind, max_y_ind)
        x_fractional_index = scale( x, region.min_long, region.max_long, min_x_ind, max_x_ind)
        y_ind_1 = y_fractional_index.to_i
        x_ind_1 = x_fractional_index.to_i
        # don't go off the edges of the array
        if y_ind_1 == max_y_ind; y_ind_1 -= 1; end
        if x_ind_1 == max_x_ind; x_ind_1 -= 1; end
        x_ind_2 = x_ind_1 + 1
        y_ind_2 = y_ind_1 + 1
        
        two_by_two = [  [@data[y_ind_1][x_ind_1], @data[y_ind_1][x_ind_2]],
                        [@data[y_ind_2][x_ind_1], @data[y_ind_2][x_ind_2]]                  
                     ]
        # elev = bilinear_interpolation( x, y, region.min_long, region.min_lat,
        #             region.max_long, region.max_lat, two_by_two)
        elev = bilinear_interpolation( x_fractional_index, y_fractional_index,
                    x_ind_1, y_ind_1, x_ind_2, y_ind_2, two_by_two)
        return elev
    end
    def DemData.from_ASTER_pgm( pgm_path, max_elevation = 8500)
         region = LatLongRegion.region_from_ASTER_filename( pgm_path)
         data = pgm_2_arr( pgm_path, max_elevation)
         # TODO: error checking
         DemData.new( region, data)
    end
end
def scale( val, src_min, src_max, dest_min, dest_max)
    retval = (val - src_min).to_f/(src_max - src_min) * (dest_max - dest_min) + dest_min
    # # ETJ DEBUG
    # puts "val = #{val}"
    # puts "src_min = #{src_min}"
    # puts "src_max = #{src_max}"
    # puts "dest_min = #{dest_min}"
    # puts "dest_max = #{dest_max}"
    # puts "retval = #{retval}"
    # # END DEBUG
    retval
end
def bilinear_interpolation( x, y, x1, y1, x2, y2, two_by_two)
    # Code adapted from http://en.wikipedia.org/wiki/Bilinear_interpolation,
    # retrieved 22 Jan 2012    
    a = two_by_two[0][0] # data at: [y1, x1]
    b = two_by_two[0][1] # data at: [y1, x2]
    c = two_by_two[1][0] # data at: [y2, x1]
    d = two_by_two[1][1] # data at: [y2, x2]
    
    recip = 1.0/((x2 -x1)*(y2-y1))

    interp = (a * recip * (x2 -  x) * (y2-y) + 
              b * recip * ( x - x1) * (y2-y) +
              c * recip * (x2 -  x) * (y-y1) +
              d * recip * ( x - x1) * (y-y1)
             )
    # # ETJ DEBUG
    # puts "x1,y1:    #{x1}\t#{y1}"
    # puts "x2,y2:    #{x2}\t#{y2}"
    # puts "x,y:      #{x}\t#{y}"    
    # 
    # puts "a,b:      #{a}\t#{b}"
    # puts "c,d:      #{c}\t#{d}"
    # puts "interp:   #{interp}"
    # # END DEBUG
    interp
end

class DemFetcherASTER
    @@local_ASTER_repo_dir = "/Users/jonese/Desktop/ASTER_repo/"
    @@local_ASTER_repo_list = @@local_ASTER_repo_dir + "ASTER_repo_list.json"
    def initialize( region)
        """ Look through the local ASTER repo. If any areas of @region are
        not locally present, download them and add them to the local repo,
        keeping track of which regions are already present in the repo list
        JSON file.

        """ # !> unused literal ignored
        @region = region
    end
end
class DemPaperCut
    @@svg_cut_style     = {:stroke => "#7f3f00", :stroke_width => 0.5, :fill => "none"}
    @@svg_valley_style  = {:stroke => "#007299", :stroke_width => 0.5, :fill => "none"}
    @@svg_mountain_style= {:stroke => "#30c05a", :stroke_width => 0.5, :fill => "none"}
    attr_accessor :orientation, :cut_width, :cut_height, :num_sections
    attr_reader :top_margin, :bot_margin, :section_h, :r_notch, :slot_width
    attr_reader :all_frame_width, :frame_width, :frame_elev
    attr_reader :x_samples
    attr_reader :dem_data
    A4_W, A4_H = 216, 279
    def initialize( dem_data,orientation=:north, 
        cut_width=133, cut_height=133,
        num_sections=25, x_samples=100,
        bot_margin=8.5, top_margin=18.5)
        """ Using a DemData instance, create a pattern of paper cuts & folds
        sufficient to represent DemData's region

        """ # !> unused literal ignored
        # TODO:  Initialization should analyze dem_data as necessary
        # and break it up into num_sections elevations.
        # Methods will ouput that data in different formats

        # TODO: margins & section separation need to be adaptive
        # to the data. If elevation is significantly different between
        # one section and the next, cut lines can interfere.
        
        # Likewise, margins might not be adequate if top or bottom
        # elevations are large
        @dem_data = dem_data
        @orientation = orientation
        @num_sections = num_sections
        @cut_width = cut_width
        @cut_height = cut_height
        @bot_margin = bot_margin
        @top_margin = top_margin
        @section_h = (cut_height-top_margin-bot_margin)/(num_sections -1)
        @notch_depth = 7.25
        
        @frame_elev = 5
        @frame_width = 12.5        
        @all_frame_width = @cut_width + 2* (@frame_elev + @frame_width)
        @r_notch = 2.5
        @slot_width = 0.5
        
        @x_samples = x_samples
        
    end
    def scale_data_points( samples)
       # Go through and generate all data points
       all_pts = samples.flatten
       max_src = all_pts.max
       min_src = all_pts.min
       range_src = max_src - min_src
       
       # Really, we need to know the largest gap between a point in
       # one section and a point in the next section: 
       # max( (samples[i][j] - samples[i+1][j]).abs) for i in num_sections, j in x_samples
       
       # But that's kind of overkill at the moment.  Let's just try 
       # a simple rule -ETJ 22 Jan 2012
       min_dest = 0
       max_dest = [ 2.5*section_h - frame_elev, top_margin - r_notch - frame_elev].min
       range_dest = max_dest - min_dest
       
       # scale all points from 0 to max_height
       all_pts.map! { |e|  (e - min_src)/range_src * range_dest + min_dest}
       
       vert_count, horiz_count = samples.length, samples[0].length
       
       # And reshape into original format
       vert_count.times { |n|  
           samples[n] = all_pts[n*horiz_count...(n+1)*horiz_count]
       }
       samples
    end
    def write_svg( filename, sub_region=nil, with_frame_sheet=true)
        # default to creating A4 sized images, and centering within that
        im = Rasem::SVGImage.new( A4_W, A4_H)
        
        # Get the data points we need, sorted correctly, from dem_data
        @sections = dem_data.sample( num_sections, x_samples, orientation, sub_region)
        @sections = scale_data_points( @sections)

        un_notched = @frame_width - @notch_depth
        
        # center everything
        x = (A4_W - cut_width)/2
        y = (A4_H - cut_height)/2
        im.start_group( {}, [x,y])
        
        # Label map with location
        title_text = "#{sub_region or dem_data.region}: Looking #{orientation}"
        im.text( 0, -10, title_text, {:font_size => 8})
        im.set_style @@svg_valley_style
            # the folds at the bottom of each section; All but one of these
            # will be obscured by the next section down        
            @num_sections.times { |n| 
                start_y = top_margin + section_h * n
                im.line( un_notched, start_y, @cut_width - un_notched, start_y)
            }
        im.unset_style
        
        # Section cuts
        im.set_style @@svg_cut_style
            # outer cut
            im.polygon(             0, 0, 
                        cut_width - 0, 0,
                        cut_width - 0, cut_height - 0,
                                    0, cut_height - 0)
            
            # sections
            @num_sections.times { |n|   
                # TODO: Could this be cleaned up with use of transforms
                # rather than ugly math? -ETJ 23 Jan 2012
                start_y = top_margin + section_h * n
                
                # left side triangles
                pts_left = [ un_notched, start_y, 
                            frame_width, start_y - frame_elev]
                # mirror on right
                pts_right = [ cut_width - frame_width, start_y - frame_elev,
                              cut_width - un_notched, start_y]
                
                # NOTE: @sections[n] has already been scaled
                pts = []
                data_step = (cut_width  - 2*@frame_width) / (@sections[n].length - 1)
                @sections[n].each_with_index { |e, i|  
                    pts << (@frame_width + i*data_step) # x
                    pts << (start_y - frame_elev - e)   # y
                }
                
                # For debugging: draw circles at all points
                draw_circles = false
                if draw_circles
                    pts.each_with_index { |e, i| 
                        if i.even?
                            im.circle( e, pts[i+1], 1.5, {:fill => true} )
                        end
                    }
                end
                
                all_pts = pts_left + pts + pts_right 
                
                # The fill here is a hack, to cover up the fold in the previous
                # section and keep us from having to calculation where
                # two sections intersect
                im.polyline( *(all_pts +  [{:fill => "white"}]))
                # im.polyline( *(all_pts))
                
            }
            
        im.unset_style
        im.end_group
        im.close
        # write the cut pattern
        # Make sure we only output SVG files
        open(filename, "w") { |io| io.write( im.output) }
        if with_frame_sheet
            dirname = File.dirname( File.expand_path( filename)) + "/"
            framename =  dirname + File.basename(filename, ".*") + "_frame.svg"
            write_frame_svg( framename)
        end
    end
    def write_frame_svg( filename)
        im = Rasem::SVGImage.new( A4_W, A4_H)
        
        # center everything
        x = (A4_W - all_frame_width)/2
        y = (A4_H - cut_height)/2
        im.start_group( {}, [x,y])        
        
        #draw frame cuts
        im.set_style @@svg_cut_style
        # circular tabs on elevations (NOTE: what are these for?)
        tab_rad = @frame_elev/2.0
        tab_elev = @frame_elev/3.0

        x1 = @frame_width + tab_elev
        x2 = @all_frame_width - @frame_width - tab_elev
        y1 = 0.25 * cut_height
        y2 = 0.75 * cut_height
        im.arc( x1, y1, tab_rad, 270, 180)
        im.arc( x1, y2, tab_rad, 270, 180)
        im.arc( x2, y1, tab_rad,  90, 180)
        im.arc( x2, y2, tab_rad,  90, 180)

        #top & bottom cuts
        im.polyline( 0,                    top_margin - r_notch, 
                     0,                    0, 
                     @all_frame_width - 0, 0,
                     @all_frame_width - 0, top_margin - r_notch)
                    
        im.polyline( 0,                    cut_height - bot_margin + r_notch,
                     0,                    cut_height - 0, 
                     @all_frame_width - 0, cut_height - 0,
                     @all_frame_width - 0, cut_height - bot_margin + r_notch)
        
        # notches

        num_sections.times { |n|
            start_y = @top_margin + section_h * n - r_notch
            # left side
            poly_left = [   r_notch,        start_y + r_notch, 
                            @notch_depth,   start_y + r_notch, 
                            @notch_depth,   start_y + r_notch + slot_width,
                            r_notch,        start_y + r_notch + slot_width]

            im.arc( r_notch, start_y, r_notch, 180, 90)
            im.polyline( *poly_left)
            im.arc( r_notch, start_y + 2*r_notch + slot_width, r_notch, 90, 90)

            # right side
            poly_right = []
            poly_left.each_with_index { |e, i|  
                poly_right << (i.odd? ? e : @all_frame_width -e )
            }            
            im.arc( @all_frame_width - r_notch, start_y, r_notch, 0, -90)
            im.polyline( *poly_right)
            im.arc( @all_frame_width - r_notch, start_y + 2*r_notch + slot_width, r_notch, 90, -90)
            
            if n < num_sections - 1
                im.line( 0, start_y + 2*r_notch + slot_width, 0, start_y + section_h)
                im.line( @all_frame_width, start_y + 2*r_notch + slot_width, @all_frame_width, start_y + section_h)
            end
        }
        im.unset_style

        # vertical line folds in the frame
        im.set_style @@svg_valley_style
        x_locs = [  @frame_width,
                    @frame_width + @frame_elev,
                    @all_frame_width - @frame_width - @frame_elev,
                    @all_frame_width - @frame_width]
        x_locs.each {|x| im.line( x, 0, x, cut_height) }
        im.unset_style
        im.end_group
        im.close
        open(filename, "w") { |io|  io.write( im.output)}
    end
end

if __FILE__ == $0
    # ETJ DEBUG
    # pgm_2_8bps( "dems/ASTGTM2_N45W122_dem.pgm", 4000)
    pgm_2_8bps( "dems/ASTGTM2_N36W117_dem.pgm", 4000)
    return
    # END DEBUG
    

    show_mountain = false
    if show_mountain
        mt_hood_link = "http://maps.google.com/?ll=45.369635,-121.698475&spn=0.7,0.6&z=13&vpsrc=6"
        hood_small_region = LatLongRegion.region_from_google_maps_link( mt_hood_link)
        # mt_hood_link = "http://maps.google.com/?ll=45.369635,-121.698475&spn=0.081885,0.11982&z=13&vpsrc=6"

        mt_hood_data_file = "dems/ASTGTM2_N45W122_dem.pgm"
        hood_data = DemData.from_ASTER_pgm( mt_hood_data_file)

        dpc = DemPaperCut.new( hood_data, :east, 133, 133, 30, 20)
        # dpc.write_svg( "/Users/jonese/Desktop/test_cut.svg", hood_small_region, true)
        dpc.write_svg( "/Users/jonese/Desktop/test_cut.svg", nil, true)
    
    else
        dummy_arr = [[50, 25], 
                     [25, 50]]
                 
        dummy_arr = [   [   0,   0,   5,   0,   0]*2,
                        [   0,   0,  10,   0,   0]*2,
                        [   0,   5,  15,   5,   0]*2,
                        [   0,   0,  10,   0,   0]*2,
                        [   0,   0,   5,   0,   0]*2,
            ]
        
        # A set of cosine waves
        dummy_arr = []
        num_slices = 32
        num_points = 32
        num_slices.times { |n|
            dummy_arr[n] = []
            num_points.times { |i|  
                a = (i + n*2).to_f/num_points * 4 * Math::PI
                dummy_arr[n] << Math.cos( a)
            }
        }
    
        # dummy_arr = [[ 0, 1, 0, 2], 
        #              [ 0, 1, 0, 2]]
        steens_link = "http://maps.google.com/?ll=42.705903,-118.639984&spn=0.171304,0.363579&t=h&z=12&vpsrc=6"
        steens_small = LatLongRegion.region_from_google_maps_link( steens_link)        
        steens_file = "dems/ASTGTM2_N36W117_dem.pgm"
        steens_data = DemData.from_ASTER_pgm( steens_file)
        # dummy_data = DemData.new( steens_llr, dummy_arr)
        # testing
        dpc = DemPaperCut.new( steens_data, :north, 133, 133, num_slices, num_points)
        dpc.write_svg( "/Users/jonese/Desktop/test_cut.svg", nil, true)
    end
end




