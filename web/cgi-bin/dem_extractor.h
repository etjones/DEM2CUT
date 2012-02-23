#ifndef DEM_EXTRACTOR_H
#define DEM_EXTRACTOR_H

#define MAX(x, y) (((x) > (y)) ? (x) : (y))
#define MIN(x, y) (((x) < (y)) ? (x) : (y))

class LatLng{
public:
    float lat;
    float lng;
    LatLng( float lat_in, float lng_in);
    LatLng();
    std::string srtm_hgt_filename();
};

class LatLngRegion{
// I think it's probably tacky to make everything public like this. 
public:
    float min_lat, max_lat, min_lng, max_lng;
    LatLng min_lat_lng, max_lat_lng;
    
    bool contains_point( LatLng lat_lng);
    bool contains_region( LatLngRegion other_region);
    LatLngRegion( LatLng min_lat_lng_in, LatLng max_lat_lng_in);
    
};

class DemRegion{
  public:
      LatLngRegion region;
      int lat_samples;
      int lng_samples;
      signed short *buf;  
      DemRegion( LatLngRegion region_in, int lat_samples_in, int lng_samples_in);
      ~DemRegion()      ;
      int read_from_file_sparse();      
      void print_samples_json();
      
};
// ===========
// = Helpers =
// = ------- =
int main_js (int argc, char const *argv[]);
float linear_interp( float a, float b, float ratio);
float scale( float val, float src_min, float src_max, float dest_min, float dest_max);
void myReplace(std::string& str, const std::string& oldStr, const std::string& newStr);
inline short fread_short_bigendian( FILE *f);

#endif /* end of include guard: DEM_EXTRACTOR_H */


