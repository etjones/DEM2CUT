#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <stdarg.h>
#include <string>

#include "dem_extractor.h"
std::string gDemFileDir;

#define MAX_ELEVATION 8700
#define MIN_ELEVATION -200
#define MIN_INTER_SLICE_DISTANCE 20

// Data gaps are marked with 0x8000, -32768 as signed short
#define NO_DATA -32768
// ==========
// = LatLng =
// = ------ =
LatLng::LatLng():lat(0), lng(0){}
LatLng::LatLng( float lat_in, float lng_in): lat(lat_in), lng(lng_in){
    // Justify our measurements so they fall within (-90, 90) lat & (-180, 180) lng
    lng = fmodf(lng + 180, 360.0)-180;
    if ( lat < -90){ lat = -90.0;}
    if ( lat > 90) { lat = 90.0;}
}
std::string LatLng::srtm_hgt_filename(){
    int lati = floor( lat);
    int lngi = floor( lng);
    
    char buff[100];
    sprintf(buff, "%c%02d%c%03d.hgt", 
            (lati < 0 ? 'S':'N'), abs(lati),
            (lngi < 0 ? 'W':'E'), abs(lngi));
    
    std::string buffAsStdStr = buff;
    return buffAsStdStr;
}
// FIXME: how to get this to compile?
LatLngRegion LatLng::enclosing_srtm_region(){
    return LatLngRegion( floor(lat), floor(lng), ceil(lat), ceil(lng));
}

// ================
// = LatLngRegion =
// = ------------ =
LatLngRegion::LatLngRegion(){}
LatLngRegion::LatLngRegion( float min_lat_in, float min_lng_in, float max_lat_in, float max_lng_in){
    min_lat = MIN( min_lat_in, max_lat_in);
    max_lat = MAX( min_lat_in, max_lat_in);
    min_lng = MIN( min_lng_in, max_lng_in);
    max_lng = MAX( min_lng_in, max_lng_in);
    
    min_lat_lng = LatLng( min_lat, min_lng);
    max_lat_lng = LatLng( max_lat, max_lng);
}
bool LatLngRegion::contains_point( LatLng lat_lng){
    return (lat_lng.lat >= min_lat && lat_lng.lat <= max_lat &&
            lat_lng.lng >= min_lng && lat_lng.lng <= max_lng );
}

bool LatLngRegion::contains_region( LatLngRegion other_region){
    LatLng corners[4] = {LatLng(min_lat, min_lng), LatLng(min_lat, max_lng),
        LatLng(max_lat, min_lng), LatLng(max_lat, max_lng)};
    int i;
    for( i = 0; i < 4; i += 1 ){
        if (!contains_point( corners[i])){ return false;}
    }
    return true;             
}

