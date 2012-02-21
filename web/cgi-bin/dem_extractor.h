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
      DemRegion( LatLngRegion region_in);
      
      void print_samples_json();
      
};
#endif /* end of include guard: DEM_EXTRACTOR_H */


