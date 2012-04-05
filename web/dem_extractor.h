#ifndef DEM_EXTRACTOR_H
#define DEM_EXTRACTOR_H

#define MAX(x, y) (((x) > (y)) ? (x) : (y))
#define MIN(x, y) (((x) < (y)) ? (x) : (y))

#define NORTH   0
#define SOUTH   1
#define EAST    2
#define WEST    3
class LatLngRegion;

class LatLng{
public:
    float lat;
    float lng;
    LatLng( float lat_in, float lng_in);
    LatLng();
    std::string srtm_hgt_filename();
    LatLngRegion enclosing_srtm_region();
    
};

class LatLngRegion{
// I think it's probably tacky to make everything public like this. But then, I think C++ is tacky.
public:
    float min_lat, max_lat, min_lng, max_lng;
    LatLng min_lat_lng, max_lat_lng;
    
    bool contains_point( LatLng lat_lng);
    bool contains_region( LatLngRegion other_region);
    LatLngRegion( float min_lat_in, float min_lng_in, float max_lat_in, float max_lng_in);
    LatLngRegion();    
};

class DemRegion{
    public:
        LatLngRegion region;
        int lat_samples;
        int lng_samples;
        int direction;
        signed short *buf;  
        DemRegion( LatLngRegion region_in, int lat_samples_in, int lng_samples_in, int direction_in=0);
        ~DemRegion(); 
        LatLng *lat_lngs_to_sample( LatLng *ll_list, LatLngRegion dst_region, 
                                    int dst_lat_samples, int dst_lng_samples);
        short elev_at_lat_lng( LatLng pt, FILE *tile, LatLngRegion tile_region, 
                                int tile_lat_samples, int tile_lng_samples);
        void print_samples_json_float();


      
};
// ===========
// = Helpers =
// = ------- =
int main_js (int argc, char const *argv[]);
float linear_interp( float a, float b, float ratio);
float scale( float val, float src_min, float src_max, float dest_min, float dest_max);
void rotate_buffer( short *rect, int w, int h, int direction);
void swap( int *a, int *b);
void swap( float *a, float *b);
void myReplace(std::string& str, const std::string& oldStr, const std::string& newStr);
short fread_valid_data( FILE *f, int file_addy);
inline short fread_short_bigendian( FILE *f);
inline short saturate( short v, short min_val, short max_val);

#endif /* end of include guard: DEM_EXTRACTOR_H */