// =============
// = DemRegion =
// = --------- =
// Constructor: if only given a map region, find data from cached DEM files.
DemRegion::DemRegion( LatLngRegion region_in, int lat_samples_in, int lng_samples_in, int direction_in):
region( region_in), lat_samples( lat_samples_in), lng_samples( lng_samples_in), direction( direction_in)
{
    // DemRegion are responsibilefor knowing where their data will come from.  
    // Another approach might put that logic in a separate place.
    
    // Find a file(s) that contain the region we care about
    //      Todo: later, this should identify correct scale of data to 
    //      use. A map of North America should use much less granular data
    //      than a map of a single mountain.
    
    // It's much slower (~4x) to read an entire file and sample from that,
    // rather than to read only the data we want from the file. 
    
    // save memory for samples
    buf = (short *)malloc( lat_samples *lng_samples * sizeof(short));
    LatLng *ll_list = (LatLng *)malloc( lat_samples*lng_samples*sizeof(LatLng));
    
    // TODO: swap lat_samples, lng_samples if we're facing East/West
    
    ll_list = lat_lngs_to_sample( ll_list, region, lat_samples, lng_samples);
    int x,y;
    
    // TODO: limit us to some reasonable number of files to read. 16? 25?
    
    // Open all files and put them in an array, all_tiles
    int min_lat = floor(region.min_lat);
    int min_lng = floor(region.min_lng);
    int lat_degree_span = ceil( region.max_lat) - floor( region.min_lat);
    int lng_degree_span = ceil( region.max_lng) - floor( region.min_lng);
    FILE **all_tiles = (FILE **)malloc( lat_degree_span * lng_degree_span * sizeof(FILE *));
    std::string filename;
        
    for( y = 0; y < lat_degree_span; y += 1 ){
        for( x = 0; x < lng_degree_span; x += 1 ){
            filename = gDemFileDir + LatLng( y + min_lat, x + min_lng).srtm_hgt_filename();
            // TODO: need to fail if we don't have a file. 
            // FIXME: what to do for nonexistent tiles?  Think they should all just read as zero?
            all_tiles[y*lng_degree_span + x] = fopen( filename.c_str(), "r");
        }
    }
    
    // TODO: get elevations for all points in ll_list, and store
    // them correctly in buffer. 
    // Open/ close appropriate file based on lat/long, which means
    // many more opens/closes than necessary, but is awfully simple.
    FILE *tile = all_tiles[0];
    LatLngRegion cur_region = ll_list[0].enclosing_srtm_region();
    LatLng ll;
    int tile_index;
    short val;
    
    for( y = 0; y < lat_samples; y += 1 ){
        for( x = 0; x < lng_samples; x += 1 ){
            ll = ll_list[y*lng_samples + x];
            // Open appropriate file if needed
            if ( !cur_region.contains_point( ll)){
                cur_region = ll.enclosing_srtm_region();
                tile_index = lng_degree_span * ((int)(ll.lat-min_lat)) + (int)(ll.lng - min_lng);
                tile = all_tiles[ tile_index];
            }
            val = elev_at_lat_lng( ll, tile, cur_region, 1201, 1201);
            buf[y*lng_samples + x] = val;
//            buf[y*lng_samples + x] = elev_at_lat_lng( ll, tile, cur_region, 1201, 1201);
            
        }
    }
    
    // TODO: if we're facing south/east/west
    // swap lat_samples, lng_samples & rotate buffers
    for( y = 0; y < lat_degree_span * lng_degree_span; y += 1 ){
        fclose( all_tiles[y]);
    }
    free( all_tiles);
    free( ll_list);
    
}
LatLng *DemRegion::lat_lngs_to_sample(  LatLng *ll_list, LatLngRegion dst_region, 
                                        int dst_lat_samples, int dst_lng_samples)
{
    int x, y;
    
    float dst_min_lat = dst_region.min_lat;
    float dst_max_lat = dst_region.max_lat;
    float dst_min_lng = dst_region.min_lng;
    float dst_max_lng = dst_region.max_lng;   
    
    float lat_gap = (dst_max_lat - dst_min_lat)/(dst_lat_samples - 1);
    float lng_gap = (dst_max_lng - dst_min_lng)/(dst_lng_samples - 1);

    float lat, lng;
    for( y = 0; y < dst_lat_samples; y += 1 ){
        lat = dst_min_lat + y * lat_gap;
        for( x = 0; x < dst_lng_samples; x += 1 ){
            lng = dst_min_lng + x * lng_gap;
            ll_list[y*dst_lng_samples + x] = LatLng( lat, lng);
        }
    }
    
    return ll_list;           
}
short DemRegion::elev_at_lat_lng( LatLng pt, FILE *tile, LatLngRegion tile_region, 
                                    int tile_lat_samples, int tile_lng_samples)
{
    short a,b,c,d, val;
    // object if we're looking in the wrong file
    if (!tile_region.contains_point( pt) ){
        return NO_DATA; // TODO: this should be some more salient error value, not NO_DATA
    }
    
    // calculate the notional exact index of this point
    // In the files, highest latitude is stored at y-index 0, so invert lat scaling
    float exact_lat_index = scale( pt.lat, tile_region.max_lat, tile_region.min_lat, 0, tile_lat_samples);
    float exact_lng_index = scale( pt.lng, tile_region.min_lng, tile_region.max_lng, 0, tile_lng_samples);

    // Make sure we don't read off the edge of the array
    if ( ceil(exact_lat_index) >= tile_lat_samples){ exact_lat_index -= 1;}
    if ( ceil(exact_lng_index) >= tile_lng_samples){ exact_lng_index -= 1;}

    // read the four surrounding data points
    int bps = 2;
    int file_addy = (floor( exact_lat_index) * tile_lng_samples + floor( exact_lng_index)) * bps;
    
    a = fread_valid_data( tile, file_addy);
    b = fread_valid_data( tile, file_addy+bps);
    c = fread_valid_data( tile, file_addy + bps*tile_lng_samples);
    d = fread_valid_data( tile, file_addy + bps + bps*tile_lng_samples);
    
    // average the four points.
    int total = a + b + c + d;
    val = total/4;
    
    // NOTE: if only one value is being taken for a very large area, this
    // point really would be better off averaging many more values; if a point
    // falls within a valley in a region of high peaks, we'll be returning
    // a technically correct but generally deceptive value for elevation. 
    // I guess I'd call this 'geographic aliasing'-ETJ 04 Apr 2012
    return val;
}

