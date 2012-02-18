#include <stdio.h>
#include <stdlib.h>
#include <time.h>

int main_js (int argc, char const *argv[]) {
    // Parse args 
    float lat, long_, lat_span, long_span; 
    int lat_samples, long_samples;    
    
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
    // "QUERY_STRING = lat=40.02&long=118.34&lat_span=0.5&long_span=0.5&lat_samples=20&long_samples=30;
    sscanf( query_string, "lat=%f&long=%f&lat_span=%f&long_span=%f&lat_samples=%d&long_samples=%d",\
        &lat, &long_, &lat_span, &long_span, &lat_samples, &long_samples);

    if (0){
        
        printf("[0, 1, 2]\n");
        return 0;
    }

    time_t t;
    time(&t);

    printf( "var lat =  %.3f;\n", lat);
    printf( "var long =  %.3f;\n", long_);
    printf( "var lat_span =  %.3f;\n", lat_span);
    printf( "var long_span =  %.3f;\n", long_span);
    printf( "var lat_samples =  %d;\n", lat_samples);
    printf( "var long_samples =  %d;\n", long_samples);

    // printf("document.getElementById('test_text').innerHTML = %ld;\n",t);
    printf("$('#test_text').html(%d);\n",long_samples);

}
#define MAX_W 255
#define MAX_H 255

float linear_interp( float a, float b, float ratio){
    return (1-ratio)*a + ratio*b;
}
float scale( float val, float src_min, float src_max, float dest_min, float dest_max)
    return linear_interp( dest_min, dest_max, (val-src_min)/(src_max-src_min));
end
signed short value_at_point( float lat, float long, 
                            float buf_min_lat, float buf_min_long,
                            float buf_max_lat, float buf_max_long,
                            int buf_lat_samples, int buf_long_samples, 
                            signed short *buf)
{
    // This would be the least efficient possible way of moving through a larg file.
    // Called on an entire image, it would touch the image memory twice for every
    // pixel we wanted, as opposed to once or less for every row in the image.
}                            
void fill_raw_samples(  float dest_min_lat, float dest_min_long, 
                        float dest_max_lat, float dest_max_long,
                        int dest_lat_samples, int dest_long_samples, 
                        signed_short *dest_buf,
                        float src_min_lat, float src_min_long,
                        float src_max_lat, float src_max_long,
                        int src_lat_samples, int src_long_samples, 
                        signed short *src_buf)
{
    // Arguments represent two regions of different sizes with different 
    // sampling rates.  
    // For instance: 
        // 90m maps are made up of 1 degree by 1 degree squares, with 1200 samples in each direction.  
        // Destination features may be 1/16th degree square, with 25 x 100 samples, for example
    
    
    // move through a file as efficiently as possible, so we can touch the 
    // original large images only as many times as we have to.
    int x, y, row;
    
    float lat_gap  = ( dest_max_lat -  dest_min_lat)/( dest_lat_samples-1);
    float long_gap = (dest_max_long - dest_min_long)/(dest_long_samples-1);
    
    float lat_index_gap = scale( lat_gap,)
    
    float min_y_index = scale( dest_min_lat,   src_min_lat,  src_max_lat, 0,  src_lat_samples);
    float min_x_index = scale( dest_min_long, src_min_long, src_max_long, 0, src_long_samples);
    
    
    
    for( y = 0; y < lat_samples; y += 1 ){
        for( row = 0; row < 2; row += 1 ){
            src_lat = dest_min_lat + (y+row)*
            for( x = 0; x < long_samples; x += 1 ){
                
            }
        }
    }
}
void print_dem_samples( float lat, float long, float lat_span, 
                        float long_span, int lat_samples, int long_samples)
{   

    signed short raw_samples[ MAX_W * MAX_H * 4];
    signed short final_samples[ MAX_W * MAX_H];
    
    // figure out what files we'll need to look through (up to four)    
    
    // Each value we're outputting should be parametrized from the four
    // nearest map points.  Figure out the indexes we're looking for.
    
    // It would be good to look through the samples we're gathering and figure
    // out the minimum distance between any two rows.  This determines the 
    // maximal height the samples could be scaled to without layers overlapping.
    
    // move through the files gathering all necessary sampling data
}                        

int main (int argc, char const *argv[]) {
    // return main_html( argc, argv);
    return main_js( argc, argv);
}
