#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <math.h>
#include <stdarg.h>

// # TODO: Make LatLng region class so I don't have to pass so many args around.

#define MAX_W 255
#define MAX_H 255

int main_js (int argc, char const *argv[]) {
    // Parse args 
    float lat, lng, lat_span, lng_span; 
    int lat_samples, lng_samples;    
    
    // Header
    printf("content-type:application/x-javascript\n\n");

    char *query_string;
    query_string = getenv("QUERY_STRING");
    // if( query_string ==NULL) {
    //     printf( "No data sent\n");
    // }
    // else {
    //     printf("var QUERY_STRING = %s;\n",query_string);
    // }

    // parse values from a string like this:
    // "QUERY_STRING = lat=40.02&lng=118.34&lat_span=0.5&lng_span=0.5&lat_samples=20&lng_samples=30;
    sscanf( query_string, "lat=%f&lng=%f&lat_span=%f&lng_span=%f&lat_samples=%d&lng_samples=%d",\
        &lat, &lng, &lat_span, &lng_span, &lat_samples, &lng_samples);

    if (0){
        
        printf("[0, 1, 2]\n");
        return 0;
    }

    time_t t;
    time(&t);

    printf( "var lat =  %.3f;\n", lat);
    printf( "var lng =  %.3f;\n", lng);
    printf( "var lat_span =  %.3f;\n", lat_span);
    printf( "var lng_span =  %.3f;\n", lng_span);
    printf( "var lat_samples =  %d;\n", lat_samples);
    printf( "var lng_samples =  %d;\n", lng_samples);

    // printf("document.getElementById('test_text').innerHTML = %ld;\n",t);
    printf("$('#test_text').html(%d);\n",lng_samples);
    return 0;
}