DemRegion::~DemRegion(){
    free(buf);
}
void DemRegion::print_samples_json_float(){
    int x,y;
    signed short *samp = buf;

    // find min and max in buffer:
    float min = 10000,max = -10000;
    for(y = 0; y < lat_samples * lng_samples; y += 1 ){
        if ( buf[y] < min){ min = buf[y];}
        if ( buf[y] > max){ max = buf[y];}
    }
    
    float val;
    float range = max - min;

    printf("[ \n");
    for( y = 0; y < lat_samples; y += 1 ){
        printf("[ ");
        for( x = 0; x < lng_samples-1; x += 1 ){
            val = ((*samp++)-min)/range;
            printf("%.3f, ", val);
        }
        val = ((*samp++)-min)/range;
        printf("%.3f ]%c\n",val, (y<lat_samples-1 ? ',': ' '));
    }
    printf("]\n");
}

// ===========
// = Helpers =
// = ------- =
inline short saturate( short v, short min_val, short max_val){
    if (v <= min_val){ return min_val;}
    if (v >= max_val){ return max_val;}
    return v;
}
short fread_valid_data( FILE *f, int file_addy){
    // Read a correct-endian short value at file_addy. 
    // If a NO_DATA value is found at file_addy, 
    // move left and right through f until we've found
    // valid values on both sides. 
    // Return a value linearly interpolated between the valid values found.
    // NOTE: This doesn't take the left & right edges of the file 
    // into account at all.  That's tacky.
    int left_offset = 0;
    int right_offset = 0;
    
    short val;
    short left_val, right_val;
    
    fseek( f, file_addy, SEEK_SET);
    val = fread_short_bigendian( f);
    
    if (val == NO_DATA){
        left_val = right_val = NO_DATA;
        // read left for a valid datum
        while( left_val == NO_DATA){
            fseek( f, -2*sizeof(short), SEEK_CUR);
            left_val = fread_short_bigendian(f);
            left_offset++;
        }
        // reset to file_addy
        fseek( f, file_addy+2, SEEK_SET);
        // read right for a valid datum
        while( right_val == NO_DATA){
            right_val = fread_short_bigendian( f);
            right_offset++;
        }
        val = linear_interp( left_val, right_val, (float)left_offset/(left_offset + right_offset));
    }
    return val;
    
}
inline short fread_short_bigendian( FILE *f){
    unsigned char a, b;
    fread( &a, 1, 1, f);
    fread( &b, 1, 1, f);
    return ((a << 8) | b);
}
void swap( int *a, int *b){
    int tmp;
    tmp = *a;
    *a = *b;
    *b = tmp;
}
void swap( float *a, float *b){
    float tmp;
    tmp = *a;
    *a = *b;
    *b = tmp;   
}
void myReplace(std::string& str, const std::string& oldStr, const std::string& newStr){
    size_t pos = 0;
    while((pos = str.find(oldStr, pos)) != std::string::npos)
    {
        str.replace(pos, oldStr.length(), newStr);
        pos += newStr.length();
    }
}
float linear_interp( float a, float b, float ratio){
    return (1-ratio)*a + ratio*b;
}
float scale( float val, float src_min, float src_max, float dest_min, float dest_max){
    return linear_interp( dest_min, dest_max, (val-src_min)/(src_max-src_min));
}
void rotate_buffer( short *rect, int w, int h, int direction){   
    short *temp = (short *)malloc( w*h*sizeof(short));
    int i,j;
    // Assumes rect is already north-facing. 
    // rect is a 1D, implicitly w * h array.  Rotating to east or west
    // will render an implicitly  h* w array.
    if (direction == SOUTH){
        // (i, j) ==> ( w - 1 -i, h - 1 -j)
        for( j = 0; j < h; j += 1 ){
            for( i = 0; i < w; i += 1 ){
                temp[ w*( h-1-j) + w - 1 - i] = rect[w*j+i];
            }
        }
    }
    else if( direction == EAST){
        // (i, j) => ( j, w-1-i)
        for( j = 0; j < h; j += 1 ){
            for( i = 0; i < w; i += 1 ){
                temp[ h*( w-1-i) + j] = rect[w*j+i];
            }
        }        
    }
    else if (direction == WEST){
        // (i,j) => (h-1-j, i)
        for( j = 0; j < h; j += 1 ){
            for( i = 0; i < w; i += 1 ){
                temp[ h*(i) + h-1-j] = rect[w*j+i];
            }
        }          
    }
    else{
        // Default to North: no change
        return;
    }
    
    // copy back to original buffer
    for( i = 0; i < w*h; i += 1 ){
        rect[i] = temp[i];
    }
    
    free( temp);
}
void print_arr_2d( short *arr, int w, int h){
    int i, j;
    for( j = 0; j < h; j += 1 ){
        for( i = 0; i < w; i += 1 ){
            printf("%3d ",arr[j*w+i]);
        }
        printf("\n");
    }
    printf("\n");
}

