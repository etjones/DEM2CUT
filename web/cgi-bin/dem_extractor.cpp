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

LatLng::LatLng():lat(0), lng(0){}
LatLng::LatLng( float lat_in, float lng_in): lat(lat_in), lng(lng_in){
    // Justify our measurements so they fall within (-90, 90) lat & (-180, 180) lng
    lng = fmodf(lng + 180, 360.0)-180;
    if ( lat < -90){ lat = -90.0;}
    if ( lat > 90) { lat = 90.0;}
}
std::string LatLng::srtm_hgt_filename(){
    // # FIXME: Looking for Mt Fuji (N35E138 at: /N35W222.hgt)
    // Problem with Google's address?
    int lati = floor( lat);
    int lngi = floor( lng);
    
    char buff[100];
    sprintf(buff, "%c%02d%c%03d.hgt", 
            (lati < 0 ? 'S':'N'), abs(lati),
            (lngi < 0 ? 'W':'E'), abs(lngi));
    
    std::string buffAsStdStr = buff;
    return buffAsStdStr;
}

LatLngRegion::LatLngRegion( LatLng min_lat_lng_in, LatLng max_lat_lng_in){
    // correct our min/max values so they're in order.  
    min_lat = MIN(min_lat_lng_in.lat, max_lat_lng_in.lat);
    max_lat = MAX(min_lat_lng_in.lat, max_lat_lng_in.lat);
    
    min_lng = MIN(min_lat_lng_in.lng, max_lat_lng_in.lng);
    max_lng = MAX(min_lat_lng_in.lng, max_lat_lng_in.lng);  
    
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


// First constructor: if only given a map region, find data from 
// cached DEM files.
DemRegion::DemRegion( LatLngRegion region_in, int lat_samples_in, int lng_samples_in):
region( region_in), lat_samples( lat_samples_in), lng_samples( lng_samples_in)
{
    // As a first pass, let's give DemRegion the responsibility
    // for knowing where their data will come from.  
    // Another approach might put that logic in a separate place.
    
    // Find a file(s) that contain the region we care about
    //      Todo: later, this should identify correct scale of data to 
    //      use. A map of North America should use much less granular data
    //      than a map of a single mountain.
    // It's much slower (~4x) to read an entire file and sample from that,
    // rather than to read only the data we want from the file. 
    
    
    // save memory for samples
    buf = (short *)malloc( lat_samples *lng_samples * sizeof(short));
    
    // For the moment, only handle data that's entirely in a single 1x1 degree
    // file.
    if ( floor( region.min_lat) != floor( region.max_lat)  ||
         floor( region.min_lng) != floor( region.max_lng) )
    {
        // Print an error string and exit
        printf( "Unable to view areas on more than one 1x1 degree tile\n");
        exit( -1);
    }
    
    if (read_from_file_sparse()) {
        // Throw error
        printf( "Failed to read from file\n");
    }
    
    
}
DemRegion::~DemRegion(){
    free(buf);
}
int DemRegion::read_from_file_sparse(){
    // First pass: We're reading from a single 1x1 degree hgt file, into
    // our own LatLngRegion, with lat_samples x lng_samples
    float src_min_lat = floor( region.min_lat);
    float src_max_lat =  ceil( region.max_lat);
    float src_min_lng = floor( region.min_lng);
    float src_max_lng =  ceil( region.max_lng);
    
    float dst_min_lat = region.min_lat;
    float dst_max_lat = region.max_lat;
    float dst_min_lng = region.min_lng;
    float dst_max_lng = region.max_lng;    
    
    int src_lat_samples = 1201;
    int src_lng_samples = 1201;
    int dst_lat_samples = lat_samples;
    int dst_lng_samples = lng_samples;
    
    int bps = 2; // bytes per sample
    
    signed short *tmp_buf = (signed short *)malloc( dst_lat_samples*dst_lng_samples*4*bps);
    
    std::string filename = gDemFileDir + region.min_lat_lng.srtm_hgt_filename();
    FILE *f = fopen( filename.c_str(), "r");
    
    if (!f){
        printf( "Failed to read from file:\n\t \"%s\"\n", filename.c_str());
        return -1;
    }
        
    // Arguments represent two regions of different sizes with different 
    // sampling rates.  
    // For instance: 
    // 90m maps are made up of 1 degree by 1 degree squares, with 1200 samples in each direction.  
    // dstination features may be 1/16th degree square, with 25 x 100 samples, for example
    
    // Each final sample will take information from four pixels, so we'll fill 
    // dst_buf with 2*2*dst_lat_samples*dst_lng_samples samples.
    
    // move through a file as efficiently as possible, so we can touch the 
    // original large images only as many times as we have to.
    int x, y, row;
    
    // Note that lat goes north as it increases, but indices go south as they increase.
    // So y indices are inverted
    float min_y_index = scale( dst_max_lat,   src_min_lat, src_max_lat, src_lat_samples, 0);
    float max_y_index = scale( dst_min_lat,   src_min_lat, src_max_lat, src_lat_samples, 0);
    float lat_index_gap  = (max_y_index - min_y_index)/(dst_lat_samples - 1);
    
    float min_x_index = scale( dst_min_lng, src_min_lng, src_max_lng, 0, src_lng_samples);
    float max_x_index = scale( dst_max_lng, src_min_lng, src_max_lng, 0, src_lng_samples);
    float lng_index_gap = (max_x_index - min_x_index)/(dst_lng_samples - 1);
    
    float src_lat, src_lng; 
    int lat_index, lng_index;
    
    signed short *tmp_ptr = tmp_buf;
    signed short a, b;
    int read_forward_offset =0;
    
    long file_addy;
    for( y = 0; y < dst_lat_samples; y += 1 ){
        src_lat = min_y_index + y*lat_index_gap;
        lat_index = floor( src_lat);
        
        // If we would run past the bottom of the image, decrement lat_index
        if ( lat_index + 2 >= src_lng_samples ){ lat_index = src_lng_samples - 2;}
        
        // NOTE: to really do our interpolations right, we'd have to save float
        // values of (lat, lng) for for each 4 points below, then interpolate 
        // between them based on those values.  
        // I'm assuming that elevations between data points are close enough
        // that a simple average will be accurate enough.  Depending on the scale
        // of maps used, this could cause significant errors, though. -ETJ 18 Feb 2012
        for( row = 0; row < 2; row += 1 ){
            for( x = 0; x < dst_lng_samples; x += 1 ){
                src_lng = min_x_index + x*lng_index_gap;
                lng_index = floor( src_lng);   
                file_addy =  (src_lng_samples*(lat_index+row) + lng_index)*bps;
                fseek( f, file_addy, SEEK_SET);
                a = fread_short_bigendian( f);
                b = fread_short_bigendian( f);
                // If there's a gap in data, move forward until 
                // we find valid data, and use that. 
                if ( a == NO_DATA && b == NO_DATA){
                    read_forward_offset = 0;
                    // FIXME: This is an error if we run off the right side of the image.
                    // Correct would be to search backward if we're on the right edge
                    while( a == NO_DATA){
                        a = fread_short_bigendian( f);
                    }
                    b = a;
                }
                else {
                    // If only one of our samples is NO_DATA, use the other
                    if ( a == NO_DATA){ a = b;}
                    if ( b == NO_DATA){ b = a;}
                }
                *tmp_ptr++ = a;
                *tmp_ptr++ = b;
            }
        }
    }
    
    // Run through tmp_buf, averaging values and storing them in persistent this.buf
    int total = 0;
    short *dst_ptr = buf;
    short *tmp_top = tmp_buf;
    short *tmp_bot = tmp_top + 2*dst_lng_samples; 
    for( y = 0; y < dst_lat_samples; y += 1 ){
        tmp_top = tmp_buf + 4*dst_lng_samples*y;
        tmp_bot = tmp_buf + 4*dst_lng_samples*y + 2*dst_lng_samples;        
        for( x = 0; x < dst_lng_samples; x += 1 ){
            total = (tmp_top[2*x] + tmp_top[2*x + 1] + tmp_bot[2*x] + tmp_bot[2*x+1])>>2;
            *dst_ptr++ = saturate( total, MIN_ELEVATION, MAX_ELEVATION);
        }
        
    }
    
    free( tmp_buf);
    return 0;
}
void DemRegion::print_samples_json(){
    int x,y;
    signed short *samp = buf;
    printf("[ \n");
    for( y = 0; y < lat_samples; y += 1 ){
        printf("[ ");
        for( x = 0; x < lng_samples-1; x += 1 ){
            printf("%6d, ", *samp++);
        }
        printf("%6d ]%c\n",*samp++, (y<lat_samples-1 ? ',': ' '));
    }
    printf("]\n");
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

void DemRegion::scale_for_window( int map_w, int map_h){
    // scale all extant values so that min and max fall within a region
    // of about map_h/(lat_samples-1)
    
    // Scale extant values so they're as large as possible while 
    // A) Fitting in the (map_w, map_h) window they've been given, and
    // B) Maintaining at least MIN_INTER_SLICE_DISTANCE units between each slice
    
    // The data array we're working with is likely so small ( < 2000 samples)
    // that it's not worth clumping each of these actions together at once.
    // Unless, well, you want to.  Then go for it...
    int x,y;
    int src_range = 0, dest_range= 0;

    // Move through array, calculating min & max values 
    short min = 10000, max= -10000;
    for(y = 0; y < lat_samples * lng_samples; y += 1 ){
        if ( buf[y] < min){ min = buf[y];}
        if ( buf[y] > max){ max = buf[y];}
    }
    
    
    src_range = max - min;
    dest_range = map_h / lat_samples; // This means every section is self-contained.  
    // That's not really what we need, since we can go above the next section if the next
    // section is also going up.  So leaving dest_range at only map_h/lat_samples is overly conservative.
    
    
    // Subtract min from all values so 0 is the baseline. Otherwise, patterns
    // on the Tibetan plateau might all go off the top of the page
    for(y = 0; y < lat_samples * lng_samples; y += 1 ){
        buf[y] -= min;
    }    
    
    // Calculate minimal distance between the same point in two adjacent slices
    short min_inter_slice_distance = 10000;
    short dif = 0;
    for( y = 0; y < lat_samples - 1; y += 1 ){
        for( x = 0; x < lng_samples; x += 1 ){
            dif = buf[lng_samples*y + x] - buf[lng_samples*(y+1) + x] ;
            if ( dif < min_inter_slice_distance){ min_inter_slice_distance = dif;}
        }
    }
    
    /* ETJ DEBUG
    printf( "****** Before scale: **************\n");
    
    for( y = 0; y < lat_samples; y += 1 ){
        for( x = 0; x < lng_samples; x += 1 ){
            printf( "%-4d ", buf[lng_samples*y + x]);
        }
        printf("\n");
    }
    printf("\n");
    printf("\n");
    // END DEBUG */
    
    // TODO: scale correctly so that we send the maximum permissible range.
    
    // Scale all values so that min_inter_slice_distance maps to MIN_INTER_SLICE_DISTANCE
    min_inter_slice_distance *= (min_inter_slice_distance < 0 ? 1 : -1);
    // float scale = (float)(MIN_INTER_SLICE_DISTANCE)/min_inter_slice_distance;
    float scale = (float)dest_range/src_range;
    for(y = 0; y < lat_samples * lng_samples; y += 1 ){
        buf[y] = (short)(buf[y] * scale);
    }   
    
    /* ETJ DEBUG
    printf( "****** After scale: **************\n");
    for( y = 0; y < lat_samples; y += 1 ){
        for( x = 0; x < lng_samples; x += 1 ){
            printf( "%-4d ", buf[lng_samples*y + x]);
        }
        printf("\n");
    }
    printf("\n");
    printf("\n");
    // END DEBUG */
     
    
}
inline short saturate( short v, short min_val, short max_val){
    if (v <= min_val){ return min_val;}
    if (v >= max_val){ return max_val;}
    return v;
}
inline short fread_short_bigendian( FILE *f){
    unsigned char a, b;
    fread( &a, 1, 1, f);
    fread( &b, 1, 1, f);
    return ((a << 8) | b);
}
int main_js (int argc, char const *argv[]) {
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
    // <DEBUG> export QUERY_STRING="lat=0.62&lng=16.47&lat_span=0.15&lng_span=0.15&lat_samples=10&lng_samples=30&map_w=266&map_h=266&cardinal=0&dem_file_dir=%2FUsers%2Fjonese%2FSites%2FDEM2CUT%2Fdems%2FSRTM_90m_global%2F"
    // <REMOTE>export QUERY_STRING="lat=0.62&lng=16.47&lat_span=0.15&lng_span=0.15&lat_samples=10&lng_samples=30&map_w=266&map_h=266&cardinal=0&dem_file_dir=%2Fhome%2Fetjones%2Fwebapps%2Fhtdocs%2FDEM2CUT%2Fdems%2FSRTM_90m_global%2F"
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
    LatLng min_ll( lat-lat_span, lng-lng_span);
    LatLng max_ll( lat+lat_span, lng+lng_span);
    LatLngRegion llr( min_ll, max_ll);
    DemRegion reg( llr, lat_samples, lng_samples);
    // reg.scale_for_window( map_w, map_h);
    reg.print_samples_json_float();
    
    return 0;
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


int main (int argc, char const *argv[]) {
    // return main_html( argc, argv);
    return main_js( argc, argv);
}