float linear_interp( float a, float b, float ratio){
    return (1-ratio)*a + ratio*b;
}
float scale( float val, float src_min, float src_max, float dest_min, float dest_max){
    return linear_interp( dest_min, dest_max, (val-src_min)/(src_max-src_min));
}
signed short *fill_src_samples( float dest_min_lat, float dest_max_lat, 
                                float dest_min_lng, float dest_max_lng,
                                float *src_min_lat, float *src_max_lat,
                                float *src_min_lng, float *src_max_lng,                                    
                                int *src_lat_samples, int *src_lng_samples)
{   // Fill up src_buf with data from the appropriate files, and set src_lat/lng_samples
    // so we know how big the data being returned is. 
    // NOTE: All necessary data is malloc'ed here and will need to be freed afterwards.
    // I think this is probably tacky, so revisit this when the design becomes 
    // clearer. -ETJ 18 Feb 2012
    
    // For the moment, just open and use one data file, regardless of 
    // inputs.  Ultimately, there's more logic that will go here to determine:
    // -- What scale of data should we use?
    // -- How to download data we don't already have?
    // -- What data format should we handle? Candidates are: TIFF, hgt, ARC, PGM
    signed short *src_buf = (signed short *)malloc( *src_lat_samples * *src_lng_samples * sizeof(short));
    char *filename = (char *)"/Users/jonese/Desktop/DEM2CUT/dems/ASTGTM2_N45W122_dem.pgm";
 
    return src_buf;
}
signed short *fill_raw_samples( float dest_min_lat, float dest_min_lng, 
                                float dest_max_lat, float dest_max_lng,
                                int dest_lat_samples, int dest_lng_samples, 
                                signed short *dest_buf,
                                float src_min_lat, float src_max_lat,
                                float src_min_lng, float src_max_lng,
                                int src_lat_samples, int src_lng_samples, 
                                signed short *src_buf)
{
    // Arguments represent two regions of different sizes with different 
    // sampling rates.  
    // For instance: 
        // 90m maps are made up of 1 degree by 1 degree squares, with 1200 samples in each direction.  
        // Destination features may be 1/16th degree square, with 25 x 100 samples, for example
    
    // Each final sample will take information from four pixels, so we'll fill 
    // dest_buf with 2*2*dest_lat_samples*dest_lng_samples samples.
    
    // move through a file as efficiently as possible, so we can touch the 
    // original large images only as many times as we have to.
    int x, y, row;
    
    // float lat_gap  = ( dest_max_lat -  dest_min_lat)/( dest_lat_samples-1);
    // float lng_gap = (dest_max_lng - dest_min_lng)/(dest_lng_samples-1);
    
    
    float min_y_index = scale( dest_min_lat,   src_min_lat, src_max_lat, 0, src_lat_samples);
    float max_y_index = scale( dest_max_lat,   src_min_lat, src_max_lat, 0, src_lat_samples );
    float lat_index_gap  = (max_y_index - min_y_index)/(dest_lat_samples - 1);
    
    float min_x_index = scale( dest_min_lng, src_min_lng, src_max_lng, 0, src_lng_samples);
    float max_x_index = scale( dest_max_lng, src_min_lng, src_max_lng, 0, src_lng_samples);
    float lng_index_gap = (max_x_index - min_x_index)/(dest_lng_samples - 1);
     
    float src_lat, src_lng; 
    int lat_index, lng_index;
    signed short *src_ptr;
    
    for( y = 0; y < dest_lat_samples; y += 1 ){
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
            src_ptr = src_ptr + (lat_index + row)*src_lng_samples;
            for( x = 0; x < dest_lng_samples; x += 1 ){
                src_lng = min_x_index + x*lng_index_gap;
                lng_index = floor( src_lng);
                dest_buf[ y*2*dest_lng_samples + 2*x]     = src_ptr[ lng_index];
                dest_buf[ y*2*dest_lng_samples + 2*x + 1] = src_ptr[ lng_index + 1];
            }
        }
    }
    return dest_buf;
}
signed short *fill_final_samples(   int lat_samples, int lng_samples, 
                                    signed short *raw_samples, 
                                    signed short *final_samples)
{
    // TODO: It would be good to look through the samples we're gathering and figure
    // out the minimum distance between any two rows.  This determines the 
    // maximal height the samples could be scaled to without layers overlapping.    
    
    // raw_samples contains four data points for each destination point. 
    // Average them and store the values in final_samples. 
    // In the future, this could be done better by bilinear interpolation
    // over a set of float lat/lng pairs. -ETJ 18 Feb 2012
    int x, y;
    signed short *top_row, *bot_row;
    for( y = 0; y < lat_samples; y += 1 ){
        top_row = raw_samples + 2*lng_samples * y;
        bot_row = raw_samples + 2*lng_samples * (y+1);
        
        for( x = 0; x < lng_samples; x += 1 ){
            final_samples[y*lng_samples + x] = (top_row[2*x] + top_row[2*x+1] + bot_row[2*x] + bot_row[2*x+1])/4;
        }
    }
    return final_samples;
}                                    
void print_dem_samples( float lat, float lng, float lat_span, 
                        float lng_span, int lat_samples, int lng_samples)
{   
    // NOTE: these buffers could be dynamically allocated to be more efficient,
    // but this is still relatively small and saves hassle.
    signed short raw_samples[ MAX_W * MAX_H * 4];
    signed short final_samples[ MAX_W * MAX_H];
    signed short *src_buf;  // will be malloc'ed in fill_src_samples
    
    int src_lat_samples, src_lng_samples;
    float src_min_lat, src_min_lng;
    float src_max_lat, src_max_lng;  
    
    float min_lat = lat - lat_span/2;
    float max_lat = lat + lat_span/2;    
                          
    float min_lng = lng - lng_span/2;
    float max_lng = lng + lng_span/2;
    
    // figure out what files we'll need to look through (up to four)    
    
    // Copy requisite map files into buffers & calculate necessary image dimensions
    fill_src_samples( min_lat, max_lat, min_lng, max_lng,
                      &src_min_lat, &src_max_lat,
                      &src_min_lng, &src_max_lng,
                      &src_lat_samples, &src_lng_samples);
                      
    // move through the files gathering all necessary sampling data
    fill_raw_samples(   lat-lat_span/2, lng-lng_span/2, lat+lat_span/2, lng+lng_span/2, 
                        lat_samples, lng_samples, raw_samples,
                        src_min_lat, src_max_lat,
                        src_max_lng, src_max_lng,
                        src_lat_samples, src_lng_samples, src_buf);

    // Put data into the final format we want;
    fill_final_samples(  lat_samples, lng_samples, raw_samples, final_samples);
    
    // And print it out, to be read by the calling webpage
}                        

int main (int argc, char const *argv[]) {
    // return main_html( argc, argv);
    return main_js( argc, argv);
}
