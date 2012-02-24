#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <stdarg.h>
#include <string>

#include "dem_extractor.h"
std::string gDemFileDir;

LatLng::LatLng():lat(0), lng(0){}
LatLng::LatLng( float lat_in, float lng_in): lat(lat_in), lng(lng_in){}
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
    

    
    // TODO: dem file location should be passed in as part of CGI script
    // std::string file_dir = "../../dems/SRTM_90m_global/";
    std::string filename = gDemFileDir + region.min_lat_lng.srtm_hgt_filename();
    FILE *f = fopen( filename.c_str(), "r");
    // ETJ DEBUG
    
    if (!f){
        printf( "Failed to read from file:\n\t \"%s\"\n", filename.c_str());
        return -1;
    }
    // END DEBUG */
        
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
    float min_y_index = scale( dst_min_lat,   src_min_lat, src_max_lat, src_lat_samples, 0);
    float max_y_index = scale( dst_max_lat,   src_min_lat, src_max_lat, src_lat_samples, 0);
    float lat_index_gap  = (max_y_index - min_y_index)/(dst_lat_samples - 1);
    
    float min_x_index = scale( dst_min_lng, src_min_lng, src_max_lng, 0, src_lng_samples);
    float max_x_index = scale( dst_max_lng, src_min_lng, src_max_lng, 0, src_lng_samples);
    float lng_index_gap = (max_x_index - min_x_index)/(dst_lng_samples - 1);
    
    float src_lat, src_lng; 
    int lat_index, lng_index;
    
        
    signed short *tmp_ptr = tmp_buf;
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
            // src_ptr = src_ptr + (lat_index + row)*src_lng_samples;
            for( x = 0; x < dst_lng_samples; x += 1 ){
                src_lng = min_x_index + x*lng_index_gap;
                lng_index = floor( src_lng);
    /* ETJ DEBUG
                printf( "File f address is: %ld\n", (long)f);
    return 1;
    // END DEBUG */                          
                file_addy =  (src_lng_samples*(lat_index+row) + lng_index)*bps;
                fseek( f, file_addy, SEEK_SET);
                // fread( tmp_ptr, 2, bps, f);
                // tmp_ptr += 2;
                *tmp_ptr++ = fread_short_bigendian( f);
                *tmp_ptr++ = fread_short_bigendian( f);
                
      
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
            *dst_ptr++ = total;
        }
        
    }
    
    free( tmp_buf);
    return 0;
}
void DemRegion::print_samples_json(){
    int x,y;
    signed short *samp = buf;
    printf("[ ");
    for( y = 0; y < lat_samples; y += 1 ){
        printf("[ ");
        for( x = 0; x < lng_samples-1; x += 1 ){
            printf("%6d, ", *samp++);
        }
        printf("%6d ],\n",*samp++);
    }
    printf("]\n");
}
#define MAX_W 255 
#define MAX_H 255

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
    char dem_file_dir[128];
    
    // Header
    printf("content-type:application/x-javascript\n\n");

    char *query_string;
    query_string = getenv("QUERY_STRING");
    
    if( query_string ==NULL) {
        printf( "No data stored in env['QUERY_STRING']\n");
        return -1;
    }
    else {
        // printf("var QUERY_STRING = %s;\n",query_string);
    }

    // parse values from a string like this:
    // <DEBUG> export QUERY_STRING="lat=0.62&long=16.47&lat_span=0.15&long_span=0.15&lat_samples=10&long_samples=30&dem_file_dir=%2FUsers%2Fjonese%2FSites%2FDEM2CUT%2Fdems%2FSRTM_90m_global%2F"
    // <REMOTE>export QUERY_STRING="lat=40.02&long=118.34&lat_span=0.5&long_span=0.5&lat_samples=20&long_samples=30&dem_file_dir=%2Fhome%2Fetjones%2Fwebapps%2Fhtdocs%2FDEM2CUT%2Fdems%2FSRTM_90m_global%2F"
    sscanf( query_string, "lat=%f&long=%f&lat_span=%f&long_span=%f&"\
           "lat_samples=%d&long_samples=%d&dem_file_dir=%s",\
           &lat, &lng, &lat_span, &lng_span, &lat_samples, &lng_samples, (char *)&dem_file_dir);        

    if (0){
        printf( "var lat =  %.3f;\n", lat);
        printf( "var lng =  %.3f;\n", lng);
        printf( "var lat_span =  %.3f;\n", lat_span);
        printf( "var lng_span =  %.3f;\n", lng_span);
        printf( "var lat_samples =  %d;\n", lat_samples);
        printf( "var lng_samples =  %d;\n", lng_samples);
        printf( "var dem_file_dir (orig)=  %s;\n", dem_file_dir);
    }
    
    // dem_file_dir gets passed with slashes subbed for %2F, so sub them back
    // Also sub for %2f in case these get passed through downcased by some browser.
    gDemFileDir = dem_file_dir;
    myReplace( gDemFileDir, "%2F", "/");
    myReplace( gDemFileDir, "%2f", "/"); 
    
    // printf("$('#test_text').html(%d);\n",lng_samples);
    
    // The actual magic
    LatLng min_ll( lat-lat_span, lng-lng_span);
    LatLng max_ll( lat+lat_span, lng+lng_span);
    LatLngRegion llr( min_ll, max_ll);
    DemRegion reg( llr, lat_samples, lng_samples);
    reg.print_samples_json();
    
    // FIXME: we print out a javascript/json formatted array, but our 
    // javascript code doesn't seem to like it.  What next?
    
    return 0;
}

void myReplace(std::string& str, const std::string& oldStr, const std::string& newStr)
{
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