// ===============
// = Entry Point =
// = ----------- =
int main (int argc, char const *argv[]) {
    // Parse args 
    float lat, lng, lat_span, lng_span; 
    int lat_samples, lng_samples;
    int map_w, map_h, cardinal;    
    char dem_file_dir[128];
    
    // Header
    printf("content-type:application/x-javascript\n\n");

    char *query_string;
    query_string = getenv("QUERY_STRING");
    
    if( query_string ==NULL) {
        printf( "No data stored in env['QUERY_STRING']\n");
        return -1;
    }

    // parse values from a string like this:
    // <DEBUG> :
    // export QUERY_STRING="lat=35.36&lng=138.73&lat_span=0.15&lng_span=0.15&lat_samples=10&lng_samples=30&map_w=266&map_h=266&cardinal=0&dem_file_dir=..%2F..%2Fdems%2FSRTM_90m_global%2F"
    sscanf( query_string, "lat=%f&lng=%f&lat_span=%f&lng_span=%f&"\
           "lat_samples=%d&lng_samples=%d&map_w=%d&map_h=%d&cardinal=%d&dem_file_dir=%s",\
           &lat, &lng, &lat_span, &lng_span, 
           &lat_samples, &lng_samples, &map_w, &map_h, &cardinal, (char *)&dem_file_dir);        

    if (0){
        printf("var QUERY_STRING = %s;\n",query_string);        
        printf( "var lat =  %.3f;\n", lat);
        printf( "var lng =  %.3f;\n", lng);
        printf( "var lat_span =  %.3f;\n", lat_span);
        printf( "var lng_span =  %.3f;\n", lng_span);
        printf( "var lat_samples =  %d;\n", lat_samples);
        printf( "var lng_samples =  %d;\n", lng_samples);
        printf( "var map_w =  %d;\n", map_w);
        printf( "var map_h =  %d;\n", map_h);        
        printf( "var cardinal =  %d;\n", cardinal);              
        printf( "var dem_file_dir (orig)=  %s;\n", dem_file_dir);
  
    }
    
    // dem_file_dir gets passed with slashes subbed for %2F, so sub them back
    // Also sub for %2f in case these get passed through downcased by some browser.
    gDemFileDir = dem_file_dir;
    myReplace( gDemFileDir, "%2F", "/");
    myReplace( gDemFileDir, "%2f", "/"); 

    
    // The actual magic
    LatLngRegion llr( lat-lat_span/2.0, lng-lng_span/2.0, lat+lat_span/2.0, lng+lng_span/2.0);
    DemRegion reg( llr, lat_samples, lng_samples, cardinal);
    // reg.scale_for_window( map_w, map_h);
    reg.print_samples_json_float();
    
    return 0;
}

