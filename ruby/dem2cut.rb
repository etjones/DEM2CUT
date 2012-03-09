#!/usr/bin/env ruby -KU
require 'optparse'

# Some gymnastics to avoid loading Rasem as a gem, even though it is one.
module Rasem
end    
require File.dirname(__FILE__) + "/rasem/lib/rasem/svg_image.rb"


MAX_ELEVATION = 8500
A4_W, A4_H = 216, 279

# ================
# = P G M  Utils =
# = ------------ =
def read_pgm_header( pgm_path)
   pgm_header_re = /P(\d)\n(\d+)\s+(\d+)\n(\d+)\n/
   header = ""
   data = []
   lines_found = 0
   filetype, width, height, range, header_bytes = [nil] *5
   open( pgm_path, "r") { |f|
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
    }
    return [filetype, width, height, range, header_bytes]
end
def pgm_header( width, height, range=255, filetype=5)
    header = %Q{P#{filetype}\n#{width} #{height}\n#{range}\n}
end
def pgm_2_8bps( pgm_path, max_elevation=MAX_ELEVATION)
    filetype, width, height, range, header_bytes = read_pgm_header( pgm_path)
    data = pgm_2_arr( pgm_path, max_elevation)    
    data = scale_2d_arr( data, true, 255, max_elevation)

    file_8bps = append_to_basename( pgm_path, "_8bps")

    write_pgm( file_8bps, data, 255)    
end
def pgm_2_arr( pgm_path, max_elevation=MAX_ELEVATION)
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
def write_pgm( pgm_path, pgm_2d_arr, output_range=255)
    height, width = pgm_2d_arr.length, pgm_2d_arr[0].length

    #Check that pgm_2d_arr all falls into output_range
    # and scale it so that it does if not
    maxval = pgm_2d_arr.map{|r| r.max}.max
    if maxval > output_range
        arr_to_use = scale_2d_arr( pgm_2d_arr, false, output_range)
    else
        arr_to_use = pgm_2d_arr
    end
    
    if output_range <= 255
        output_range = 255
        data_format_str = "C*"
    else
        output_range = 65535
        data_format_str = 'n*'
    end
    
    out = pgm_header( width, height, output_range, 5)
    height.times { |y|  out << pgm_2d_arr[y].pack( data_format_str)}
    
    open( pgm_path, "w"){|f| f.write(out)}    
end

# ===============
# = H G T Utils =
# = ----------- =
def hgt_2_arr( hgt_path, max_elevation=MAX_ELEVATION)
    # SRTM files come in one of two common formats: 3 arc-second (~90m)
    # and 1 arc-second (~30m).  Files are 1 degree square, so 3601 x 3601
    # for 1 arc-second, or 1201 x 1201 for 3 arc-second. 
    # Data points are 2 byte signed shorts.
    
    case File.size( hgt_path)
    when 1201 * 1201 * 2: w = 1201; h = 1201
    when 3601 * 3601 * 2: w = 3601; h = 3601
    # TODO: raise an error if this isn't a correct size
    else return false
    end
    
    
    token_key = "n*"
    bytes_per_token = 2
    
    max_unsigned_short = 2**15
    
    data = []
    open( hgt_path, "r") do |f|
        h.times { |y| 
            # String#unpack doesn't have a network-ordered signed-short
            # key.  So do this for ourselves
            data[y] = f.read( w * bytes_per_token).unpack( token_key)
            data[y].map!{|e|
                if e >= max_unsigned_short
                    e -= max_unsigned_short
                end
                if e > max_elevation
                    e = 0
                else
                    e 
                end
            }
        }
    end
    data
end

# ====================
# = Arc ASCII  Utils =
# = ---------------- =
def arc_ascii_2_arr( arc_path, max_elevation=MAX_ELEVATION)
    data = []
    header = read_arc_ascii_header( arc_path)
    return false unless header
    w, h, xll, yll, cellsize, no_data, header_bytes  = *header
    open( arc_path, "r"){ |f|
        f.read( header_bytes)
        h.times { |y|  
            line = f.readline
            data[y] = line.split(" ").map { |e| e.to_i }
        }
    }
    # also get the region 
    ll_min = LatLong.new( yll, xll)
    ll_max = LatLong.new( yll + h*cellsize, xll + w*cellsize)
    region = LatLongRegion.new( ll_min, ll_max)
    
    [data, region]
end
def read_arc_ascii_header( arc_path)
    #     arc ascii header is of the form: 
    # "ncols         6001
    # nrows         6001
    # xllcorner     -120.00041666668
    # yllcorner     44.999583672325
    # cellsize      0.00083333333333333
    # NODATA_value  -9999
    # "
    #  See: http://docs.codehaus.org/display/GEOTOOLS/ArcInfo+ASCII+Grid+format
    # for more info
    arc_header_re = /(?x)ncols       \s+(\d+)            [\n\r]+
                        nrows        \s+(\d+)            [\n\r]+
                        xllcorner    \s+(-?\d+(?:\.\d+)) [\n\r]+
                        yllcorner    \s+(-?\d+(?:\.\d+)) [\n\r]+
                        cellsize     \s+(-?\d+(?:\.\d+)) [\n\r]+
                        (nodata_value\s+(?:-?\d+)        [\n\r]+)?/

    # NOTE: This is less flexible than it ought to be.  NODATA_value isn't
    # necessarily included, and if it's not present we'll miss out on 
    # some data values without some check for it.  Under the spirit of 
    # simplest possible solution that can work, here goes, though.
    header = ""
    data = []
    w, h, xll, yll, cellsize, no_data, header_bytes = [nil] * 7
    open( arc_path, "r"){ |f|
        6.times { |n| header <<  f.readline}
        match = arc_header_re.match(header)
        # NOTE: should raise exception if the header wasn't recognized
        if not match; return false; end        
        w, h, xll, yll, cellsize, no_data = match.captures.map { |e| e.to_f }
        header_bytes = f.pos
    }
    return [ w.to_i, h.to_i, xll, yll, cellsize, no_data.to_i, header_bytes]    
end

# ==================
# = Util functions =
# = -------------- =
def append_to_basename( file_path, to_append)
    ext = File.extname( file_path)
    dirname, basename = File.split( File.expand_path( file_path))
    appended = dirname + "/" + File.basename(basename, ".*") + to_append + ext
    appended
end
def scale_2d_arr( pgm_2d_arr, in_place=false, max_dest_val=255, max_source_val=nil)
    # FIXME: assumes all values in pgm_2d_arr are positive. This could be fixed by
    # calculating minimum values and using those in the scaling
    if not max_source_val
        maxes = []
        pgm_2d_arr.each {|e|  maxes << e.max}
        max_source_val = maxes.max
    end
    scale_factor = max_dest_val.to_f/max_source_val
    if in_place
        pgm_2d_arr.each {|d|  d.map! { |e|  (e*scale_factor).to_i}}
        return pgm_2d_arr
    else
        out = pgm_2d_arr.map {|d| d.map { |e| (e*scale_factor).to_i }} 
        return out
    end
end
def scale( val, src_min, src_max, dest_min, dest_max)
    retval = (val - src_min).to_f/(src_max - src_min) * (dest_max - dest_min) + dest_min
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
    interp
end

# ==========
# = DemData =
# = ------ =
class DemData
    attr_reader :region, :data
    def initialize( region, data=nil, should_download=true)
        # DemData represents a rectangular region on earth,
        # and can be queried about the elevation at any particular point
        # within its bounds
        @region = nil
        @data = data # for now, assume data is a 2D array of elevations
        set_region( region)
        
        # if directed, find data for a region from the SRTM index
        # TODO: need some more tests here: is this region small enough 
        # to fit in a single file? etc
        if data == nil and should_download
            data = download_hgt
        end
        
    end
    def download_hgt
        # TODO: Finish writing this
        # look in index file for URL to HGT file
        
        # download HGT file, if found
        
        # unzip downloaded file and store it in cached_dem_files
        
        
        # read file into data and return it
        data = hgt_2_arr( hgt_path)
        return data
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
        # y indices move top to bottom, but latitudes run bottom to top.  Invert them
        y_fractional_index = scale( y, region.max_lat,  region.min_lat,  min_y_ind, max_y_ind)
        x_fractional_index = scale( x, region.min_long, region.max_long, min_x_ind, max_x_ind)
        y_ind_1 = y_fractional_index.to_i
        x_ind_1 = x_fractional_index.to_i
        # TODO: possible off-by-one error in y indices:  should be -1 or +1?
        
        # don't go off the edges of the array
        if y_ind_1 == max_y_ind; y_ind_1 -= 1; end
        if x_ind_1 == max_x_ind; x_ind_1 -= 1; end
        x_ind_2 = x_ind_1 + 1
        y_ind_2 = y_ind_1 + 1
        
        two_by_two = [  [@data[y_ind_1][x_ind_1], @data[y_ind_1][x_ind_2]],
                        [@data[y_ind_2][x_ind_1], @data[y_ind_2][x_ind_2]]                  
                     ]
        elev = bilinear_interpolation( x_fractional_index, y_fractional_index,
                    x_ind_1, y_ind_1, x_ind_2, y_ind_2, two_by_two)
                    
        return elev
    end
    def DemData.from_ASTER_pgm( pgm_path, max_elevation = MAX_ELEVATION)
         region = LatLongRegion.from_lat_long_str( pgm_path)
         data = pgm_2_arr( pgm_path, max_elevation)
         # TODO: error checking
         DemData.new( region, data)
    end
    def DemData.from_SRTM_hgt( hgt_path, max_elevation = MAX_ELEVATION)
        region = LatLongRegion.from_SRTM_hgt( hgt_path)
        data = hgt_2_arr( hgt_path, max_elevation)
        DemData.new( region, data)
    end
    def DemData.from_file( path, max_elevation= MAX_ELEVATION)
        case File.extname(path).downcase
        when  '.hgt': 
            return DemData.from_SRTM_hgt( path, max_elevation) 
        when '.pgm':
            return DemData.from_ASTER_pgm( path, max_elevation)
        when '.asc':
            # Arc ascii files also contain region info             
            data, region = arc_ascii_2_arr( path, max_elevation)
            return DemData.new( region, data, false)
        end
    end
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
        sn = ( lat  > 0 ? 'N' : 'S')
        ew = ( long > 0 ? 'E' : 'W')
        "%s%.2f%s%.2f"%[sn, lat.abs, ew, long.abs]
    end
    def LatLong.from_s( str)
        found_groups = /(\w)(\d+)(\w)(\d+)/.match( str) 
        north_south, lat, east_west, long = found_groups.captures
        long = long.to_i * (("Ee".include? east_west) ? 1 : -1)
        lat = lat.to_i * (("Nn".include? north_south) ? 1 : -1)
        LatLong.new( lat, long)
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
    def LatLongRegion.from_google_maps_link( gm_link)
        # Parse region from links like:
        # "http://maps.google.com/?ll=45.369635,-121.698475&spn=0.081885,0.11982&z=13&vpsrc=6"
        found_groups = /ll=(-?\d+\.\d+),(-?\d+\.\d+)&spn=(\d+\.\d+),(\d+\.\d+)/.match( gm_link)
        # TODO: error checking
        lat, long, lat_span, long_span = found_groups.captures.map { |e| e.to_f }
        min = LatLong.new( lat - lat_span/2, long - long_span/2)
        max = LatLong.new( lat + lat_span/2, long + long_span/2)
        LatLongRegion.new( min, max)
    end
    def LatLongRegion.from_lat_long_str( str)
        # parse filenames like: ASTGTM2_N45W122_dem for lat/long data.
        # these files are all one degree wide & high
        min = LatLong.from_s( str)
        max = LatLong.new( min.lat + 1, min.long + 1)
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
    def aspect_ratio
        (max_lat - min_lat).to_f/(max_long - min_long)
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
    def initialize( dem_data,orientation=:north, 
                    cut_width=133, cut_height=133,
                    num_sections=25, x_samples=100,
                    bot_margin=8.5, top_margin=18.5)
        # Using a DemData instance, create a pattern of paper cuts & folds
        # sufficient to represent DemData's region

        # TODO: margins & section separation need to be adaptive
        # to the data. If elevation is significantly different between
        # one section and the next, cut lines can overlap each other
        
        # Likewise, margins might not be adequate if top or bottom
        # elevations are large
        @dem_data = dem_data
        @orientation = orientation
        @num_sections = num_sections
        @cut_width = cut_width
        @cut_height = cut_height
        @bot_margin = bot_margin
        @top_margin = top_margin
        @section_h = (cut_height - bot_margin - top_margin) / (num_sections -1)
        @notch_depth = 7.25
        
        @frame_elev = 5
        @frame_width = 12.5        
        @all_frame_width = @cut_width + 2* (@frame_elev + @frame_width)
        @r_notch = 2.5
        @slot_width = 0.5
        
        @x_samples = x_samples
    
        # If dem_data's region is not square, we don't want a square 
        # cut pattern.  Alter top/ bottom margin so we get a 
        # suitable aspect ration.
        # FIXME: this logic is incomplete
        @top_margin, @bot_margin, @section_h = fix_aspect_ratio( dem_data.region, cut_width-2*frame_width, cut_height)
         
        
    end
    def fix_aspect_ratio( region, w, h)
        aspect_ratio = region.aspect_ratio

        # Handle regions wider than tall
        if region.aspect_ratio <= 1
            new_h = w * aspect_ratio
        
            bot = (h - new_h)/2.0
            top = (h - new_h)/2.0
            sect = new_h/(@num_sections -1)  
     
            return top, bot, sect
        else
            # Haven't decided how to deal with taller-than-wide regions
            # So don't change anything; this will continue the previous
            # ratio-altering behavior
            return @top_margin, @bot_margin, @section_h
        end
    end
    def scale_data_points( samples)
       # Go through and generate all data points
        all_pts = samples.flatten
        max_src = all_pts.max
        min_src = all_pts.min
        range_src = max_src - min_src
       
        # To guarantee that cut lines don't intersect, we need to know the 
        # smallest gap between a point in one section and a point in the 
        # next section: 
        # gaps = []
        # 
        # samples[0..-2].each_with_index { |e, y|  
        #     e.each_with_index { |f, x|  
        #         gaps = f - samples[y+1][x] 
        #     }
        # }
        # min_inter_section_gap = gaps.min
        
        # But that's kind of overkill at the moment.  Let's just try 
        # a simple rule -ETJ 22 Jan 2012
        min_dest = 0
        # max_dest = [ 7.5*section_h - frame_elev, top_margin - r_notch - frame_elev].min
        max_dest = 6*section_h - frame_elev
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
    def write_svg( filename, sub_region=nil, title=nil, with_frame_sheet=true)
        # default to creating A4 sized images, and centering within that
        im = Rasem::SVGImage.new( A4_W, A4_H)
        
        if sub_region
            @top_margin, @bot_margin, @section_h = fix_aspect_ratio( sub_region, cut_width, cut_height)
        end
        
        # Get the data points we need, sorted correctly, from dem_data
        @sections = dem_data.sample( num_sections, x_samples, orientation, sub_region)
        @sections = scale_data_points( @sections)

        un_notched = @frame_width - @notch_depth
        
        # center everything
        x = (A4_W - cut_width)/2
        y = (A4_H - cut_height)/2
        im.start_group( {}, [x,y])
        
        # Label map with location
        lat_long_text = "#{sub_region or dem_data.region}: Looking #{orientation}"
        im.text( 0, -30, title, {:font_size => 8}) if title
        im.text( 0, -10, lat_long_text, {:font_size => 8})
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
                # TODO: Clean this up with use of transforms in the SVG code
                # rather than ugly math -ETJ 23 Jan 2012
                start_y = top_margin + section_h * n

                pts_left = [ un_notched, start_y]
                pts_right = [cut_width - un_notched, start_y]
                
                # Created a vertical line at left and right of each section,
                # as in Miyamoto's original.  these tended to overlap each other,
                # so I've taken that line out
                if false
                    # left side triangles
                    pts_left = [ un_notched, start_y, 
                                frame_width, start_y - frame_elev]
                    # mirror on right
                    pts_right = [ cut_width - frame_width, start_y - frame_elev,
                                  cut_width - un_notched, start_y]
                end
                
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
                # section and keep us from having to calculate where
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
            framename = append_to_basename( filename, "_frame")
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
            # translate each set of notches down by start_y
            im.start_group( nil, [0, start_y])
                # left side
                poly_left = [   r_notch,        r_notch, 
                                @notch_depth,   r_notch, 
                                @notch_depth,   r_notch + slot_width,
                                r_notch,        r_notch + slot_width]

                im.arc( r_notch, 0, r_notch, 180, 90)
                im.polyline( *poly_left)
                im.arc( r_notch, 2*r_notch + slot_width, r_notch, 90, 90)

                # right side
                poly_right = []
                poly_left.each_with_index { |e, i|  
                    poly_right << (i.odd? ? e : @all_frame_width -e )
                }            
                im.arc( @all_frame_width - r_notch, 0, r_notch, 0, -90)
                im.polyline( *poly_right)
                im.arc( @all_frame_width - r_notch, 2*r_notch + slot_width, r_notch, 90, -90)
            
                if n < num_sections - 1
                    im.line( 0, 2*r_notch + slot_width, 0, section_h)
                    im.line( @all_frame_width, 2*r_notch + slot_width, @all_frame_width, section_h)
                end
            
            im.end_group
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

def main_manual_test
    which_region = [:fuji, :hood, :rainier, :steens, :cosine]
    use_subregion = true
    
    file = nil
    link = nil
    case which_region[1]
    when :fuji
        # Mt. Fuji
        title = "Mt. Fuji"
        link = "http://maps.google.com/?ll=35.360496,138.742905&spn=0.120255,0.218353&t=h&z=13"
        file = "dems/ASTGTM2_N35E138_dem.pgm"
    when :hood    
        title = "Mt. Hood, a volcanic peak near Portland Oregon, USA"
        link = "http://maps.google.com/?ll=45.369635,-121.698475&spn=0.081885,0.11982&z=13&vpsrc=6"
        file = "dems/ASTGTM2_N45W122_dem.pgm"
    when :rainier
        title ="Mt. Rainier, a volcanic peak near Seattle, Washington, USA"
        link = "http://maps.google.com/?ll=46.857609,-121.771431&spn=0.159408,0.28186&t=h&z=12"
        file = "dems/ASTGTM2_N46W122_dem.pgm"
    when :steens
        title = "Steens Mountain, a fault-block mountain \nin barren land in SE Oregon, USA"
        link ="http://maps.google.com/?ll=42.565219,-118.44635&spn=0.343382,0.413611&t=h&z=11"
        file = "dems/ASTGTM2_N42W119_dem.pgm"
    when :cosine
        title = "A set of cosine waves"
        dummy_arr = []
        num_slices = 10
        num_points = 32
        num_slices.times { |n|
            dummy_arr[n] = []
            num_points.times { |i|  
                a = (i + n*3).to_f/num_points * 4 * Math::PI
                dummy_arr[n] << Math.cos( a)
            }
        }
        
        steens_link = "http://maps.google.com/?ll=42.705903,-118.639984&spn=0.171304,0.273579&t=h&z=12&vpsrc=6"        
        dummy_region = LatLongRegion.from_google_maps_link(steens_link)
        dummy_data = DemData.new( dummy_region, dummy_arr)
        dpc = DemPaperCut.new( dummy_data, :north, 133, 133, num_slices, num_points)
        dpc.write_svg( ENV['HOME'] + "/Desktop/test_cut.svg", nil, title, true)
    end
    
    if link and file
        region = LatLongRegion.from_google_maps_link( link)
        data = DemData.from_ASTER_pgm( file)
        dpc = DemPaperCut.new( data, :north, 133, 133, 16, 50)
        region = ( use_subregion ? region : nil)
        dpc.write_svg( ENV['HOME'] + "/Desktop/test_cut.svg", region, title, true)
    end
end
def cli_main( args_dict)
    keys = [:cardinal_dir, :dem_file, :out_file, :link, :include_frame_cut, 
            :vertical_scale, :slices, :points_per_slice, :title]
    cardinal_dir, dem_file, out_file, link, include_frame_cut, vertical_scale, slices, points_per_slice, title = keys.map { |k|  args_dict[k]}   
    
    region = LatLongRegion.from_google_maps_link( link)
    data = nil
    if dem_file
        data = DemData.from_file( dem_file) 
    end
    dpc = DemPaperCut.new( data, cardinal_dir, 133, 133, slices, points_per_slice)
    
    if not out_file
        out_file = ENV['HOME'] + "/Desktop/#{title || 'cut_pattern'}.svg"
    end
    dpc.write_svg( out_file, region, title, include_frame_cut)
    
end
def parse_args
   options = {} 
   optparse = OptionParser.new {|opts|
        opts.banner = "Usage: #{File.basename($0)}"
       
        # TODO: make :link a mandatory argument
       
        options[:link] = nil
        opts.on( '-l', '--link LINK', 'Google maps link, showing an '+ 
                        'area within a single 1x1 degree square'){|link|
            options[:link] = link
        }
        
        options[:out_file] = nil
        opts.on('-o', '--out_file OUT_FILE.svg', "Path to output file"){|out_file|
            options[:out_file] = out_file
        }        
       
        options[:dem_file] = nil
        df_exts =  ['.hgt','.pgm','.asc']
        opts.on('-d', '--dem_file DEM_FILE', "DEM file. Extension must be one "+
                    "of [#{df_exts.join(', ')}]"){|dem_file|
            next unless dem_file
            if df_exts.include?(File.extname( dem_file).downcase) and File.exist?( dem_file)
                options[:dem_file] = dem_file
            else
                puts("Can't find dem_file '#{dem_file}' or it has the wrong extension.\n",
                     "Dem_file extension must be one of #{df_exts.join(', ')}")
                # exit here?
                return 
            end
        }
        
        options[:title] = ""
        opts.on('-t', '--title TITLE', 'Title for SVG'){|title|
            options[:title] = title
        }
       
        options[:include_frame_cut] = false
        opts.on('-f', '--frame', 'If specified, output a second image for use '+
                'as the frame for the cut pattern'){
            options[:include_frame_cut] = true
        }
        
        options[:slices] = 15
        opts.on('-s', '--slices NUM', Integer, 'Number of slices in cut pattern'){|slices|
            options[:slices] = slices
        }
        
        options[:points_per_slice] = 50
        opts.on('-p', '--points_per_slice NUM', Integer, 'Number of data points in each slice'){|points_per_slice|
            options[:points_per_slice] = points_per_slice
        }        
        
        options[:cardinal_dir] = :north
        cardinals = ["N" =>:north,"S"=>:south,"E"=>:east,"W"=>:west]
        opts.on('-c', '--cardinal_dir [N|S|E|W]', "Cardinal direction"){|dir|
            if cardinals.include?( dir.upcase! )
                options[:cardinal_dir] = cardinals[dir]
            end
        }
        
        options[:vertical_scale] = 2.0
        opts.on("-v", '--vertical_scale FLOAT',Float,"Vertical scale factor"){|vertical_scale|
            options[:vertical_scale] = vertical_scale
        }
        
        # This displays the help screen, all programs are
        # assumed to have this option.
        opts.on( '-h', '--help', 'Display this screen' ) do
            puts opts
            exit
        end        
   }
   
   ARGV << '-h' if ARGV.empty?
   optparse.parse!
   options
end

if __FILE__ == $0
    args_dict = parse_args
    cli_main( args_dict)
end



